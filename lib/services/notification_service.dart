import 'package:audioplayers/audioplayers.dart';
import 'package:eavesdrop/incoming_call_screen.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    await requestPermission();

    // Get the token and save it to Firestore
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _saveToken(user.uid);
      }
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // print('Got a message whilst in the foreground!');
      // print('Message data: ${message.data}');

      if (message.notification != null) {
        // print('Message also contained a notification: ${message.notification}');
        // Play ringing sound
        playRingingSound();
        // Show incoming call screen
        _showIncomingCall(message.data['callId']);
      }
    });

    // Background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // print('A new onMessageOpenedApp event was published!');
      _showIncomingCall(message.data['callId']);
    });
  }

  Future<void> _saveToken(String uid) async {
    String? token = await _fcm.getToken();
    if (token != null) {
      await _db.saveUserToken(uid, token);
    }
    _fcm.onTokenRefresh.listen((newToken) {
      _db.saveUserToken(uid, newToken);
    });
  }

  Future<void> requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      // print('User granted provisional permission');
    } else {
      // print('User declined or has not accepted permission');
    }
  }

  void _showIncomingCall(String callId) async {
    final call = await _db.getCallById(callId);
    if (call != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(call: call),
        ),
      );
    }
  }

  void playRingingSound() {
    _audioPlayer.play(AssetSource('sounds/ring.mp3'));
  }

  void stopRingingSound() {
    _audioPlayer.stop();
  }
}
