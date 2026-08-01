import 'package:eavesdrop/incoming_call_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'call_state_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await requestPermission();
    await _initializeLocalNotifications();

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

  Future<void> _initializeLocalNotifications() async {
    tz.initializeTimeZones();
    final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(initializationSettings);
  }

  Future<void> scheduleCallReminder(CallModel call) async {
    final scheduledDate = tz.TZDateTime.from(
      call.startTime.toDate().subtract(const Duration(minutes: 10)),
      tz.local,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _localNotifications.zonedSchedule(
      call.id.hashCode,
      'Upcoming Call: ${call.title}',
      'Your call with ${call.userNickname} starts in 10 minutes!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'call_reminders',
          'Call Reminders',
          channelDescription: 'Notifications for upcoming booked calls',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: call.id,
    );
  }

  Future<void> cancelCallReminder(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
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
