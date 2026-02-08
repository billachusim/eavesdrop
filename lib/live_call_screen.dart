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
  bool _isJoiningChannel = true;
  bool _isBroadcaster = false;

  @override
  void initState() {
    super.initState();
    initializeAgora();

    final user = Provider.of<User?>(context, listen: false);
    // Show auth wall after 60 seconds if user is a guest
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && user == null) {
        setState(() {
          _showAuthWall = true;
          _agoraService.muteAllRemoteAudioStreams(true);
        });
      }
    });
  }

  Future<void> initializeAgora() async {
    final user = Provider.of<User?>(context, listen: false);
    if (user == null) {
      if (mounted) {
        setState(() => _isJoiningChannel = false);
      }
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
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission is required to broadcast.'),
          ));
          setState(() => _isJoiningChannel = false);
        }
        return;
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

    if (mounted) {
      setState(() {
        _isJoiningChannel = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _stopRecordingAndUpload() async {
    if (!_isBroadcaster) return;
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
    if (endCall) {
      await _db.endCall(widget.call.id);
    }
    await _stopRecordingAndUpload();
    await _agoraService.leaveChannel();
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
                  ],
                ),
              );
            },
          )
        : const OnboardingScreen();
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
          onPressed: () async {
            final navigator = Navigator.of(context);
            await _leaveChannel(endCall: isPrivilegedUser);
            navigator.pop();
          },
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
                left: index * 22,
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
            onPressed: () {},
            icon: const Icon(Icons.question_answer_outlined),
            label: const Text("Send a Question"),
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
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _leaveChannel(endCall: true);
              navigator.pop();
            },
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
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _leaveChannel();
              navigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Leave Quietly",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}

class SpeakerAvatar extends StatelessWidget {
  final String name;
  final String image;
  final bool isSpeaking;

  const SpeakerAvatar({
    super.key,
    required this.name,
    required this.image,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AvatarGlow(
          animate: isSpeaking,
          glowColor: Colors.greenAccent,
          duration: const Duration(milliseconds: 2000),
          glowRadiusFactor: 60,
          child: CircleAvatar(
            radius: 42,
            backgroundImage: NetworkImage(image),
          ),
        ),
        const SizedBox(height: 10),
        Text(name),
      ],
    );
  }
}
