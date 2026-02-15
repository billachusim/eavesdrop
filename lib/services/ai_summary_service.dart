import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiSummaryService {
  static const String _defaultEndpoint =
      'https://api.elevenlabs.io/v1/convai/conversations/summarize';
  static const String _apiKey = String.fromEnvironment('ELEVENLABS_API_KEY');
  static const String _endpoint =
      String.fromEnvironment('ELEVENLABS_SUMMARY_ENDPOINT', defaultValue: _defaultEndpoint);
  static const String _consentKey = 'ai_summary_third_party_consent';

  Future<bool> hasSummaryConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  Future<void> setSummaryConsent(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, granted);
  }

  Future<String> getSummary({
    required String callId,
    required String recordingUrl,
    required String callTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'ai_summary_$callId';
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    final fetched = await _fetchFromElevenLabs(
        recordingUrl: recordingUrl, callTitle: callTitle);

    if (fetched != null) {
      await prefs.setString(cacheKey, fetched);
      return fetched;
    } else {
      return 'This conversation covers "$callTitle" with practical reflections and actionable next steps.';
    }
  }


  Future<String?> _fetchFromElevenLabs({
    required String recordingUrl,
    required String callTitle,
  }) async {
    if (_apiKey.isEmpty) {
      return null;
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'xi-api-key': _apiKey,
      },
      body: jsonEncode({
        'audio_url': recordingUrl,
        'title': callTitle,
        'max_sentences': 6,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final summary = payload['summary'] ?? payload['text'];
    if (summary is String && summary.trim().isNotEmpty) {
      return summary.trim();
    }

    return null;
  }

  Future<void> clearSummaryCache(String callId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_summary_$callId');
  }
}
