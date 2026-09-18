import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  final profile = ref.watch(userProfileProvider).value;
  if (user == null || profile == null) {
    return Stream.value([]);
  }

  final service = ref.watch(notificationServiceProvider);
  final blockedUsers = profile.blockedUsers.toSet();
  return service
      .streamNotifications(user.uid)
      .map(
        (notifications) => notifications
            .where(
              (notification) => !blockedUsers.contains(notification.senderId),
            )
            .toList(),
      );
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificationsStreamProvider);
  return notifsAsync.maybeWhen(
    data: (notifs) => notifs.where((n) => !n.read).length,
    orElse: () => 0,
  );
});
