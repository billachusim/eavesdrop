import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eavesdrop/booking/booking_screen.dart';
import 'package:eavesdrop/credits_screen.dart';
import 'package:eavesdrop/host_profile_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/ai_summary_service.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CallDetailsScreen extends StatefulWidget {
  final CallModel call;
  final bool autoplay;

  const CallDetailsScreen({
    super.key,
    required this.call,
    this.autoplay = false,
  });

  @override
  State<CallDetailsScreen> createState() => _CallDetailsScreenState();
}

class _CallDetailsScreenState extends State<CallDetailsScreen> {
  final DatabaseService _db = DatabaseService();
  final AiSummaryService _summaryService = AiSummaryService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const int _unlockCost = 20;
  static const Duration _freePreview = Duration(minutes: 1);

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _audioUnlocked = false;
  bool _summaryUnlocked = false;
  bool _isPromptingAudioUnlock = false;
  bool _isLoadingSummary = false;
  String? _summaryText;

  @override
  void initState() {
    super.initState();
    if (widget.call.recordingUrl != null &&
        widget.call.recordingUrl!.isNotEmpty) {
      _initAudioPlayer();
      _loadSummary();
      if (widget.autoplay) {
        _audioPlayer.play(UrlSource(widget.call.recordingUrl!));
      }
    }
  }

