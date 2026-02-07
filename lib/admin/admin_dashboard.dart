import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/services/database_service.dart';
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
              itemCount: calls.length,
              itemBuilder: (context, index) {
                final call = calls[index];
                return ListTile(
                  title: Text(call.title),
                  subtitle: Text('with ${call.userNickname}'),
                  onTap: () {
                    // Navigate to call details page for admins
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
