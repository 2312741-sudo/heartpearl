import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class FriendRequestModel {
  final String id;
  final String from;
  final String to;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime createdAt;
  final UserModel? fromUser;

  const FriendRequestModel({
    required this.id,
    required this.from,
    required this.to,
    this.status = 'pending',
    required this.createdAt,
    this.fromUser,
  });

  factory FriendRequestModel.fromFirestore(DocumentSnapshot doc, {UserModel? fromUser}) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    }

    return FriendRequestModel(
      id: doc.id,
      from: data['from'] as String? ?? '',
      to: data['to'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: parsedDate,
      fromUser: fromUser,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FriendRequestModel copyWith({
    String? id,
    String? from,
    String? to,
    String? status,
    DateTime? createdAt,
    UserModel? fromUser,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      fromUser: fromUser ?? this.fromUser,
    );
  }
}
