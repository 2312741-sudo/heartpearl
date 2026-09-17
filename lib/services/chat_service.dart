import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream user chat rooms
  Stream<List<ChatRoomModel>> streamChats(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoomModel.fromFirestore(doc))
          .toList();
    });
  }

  // Stream messages in a chat room
  Stream<List<ChatMessageModel>> streamMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessageModel.fromFirestore(doc))
          .toList();
    });
  }

  // Send message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? photoUrl,
    String type = 'text',
    required String recipientId,
    required String currentUserName,
    required String currentUserAvatar,
    required String recipientName,
    required String recipientAvatar,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && photoUrl == null) return;

    // Add message
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': senderId,
      'text': trimmed,
      'photoUrl': photoUrl,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update chat summary metadata
    await _db.collection('chats').doc(chatId).set({
      'participants': [senderId, recipientId]..sort(),
      'participantsInfo': {
        senderId: {'name': currentUserName, 'avatar': currentUserAvatar},
        recipientId: {'name': recipientName, 'avatar': recipientAvatar},
      },
      'lastMessage': photoUrl != null ? '📷 $trimmed' : trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount.$recipientId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // In-app notification
    try {
      await _db.collection('notifications').add({
        'userId': recipientId,
        'senderId': senderId,
        'type': 'message',
        'title': 'HeartPearl',
        'body': '💬 $currentUserName: $trimmed',
        'read': false,
        'chatId': chatId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Mark chat as read
  Future<void> markChatAsRead(String chatId, String userId) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'unreadCount.$userId': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
