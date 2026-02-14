import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final int credits;
  final bool isAdmin;
  final bool isSuperAdmin;
  final String? fcmToken;
  final bool isPremium;
  final Timestamp? premiumExpiryDate;
  final bool isHost;
  final String? photoURL;
  final List<String> followedHostIds;
  final List<String> followedTopics;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.credits = 0,
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.fcmToken,
    this.isPremium = false,
    this.premiumExpiryDate,
    this.isHost = false,
    this.photoURL,
    this.followedHostIds = const [],
    this.followedTopics = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      email: data['email'],
      displayName: data['displayName'],
      credits: data['credits'] as int? ?? 0,
      isAdmin: data['isAdmin'] as bool? ?? false,
      isSuperAdmin: data['isSuperAdmin'] as bool? ?? false,
      fcmToken: data['fcmToken'] as String?,
      isPremium: data['isPremium'] as bool? ?? false,
      premiumExpiryDate: data['premiumExpiryDate'] as Timestamp?,
      isHost: data['isHost'] as bool? ?? false,
      photoURL: data['photoURL'] as String?,
      followedHostIds: List<String>.from(data['followedHostIds'] ?? const []),
      followedTopics: List<String>.from(data['followedTopics'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'credits': credits,
      'isAdmin': isAdmin,
      'isSuperAdmin': isSuperAdmin,
      'fcmToken': fcmToken,
      'isPremium': isPremium,
      'premiumExpiryDate': premiumExpiryDate,
      'isHost': isHost,
      'photoURL': photoURL,
      'followedHostIds': followedHostIds,
      'followedTopics': followedTopics,
    };
  }
}
