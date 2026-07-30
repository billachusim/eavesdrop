import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:eavesdrop/constants/avatars.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream for auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign up with email and password
  Future<User?> signUpWithEmailAndPassword(
      String email, String password, String displayName, String photoURL) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        // Create a new user document with initial credits
        await _db.createUser(UserModel(
          uid: user.uid,
          email: user.email,
          displayName: displayName,
          photoURL: photoURL,
          credits: 100,
        ));
      }
      return user;
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      return null;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
  }

  // Social Sign In Helper
  Future<User?> _handleSocialSignIn(UserCredential credential, {String? providedDisplayName}) async {
    User? user = credential.user;
    if (user != null) {
      // Check if user already exists in Firestore
      UserModel? existingUser = await _db.getUserById(user.uid);
      if (existingUser == null) {
        // Create a new user document with initial credits for first-time social sign-in
        await _db.createUser(UserModel(
          uid: user.uid,
          email: user.email,
          displayName: providedDisplayName ?? user.displayName ?? "User ${user.uid.substring(0, 5)}",
          photoURL: user.photoURL ?? Avatars.getRandomAvatar(),
          credits: 100,
        ));
      }
    }
    return user;
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      return await _handleSocialSignIn(result);
    } catch (e) {
      if (kDebugMode) {
        print("Google Sign-In Error: ${e.toString()}");
      }
      rethrow;
    }
  }

  // Sign in with Apple
  Future<User?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final AuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      // Extract name if provided (usually only on first sign-in)
      String? name;
      if (appleCredential.givenName != null) {
        name = "${appleCredential.givenName} ${appleCredential.familyName ?? ""}".trim();
      } else if (result.user?.displayName != null) {
        name = result.user!.displayName;
      }

      return await _handleSocialSignIn(result, providedDisplayName: name);
    } catch (e) {
      if (kDebugMode) {
        print("Apple Sign-In Error: ${e.toString()}");
      }
      rethrow;
    }
  }

  /// Generates a cryptographically secure random nonce, to be included in a
  /// credential request.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.-_';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
