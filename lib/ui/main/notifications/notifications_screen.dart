import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    final user = ref.read(userProfileProvider).value;
    if (user != null) {
      ref.read(notificationServiceProvider).markAllAsRead(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thông báo',
          style: AppTypography.h2(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: notifsAsync.when(
        data: (notifs) {
          if (notifs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.bell,
                    size: 64,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  const SizedBox(height: AppDimens.spaceBase),
                  Text(
                    'Bạn chưa có thông báo nào',
                    style: AppTypography.h3(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
            itemCount: notifs.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final notif = notifs[index];

              IconData icon = LucideIcons.bell;
              Color iconColor = AppColors.primaryLight;
              if (notif.type == 'photo') {
                icon = LucideIcons.camera;
                iconColor = AppColors.secondary;
              } else if (notif.type == 'reaction') {
                icon = LucideIcons.heart;
                iconColor = AppColors.error;
              } else if (notif.type == 'friend_request') {
                icon = LucideIcons.userPlus;
                iconColor = AppColors.success;
              } else if (notif.type == 'message') {
                icon = LucideIcons.messageCircle;
                iconColor = AppColors.info;
              }

              return Container(
                color: notif.read
                    ? Colors.transparent
                    : (isDark
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.04)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  title: Text(
                    notif.title,
                    style: AppTypography.bodyBold(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        notif.body,
                        style: AppTypography.body(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateHelper.timeAgo(notif.createdAt),
                        style: AppTypography.caption(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }
}
