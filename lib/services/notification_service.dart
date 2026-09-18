import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';
import '../ui/common/in_app_message_overlay.dart';
import '../ui/main/chat/chat_room_screen.dart';
import '../ui/main/friends/friends_screen.dart';
import '../ui/main/notifications/notifications_screen.dart';
import 'auth_service.dart';
import 'widget_service.dart';

/// Top-level background message handler (must be top-level, not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'location_widget_update') {
    // App is in background/terminated — update widget data from Firestore
    try {
      await WidgetService.initializeHomeWidget();
      await WidgetService.updateLocationWidget();
    } catch (_) {}
  }
}

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();

  /// Register the background message handler — call once at app start (before runApp)
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Initialize FCM
  Future<void> initializeFCM(String userId) async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Show banner and play sound even if app is in foreground on iOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _fcm.getToken();
        if (token != null) {
          await _authService.updateFCMToken(userId, token);
        }
      }

      // Listen for foreground data messages (app open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (message.data['type'] == 'location_widget_update') {
          try {
            await WidgetService.updateLocationWidget();
          } catch (_) {}
        }
      });

      // Listen for when user taps notification to open app from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleNotificationClick(message);
      });

      // Check if the app was launched by tapping a notification from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        handleNotificationClick(initialMessage);
      }
    } catch (_) {}
  }

  /// Handle outside-app notification clicks and deep-link to the right screen
  static void handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'chat_message') {
      final senderId = data['senderId'] as String?;
      final friendName = (data['friendName'] as String?) ?? 'Bạn bè';
      final friendAvatar = data['friendAvatar'] as String?;

      if (senderId != null && senderId.isNotEmpty) {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              friendId: senderId,
              friendName: friendName,
              friendAvatar: friendAvatar != null && friendAvatar.isNotEmpty
                  ? friendAvatar
                  : null,
            ),
          ),
        );
      }
    } else if (type == 'friend_request' || type == 'friend_accept') {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => FriendsScreen(
            initialIndex: type == 'friend_request' ? 1 : 0,
          ),
        ),
      );
    } else if (type == 'photo' || type == 'reaction') {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        ),
      );
    }
  }

  // Stream in-app notifications
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  // Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (_) {}
  }

  // Mark all unread notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  // Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
    } catch (_) {}
  }

  // Clear all notifications for user
  Future<void> clearAllNotifications(String userId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (_) {}
  }
}
