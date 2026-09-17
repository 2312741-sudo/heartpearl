import 'package:cloud_firestore/cloud_firestore.dart';

class ChatParticipantInfo {
  final String name;
  final String avatar;

  const ChatParticipantInfo({required this.name, required this.avatar});

  factory ChatParticipantInfo.fromMap(Map<String, dynamic> map) {
    return ChatParticipantInfo(
      name: map['name'] as String? ?? 'Bạn bè',
      avatar: map['avatar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'avatar': avatar};
}

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final Map<String, ChatParticipantInfo> participantsInfo;
  final String lastMessage;
  final DateTime updatedAt;
  final Map<String, int> unreadCount;

  const ChatRoomModel({
    required this.id,
    required this.participants,
    required this.participantsInfo,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = const {},
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['updatedAt'] is Timestamp) {
      parsedDate = (data['updatedAt'] as Timestamp).toDate();
    } else if (data['updatedAt'] is String) {
      parsedDate = DateTime.tryParse(data['updatedAt']) ?? DateTime.now();
    }

    final rawParticipants = data['participants'];
    final List<String> participants = List<String>.from(rawParticipants ?? []);

    final rawInfo = data['participantsInfo'];
    final Map<String, ChatParticipantInfo> participantsInfo = {};
    if (rawInfo is Map) {
      rawInfo.forEach((k, v) {
        if (v is Map) {
          participantsInfo[k.toString()] =
              ChatParticipantInfo.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    final rawUnread = data['unreadCount'];
    final Map<String, int> unreadCount = {};
    if (rawUnread is Map) {
      rawUnread.forEach((k, v) {
        if (v is num) unreadCount[k.toString()] = v.toInt();
      });
    }

    return ChatRoomModel(
      id: doc.id,
      participants: participants,
      participantsInfo: participantsInfo,
      lastMessage: data['lastMessage'] as String? ?? '',
      updatedAt: parsedDate,
      unreadCount: unreadCount,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String senderId;
  final String text;
  final String? photoUrl;
  final String type; // 'text', 'reaction', 'photo'
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.photoUrl,
    this.type = 'text',
    required this.createdAt,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    }

    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      type: data['type'] as String? ?? 'text',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'photoUrl': photoUrl,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
