import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:eavesdrop/auth/onboarding_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/agora_service.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class LiveCallScreen extends StatefulWidget {
  final CallModel call;

  const LiveCallScreen({super.key, required this.call});

  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends State<LiveCallScreen> {
  final DatabaseService _db = DatabaseService();
  final AgoraService _agoraService = AgoraService();
  final StorageService _storageService = StorageService();
  bool _showAuthWall = false;
  bool _isMuted = false;
  bool _isBroadcaster = false;
  bool _isProcessingEnd = false;

  // A list to hold questions sent during the call
  final List<Map<String, String>> _questions = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await initializeAgora();
      final user = Provider.of<User?>(context, listen: false);
      // Show auth wall after 60 seconds if user is a guest
      if (mounted && user == null) {
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) {
            setState(() {
              _showAuthWall = true;
              _agoraService.muteAllRemoteAudioStreams(true);
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join call: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> initializeAgora() async {
    final user = Provider.of<User?>(context, listen: false);
    if (user == null) {
      // Guest logic: Initialize and join as audience
      await _agoraService.initialize();
      // Guests don't need a token for audience role usually, but if your setup requires it, handle that here.
      // For simplicity, we assume guests can listen without a specific token.
      await _agoraService.joinChannel('', widget.call.channelName, 0, ClientRoleType.clientRoleAudience);
      return;
    }

    final userModel = await _db.streamUser(user.uid).first;
    final isBroadcaster = user.uid == widget.call.hostId ||
        userModel.isAdmin ||
        userModel.isSuperAdmin;

    if (mounted) {
      setState(() => _isBroadcaster = isBroadcaster);
    }

    if (isBroadcaster) {
      if (await Permission.microphone.request() != PermissionStatus.granted) {
        throw Exception('Microphone permission is required to broadcast.');
      }
    }

    await Permission.bluetoothConnect.request();
    await _agoraService.initialize();

    final role = isBroadcaster
        ? ClientRoleType.clientRoleBroadcaster
        : ClientRoleType.clientRoleAudience;

    final functions = FirebaseFunctions.instance;
    final results = await functions.httpsCallable('generateAgoraToken').call({
      'channelName': widget.call.channelName,
      'uid': user.uid.hashCode,
    });
    final token = results.data['token'];

    await _agoraService.joinChannel(
        token, widget.call.channelName, user.uid.hashCode, role);

    if (isBroadcaster) {
      await _agoraService.startRecording();
    }
  }

  @override
  void dispose() {
    // IMPORTANT: Dispose the Agora service to release the engine.
    _agoraService.dispose();
    super.dispose();
  }

  Future<void> _stopRecordingAndUpload() async {
    if (!_isBroadcaster) return;

    // Show saving indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving recording...')),
      );
    }

    final recordingPath = await _agoraService.stopRecording();
    if (recordingPath != null) {
      final recordingUrl = await _storageService.uploadFile(
          recordingPath, 'recordings/${widget.call.id}.aac');
      if (recordingUrl != null && mounted) {
        await _db.updateCallRecordingUrl(widget.call.id, recordingUrl);
      }
    }
  }

  Future<void> _leaveChannel({bool endCall = false}) async {
    if (_isProcessingEnd) return; // Prevent double taps

    // 1. Show Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(endCall ? 'End Call?' : 'Leave Call?'),
        content: Text(endCall
            ? 'This will end the call for everyone and save the recording.'
            : 'Are you sure you want to leave quietly?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 2. Start Progress Indicator
    setState(() => _isProcessingEnd = true);

    try {
      final navigator = Navigator.of(context);

      // 3. Execute logic
      if (endCall && _isBroadcaster) {
        await _stopRecordingAndUpload();
        await _db.endCall(widget.call.id);
      }

      await _agoraService.leaveChannel();

      // 4. Pop screen
      if (navigator.canPop()) {
        navigator.pop();
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error leaving call: ${e.toString()}'))
        );
      }
    } finally {
      // 5. Stop progress indicator
      if(mounted) {
        setState(() => _isProcessingEnd = false);
      }
    }
  }

  void _handleSendQuestion(UserModel currentUser) async {
    if (currentUser.credits < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough credits. You need 100 to ask a question.')),
      );
      return;
    }

    final questionController = TextEditingController();
    final question = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ask a Question (100 Credits)'),
        content: TextField(
          controller: questionController,
          decoration: const InputDecoration(hintText: 'Type your question here...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(questionController.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (question != null && question.isNotEmpty) {
      // Deduct credits and add question to the list
      await _db.updateUserCredits(currentUser.uid, -100);
      setState(() {
        _questions.add({
          'name': ?currentUser.displayName,
          'question': question,
        });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question sent!')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();
    final user = Provider.of<User?>(context);

    return user != null
        ? StreamBuilder<UserModel>(
      stream: _db.streamUser(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0B0B),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userModel = snapshot.data!;
        final isHost = userModel.uid == widget.call.hostId;
        final isPrivilegedUser =
            isHost || userModel.isAdmin || userModel.isSuperAdmin;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0B0B),
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DefaultTextStyle(
                    style: textTheme.bodyMedium!
                        .copyWith(color: Colors.white),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _topBar(context, isPrivilegedUser),
                        const SizedBox(height: 30),
                        Text(
                          widget.call.title,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 30),
                        // New: Conditionally show questions or speakers
                        if (_questions.isNotEmpty)
                          _questionsList()
                        else
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  SpeakerAvatar(
                                    name: widget.call.userNickname,
                                    image: "https://i.pravatar.cc/300?img=5",
                                    isSpeaking: true,
                                  ),
                                  SpeakerAvatar(
                                    name: widget.call.userNickname,
                                    image: "https://i.pravatar.cc/300?img=47",
                                    isSpeaking: false,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _listenerStrip(),
                        const SizedBox(height: 20),
                        _bottomControls(context, userModel),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showAuthWall) const OnboardingScreen(),
              // New: Loading indicator for ending call
              if (_isProcessingEnd)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Ending Call...", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    )
        : const OnboardingScreen(); // Or a guest view
  }

  // New: Widget to display the list of questions
  Widget _questionsList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final item = _questions[index];
          return Card(
            color: Colors.grey[850],
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: Text(item['question']!, style: const TextStyle(color: Colors.white)),
              subtitle: Text('- ${item['name']}', style: const TextStyle(color: Colors.white70)),
            ),
          );
        },
      ),
    );
  }

  Widget _topBar(BuildContext context, bool isPrivilegedUser) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "LIVE",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.people_alt_outlined,
            size: 18, color: Colors.white70),
        const SizedBox(width: 4),
        Text("${widget.call.listeners} listening",
            style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _leaveChannel(endCall: isPrivilegedUser),
        )
      ],
    );
  }

  Widget _listenerStrip() {
    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: Stack(
            children: List.generate(
              8,
                  (index) => Positioned(
                left: index * 22.0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(
                      "https://i.pravatar.cc/150?img=${index + 10}"),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "This conversation is being broadcast.",
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _bottomControls(BuildContext context, UserModel user) {
    final bool isHost = user.uid == widget.call.hostId;
    final bool isPrivilegedUser = isHost || user.isAdmin || user.isSuperAdmin;
    final bool isJustAdmin = user.isAdmin && !user.isSuperAdmin;
    final bool canLeaveQuietly = !isJustAdmin || isHost;

    return Column(
      children: [
        if (_isBroadcaster)
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
                _agoraService.muteLocalAudioStream(_isMuted);
              });
            },
            icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            label: Text(_isMuted ? "Unmute" : "Mute"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () => _handleSendQuestion(user),
            icon: const Icon(Icons.question_answer_outlined),
            label: const Text("Send a Question (100 Credits)"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (isPrivilegedUser) ...[
          ElevatedButton(
            onPressed: () => _leaveChannel(endCall: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "End Call",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (canLeaveQuietly)
          ElevatedButton(
            onPressed: () => _leaveChannel(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Leave Quietly'),
          ),
      ],
    );
  }
}


// NOTE: SpeakerAvatar widget is not defined in this file. Assuming it exists elsewhere.
// You might need to add this if it's not defined.
class SpeakerAvatar extends StatelessWidget {
  final String name;
  final String image;
  final bool isSpeaking;

  const SpeakerAvatar({
    super.key,
    required this.name,
    required this.image,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarGlow(
      glowColor: Colors.blue,
      glowRadiusFactor: 60.0,
      duration: const Duration(milliseconds: 2000),
      repeat: true,
      glowCount: 2,
      animate: isSpeaking,
      child: Material(
        elevation: 8.0,
        shape: const CircleBorder(),
        child: CircleAvatar(
          backgroundImage: NetworkImage(image),
          radius: 40.0,
        ),
      ),
    );
  }
}
