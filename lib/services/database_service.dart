import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new user document
  Future<void> createUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      // print(e.toString());
    }
  }

  // Get a user document
  Stream<UserModel> streamUser(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => UserModel.fromMap(snap.data()!, snap.id));
  }

  // Book a new call
  Future<void> bookCall(CallModel call, int cost) async {
    try {
      DocumentReference docRef = await _db.collection('calls').add(call.toMap());
      await docRef.update({'channelName': docRef.id, 'hasEnded': false});
      await updateUserCredits(call.hostId, -cost);
    } catch (e) {
      // print(e.toString());
    }
  }

  // Update user credits
  Future<void> updateUserCredits(String uid, int amount) async {
    try {
      await _db.collection('users').doc(uid).update({
        'credits': FieldValue.increment(amount),
      });
    } catch (e) {
      // print(e.toString());
    }
  }

  // Activate premium subscription
  Future<void> activatePremiumSubscription(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isPremium': true,
        'premiumExpiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });
    } catch (e) {
      // print(e.toString());
    }
  }

  // Get a user's calls
  Stream<List<CallModel>> streamCalls(String uid) {
    return _db
        .collection('calls')
        .where('callerId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CallModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Get all calls for the admin dashboard
  Stream<List<CallModel>> streamAllCalls() {
    return _db
        .collection('calls')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CallModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Get all live calls
  Stream<List<CallModel>> streamLiveCalls() {
    return _db
        .collection('calls')
        .where('isLive', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CallModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Get all upcoming calls
  Stream<List<CallModel>> streamUpcomingCalls() {
    return _db
        .collection('calls')
        .where('isLive', isEqualTo: false)
        .where('isFeatured', isEqualTo: true)
        .where('startTime', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snap) =>
        snap.docs.map((doc) => CallModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Get all of a user's upcoming calls
  Stream<List<CallModel>> streamUserUpcomingCalls(String uid) {
    return _db
        .collection('calls')
        .where('isLive', isEqualTo: false)
        .where('startTime', isGreaterThan: Timestamp.now())
        .where('callerId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
        snap.docs.map((doc) => CallModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Get all featured past calls
  Stream<List<CallModel>> streamFeaturedPastCalls() {
    return _db
        .collection('calls')
        .where('isLive', isEqualTo: false)
        .where('isFeatured', isEqualTo: true)
        .where('startTime', isLessThan: Timestamp.now())
        .snapshots()
        .map((snap) =>
        snap.docs.map((doc) => CallModel.fromMap(doc.data(), doc.id)).toList());
  }


  // Save user FCM token
  Future<void> saveUserToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      // print(e.toString());
    }
  }

  // Get a call by its ID
  Future<CallModel?> getCallById(String callId) async {
    try {
      DocumentSnapshot doc = await _db.collection('calls').doc(callId).get();
      if (doc.exists) {
        return CallModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      // print(e.toString());
    }
    return null;
  }

  // Update call recording URL
  Future<void> updateCallRecordingUrl(String callId, String recordingUrl) async {
    try {
      await _db.collection('calls').doc(callId).update({
        'recordingUrl': recordingUrl,
      });
    } catch (e) {
      // print(e.toString());
    }
  }

  // Set a reminder for a call
  Future<void> setReminder(String callId, String userId) async {
    try {
      await _db.collection('calls').doc(callId).collection('reminders').doc(userId).set({});
    } catch (e) {
      // print(e.toString());
    }
  }
  
  // End a call
  Future<void> endCall(String callId) async {
    try {
      await _db.collection('calls').doc(callId).update({
        'isLive': false,
        'hasEnded': true,
      });
    } catch (e) {
      // print(e.toString());
    }
  }

  // Toggle featured status of a call
  Future<void> toggleFeaturedCall(String callId, bool isFeatured) async {
    try {
      await _db.collection('calls').doc(callId).update({
        'isFeatured': isFeatured,
      });
    } catch (e) {
      // print(e.toString());
    }
  }
}
