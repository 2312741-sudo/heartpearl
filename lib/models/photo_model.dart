import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class PhotoModel {
  final String id;
  final String senderId;
  final UserModel? senderUser;
  final List<String> recipientIds;
  final String imageUrl;
  final String? videoUrl;
  final String? caption;
  final String mediaType; // 'photo' or 'video'
  final bool isMirrored;
  final bool filter;
  final DateTime createdAt;
  final Map<String, String> reactions; // userId -> selfieUrl
  final Map<String, String> textReactions; // userId -> message
  final Map<String, bool> seen; // userId -> hasSeen

  const PhotoModel({
    required this.id,
    required this.senderId,
    this.senderUser,
    required this.recipientIds,
    required this.imageUrl,
    this.videoUrl,
    this.caption,
    this.mediaType = 'photo',
    this.isMirrored = false,
    this.filter = false,
    required this.createdAt,
    this.reactions = const {},
    this.textReactions = const {},
    this.seen = const {},
  });

  bool get isVideo => mediaType == 'video';

  factory PhotoModel.fromFirestore(DocumentSnapshot doc, {UserModel? senderUser}) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    }

    final rawReactions = data['reactions'];
    final Map<String, String> parsedReactions = {};
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        if (v != null) parsedReactions[k.toString()] = v.toString();
      });
    }

    final rawTextReactions = data['textReactions'];
    final Map<String, String> parsedTextReactions = {};
    if (rawTextReactions is Map) {
      rawTextReactions.forEach((k, v) {
        if (v != null) parsedTextReactions[k.toString()] = v.toString();
      });
    }

    final rawSeen = data['seen'];
    final Map<String, bool> parsedSeen = {};
    if (rawSeen is Map) {
      rawSeen.forEach((k, v) {
        parsedSeen[k.toString()] = v == true;
      });
    }

    return PhotoModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderUser: senderUser,
      recipientIds: List<String>.from(data['recipientIds'] ?? []),
      imageUrl: data['imageUrl'] as String? ?? '',
      videoUrl: data['videoUrl'] as String?,
      caption: data['caption'] as String?,
      mediaType: data['mediaType'] as String? ?? 'photo',
      isMirrored: data['isMirrored'] as bool? ?? false,
      filter: data['filter'] as bool? ?? false,
      createdAt: parsedDate,
      reactions: parsedReactions,
      textReactions: parsedTextReactions,
      seen: parsedSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'recipientIds': recipientIds,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'caption': caption,
      'mediaType': mediaType,
      'isMirrored': isMirrored,
      'filter': filter,
      'createdAt': Timestamp.fromDate(createdAt),
      'reactions': reactions,
      'textReactions': textReactions,
      'seen': seen,
    };
  }

  PhotoModel copyWith({
    String? id,
    String? senderId,
    UserModel? senderUser,
    List<String>? recipientIds,
    String? imageUrl,
    String? videoUrl,
    String? caption,
    String? mediaType,
    bool? isMirrored,
    bool? filter,
    DateTime? createdAt,
    Map<String, String>? reactions,
    Map<String, String>? textReactions,
    Map<String, bool>? seen,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderUser: senderUser ?? this.senderUser,
      recipientIds: recipientIds ?? this.recipientIds,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      caption: caption ?? this.caption,
      mediaType: mediaType ?? this.mediaType,
      isMirrored: isMirrored ?? this.isMirrored,
      filter: filter ?? this.filter,
      createdAt: createdAt ?? this.createdAt,
      reactions: reactions ?? this.reactions,
      textReactions: textReactions ?? this.textReactions,
      seen: seen ?? this.seen,
    );
  }
}
