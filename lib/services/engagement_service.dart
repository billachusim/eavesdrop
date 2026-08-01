import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class EngagementService {
  static final EngagementService _instance = EngagementService._internal();
  factory EngagementService() => _instance;
  EngagementService._internal();

  static const String _keyBookingCount = 'booking_count';
  static const String _keyListenCount = 'listen_count';
  static const String _keyOpenDates = 'open_dates';
  static const String _keyHasReviewed = 'has_reviewed_v2';

  final InAppReview _inAppReview = InAppReview.instance;

  Future<void> recordAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    Set<String> openDates = (prefs.getStringList(_keyOpenDates) ?? []).toSet();
    openDates.add(today);
    await prefs.setStringList(_keyOpenDates, openDates.toList());
    
    _checkAndRequestReview();
  }

  Future<void> recordBooking() async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt(_keyBookingCount) ?? 0;
    count++;
    await prefs.setInt(_keyBookingCount, count);
    
    _checkAndRequestReview();
  }

  Future<void> recordListen() async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt(_keyListenCount) ?? 0;
    count++;
    await prefs.setInt(_keyListenCount, count);
    
    _checkAndRequestReview();
  }

  Future<void> _checkAndRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (prefs.getBool(_keyHasReviewed) ?? false) return;

    final bookingCount = prefs.getInt(_keyBookingCount) ?? 0;
    final listenCount = prefs.getInt(_keyListenCount) ?? 0;
    final openDates = prefs.getStringList(_keyOpenDates) ?? [];

    bool shouldRequest = false;
    
    if (bookingCount >= 2) {
      shouldRequest = true;
    } else if (listenCount >= 2) {
      shouldRequest = true;
    } else if (openDates.length >= 3) {
      shouldRequest = true;
    }

    if (shouldRequest) {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await prefs.setBool(_keyHasReviewed, true);
      }
    }
  }
}
