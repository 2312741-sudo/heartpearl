import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/chat_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/app_badge.dart';
import '../../common/skeleton_loader.dart';
import '../../common/user_avatar.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProfileProvider).value;
    final chatsAsync = ref.watch(chatRoomsProvider);

    ref.listen<AsyncValue<List<ChatRoomModel>>>(
      chatRoomsProvider,
      (previous, next) {
        next.whenData((chats) {
          final uid = user?.uid;
          if (uid == null) return;
          for (final chat in chats) {
            final unread = chat.unreadCount[uid] ?? 0;
            if (unread > 0) {
              ref.read(chatServiceProvider).markMessagesAsDelivered(chat.id, recipientId: uid);
            }
          }
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevronLeft,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.tr('chat_title', lang: lang),
          style: AppTypography.h2(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: chatsAsync.when(
        data: (chats) {
          final uid = user?.uid;
          if (uid != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              for (final chat in chats) {
                final unread = chat.unreadCount[uid] ?? 0;
                if (unread > 0) {
                  ref.read(chatServiceProvider).markMessagesAsDelivered(chat.id, recipientId: uid);
                }
              }
            });
          }
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      boxShadow: AppDimens.glowShadow(
                        AppColors.primary,
                        opacity: 0.25,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.messageCircle,
                      size: 48,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  Text(
                    AppStrings.tr('chat_empty', lang: lang),
                    style: AppTypography.h3(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
            itemCount: chats.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              height: 1,
              indent: 80,
            ),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final friendId = chat.participants.firstWhere(
                (id) => id != user?.uid,
                orElse: () => '',
              );

              final friendInfo = chat.participantsInfo[friendId] ??
                  const ChatParticipantInfo(name: 'Bạn bè', avatar: '');

              final unread = user != null ? (chat.unreadCount[user.uid] ?? 0) : 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: 6,
                ),
                leading: UserAvatar(
                  imageUrl: friendInfo.avatar,
                  name: friendInfo.name,
                  size: 52,
                ),
                title: Text(
                  friendInfo.name,
                  style: AppTypography.bodyBold(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(
                    color: unread > 0
                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ).copyWith(
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateHelper.formatShortTime(chat.updatedAt),
                      style: AppTypography.caption(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (unread > 0) AppBadge(count: unread),
                  ],
                ),
                onTap: () {
                  HapticHelper.light();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatRoomScreen(
                        friendId: friendId,
                        friendName: friendInfo.name,
                        friendAvatar: friendInfo.avatar,
                      ),
                    ),
                  );
                },
              ).animate().fadeIn(
                duration: 300.ms,
                delay: (index.clamp(0, 8) * 50).ms,
              ).slideY(begin: 0.08, end: 0);
            },
          );
        },
        loading: () => const SkeletonListView(),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }
}
