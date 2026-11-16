import 'dart:async';
import 'package:eavesdrop/auth/auth_service.dart';
import 'package:eavesdrop/auth/wrapper.dart';
import 'package:eavesdrop/services/engagement_service.dart';
import 'package:eavesdrop/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';

final NotificationService _notificationService = NotificationService();

// Must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //_notificationService.showIncomingCall(message.data['callId']);
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }

    // Report Flutter and platform errors to Crashlytics instead of letting
    // them take the app down silently.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _recordError(details.exception, details.stack, fatal: true);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _recordError(error, stack, fatal: true);
      return true;
    };

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Background message handler setup failed: $e');
    }

    runApp(const MyApp());

    // App Check, notification permission, reminders and the review prompt
    // all run after the first frame so none of them can block or crash start.
    unawaited(_initAfterLaunch());
  }, (error, stack) => _recordError(error, stack));
}

void _recordError(Object error, StackTrace? stack, {bool fatal = false}) {
  debugPrint('Uncaught error: $error');
  try {
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    }
  } catch (_) {}
}

Future<void> _initAfterLaunch() async {
  try {
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        )
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
  // Give the first screen a moment before any system prompt appears.
  await Future<void>.delayed(const Duration(seconds: 2));
  try {
    await _notificationService.initialize().timeout(const Duration(seconds: 30));
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }
  try {
    await EngagementService().recordAppOpen();
  } catch (e) {
    debugPrint('Engagement init failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<User?>.value(
          value: AuthService().user,
          initialData: null,
        ),
        Provider<NotificationService>.value(value: _notificationService),
      ],
      child: MaterialApp(
        navigatorKey: _notificationService.navigatorKey,
        title: 'Eavesdrop',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.black,
          scaffoldBackgroundColor: const Color(0xFF0D0D0D),
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            secondary: Colors.greenAccent,
            surface: Color(0xFF121212),
            error: Colors.red,
            onPrimary: Colors.black,
            onSecondary: Colors.black,
            onSurface: Colors.white,
            onError: Colors.white,
            brightness: Brightness.dark,
          ),
        ),
        home: const Wrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
