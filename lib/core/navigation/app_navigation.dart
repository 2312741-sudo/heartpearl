import 'package:flutter/material.dart';
import '../../ui/main/chat/chat_room_screen.dart';
import '../../ui/main/friends/friends_screen.dart';
import '../../ui/main/notifications/notifications_screen.dart';

/// Global alias for backward compatibility
GlobalKey<NavigatorState> get appNavigatorKey => AppNavigation.navigatorKey;

class AppNavigation {
  /// Global navigator key attached to MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Safely schedule navigation action, ensuring MaterialApp is mounted even on cold start
  static void scheduleNavigation(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        action();
      } else {
        // Fallback retry if navigator is still building (cold start from push notification)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (navigatorKey.currentState != null) {
            action();
          }
        });
      }
    });
  }

  /// Pop all modals, dialogs, and subroutes until the root screen (MainScaffold)
  static void popToRoot() {
    try {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } catch (_) {}
  }

  /// Navigate cleanly to ChatRoomScreen without stacking duplicate instances
  static void navigateToChat({
    required String friendId,
    required String friendName,
    String? friendAvatar,
  }) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // 1. If user is ALREADY chatting with this specific friend, do not push duplicate
    if (ChatRoomScreen.activeFriendId == friendId) {
      return;
    }

    // 2. Safely pop any open dialogs, bottom sheets, or previous chat rooms back to root
    popToRoot();

    // 3. Push new ChatRoomScreen as the single top route
    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/chat_room'),
        builder: (context) => ChatRoomScreen(
          friendId: friendId,
          friendName: friendName,
          friendAvatar: friendAvatar != null && friendAvatar.isNotEmpty
              ? friendAvatar
              : null,
        ),
      ),
    );
  }

  /// Navigate cleanly to FriendsScreen without stacking
  static void navigateToFriends({int initialIndex = 0}) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Safely pop all dialogs/sheets back to root
    popToRoot();

    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/friends'),
        builder: (context) => FriendsScreen(initialIndex: initialIndex),
      ),
    );
  }

  /// Navigate cleanly to NotificationsScreen without stacking
  static void navigateToNotifications() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Safely pop all dialogs/sheets back to root
    popToRoot();

    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/notifications'),
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }
}
