import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String username;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? fcmToken;
  final List<String> friends;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    this.fcmToken,
    this.friends = const [],
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromMap(data, uid: doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> data, {required String uid}) {
    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    }

    return UserModel(
      uid: uid,
      displayName: data['displayName'] as String? ?? 'Người dùng',
      username: data['username'] as String? ?? 'user',
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      fcmToken: data['fcmToken'] as String?,
      friends: List<String>.from(data['friends'] ?? []),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'phone': phone,
      'email': email,
      'avatarUrl': avatarUrl,
      'fcmToken': fcmToken,
      'friends': friends,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? username,
    String? phone,
    String? email,
    String? avatarUrl,
    String? fcmToken,
    List<String>? friends,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      friends: friends ?? this.friends,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
