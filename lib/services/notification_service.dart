import 'package:eavesdrop/incoming_call_screen.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'call_state_service.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    await requestPermission();

    // Get the token and save it to Firestore
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _saveToken(user.uid);
      }
    });

    // For handling notification when the app is in terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        showIncomingCall(message.data['callId']);
      }
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showIncomingCall(message.data['callId']);
      }
    });

    // Background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      showIncomingCall(message.data['callId']);
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

  void showIncomingCall(String callId) async {
    final call = await _db.getCallById(callId);
    final isNotInThisCall = CallStateService.activeCallId != call?.id;
    if (isNotInThisCall) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(call: call!),
        ),
      );
    } else {
    }
  }
}
