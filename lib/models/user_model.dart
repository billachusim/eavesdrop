class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final int credits;
  final bool isAdmin;
  final bool isSuperAdmin;
  final String? fcmToken;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.credits = 0,
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.fcmToken,
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
    };
  }
}
