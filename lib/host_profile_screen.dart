import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HostProfileScreen extends StatelessWidget {
  final UserModel host;
  const HostProfileScreen({super.key, required this.host});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final currentUser = context.watch<User?>();

    return Scaffold(
      appBar: AppBar(title: Text(host.displayName ?? 'Host Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: host.photoURL != null && host.photoURL!.isNotEmpty
                      ? NetworkImage(host.photoURL!)
                      : null,
                  child: (host.photoURL == null || host.photoURL!.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host.displayName ?? 'Host',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text('Specialties: Relationships · Career · Anxiety'),
                      const Text('Language: English'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentUser != null)
              StreamBuilder<UserModel>(
                stream: db.streamUser(currentUser.uid),
                builder: (context, snapshot) {
                  final isFollowing = snapshot.data?.followedHostIds.contains(host.uid) ?? false;
                  return FilledButton.icon(
                    onPressed: () async {
                      if (isFollowing) {
                        await db.unfollowHost(currentUser.uid, host.uid);
                      } else {
                        await db.followHost(currentUser.uid, host.uid);
                      }
                    },
                    icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add),
                    label: Text(isFollowing ? 'Following' : 'Follow Host'),
                  );
                },
              ),
            const SizedBox(height: 20),
            const Text('Recent conversations', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<CallModel>>(
                stream: db.streamAllCalls(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final calls = snapshot.data!
                      .where((c) => c.hostId == host.uid)
                      .toList()
                    ..sort((a, b) => b.startTime.compareTo(a.startTime));
                  if (calls.isEmpty) {
                    return const Center(child: Text('No calls yet for this host.'));
                  }
                  return ListView.builder(
                    itemCount: calls.length,
                    itemBuilder: (context, index) {
                      final call = calls[index];
                      return ListTile(
                        title: Text(call.title),
                        subtitle: Text(call.userNickname),
                        trailing: Text(call.isLive ? 'LIVE' : 'RECORDED'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
