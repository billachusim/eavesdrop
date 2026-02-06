class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final int credits;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.credits = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    final String uid = documentId;
    final String? email = data['email'];
    final String? displayName = data['displayName'];
    final int credits = data['credits'] as int? ?? 0;
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      credits: credits,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'credits': credits,
    };
  }
}
