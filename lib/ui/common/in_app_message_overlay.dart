import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/haptic_helper.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../main/chat/chat_room_screen.dart';
import 'frosted_container.dart';
import 'user_avatar.dart';

/// Global navigator key to allow in-app popups to navigate to chat rooms
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class _ActiveMessageNotification {
  final String chatId;
  final String friendId;
  final String friendName;
  final String friendAvatar;
  final String message;

  const _ActiveMessageNotification({
    required this.chatId,
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    required this.message,
  });
}

class InAppMessageOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const InAppMessageOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<InAppMessageOverlay> createState() =>
      _InAppMessageOverlayState();
}

class _InAppMessageOverlayState extends ConsumerState<InAppMessageOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final Map<String, int> _previousUnreadCounts = {};
  bool _isInitialLoad = true;
  _ActiveMessageNotification? _currentNotification;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleChatsUpdate(List<ChatRoomModel> chats, String currentUserId) {
    if (_isInitialLoad) {
      for (final chat in chats) {
        _previousUnreadCounts[chat.id] = chat.unreadCount[currentUserId] ?? 0;
      }
      _isInitialLoad = false;
      return;
    }

    ChatRoomModel? triggeredChat;
    String? triggeredFriendId;

    for (final chat in chats) {
      final currentUnread = chat.unreadCount[currentUserId] ?? 0;
      final previousUnread = _previousUnreadCounts[chat.id] ?? 0;

      // Unread count increased -> a new message arrived
      if (currentUnread > previousUnread) {
        final friendId = chat.participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        // Check if user is currently inside this chat room
        if (ChatRoomScreen.activeChatId != chat.id && friendId.isNotEmpty) {
          triggeredChat = chat;
          triggeredFriendId = friendId;
        }
      }

      _previousUnreadCounts[chat.id] = currentUnread;
    }

    if (triggeredChat != null && triggeredFriendId != null) {
      _showNotification(triggeredChat, triggeredFriendId);
    }
  }

  void _showNotification(ChatRoomModel chat, String friendId) {
    final friendInfo = chat.participantsInfo[friendId] ??
        const ChatParticipantInfo(name: 'Bạn bè', avatar: '');

    _dismissTimer?.cancel();

    setState(() {
      _currentNotification = _ActiveMessageNotification(
        chatId: chat.id,
        friendId: friendId,
        friendName: friendInfo.name,
        friendAvatar: friendInfo.avatar,
        message: chat.lastMessage.isNotEmpty ? chat.lastMessage : 'Đã gửi một tin nhắn',
      );
    });

    HapticHelper.light();
    _animController.forward(from: 0.0);

    // Auto-dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      _dismiss();
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentNotification = null;
        });
      }
    });
  }

  void _handleTapNotification(_ActiveMessageNotification notif) {
    HapticHelper.medium();
    _dismiss();

    // Navigate to ChatRoomScreen using the global navigator key
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          friendId: notif.friendId,
          friendName: notif.friendName,
          friendAvatar: notif.friendAvatar.isNotEmpty ? notif.friendAvatar : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    if (user != null) {
      ref.listen<AsyncValue<List<ChatRoomModel>>>(
        chatRoomsProvider,
        (previous, next) {
          next.whenData((chats) {
            _handleChatsUpdate(chats, user.uid);
          });
        },
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        widget.child,

        // In-App Notification Banner
        if (_currentNotification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: 6,
                ),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: GestureDetector(
                      onTap: () => _handleTapNotification(_currentNotification!),
                      onVerticalDragEnd: (details) {
                        // Swipe up to dismiss
                        if ((details.primaryVelocity ?? 0) < 0) {
                          _dismiss();
                        }
                      },
                      child: FrostedContainer(
                        borderRadius: AppDimens.radiusFull,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        backgroundColor: isDark
                            ? const Color(0xE61E0D26)
                            : Colors.white.withValues(alpha: 0.95),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        child: Row(
                          children: [
                            // Avatar of friend
                            UserAvatar(
                              imageUrl: _currentNotification!.friendAvatar,
                              name: _currentNotification!.friendName,
                              size: 44,
                            ),

                            const SizedBox(width: 12),

                            // Friend name + Message
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _currentNotification!.friendName,
                                          style: AppTypography.bodyBold(
                                            color: isDark
                                                ? AppColors.white
                                                : AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.messageCircle,
                                              size: 11,
                                              color: AppColors.primaryLight,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Tin nhắn mới',
                                              style: TextStyle(
                                                color: AppColors.primaryLight,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _currentNotification!.message,
                                    style: AppTypography.caption(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Close button
                            GestureDetector(
                              onTap: _dismiss,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                ),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
