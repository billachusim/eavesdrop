import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:flutter/material.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs
              .map((doc) =>
                  UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.displayName ?? 'No display name'),
                subtitle: Text(user.email ?? 'No email'),
                trailing: Switch(
                  value: user.isHost,
                  onChanged: (value) {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'isHost': value});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
