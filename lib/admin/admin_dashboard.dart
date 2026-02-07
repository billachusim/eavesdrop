import 'package:eavesdrop/calls/call_details_screen.dart';
import 'package:eavesdrop/live_call_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/widgets/call_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: StreamProvider<List<CallModel>>.value(
        value: db.streamAllCalls(),
        initialData: const [],
        child: Consumer<List<CallModel>>(
          builder: (context, calls, child) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: calls.length,
              itemBuilder: (context, index) {
                final call = calls[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: CallCard(
                    call: call,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => call.isLive
                              ? LiveCallScreen(call: call)
                              : CallDetailsScreen(call: call),
                        ),
                      );
                    },
                    onPlayRecording: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallDetailsScreen(call: call),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
