import 'package:audioplayers/audioplayers.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyCallsScreen extends StatelessWidget {
  const MyCallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final DatabaseService db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calls'),
      ),
      body: StreamProvider<List<CallModel>>.value(
        value: db.streamCalls(user!.uid),
        initialData: const [],
        child: Consumer<List<CallModel>>(
          builder: (context, calls, child) {
            return ListView.builder(
              itemCount: calls.length,
              itemBuilder: (context, index) {
                final call = calls[index];
                return CallListItem(call: call);
              },
            );
          },
        ),
      ),
    );
  }
}

class CallListItem extends StatefulWidget {
  final CallModel call;

  const CallListItem({super.key, required this.call});

  @override
  State<CallListItem> createState() => _CallListItemState();
}

class _CallListItemState extends State<CallListItem> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Call with ${widget.call.callerId}'),
      subtitle: Text(widget.call.startTime.toDate().toString()),
      trailing: widget.call.recordingUrl != null
          ? IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                  setState(() {
                    _isPlaying = false;
                  });
                } else {
                  await _audioPlayer.play(UrlSource(widget.call.recordingUrl!));
                  setState(() {
                    _isPlaying = true;
                  });
                }
              },
            )
          : null,
    );
  }
}
