import 'package:eavesdrop/calls/call_details_screen.dart';
import 'package:eavesdrop/live_call_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/widgets/call_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoriteCallsScreen extends StatelessWidget {
  const FavoriteCallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in to view favorites.')));
    }

    final db = DatabaseService();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Calls')),
      body: StreamBuilder<List<String>>(
        stream: db.streamFavoriteCallIds(user.uid),
        builder: (context, snapshot) {
          final ids = snapshot.data ?? const <String>[];
          if (ids.isEmpty) {
            return const Center(child: Text('No saved calls yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ids.length,
            itemBuilder: (context, index) {
              return StreamBuilder<CallModel?>(
                stream: db.streamCall(ids[index]),
                builder: (context, callSnap) {
                  final call = callSnap.data;
                  if (call == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CallCard(
                      call: call,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => call.isLive
                                ? LiveCallScreen(call: call)
                                : CallDetailsScreen(call: call),
                          ),
                        );
                      },
                      onPlayRecording: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallDetailsScreen(call: call, autoplay: true),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
