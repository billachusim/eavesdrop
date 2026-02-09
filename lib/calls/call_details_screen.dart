import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:flutter/material.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.call.recordingUrl != null &&
        widget.call.recordingUrl!.isNotEmpty) {
      _initAudioPlayer();
      if (widget.autoplay) {
        _audioPlayer.play(UrlSource(widget.call.recordingUrl!));
      }
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallInfo(TextTheme textTheme) {
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
              backgroundImage: NetworkImage("https://firebasestorage.googleapis.com/v0/b/clair-52652/o/ClaireVartar%2Ficons8-strawberry-72.png?alt=media&token=ff64370f-939c-46ce-af5e-d220a625ef51"),
              child: Icon(Icons.person, color: Colors.white70),
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
                await _audioPlayer.play(UrlSource(widget.call.recordingUrl!));
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
              "No recording on this conversation.",
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge!.copyWith(color: Colors.white70),
            ),
          ],
        ));
  }
}
