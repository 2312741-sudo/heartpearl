import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream user chat rooms
  Stream<List<ChatRoomModel>> streamChats(
    String userId, {
    Set<String> blockedUserIds = const {},
  }) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatRoomModel.fromFirestore(doc))
              .where((chat) => !chat.participants.any(blockedUserIds.contains))
              .toList();
        });
  }

  // Stream messages in a chat room
  Stream<List<ChatMessageModel>> streamMessages(
    String chatId, {
    Set<String> blockedUserIds = const {},
  }) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessageModel.fromFirestore(doc))
              .where((message) => !blockedUserIds.contains(message.senderId))
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

    try {
      if (senderId.isEmpty || recipientId.isEmpty || senderId == recipientId) {
        throw ArgumentError('Người gửi hoặc người nhận không hợp lệ.');
      }
      if (await _isInteractionBlocked(senderId, recipientId)) {
        throw StateError('Không thể gửi tin nhắn do cài đặt chặn.');
      }

      final chatReference = _db.collection('chats').doc(chatId);
      final messageReference = chatReference.collection('messages').doc();
      final batch = _db.batch();
      batch.set(messageReference, {
        'senderId': senderId,
        'text': trimmed,
        'photoUrl': photoUrl,
        'type': type,
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(chatReference, {
        'participants': [senderId, recipientId]..sort(),
        'participantsInfo': {
          senderId: {'name': currentUserName, 'avatar': currentUserAvatar},
          recipientId: {'name': recipientName, 'avatar': recipientAvatar},
        },
        'lastMessage': photoUrl != null ? '📷 $trimmed' : trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount.$recipientId': FieldValue.increment(1),
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (error) {
      throw Exception('Không thể gửi tin nhắn: $error');
    }
  }

  Future<void> prepareChatAccess({
    required String chatId,
    required String senderId,
    required String recipientId,
    required String currentUserName,
    required String currentUserAvatar,
    required String recipientName,
    required String recipientAvatar,
  }) async {
    try {
      if (await _isInteractionBlocked(senderId, recipientId)) {
        throw StateError('Không thể tương tác do cài đặt chặn.');
      }
      await _db.collection('chats').doc(chatId).set({
        'participants': [senderId, recipientId]..sort(),
        'participantsInfo': {
          senderId: {'name': currentUserName, 'avatar': currentUserAvatar},
          recipientId: {'name': recipientName, 'avatar': recipientAvatar},
        },
      }, SetOptions(merge: true));
    } catch (error) {
      throw Exception('Không thể chuẩn bị cuộc trò chuyện: $error');
    }
  }

  Future<bool> _isInteractionBlocked(String firstUid, String secondUid) async {
    final documents = await Future.wait([
      _db.collection('users').doc(firstUid).get(),
      _db.collection('users').doc(secondUid).get(),
    ]);

    bool containsUid(
      DocumentSnapshot<Map<String, dynamic>> document,
      String uid,
    ) {
      final raw = document.data()?['blockedUsers'];
      return raw is Iterable && raw.whereType<String>().contains(uid);
    }

    return containsUid(documents[0], secondUid) ||
        containsUid(documents[1], firstUid);
  }

  // Mark all unread messages received by recipient in this chat as delivered
  Future<void> markMessagesAsDelivered(
    String chatId, {
    String? recipientId,
    String? senderId,
  }) async {
    try {
      final query = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('status', isEqualTo: 'sent')
          .limit(30)
          .get();

      if (query.docs.isEmpty) return;

      final batch = _db.batch();
      var hasUpdates = false;

      for (final doc in query.docs) {
        final data = doc.data();
        final docSenderId = data['senderId'] as String?;
        final isTarget = (senderId != null && docSenderId == senderId) ||
            (recipientId != null && docSenderId != recipientId);

        if (isTarget) {
          batch.update(doc.reference, {'status': 'delivered'});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (_) {}
  }

  // Mark all unread messages received by viewer in this chat as seen
  Future<void> markMessagesAsSeen(
    String chatId, {
    required String viewerId,
  }) async {
    try {
      final query = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('status', whereIn: ['sent', 'delivered'])
          .limit(40)
          .get();

      if (query.docs.isEmpty) return;

      final batch = _db.batch();
      var hasUpdates = false;

      for (final doc in query.docs) {
        final data = doc.data();
        if (data['senderId'] != viewerId) {
          batch.update(doc.reference, {'status': 'seen'});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (_) {}
  }

  // Mark chat as read
  Future<void> markChatAsRead(String chatId, String userId) async {
    try {
      await _db.collection('chats').doc(chatId).update({
        'unreadCount.$userId': 0,
      }).catchError((_) async {
        await _db.collection('chats').doc(chatId).set({
          'unreadCount': {userId: 0},
        }, SetOptions(merge: true));
      });
    } catch (_) {}
  }
}
