import 'dart:math' as math;
import 'package:eavesdrop/auth/onboarding_screen.dart';
import 'package:eavesdrop/booking/booking_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var currentUser = FirebaseAuth.instance.currentUser;


  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (currentUser == null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const OnboardingScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const BookingScreen()),
            );
          }
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    return Transform.rotate(
                      angle: _controller.value * 1 * math.pi,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    "assets/images/iconWhitePetal.png",
                    height: 120,
                    width: 120,
                  ),
                ),
              ),
              const Text("By Tech Faculty", style: TextStyle(color: Colors.black),)
            ],
          ),
        ),
      ),
    );
  }
}
