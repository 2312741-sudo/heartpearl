import 'package:flutter_test/flutter_test.dart';
import 'package:heartpearl/models/user_model.dart';
import 'package:heartpearl/models/photo_model.dart';
import 'package:heartpearl/models/chat_model.dart';
import 'package:heartpearl/models/friend_request_model.dart';
import 'package:heartpearl/models/notification_model.dart';
import 'package:heartpearl/core/utils/date_helper.dart';
import 'package:heartpearl/core/utils/camera_filters.dart';
import 'package:heartpearl/services/content_filter_service.dart';
import 'package:heartpearl/services/widget_service.dart';
import 'package:heartpearl/services/media_downloader_service.dart';
import 'package:heartpearl/core/utils/url_launcher_helper.dart';
import 'package:heartpearl/core/constants/app_info.dart';

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
        blockedUsers: ['user_blocked'],
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['displayName'], 'Thanh Tâm');
      expect(map['username'], 'tamchau');
      expect(map['email'], 'tam@example.com');
      expect(map['friends'], ['user_456', 'user_789']);
      expect(map['blockedUsers'], ['user_blocked']);

      final fromMapUser = UserModel.fromMap(map, uid: 'user_123');
      expect(fromMapUser.uid, 'user_123');
      expect(fromMapUser.displayName, 'Thanh Tâm');
      expect(fromMapUser.username, 'tamchau');
      expect(fromMapUser.blockedUsers, ['user_blocked']);
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
      expect(BeautyFilter.all.length, 25);
      expect(BeautyFilter.all.first.type, BeautyFilterType.normal);
      expect(BeautyFilter.all[1].type, BeautyFilterType.pearlNatural);
      expect(BeautyFilter.all[1].name, 'Pearl Natural');
    });

    test(
      'ContentFilterService detects objectionable text per Guideline 1.2',
      () {
        expect(ContentFilterService.isObjectionable('Hello friend'), isFalse);
        expect(
          ContentFilterService.isObjectionable('Khoảnh khắc tuyệt vời!'),
          isFalse,
        );
        expect(ContentFilterService.isObjectionable('fuck you'), isTrue);
        expect(ContentFilterService.isObjectionable('đụ má mày'), isTrue);
        expect(
          ContentFilterService.isObjectionable('chat sex gái gọi'),
          isTrue,
        );
      },
    );

    test('NotificationModel mapping and serialization test', () {
      final now = DateTime(2026, 9, 18, 12, 0);
      final notif = NotificationModel(
        id: 'notif_001',
        userId: 'user_recipient',
        senderId: 'user_sender',
        senderName: 'Lan Hương',
        senderAvatarUrl: 'https://example.com/avatar.jpg',
        type: 'photo',
        title: 'HeartPearl',
        body: '📸 Lan Hương vừa chia sẻ khoảnh khắc mới với bạn!',
        read: false,
        photoId: 'photo_999',
        createdAt: now,
      );

      final map = notif.toMap();
      expect(map['userId'], 'user_recipient');
      expect(map['senderId'], 'user_sender');
      expect(map['senderName'], 'Lan Hương');
      expect(map['senderAvatarUrl'], 'https://example.com/avatar.jpg');
      expect(map['type'], 'photo');
      expect(map['read'], false);
      expect(map['photoId'], 'photo_999');
    });

    test('BeautySettings serialization and default values', () {
      const settings = BeautySettings();
      expect(settings.enabled, isTrue);
      expect(settings.overall, 0.52);
      expect(settings.smoothing, 0.48);
      expect(settings.hasEffect, isTrue);

      final map = settings.toMap();
      final restored = BeautySettings.fromMap(map);
      expect(restored.enabled, settings.enabled);
      expect(restored.overall, settings.overall);
      expect(restored.smoothing, settings.smoothing);
      expect(restored.vitality, settings.vitality);

      final off = BeautySettings.off;
      expect(off.hasEffect, isFalse);
    });

    test('FilterCategory categorizes filters correctly', () {
      expect(FilterCategory.values.length, 8);
      final naturalFilters = BeautyFilter.inCategory(FilterCategory.natural);
      expect(naturalFilters.length, 3);
      expect(naturalFilters.any((f) => f.name == 'Pearl Natural'), isTrue);

      final koreanFilters = BeautyFilter.inCategory(
        FilterCategory.koreanBeauty,
      );
      expect(koreanFilters.length, 3);
      expect(koreanFilters.any((f) => f.name == 'Milk Glow'), isTrue);
    });

    test('WidgetService constants are correct', () {
      expect(WidgetService.appGroupId, 'group.com.tamchau.app');
      expect(WidgetService.iOSWidgetName, 'widget');
      expect(WidgetService.locationWidgetUniqueName,
          'com.heartpearl.heartpearl.locationWidgetRefresh');
    });

    test('MediaDownloaderService album name is correct', () {
      expect(MediaDownloaderService.albumName, 'HeartPearl');
    });

    test('UrlLauncherHelper constants and URL validity check', () {
      expect(UrlLauncherHelper.supportEmail, 'nthanhtam.402@gmail.com');
      expect(UrlLauncherHelper.privacyPolicyUrl,
          'https://tamchau-865f3.web.app/privacy-policy.html');
      expect(UrlLauncherHelper.eulaUrl,
          'https://tamchau-865f3.web.app/eula.html');
      expect(UrlLauncherHelper.deleteAccountUrl,
          'https://tamchau-865f3.web.app/delete-account.html');
      expect(UrlLauncherHelper.webPortalUrl,
          'https://tamchau-865f3.web.app');

      expect(Uri.parse(UrlLauncherHelper.privacyPolicyUrl).isAbsolute, isTrue);
      expect(Uri.parse(UrlLauncherHelper.eulaUrl).isAbsolute, isTrue);
      expect(Uri.parse(UrlLauncherHelper.deleteAccountUrl).isAbsolute, isTrue);
      expect(Uri.parse(UrlLauncherHelper.webPortalUrl).isAbsolute, isTrue);
    });

    test('AppInfo constants are defined and valid', () {
      expect(AppInfo.appName, 'HeartPearl');
      expect(AppInfo.appVersion, '1.0.1');
      expect(AppInfo.buildNumber, '7');
      expect(AppInfo.fullVersion, '1.0.1 (Build 7)');
      expect(AppInfo.bundleId, 'com.heartpearl.heartpearl');
      expect(AppInfo.supportEmail, 'nthanhtam.402@gmail.com');
      expect(AppInfo.copyright, contains('HeartPearl'));
    });
  });
}
