import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String? userId;
  final String? nickname;
  final String? bookingId;
  final bool? isTrial;
  final DateTime? bookingStart;
  final DateTime? bookingEnd;
  final String? title;
  final String? mood;
  final String? location;
  final String? personalityAvatar;
  final String? personalityId;
  final bool? isPrivate;
  final String? channelId;

  BookingModel({
    this.userId,
    this.nickname,
    this.bookingId,
    this.isTrial,
    this.bookingStart,
    this.bookingEnd,
    this.title,
    this.mood,
    this.location,
    this.personalityAvatar,
    this.personalityId,
    this.isPrivate,
    this.channelId,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      userId: json['userId'],
      nickname: json['nickname'],
      bookingId: json['bookingId'],
      isTrial: json['isTrial'],
      bookingStart: (json['bookingStart'] as Timestamp?)?.toDate(),
      bookingEnd: (json['bookingEnd'] as Timestamp?)?.toDate(),
      title: json['title'],
      mood: json['mood'],
      location: json['location'],
      personalityAvatar: json['personalityAvatar'],
      personalityId: json['personalityId'],
      isPrivate: json['isPrivate'],
      channelId: json['channelId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nickname': nickname,
      'bookingId': bookingId,
      'isTrial': isTrial,
      'bookingStart': bookingStart != null ? Timestamp.fromDate(bookingStart!) : null,
      'bookingEnd': bookingEnd != null ? Timestamp.fromDate(bookingEnd!) : null,
      'timeOfBooking': FieldValue.serverTimestamp(), // Added for sorting
      'title': title,
      'mood': mood,
      'location': location,
      'personalityAvatar': personalityAvatar,
      'personalityId': personalityId,
      'isPrivate': isPrivate,
      'channelId': channelId,
    };
  }
}
