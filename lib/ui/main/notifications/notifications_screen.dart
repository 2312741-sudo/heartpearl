import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/notification_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../common/skeleton_loader.dart';
import '../../common/user_avatar.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_room_screen.dart';
import '../friends/friends_screen.dart';
import '../viewer/photo_viewer_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _filterIndex = 0; // 0: Tất cả, 1: Chưa đọc

  Future<void> _handleNotificationTap(NotificationModel notif) async {
    HapticHelper.light();
    final notifService = ref.read(notificationServiceProvider);

    // Mark as read
    if (!notif.read) {
      await notifService.markAsRead(notif.id);
    }

    if (!mounted) return;

    // Deep link based on notification type
    switch (notif.type) {
      case 'photo':
      case 'reaction':
        if (notif.photoId != null && notif.photoId!.isNotEmpty) {
          final photoService = ref.read(photoServiceProvider);
          final photo = await photoService.getPhotoById(notif.photoId!);
          if (!mounted) return;
          if (photo != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PhotoViewerScreen(photo: photo),
              ),
            );
            return;
          }
        }
        // Fallback: Notify user photo might have expired or been removed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Khoảnh khắc này đã hết hạn hoặc không còn khả dụng.'),
          ),
        );
        break;

      case 'friend_request':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FriendsScreen(initialIndex: 1),
          ),
        );
        break;

      case 'friend_accept':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FriendsScreen(initialIndex: 0),
          ),
        );
        break;

      case 'message':
        if (notif.senderId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                friendId: notif.senderId,
                friendName: notif.senderName ?? notif.title,
                friendAvatar: notif.senderAvatarUrl,
              ),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ChatListScreen(),
          ),
        );
        break;

      default:
        break;
    }
  }

  Future<void> _confirmClearAll(String userId, bool isDark) async {
    HapticHelper.medium();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Xóa tất cả thông báo?',
          style: AppTypography.h3(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Tất cả thông báo sẽ bị xóa vĩnh viễn khỏi tài khoản của bạn.',
          style: AppTypography.body(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Hủy',
              style: AppTypography.body(
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(notificationServiceProvider).clearAllNotifications(userId);
      HapticHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa toàn bộ thông báo.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProfileProvider).value;
    final notifsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  LucideIcons.arrowLeft,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Thông báo',
          style: AppTypography.h2(
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          if (user != null) ...[
            // Mark all as read button
            IconButton(
              tooltip: 'Đánh dấu tất cả đã đọc',
              icon: Icon(
                LucideIcons.checkCheck,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                size: 22,
              ),
              onPressed: () async {
                HapticHelper.selection();
                await ref
                    .read(notificationServiceProvider)
                    .markAllAsRead(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã đánh dấu tất cả là đã đọc.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            // Clear all button
            IconButton(
              tooltip: 'Xóa tất cả thông báo',
              icon: Icon(
                LucideIcons.trash2,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
                size: 20,
              ),
              onPressed: () => _confirmClearAll(user.uid, isDark),
            ),
          ],
        ],
      ),
      body: notifsAsync.when(
        data: (allNotifs) {
          final unreadCount = allNotifs.where((n) => !n.read).length;
          final displayNotifs = _filterIndex == 1
              ? allNotifs.where((n) => !n.read).toList()
              : allNotifs;

          return Column(
            children: [
              // Filter Chips Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceSm,
                ),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Tất cả (${allNotifs.length})',
                      isSelected: _filterIndex == 0,
                      isDark: isDark,
                      onTap: () {
                        HapticHelper.selection();
                        setState(() => _filterIndex = 0);
                      },
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    _buildFilterChip(
                      label: 'Chưa đọc ($unreadCount)',
                      isSelected: _filterIndex == 1,
                      isDark: isDark,
                      hasBadge: unreadCount > 0,
                      onTap: () {
                        HapticHelper.selection();
                        setState(() => _filterIndex = 1);
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.5),

              // Content List
              Expanded(
                child: displayNotifs.isEmpty
                    ? _buildEmptyState(isDark: isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.spaceSm,
                        ),
                        itemCount: displayNotifs.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.5)
                              : AppColors.lightBorder.withValues(alpha: 0.5),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final notif = displayNotifs[index];
                          return Dismissible(
                            key: ValueKey(notif.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spaceLg,
                              ),
                              color: AppColors.error,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.trash2,
                                    color: AppColors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Xóa',
                                    style: AppTypography.captionBold(
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) {
                              HapticHelper.selection();
                              ref
                                  .read(notificationServiceProvider)
                                  .deleteNotification(notif.id);
                            },
                            child: _buildNotificationTile(
                              notif: notif,
                              isDark: isDark,
                            ),
                          ).animate().fadeIn(
                            duration: 300.ms,
                            delay: (index.clamp(0, 8) * 50).ms,
                          ).slideY(begin: 0.08, end: 0);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const SkeletonListView(),
        error: (err, _) => Center(
          child: Text(
            'Lỗi tải thông báo: $err',
            style: AppTypography.body(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryLight
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.medium.copyWith(
                color: isSelected
                    ? AppColors.white
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasBadge && !isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required NotificationModel notif,
    required bool isDark,
  }) {
    IconData typeIcon = LucideIcons.bell;
    Color typeColor = AppColors.primaryLight;

    switch (notif.type) {
      case 'photo':
        typeIcon = LucideIcons.camera;
        typeColor = AppColors.secondary;
        break;
      case 'reaction':
        typeIcon = LucideIcons.heart;
        typeColor = AppColors.error;
        break;
      case 'friend_request':
        typeIcon = LucideIcons.userPlus;
        typeColor = AppColors.success;
        break;
      case 'friend_accept':
        typeIcon = LucideIcons.userCheck;
        typeColor = AppColors.primary;
        break;
      case 'message':
        typeIcon = LucideIcons.messageCircle;
        typeColor = AppColors.info;
        break;
    }

    return InkWell(
      onTap: () => _handleNotificationTap(notif),
      child: Container(
        color: notif.read
            ? Colors.transparent
            : (isDark
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.05)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sender Avatar with Type Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  imageUrl: notif.senderAvatarUrl,
                  name: notif.senderName ?? 'User',
                  size: 46,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBackground
                            : AppColors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      typeIcon,
                      color: AppColors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppDimens.spaceMd),

            // Notification Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          notif.senderName ?? notif.title,
                          style: AppTypography.bodyBold(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateHelper.timeAgo(notif.createdAt),
                        style: AppTypography.caption(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: AppTypography.body(
                      color: notif.read
                          ? (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary)
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                    ).copyWith(
                      fontWeight:
                          notif.read ? FontWeight.normal : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Unread Indicator Dot
            if (!notif.read)
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              )
            else
              const Icon(
                LucideIcons.chevronRight,
                color: Colors.white24,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isDark}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space2Xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
                boxShadow: AppDimens.glowShadow(
                  AppColors.primary,
                  opacity: 0.25,
                ),
              ),
              child: Icon(
                _filterIndex == 1
                    ? LucideIcons.checkCheck
                    : LucideIcons.bellOff,
                size: 48,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Text(
              _filterIndex == 1
                  ? 'Tuyệt vời! Không có thông báo chưa đọc'
                  : 'Bạn chưa có thông báo nào',
              style: AppTypography.h3(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _filterIndex == 1
                  ? 'Bạn đã xem hết tất cả thông báo.'
                  : 'Khi bạn bè chia sẻ khoảnh khắc, thả cảm xúc hoặc gửi tin nhắn, thông báo sẽ xuất hiện ở đây.',
              style: AppTypography.body(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
