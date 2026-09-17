import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
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
