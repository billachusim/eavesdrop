import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/auth/onboarding_screen.dart';
import 'package:eavesdrop/models/booking_model.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

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

  // Book a new call (Kept for other potential uses)
  Future<void> bookCall(CallModel call, int cost) async {
    try {
      final callDocRef = _db.collection('calls').doc(call.id);
      final userDocRef = _db.collection('users').doc(call.callerId);

      await _db.runTransaction((transaction) async {
        // Create the new call document
        transaction.set(callDocRef, call.toMap());

        // Deduct the cost from the user's credits
        transaction.update(userDocRef, {
          'credits': FieldValue.increment(-cost),
        });
      });
    } catch (e) {
      // It's better to re-throw the error to be handled by the UI
      // print(e.toString());
      rethrow;
    }
  }

  // Create a new booking and its corresponding call document
  Future<void> createBookingAndCall(
      {required BookingModel booking,
        required CallModel call,
        required int cost}) async {
    try {
      final bookingDocRef = _db.collection('bookings').doc(booking.bookingId);
      final callDocRef = _db.collection('calls').doc(call.id);
      final userDocRef = _db.collection('users').doc(call.callerId);

      await _db.runTransaction((transaction) async {
        // 1. Create the booking document
        transaction.set(bookingDocRef, booking.toMap());

        // 2. Create the call document
        transaction.set(callDocRef, call.toMap());

        // 3. Deduct the cost from the user's credits
        transaction.update(userDocRef, {
          'credits': FieldValue.increment(-cost),
        });
      });
    } catch (e) {
      // Re-throw the error to be handled by the UI
      rethrow;
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

  Future<bool> deductCreditsIfEnough(String uid, int cost) async {
    try {
      final userDocRef = _db.collection('users').doc(uid);
      return await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final userData = userSnapshot.data();
        final currentCredits = userData?['credits'] as int? ?? 0;

        if (currentCredits < cost) {
          return false;
        }

        transaction.update(userDocRef, {
          'credits': FieldValue.increment(-cost),
        });
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  // Activate premium subscription
  Future<void> activatePremiumSubscription(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isPremium': true,
        'premiumExpiryDate':
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
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
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((doc) => CallModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Get all calls for the admin dashboard
  Stream<List<CallModel>> streamAllCalls() {
    return _db.collection('calls')
        .orderBy('startTime', descending: true)
        .limit(50)
        .snapshots().map((snap) =>
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
        .orderBy('startTime', descending: true)
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
        .orderBy('startTime', descending: true)
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
        .orderBy('startTime', descending: true)
        .limit(50)
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


  // Add a user to the listeners subcollection for a call and increment count
  Future<void> joinCallListeners(String callId, String userId, String photoURL) async {
    try {
      final callRef = _db.collection('calls').doc(callId);
      final listenerRef = callRef.collection('listeners').doc(userId);

      await _db.runTransaction((transaction) async {
        // Add user to subcollection
        transaction.set(listenerRef, {'photoURL': photoURL});
        // Increment listener count on main call document
        transaction.update(callRef, {'listeners': FieldValue.increment(1)});
      });
    } catch (e) {
      // print(e.toString());
    }
  }

  // Remove a user from the listeners subcollection for a call and decrement count
  Future<void> leaveCallListeners(String callId, String userId) async {
    try {
      final callRef = _db.collection('calls').doc(callId);
      final listenerRef = callRef.collection('listeners').doc(userId);

      await _db.runTransaction((transaction) async {
        // Remove user from subcollection
        transaction.delete(listenerRef);
        // Decrement listener count on main call document
        transaction.update(callRef, {'listeners': FieldValue.increment(-1)});
      });
    } catch (e) {
      // print(e.toString());
    }
  }


  // Stream the listeners for a specific call
  Stream<List<Map<String, dynamic>>> streamCallListeners(String callId) {
    return _db
        .collection('calls')
        .doc(callId)
        .collection('listeners')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }



  // Stream a single call document by its ID
  Stream<CallModel?> streamCall(String callId) {
    return _db.collection('calls').doc(callId).snapshots().map((snap) {
      if (snap.exists) {
        return CallModel.fromMap(snap.data()!, snap.id);
      }
      return null;
    });
  }

  // Add a question to a call's subcollection
  Future<void> addQuestionToCall(
      String callId, Map<String, dynamic> questionData) async {
    try {
      await _db
          .collection('calls')
          .doc(callId)
          .collection('questions')
          .add(questionData);
    } catch (e) {
      // print(e.toString());
      rethrow;
    }
  }

  // Stream the questions for a specific call
  Stream<List<Map<String, dynamic>>> streamCallQuestions(String callId) {
    return _db
        .collection('calls')
        .doc(callId)
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
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

  // Check if a reminder is set for a call
  Future<bool> isReminderSet(String callId, String userId) async {try {
    final doc = await _db
        .collection('calls')
        .doc(callId)
        .collection('reminders')
        .doc(userId)
        .get();
    return doc.exists;
  } catch (e) {
    // print(e.toString());
    return false;
  }
  }


  // Set a reminder for a call
  Future<void> setReminder(String callId, String userId) async {
    try {
      await _db
          .collection('calls')
          .doc(callId)
          .collection('reminders')
          .doc(userId)
          .set({});
      await pushNotification(
        userId,
        title: 'Reminder Set',
        body: 'You will be notified when this call starts.',
        type: 'reminder',
      );
    } catch (e) {
      // print(e.toString());
    }
  }


  // Remove a reminder for a call
  Future<void> removeReminder(String callId, String userId) async {
    try {
      await _db
          .collection('calls')
          .doc(callId)
          .collection('reminders')
          .doc(userId)
          .delete();
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

  // ------- Social discovery + engagement -------

  Stream<List<UserModel>> streamHosts() {
    return _db
        .collection('users')
        .where('isHost', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> followHost(String uid, String hostId) async {
    await _db.collection('users').doc(uid).set({
      'followedHostIds': FieldValue.arrayUnion([hostId]),
    }, SetOptions(merge: true));
  }

  Future<void> unfollowHost(String uid, String hostId) async {
    await _db.collection('users').doc(uid).set({
      'followedHostIds': FieldValue.arrayRemove([hostId]),
    }, SetOptions(merge: true));
  }

  Future<void> followTopic(String uid, String topic) async {
    final normalizedTopic = topic.toLowerCase();
    await _db.collection('users').doc(uid).set({
      'followedTopics': FieldValue.arrayUnion([normalizedTopic]),
    }, SetOptions(merge: true));
  }

  Future<void> unfollowTopic(String uid, String topic) async {
    final normalizedTopic = topic.toLowerCase();
    await _db.collection('users').doc(uid).set({
      'followedTopics': FieldValue.arrayRemove([normalizedTopic]),
    }, SetOptions(merge: true));
  }

  Future<void> favoriteCall(String uid, CallModel call) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favoriteCalls')
        .doc(call.id)
        .set({
      'callId': call.id,
      'savedAt': Timestamp.now(),
      'title': call.title,
      'callerId': call.callerId,
      'hostId': call.hostId,
      'startTime': call.startTime,
    }, SetOptions(merge: true));
  }

  Future<void> unfavoriteCall(String uid, String callId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favoriteCalls')
        .doc(callId)
        .delete();
  }

  Stream<List<String>> streamFavoriteCallIds(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favoriteCalls')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Future<void> addReactionToCall(String callId, String emoji, String userId) async {
    await _db.collection('calls').doc(callId).collection('reactions').add({
      'emoji': emoji,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamRecentReactions(String callId) {
    return _db
        .collection('calls')
        .doc(callId)
        .collection('reactions')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> upvoteQuestion(String callId, String questionId, String uid) async {
    await _db
        .collection('calls')
        .doc(callId)
        .collection('questions')
        .doc(questionId)
        .set({
      'upvotes': FieldValue.increment(1),
      'upvotedBy': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));
  }

  Future<void> pinQuestion(String callId, String questionId, bool pinned) async {
    await _db
        .collection('calls')
        .doc(callId)
        .collection('questions')
        .doc(questionId)
        .set({'pinned': pinned}, SetOptions(merge: true));
  }

  Future<void> dismissQuestion(String callId, String questionId) async {
    await _db
        .collection('calls')
        .doc(callId)
        .collection('questions')
        .doc(questionId)
        .set({'dismissed': true}, SetOptions(merge: true));
  }

  Future<void> banUserFromCall(String callId, String userId) async {
    await _db.collection('calls').doc(callId).collection('bannedUsers').doc(userId).set({
      'bannedAt': Timestamp.now(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamNotifications(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> pushNotification(String uid,
      {required String title, required String body, String? type}) async {
    await _db.collection('users').doc(uid).collection('notifications').add({
      'title': title,
      'body': body,
      'type': type ?? 'general',
      'createdAt': Timestamp.now(),
      'read': false,
    });
  }


  /// [delete] all users informations
  void deleteUserAccount(BuildContext context, String userId) async {
    await FirebaseAuth.instance.signOut();
    final userId0 = userId;
    final collection = FirebaseFirestore.instance
        .collection('users');
    await collection.doc(userId0).delete();
    // Use pushAndRemoveUntil to clear the navigation stack
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

}
