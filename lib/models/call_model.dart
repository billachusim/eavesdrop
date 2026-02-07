import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String id;
  final String hostId;
  final String callerId;
  final bool isPrivate;
  final bool isLive;
  final Timestamp startTime;
  final String channelName;
  final int listeners;
  final String title;
  final String userNickname;
  final String personalityAvatar;
  final String? userLocation;
  final String? userMood;
  final String? recordingUrl;
  final bool isFeatured;
  // New fields for call state management
  final String bookingId;
  final bool accepted;
  final bool rejected;
  final bool connected;
  final bool callEnd;

  CallModel({
    required this.id,
    required this.hostId,
    required this.callerId,
    required this.isPrivate,
    required this.isLive,
    required this.startTime,
    required this.channelName,
    this.listeners = 0,
    required this.title,
    required this.userNickname,
    required this.personalityAvatar,
    this.userLocation,
    this.userMood,
    this.recordingUrl,
    this.isFeatured = false,
    // Initialize new fields
    required this.bookingId,
    this.accepted = false,
    this.rejected = false,
    this.connected = false,
    this.callEnd = false,
  });

  factory CallModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CallModel(
      id: documentId,
      hostId: data['hostId'] as String,
      callerId: data['callerId'] as String,
      isPrivate: data['isPrivate'] as bool? ?? false,
      isLive: data['isLive'] as bool? ?? false,
      startTime: data['startTime'] as Timestamp,
      channelName: data['channelName'] as String,
      listeners: data['listeners'] as int? ?? 0,
      title: data['title'] as String? ?? '',
      userNickname: data['userNickname'] as String? ?? '',
      personalityAvatar: data['personalityAvatar'] as String? ?? '',
      userLocation: data['userLocation'] as String?,
      userMood: data['userMood'] as String?,
      recordingUrl: data['recordingUrl'] as String?,
      isFeatured: data['isFeatured'] as bool? ?? false,
      // Assign new fields from map
      bookingId: data['bookingId'] as String? ?? '',
      accepted: data['accepted'] as bool? ?? false,
      rejected: data['rejected'] as bool? ?? false,
      connected: data['connected'] as bool? ?? false,
      callEnd: data['callEnd'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'callerId': callerId,
      'isPrivate': isPrivate,
      'isLive': isLive,
      'startTime': startTime,
      'channelName': channelName,
      'listeners': listeners,
      'title': title,
      'userNickname': userNickname,
      'personalityAvatar': personalityAvatar,
      'userLocation': userLocation,
      'userMood': userMood,
      'recordingUrl': recordingUrl,
      'isFeatured': isFeatured,
      // Add new fields to map
      'bookingId': bookingId,
      'accepted': accepted,
      'rejected': rejected,
      'connected': connected,
      'callEnd': callEnd,
    };
  }
}
