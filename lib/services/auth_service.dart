import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'widget_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check username availability
  Future<bool> isUsernameAvailable(String username) async {
    final cleanUsername = username.toLowerCase().trim();
    if (cleanUsername.isEmpty) return false;

    final snapshot = await _db
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    return snapshot.docs.isEmpty;
  }

  // Sign up with Email & Password
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user!;
    await firebaseUser.updateDisplayName(displayName);

    final defaultUsername = username ??
        ('${email.split('@').first.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch % 1000}');

    final newUser = UserModel(
      uid: firebaseUser.uid,
      displayName: displayName,
      username: defaultUsername.toLowerCase(),
      email: firebaseUser.email,
      phone: firebaseUser.phoneNumber,
      friends: [],
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
    return newUser;
  }

  // Sign in with Email & Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ==========================================
  // PHONE NUMBER AUTHENTICATION (SMS OTP)
  // ==========================================

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      forceResendingToken: resendToken,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout ?? (_) {},
    );
  }

  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final firebaseUser = userCredential.user;

    if (firebaseUser != null) {
      final doc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists) {
        final shortUid = firebaseUser.uid.length >= 6
            ? firebaseUser.uid.substring(0, 6).toLowerCase()
            : firebaseUser.uid.toLowerCase();
        final defaultUsername = 'user_$shortUid';
        final newUser = UserModel(
          uid: firebaseUser.uid,
          displayName: 'Thành viên HeartPearl',
          username: defaultUsername,
          phone: firebaseUser.phoneNumber,
          friends: [],
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
      }
    }
    return userCredential;
  }

  // ==========================================
  // GOOGLE SIGN-IN
  // ==========================================

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email'],
      clientId: '592218033486-8j6s0j3h9acvep29p70m56chb0dcfqtr.apps.googleusercontent.com',
    );
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      // User cancelled
      return null;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final firebaseUser = userCredential.user;

    if (firebaseUser != null) {
      final userDoc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (!userDoc.exists) {
        final emailPrefix = firebaseUser.email != null
            ? firebaseUser.email!.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase()
            : 'user';
        final defaultUsername = '${emailPrefix}_${DateTime.now().millisecondsSinceEpoch % 1000}';
        final newUser = UserModel(
          uid: firebaseUser.uid,
          displayName: firebaseUser.displayName ?? 'Người dùng',
          username: defaultUsername,
          email: firebaseUser.email,
          avatarUrl: firebaseUser.photoURL,
          friends: [],
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
      }
    }
    return userCredential;
  }

  // ==========================================
  // SIGN IN WITH APPLE
  // ==========================================

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final OAuthCredential credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final firebaseUser = userCredential.user;

    if (firebaseUser != null) {
      final userDoc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (!userDoc.exists) {
        String displayName = 'Apple User';
        if (appleCredential.givenName != null || appleCredential.familyName != null) {
          final first = appleCredential.givenName ?? '';
          final last = appleCredential.familyName ?? '';
          displayName = '$last $first'.trim();
        }
        final emailPrefix = (firebaseUser.email ?? 'user')
            .split('@')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
            .toLowerCase();
        final defaultUsername = '${emailPrefix}_${DateTime.now().millisecondsSinceEpoch % 1000}';

        final newUser = UserModel(
          uid: firebaseUser.uid,
          displayName: displayName.isNotEmpty ? displayName : 'Thành viên Apple',
          username: defaultUsername,
          email: firebaseUser.email,
          friends: [],
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
      }
    }
    return userCredential;
  }

  // ==========================================
  // SIGN OUT & ACCOUNT DELETION (Apple Standard)
  // ==========================================

  // Sign out
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // Delete user account permanently according to Apple App Store Review Guideline 5.1.1(v)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1. Delete user's uploaded photos and storage media files
    try {
      final photosSnapshot = await _db
          .collection('photos')
          .where('senderId', isEqualTo: uid)
          .get();

      final storage = FirebaseStorage.instance;
      for (final doc in photosSnapshot.docs) {
        try {
          final imageUrl = doc.data()['imageUrl'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            await storage.refFromURL(imageUrl).delete().catchError((_) {});
          }
          final videoUrl = doc.data()['videoUrl'] as String?;
          if (videoUrl != null && videoUrl.isNotEmpty) {
            await storage.refFromURL(videoUrl).delete().catchError((_) {});
          }
        } catch (_) {}
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting user photos: $e');
    }

    // 2. Remove user from all friends' lists
    try {
      final friendsSnapshot = await _db
          .collection('users')
          .where('friends', arrayContains: uid)
          .get();

      final batch = _db.batch();
      for (final friendDoc in friendsSnapshot.docs) {
        batch.update(friendDoc.reference, {
          'friends': FieldValue.arrayRemove([uid]),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error removing user from friends: $e');
    }

    // 3. Delete friend requests (both sent and received)
    try {
      final reqSent = await _db
          .collection('friendRequests')
          .where('from', isEqualTo: uid)
          .get();
      for (final doc in reqSent.docs) {
        await doc.reference.delete();
      }

      final reqReceived = await _db
          .collection('friendRequests')
          .where('to', isEqualTo: uid)
          .get();
      for (final doc in reqReceived.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting friend requests: $e');
    }

    // 4. Delete notifications for or from this user
    try {
      final notifsForUser = await _db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in notifsForUser.docs) {
        await doc.reference.delete();
      }

      final notifsFromUser = await _db
          .collection('notifications')
          .where('senderId', isEqualTo: uid)
          .get();
      for (final doc in notifsFromUser.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting notifications: $e');
    }

    // 5. Delete user avatar in storage if exists
    try {
      await FirebaseStorage.instance
          .ref()
          .child('avatars/$uid.jpg')
          .delete()
          .catchError((_) {});
    } catch (_) {}

    // 6. Delete user Firestore document
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting user doc: $e');
    }

    // 7. Clear local data & widget cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await WidgetService.updateLatestPhoto('');
    } catch (_) {}

    // 8. Delete user from Firebase Authentication
    // May throw FirebaseAuthException with code 'requires-recent-login'
    await user.delete();
  }

  // Get user profile document
  Future<UserModel?> getUserDocument(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  // Stream user profile document
  Stream<UserModel?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Update user document
  Future<void> updateUserDocument(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // Update FCM token
  Future<void> updateFCMToken(String uid, String token) async {
    await updateUserDocument(uid, {'fcmToken': token});
  }
}