  Future<void> _loadSummary() async {
    if (widget.call.recordingUrl == null || widget.call.recordingUrl!.isEmpty) {
      return;
    }

    final hasConsent = await _ensureSummaryDataSharingConsent();
    if (!hasConsent) {
      if (!mounted) {
        return;
      }
      setState(() {
        _summaryText =
            'AI summary is turned off because you have not consented to share recording data with ElevenLabs.';
      });
      return;
    }

    setState(() {
      _isLoadingSummary = true;
    });

    final summary = await _summaryService.getSummary(
      callId: widget.call.id,
      recordingUrl: widget.call.recordingUrl!,
      callTitle: widget.call.title,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _summaryText = summary;
      _isLoadingSummary = false;
    });
  }

  Future<bool> _ensureSummaryDataSharingConsent() async {
    final hasConsent = await _summaryService.hasSummaryConsent();
    if (hasConsent || !mounted) {
      return hasConsent;
    }

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Allow AI summaries?'),
        content: const Text(
          'To generate an AI summary, Eavesdrop sends the call audio URL and call title to ElevenLabs. '
          'Only allow this if you consent to sharing this conversation data with ElevenLabs for summarization.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Don\'t allow'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    final allow = granted ?? false;
    await _summaryService.setSummaryConsent(allow);
    return allow;
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (!mounted) {
        return;
      }

      setState(() => _position = newPosition);
      if (!_audioUnlocked &&
          !_isPromptingAudioUnlock &&
          newPosition >= _freePreview &&
          _isPlaying) {
        _audioPlayer.pause();
        _showAudioUnlockPrompt();
      }
    });
  }

  Future<void> _showAudioUnlockPrompt() async {
    _isPromptingAudioUnlock = true;
    final unlocked = await _requestCreditUnlock(
      featureName: 'continue listening',
      title: 'Continue listening?',
      description:
          'You listened to the free first minute. Unlock the remaining recording for $_unlockCost credits.',
    );

    if (!mounted) {
      return;
    }

    if (unlocked) {
      setState(() {
        _audioUnlocked = true;
      });
      await _audioPlayer.resume();
    }

    _isPromptingAudioUnlock = false;
  }

  Future<bool> _requestCreditUnlock({
    required String featureName,
    required String title,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pay $_unlockCost credits'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return false;
    }

    final didDeduct = await _db.deductCreditsIfEnough(user.uid, _unlockCost);
    if (!mounted) {
      return false;
    }

    if (!didDeduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough credits. Please top up to continue.')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreditsScreen()),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_unlockCost credits deducted for $featureName.')),
    );
    return true;
  }

  String get _summaryFirstSentence {
    final summary = _summaryText?.trim() ?? '';
    if (summary.isEmpty) {
      return '';
    }
    final index = summary.indexOf('. ');
    if (index == -1) {
      return summary;
    }
    return summary.substring(0, index + 1);
  }

  String get _summaryRemainingText {
    final summary = _summaryText?.trim() ?? '';
    if (summary.isEmpty) {
      return '';
    }
    final first = _summaryFirstSentence;
    if (summary.length <= first.length) {
      return '';
    }
    return summary.substring(first.length).trim();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A1A),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.call.title,
                style: textTheme.titleLarge!
                    .copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              centerTitle: true,
              background: StreamBuilder<UserModel>(
                  stream: DatabaseService().streamUser(widget.call.callerId),
                  builder: (context, snapshot) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (snapshot.hasData && snapshot.data!.photoURL != null)
                          CachedNetworkImage(
                            imageUrl: snapshot.data!.photoURL!,
                            fit: BoxFit.cover,
                            color: Colors.black.withAlpha(128),
                            colorBlendMode: BlendMode.darken,
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0D0D0D),
                                const Color(0xFF0D0D0D).withAlpha(0)
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCallInfo(textTheme),
                  const SizedBox(height: 30),

                  if (widget.call.recordingUrl != null &&
                      widget.call.recordingUrl!.isNotEmpty)
                    _buildAudioPlayer(textTheme)
                  else
                    _buildNoRecordingAvailable(textTheme),
                  const SizedBox(height: 16),
                  _buildAiSummary(textTheme),
                  const SizedBox(height: 20),
                  _buildPostCallUpsell(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallInfo(TextTheme textTheme) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conversation with ${widget.call.userNickname}',
          style: textTheme.headlineSmall!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        // Host Info
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                  'https://firebasestorage.googleapis.com/v0/b/clair-52652/o/ClaireVartar%2Fclaire_icon.png?alt=media&token=5e14455d-0402-453d-80d0-63b55890f691'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ms. Claire',
                  style: textTheme.bodyLarge!
                      .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Host',
                  style: textTheme.bodyMedium!.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Co-host Info
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                  "https://firebasestorage.googleapis.com/v0/b/clair-52652/o/ClaireVartar%2Ficons8-strawberry-72.png?alt=media&token=ff64370f-939c-46ce-af5e-d220a625ef51"),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mr. Bill',
                  style: textTheme.bodyLarge!
                      .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Co-host',
                  style: textTheme.bodyMedium!.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eaves: ',
              style: textTheme.bodyLarge!
                  .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(
                height: 40,
                child: _listenerStrip()
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              DateFormat.yMMMMEEEEd().format(widget.call.startTime.toDate()),
              style: textTheme.bodyMedium!.copyWith(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.access_time, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              DateFormat.jm().format(widget.call.startTime.toDate()),
              style: textTheme.bodyMedium!.copyWith(color: Colors.white70),
            ),
          ],
        ),
        if (widget.call.userMood != null && widget.call.userMood!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Chip(
              avatar: const Icon(Icons.sentiment_satisfied_alt),
              label: Text('Mood: ${widget.call.userMood!}'),
              backgroundColor: const Color(0xFF2D2D2D),
            ),
          ),
        if (widget.call.userLocation != null &&
            widget.call.userLocation!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Chip(
              avatar: const Icon(Icons.location_on_outlined),
              label: Text('Location: ${widget.call.userLocation!}'),
              backgroundColor: const Color(0xFF2D2D2D),
            ),
          ),
        const SizedBox(height: 12),
        StreamBuilder<UserModel>(
          stream: _db.streamUser(widget.call.hostId),
          builder: (context, snapshot) {
            final host = snapshot.data;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (host != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HostProfileScreen(host: host)),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Host Profile'),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: 'https://eavesdrop.app/call/${widget.call.id}'),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share link copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
                if (currentUser != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _db.favoriteCall(currentUser.uid, widget.call);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved to favorites.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostCallUpsell() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24),
        const SizedBox(height: 8),
        const Text('Keep going', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookingScreen()),
                  );
                },
                icon: const Icon(Icons.calendar_today),
                label: const Text('Book Follow-up'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreditsScreen()),
                  );
                },
                icon: const Icon(Icons.local_offer_outlined),
                label: const Text('Value Packs'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioPlayer(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withAlpha(77),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withAlpha(32),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
            ),
            child: Slider(
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
              },
              value: _position.inSeconds
                  .toDouble()
                  .clamp(0.0, _duration.inSeconds.toDouble()),
              min: 0.0,
              max: _duration.inSeconds.toDouble(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: textTheme.bodySmall!.copyWith(color: Colors.white70),
              ),
              Text(
                _formatDuration(_duration),
                style: textTheme.bodySmall!.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IconButton(
            icon: Icon(_isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled),
            iconSize: 72,
            color: Colors.white,
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                if (!_audioUnlocked && _position >= _freePreview) {
                  await _showAudioUnlockPrompt();
                } else {
                  await _audioPlayer.play(UrlSource(widget.call.recordingUrl!));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecordingAvailable(TextTheme textTheme) {
    return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(Icons.mic_off_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              "No recording available.",
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge!.copyWith(color: Colors.white70),
            ),
          ],
        ));
  }

  Widget _buildAiSummary(TextTheme textTheme) {
    final firstSentence = _summaryFirstSentence;
    final remainingText = _summaryRemainingText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Text(
                'Call Summary',
                style: textTheme.titleMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingSummary)
            const Center(child: CircularProgressIndicator())
          else if ((_summaryText ?? '').isEmpty)
            Text(
              'Summary unavailable right now.',
              style: textTheme.bodyMedium!.copyWith(color: Colors.white60),
            )
          else ...[
            Text(
              firstSentence,
              style: textTheme.bodyLarge!.copyWith(color: Colors.white),
            ),
            if (remainingText.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (_summaryUnlocked)
                Text(
                  remainingText,
                  style: textTheme.bodyMedium!.copyWith(color: Colors.white70),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Text(
                        remainingText,
                        style: textTheme.bodyMedium!.copyWith(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final unlocked = await _requestCreditUnlock(
                          featureName: 'viewing full summary',
                          title: 'Unlock full summary?',
                          description:
                              'Read the complete summary of the conversation for $_unlockCost credits.',
                        );
                        if (unlocked && mounted) {
                          setState(() {
                            _summaryUnlocked = true;
                          });
                        }
                      },
                      icon: const Icon(Icons.lock_open_outlined),
                      label: const Text('Unlock full summary (20 credits)'),
                    ),
                  ],
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _listenerStrip() {
    return SizedBox(
      height: 40,
      width: 100,
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

}
