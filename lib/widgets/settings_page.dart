import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/services/share_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../auth/onboarding_screen.dart';
import '../notification_center_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _firebaseServices = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;


  void _launchDeletionPolicy() async {
    final Uri url = Uri.parse("https://sites.google.com/view/claire-diary/delete-your-dear-claire-account?authuser=0");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the policy page.')),
      );
    }
  }


  void _confirmAndDeleteAccount() {
    // Ensure there is a current user
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is currently signed in.')),
      );
      return;
    }

    // Show a confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
              'This action is permanent and cannot be undone. All your data will be removed. Are you sure you want to proceed?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                // The original firebaseServices.deleteUserAccount handles navigation.
                _firebaseServices.deleteUserAccount(context, currentUser!.uid);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextButton.icon(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            label: const Text('Alerts', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationCenterScreen(),
                ),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text('Share App', style: TextStyle(color: Colors.white)),
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              ShareService.shareApp(
                sharePositionOrigin: box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null,
              );
            },
          ),
          if (currentUser == null)
            TextButton.icon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Login', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OnboardingScreen(),
                  ),
                );
              },
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Logout', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await AuthService().signOut();
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            onTap: _confirmAndDeleteAccount,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
            child: RichText(
              text: TextSpan(
                text: 'Review and confirm data deletion.',
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = _launchDeletionPolicy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
