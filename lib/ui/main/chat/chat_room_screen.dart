import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/chat_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/user_avatar.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendAvatar;

  const ChatRoomScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatar,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _textController = TextEditingController();

  String get _chatId {
    final user = ref.read(userProfileProvider).value;
    final uid = user?.uid ?? '';
    final participants = [uid, widget.friendId]..sort();
    return participants.join('_');
  }

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    final user = ref.read(userProfileProvider).value;
    if (user != null) {
      ref.read(chatServiceProvider).markChatAsRead(_chatId, user.uid);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    _textController.clear();
    HapticHelper.light();

    try {
      await ref.read(chatServiceProvider).sendMessage(
            chatId: _chatId,
            senderId: user.uid,
            text: text,
            recipientId: widget.friendId,
            currentUserName: user.displayName,
            currentUserAvatar: user.avatarUrl ?? '',
            recipientName: widget.friendName,
            recipientAvatar: widget.friendAvatar ?? '',
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProfileProvider).value;
    final messagesAsync = ref.watch(chatMessagesProvider(_chatId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevronLeft,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            UserAvatar(
              imageUrl: widget.friendAvatar,
              name: widget.friendName,
              size: 36,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Text(
              widget.friendName,
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        AppStrings.tr('chat_empty', lang: lang),
                        style: AppTypography.body(color: AppColors.darkTextMuted),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceBase,
                      vertical: AppDimens.spaceSm,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == user?.uid;

                      return _MessageBubble(
                        message: message,
                        isMe: isMe,
                        friendAvatar: widget.friendAvatar,
                        friendName: widget.friendName,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, stack) => Center(child: Text('Lỗi: $err')),
              ),
            ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceBase,
                vertical: AppDimens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: AppTypography.body(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: AppStrings.tr('chat_placeholder', lang: lang),
                        hintStyle: AppTypography.body(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: IconButton(
                      icon: const Icon(LucideIcons.send, color: AppColors.white, size: 18),
                      onPressed: _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final String? friendAvatar;
  final String friendName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.friendAvatar,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(
              imageUrl: friendAvatar,
              name: friendName,
              size: 28,
            ),
            const SizedBox(width: AppDimens.spaceSm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe ? AppColors.primaryGradient : null,
                color: isMe
                    ? null
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppDimens.radiusLg),
                  topRight: const Radius.circular(AppDimens.radiusLg),
                  bottomLeft: Radius.circular(isMe ? AppDimens.radiusLg : 4),
                  bottomRight: Radius.circular(isMe ? 4 : AppDimens.radiusLg),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.photoUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      child: CachedNetworkImage(
                        imageUrl: message.photoUrl!,
                        width: 180,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: AppTypography.body(
                        color: isMe
                            ? AppColors.white
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
