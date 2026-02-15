import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:eavesdrop/auth/onboarding_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/paywall_overlay.dart';
import 'package:eavesdrop/services/agora_service.dart';
import 'package:eavesdrop/services/call_state_service.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/services/ringtone_service.dart';
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
  bool _showPaywall = false;
  bool _isMuted = false;
  bool _isBroadcaster = false;
  bool _isProcessingEnd = false;
  bool _hasJoinedListeners = false;
  String _connectionLabel = 'Connecting…';
  bool _connectionWarning = false;
  static const Duration _freeTrialDuration = Duration(minutes: 10);
  Duration _freeTrialRemaining = _freeTrialDuration;
  Timer? _trialTimer;



  @override
  void initState() {
    super.initState();
    _initialize();
    CallStateService.activeCallId = widget.call.id;
  }

  Future<void> _initialize() async {
    try {
      await _initializeAgora();
      // Free-trial timer + paywall/auth walls.
      if (mounted) {
        _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          if (_isBroadcaster) {
            timer.cancel();
            return;
          }
          setState(() {
            _freeTrialRemaining -= const Duration(seconds: 1);
          });
          if (_freeTrialRemaining <= Duration.zero) {
            timer.cancel();
          }
        });

        Future.delayed(_freeTrialDuration, () {
          if (!mounted) return;

          // Re-check user status inside the delayed future.
          final currentUser = Provider.of<User?>(context, listen: false);
          if (currentUser == null) {
            // For guest users, show the Auth Wall.
            setState(() {
              _showAuthWall = true;
              _agoraService.muteAllRemoteAudioStreams(true);
            });
          } else if (!_isBroadcaster) {
            // For signed-in, non-host users, show the Paywall.
            setState(() {
              _showPaywall = true;
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

  Future<void> _initializeAgora() async {
    final user = Provider.of<User?>(context, listen: false);
    if (user == null) {
      // Guest logic: Initialize and join as audience
      await _agoraService.initialize(
        onConnectionStateChanged: (connection, state, reason) {
          if (!mounted) return;
          setState(() {
            switch (state) {
              case ConnectionStateType.connectionStateConnecting:
                _connectionLabel = 'Connecting…';
                _connectionWarning = false;
                break;
              case ConnectionStateType.connectionStateConnected:
                _connectionLabel = 'Connected';
                _connectionWarning = false;
                break;
              case ConnectionStateType.connectionStateReconnecting:
                _connectionLabel = 'Reconnecting…';
                _connectionWarning = true;
                break;
              case ConnectionStateType.connectionStateFailed:
                _connectionLabel = 'Connection failed';
                _connectionWarning = true;
                break;
              case ConnectionStateType.connectionStateDisconnected:
                _connectionLabel = 'Disconnected';
                _connectionWarning = true;
                break;
              default:
                _connectionLabel = 'Updating…';
                _connectionWarning = false;
                break;
            }
          });
        },
      );
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
    await _agoraService.initialize(
      onConnectionStateChanged: (connection, state, reason) {
        if (!mounted) return;
        setState(() {
          switch (state) {
            case ConnectionStateType.connectionStateConnecting:
              _connectionLabel = 'Connecting…';
              _connectionWarning = false;
              break;
            case ConnectionStateType.connectionStateConnected:
              _connectionLabel = 'Connected';
              _connectionWarning = false;
              break;
            case ConnectionStateType.connectionStateReconnecting:
              _connectionLabel = 'Reconnecting…';
              _connectionWarning = true;
              break;
            case ConnectionStateType.connectionStateFailed:
              _connectionLabel = 'Connection failed';
              _connectionWarning = true;
              break;
            case ConnectionStateType.connectionStateDisconnected:
              _connectionLabel = 'Disconnected';
              _connectionWarning = true;
              break;
              default:
                _connectionLabel = 'Updating…';
                _connectionWarning = false;
                break;
          }
        });
      },
    );

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

    if (!_hasJoinedListeners) {
      await _db.joinCallListeners(
          widget.call.id, userModel.uid, userModel.photoURL.toString());
      if (mounted) {
        setState(() {
          _hasJoinedListeners = true;
        });
      }
    }
    if (isBroadcaster) {
      await _agoraService.startRecording();
    }
  }

  @override
  void dispose() {
    _agoraService.leaveChannel().then((_) {
      _agoraService.dispose();
    });
    _trialTimer?.cancel();
    if (CallStateService.activeCallId == widget.call.id) {
      CallStateService.activeCallId = null;
    }
    RingtoneService.stopRingtone();
    super.dispose();
  }

  Future<void> _stopRecordingAndUpload() async {
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

    setState(() => _isProcessingEnd = true);

    try {
      if (endCall && _isBroadcaster) {
        _stopRecordingAndUpload();
        await _db.endCall(widget.call.id);
      }

      await _agoraService.leaveChannel();

      // Use context-aware Navigator and check if mounted before popping.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error leaving call: ${e.toString()}')));
      }
    } finally {
      // Ensure state is not set on an unmounted widget.
      if (mounted) {
        setState(() => _isProcessingEnd = false);
      }
    }
  }


  void _handleSendQuestion(UserModel currentUser) async {if (currentUser.credits < 20) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not enough credits. You need 20 to ask a question.')),
    );
    return;
  }

  final questionController = TextEditingController();
  final question = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ask a Question (20 Credits)'),
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
    await _db.updateUserCredits(currentUser.uid, -20);
    // Save question to the database
    await _db.addQuestionToCall(widget.call.id, {
      'userId': currentUser.uid,
      'name': currentUser.displayName,
      'photoURL': currentUser.photoURL,
      'question': question,
      'upvotes': 0,
      'pinned': false,
      'dismissed': false,
      'timestamp': DateTime.now(),
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
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0B0B),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userModel = userSnapshot.data!;
        final isHost = userModel.uid == widget.call.hostId;
        final isPrivilegedUser =
            isHost || userModel.isAdmin || userModel.isSuperAdmin;

        // NEW: StreamBuilder to listen for call state changes
        return StreamBuilder<CallModel?>(
          stream: _db.streamCall(widget.call.id),
          builder: (context, callSnapshot) {
            if (!callSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFF0B0B0B),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final call = callSnapshot.data!;
            // If call has ended, pop the screen
            if (call.hasEnded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
            }

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
                              call.title, // Use title from stream
                              textAlign: TextAlign.center,
                              style: textTheme.titleLarge!.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _reactionsTicker(),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Center(
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SpeakerAvatar(
                                      name: widget.call.hostName,
                                      image: widget.call.personalityAvatar,
                                      isSpeaking: true,
                                    ),
                                    SpeakerAvatar(
                                      name: widget.call.userNickname,
                                      image: widget.call.userPhotoURL,
                                      isSpeaking: false,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Show questions list only for admin/host
                            if (isPrivilegedUser)
                              _questionsList(),
                            const SizedBox(height: 20),
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
                  if (_showPaywall)
                    PaywallOverlay(
                      user: userModel,
                      onUnlock: () {
                        setState(() {
                          _showPaywall = false;
                          _agoraService.muteAllRemoteAudioStreams(false);
                        });
                      },
                    ),
                  if (_isProcessingEnd)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Ending Call...",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    )
        : const OnboardingScreen(); // Or a guest view
  }

  Widget _questionsList() {
    // Only show if user is a broadcaster (admin/host)
    //if (!_isBroadcaster) return const SizedBox.shrink();

    return Expanded(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.streamCallQuestions(widget.call.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Show a placeholder when there are no questions
            return const Center(
              child: Text(
                'Questions from users will appear here.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          final questions = [...snapshot.data!]
            ..removeWhere((q) => q['dismissed'] == true)
            ..sort((a, b) => ((b['upvotes'] ?? 0) as num).compareTo((a['upvotes'] ?? 0) as num));
          return ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final item = questions[index];
              return Card(
                color: Colors.grey[850]!.withValues(alpha: 0.8),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  // Added leading CircleAvatar for user's photo
                  leading: CircleAvatar(
                    backgroundImage: item['photoURL'] != null
                        ? NetworkImage(item['photoURL'])
                        : null,
                    child: item['photoURL'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(item['question']!, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('- ${item['name']} · ${(item['upvotes'] ?? 0)} upvotes', style: const TextStyle(color: Colors.white70)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isBroadcaster)
                        IconButton(
                          icon: const Icon(Icons.thumb_up_alt_outlined),
                          onPressed: () {
                            final currentUser = Provider.of<User?>(context, listen: false);
                            if (currentUser != null && item['id'] != null) {
                              _db.upvoteQuestion(widget.call.id, item['id'], currentUser.uid);
                            }
                          },
                        ),
                      if (_isBroadcaster && item['id'] != null)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'pin') {
                              _db.pinQuestion(widget.call.id, item['id'], true);
                            } else if (value == 'dismiss') {
                              _db.dismissQuestion(widget.call.id, item['id']);
                            } else if (value == 'ban' && item['userId'] != null) {
                              _db.banUserFromCall(widget.call.id, item['userId']);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'pin', child: Text('Pin question')),
                            PopupMenuItem(value: 'dismiss', child: Text('Dismiss question')),
                            PopupMenuItem(value: 'ban', child: Text('Ban user from room')),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
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
        StreamBuilder<CallModel?>(
            stream: _db.streamCall(widget.call.id),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text("${snapshot.data!.listeners} listening",
                    style: const TextStyle(color: Colors.white70));
              }
              return const Text("...",
                  style: TextStyle(color: Colors.white70));
            }),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _connectionWarning
                ? Colors.orange.withValues(alpha: 0.2)
                : Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _connectionLabel,
            style: TextStyle(
              color: _connectionWarning ? Colors.orangeAccent : Colors.greenAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: (){},
          icon: const Icon(Icons.stop_circle_outlined,
              color: Colors.redAccent),
          tooltip: 'Recording',
        )
      ],
    );
  }

  Widget _listenerStrip() {
    return SizedBox(
      height: 40,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.streamCallListeners(widget.call.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink(); // Or a placeholder
          }
          final listeners = snapshot.data!;
          return Stack(
            alignment: Alignment.centerLeft,
            children: List.generate(
              listeners.length > 10 ? 10 : listeners.length, // Show max 5
                  (index) {
                final listener = listeners[index];
                final photoURL = listener['photoURL'] as String?;
                return Positioned(
                  left: index * 25.0,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: photoURL != null && photoURL.isNotEmpty
                        ? NetworkImage(photoURL)
                        : null,
                    // Fallback for missing or empty URL
                    child: (photoURL == null || photoURL.isEmpty)
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _reactionsTicker() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.streamRecentReactions(widget.call.id),
      builder: (context, snapshot) {
        final reactions = snapshot.data ?? const [];
        if (reactions.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reactions.length > 10 ? 10 : reactions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final emoji = reactions[index]['emoji']?.toString() ?? '👏';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji),
              );
            },
          ),
        );
      },
    );
  }


  Widget _interactionControls(BuildContext context, UserModel userModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        FloatingActionButton(
          heroTag: 'reactions_btn',
          onPressed: () {
            final user = Provider.of<User?>(context, listen: false);
            if (user != null) {
              _db.addReactionToCall(widget.call.id, '😂', user.uid);
            }
          },
          backgroundColor: const Color(0xFF2B2B2B),
          child: const Text("😂", style: TextStyle(fontSize: 24)),
        ),
        if (_isBroadcaster)
          FloatingActionButton(
            heroTag: 'mute_btn',
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
                _agoraService.muteLocalAudioStream(_isMuted);
              });
            },
            backgroundColor:
            _isMuted ? Colors.red : const Color(0xFF2B2B2B),
            child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
          ),
        if (!_isBroadcaster) // Only show for non-broadcasters
          FloatingActionButton(
            heroTag: 'question_btn',
            onPressed: () => _handleSendQuestion(userModel),
            backgroundColor: const Color(0xFF2B2B2B),
            child: const Icon(Icons.question_answer_outlined),
          ),
        FloatingActionButton(
          heroTag: 'share_btn',
          onPressed: () {},
          backgroundColor: const Color(0xFF2B2B2B),
          child: const Icon(Icons.share_outlined),
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
        if (!_isBroadcaster)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _freeTrialRemaining > Duration.zero
                  ? 'Free trial left: ${_freeTrialRemaining.inMinutes.toString().padLeft(2, '0')}:${(_freeTrialRemaining.inSeconds % 60).toString().padLeft(2, '0')}'
                  : 'Free trial ended. Unlock to continue listening.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),

        _interactionControls(context, user),

        const SizedBox(height: 12),
        if (isPrivilegedUser) ...[
          ElevatedButton(
            onPressed: () async {
              await _leaveChannel(endCall: true);
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
              await _leaveChannel();
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
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarGlow(
          glowRadiusFactor: 50.0,
          animate: isSpeaking,
          glowColor: Colors.white,
          child: CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(image),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }
}
