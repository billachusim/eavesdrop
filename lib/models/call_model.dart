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

  CallModel({
    required this.id,
    required this.hostId,
    required this.callerId,
    required this.isPrivate,
    required this.isLive,
    required this.startTime,
    required this.channelName,
    this.listeners = 0,
  });

  factory CallModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CallModel(
      id: documentId,
      hostId: data['hostId'] as String,
      callerId: data['callerId'] as String,
      isPrivate: data['isPrivate'] as bool,
      isLive: data['isLive'] as bool,
      startTime: data['startTime'] as Timestamp,
      channelName: data['channelName'] as String,
      listeners: data['listeners'] as int? ?? 0,
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
    };
  }
}
