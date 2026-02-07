import 'package:audioplayers/audioplayers.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class CallDetailsScreen extends StatefulWidget {
  final CallModel call;

  const CallDetailsScreen({Key? key, required this.call}) : super(key: key);

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

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.call.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nickname: ${widget.call.userNickname}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Avatar: ${widget.call.personalityAvatar}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Date: ${widget.call.startTime.toDate().toLocal()}'.split(' ')[0], style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            if (widget.call.userLocation != null && widget.call.userLocation!.isNotEmpty)
              Text('Location: ${widget.call.userLocation}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            if (widget.call.userMood != null && widget.call.userMood!.isNotEmpty)
              Text('Mood: ${widget.call.userMood}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            if (widget.call.recordingUrl != null)
              Column(
                children: [
                  Slider(
                    min: 0,
                    max: _duration.inSeconds.toDouble(),
                    value: _position.inSeconds.toDouble(),
                    onChanged: (value) async {
                      final position = Duration(seconds: value.toInt());
                      await _audioPlayer.seek(position);
                      await _audioPlayer.resume();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatTime(_position)),
                        Text(formatTime(_duration - _position)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 48),
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
          ],
        ),
      ),
    );
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }
}
