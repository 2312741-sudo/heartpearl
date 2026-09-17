import 'package:flutter_test/flutter_test.dart';
import 'package:heartpearl/models/user_model.dart';
import 'package:heartpearl/models/photo_model.dart';
import 'package:heartpearl/models/chat_model.dart';
import 'package:heartpearl/models/friend_request_model.dart';
import 'package:heartpearl/core/utils/date_helper.dart';
import 'package:heartpearl/core/utils/camera_filters.dart';

void main() {
  group('HeartPearl Models & Helpers Tests', () {
    test('UserModel serialization and deserialization', () {
      final now = DateTime(2026, 9, 17, 8, 30);
      final user = UserModel(
        uid: 'user_123',
        displayName: 'Thanh Tâm',
        username: 'tamchau',
        email: 'tam@example.com',
        friends: ['user_456', 'user_789'],
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['displayName'], 'Thanh Tâm');
      expect(map['username'], 'tamchau');
      expect(map['email'], 'tam@example.com');
      expect(map['friends'], ['user_456', 'user_789']);

      final fromMapUser = UserModel.fromMap(map, uid: 'user_123');
      expect(fromMapUser.uid, 'user_123');
      expect(fromMapUser.displayName, 'Thanh Tâm');
      expect(fromMapUser.username, 'tamchau');
    });

    test('PhotoModel reactions and video flag test', () {
      final now = DateTime.now();
      final photo = PhotoModel(
        id: 'photo_001',
        senderId: 'user_123',
        recipientIds: ['user_456'],
        imageUrl: 'https://example.com/photo.jpg',
        mediaType: 'video',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now,
        reactions: {'user_456': 'https://example.com/selfie.jpg'},
        textReactions: {'user_456': '❤️'},
      );

      expect(photo.isVideo, isTrue);
      expect(photo.reactions.containsKey('user_456'), isTrue);
      expect(photo.textReactions['user_456'], '❤️');
    });

    test('FriendRequestModel mapping test', () {
      final req = FriendRequestModel(
        id: 'req_001',
        from: 'user_123',
        to: 'user_456',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      final map = req.toMap();
      expect(map['from'], 'user_123');
      expect(map['to'], 'user_456');
      expect(map['status'], 'pending');
    });

    test('ChatMessageModel mapping test', () {
      final msg = ChatMessageModel(
        id: 'msg_001',
        senderId: 'user_123',
        text: 'Xin chào bạn!',
        type: 'text',
        createdAt: DateTime.now(),
      );

      final map = msg.toMap();
      expect(map['senderId'], 'user_123');
      expect(map['text'], 'Xin chào bạn!');
      expect(map['type'], 'text');
    });

    test('DateHelper relative time test', () {
      final now = DateTime.now();
      final justNow = now.subtract(const Duration(seconds: 10));
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));

      expect(DateHelper.timeAgo(justNow, lang: 'vi'), 'vừa xong');
      expect(DateHelper.timeAgo(fiveMinAgo, lang: 'vi'), '5 phút trước');
    });

    test('BeautyFilter configuration check', () {
      expect(BeautyFilter.all.length, 4);
      expect(BeautyFilter.all.first.type, BeautyFilterType.normal);
      expect(BeautyFilter.all[1].type, BeautyFilterType.softGlow);
    });
  });
}
