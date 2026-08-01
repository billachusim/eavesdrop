import 'package:eavesdrop/auth/immersive_onboarding.dart';
import 'package:eavesdrop/live_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    if (_seenOnboarding == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // If user is already logged in, go straight to home screen
    if (user != null) {
      return const LiveHomeScreen();
    }

    // If user is guest and hasn't seen onboarding, show it
    if (!_seenOnboarding!) {
      return const ImmersiveOnboarding();
    }

    // Otherwise (guest who has seen onboarding), show home screen
    return const LiveHomeScreen();
  }
}
