import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String type; // 'photo', 'reaction', 'friend_request', 'friend_accept', 'message'
  final String title;
  final String body;
  final bool read;
  final String? photoId;
  final String? requestId;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    this.photoId,
    this.requestId,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    }

    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String?,
      senderAvatarUrl: data['senderAvatarUrl'] as String?,
      type: data['type'] as String? ?? 'photo',
      title: data['title'] as String? ?? 'HeartPearl',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      photoId: data['photoId'] as String?,
      requestId: data['requestId'] as String?,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'senderId': senderId,
      if (senderName != null) 'senderName': senderName,
      if (senderAvatarUrl != null) 'senderAvatarUrl': senderAvatarUrl,
      'type': type,
      'title': title,
      'body': body,
      'read': read,
      'photoId': photoId,
      if (requestId != null) 'requestId': requestId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
