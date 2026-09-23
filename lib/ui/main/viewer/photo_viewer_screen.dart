import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'report_content_sheet.dart';
import 'selfie_reaction_modal.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../services/content_filter_service.dart';
import '../../../services/media_downloader_service.dart';
import '../../../models/photo_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/frosted_container.dart';
import '../../common/gradient_button.dart';
import '../../common/media_thumbnail.dart';
import '../../common/user_avatar.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  final PhotoModel photo;

  const PhotoViewerScreen({super.key, required this.photo});

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  VideoPlayerController? _videoController;
  final _textReactionController = TextEditingController();

  bool _isPlaying = true;
  bool _isReacting = false;
  String? _selectedEnlargedReaction;

  static const List<String> quickEmojis = [
    '❤️',
    '😍',
    '🔥',
    '😂',
    '🥺',
    '👏',
    'Đẹp quá!',
    'Thích!',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.photo.isVideo && widget.photo.videoUrl != null) {
      _initVideo(widget.photo.videoUrl!);
    }
  }

  Future<void> _initVideo(String url) async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _textReactionController.dispose();
    super.dispose();
  }

  // Handle Selfie Reaction with HeartPearl native camera algorithm
  Future<void> _handleSelfieReact() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    if (!await _canInteract(user.uid)) return;
    if (!mounted) return;

    HapticHelper.medium();
    final capturedPath = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SelfieReactionModal(),
    );

    if (capturedPath == null) return;

    setState(() => _isReacting = true);
    final photoService = ref.read(photoServiceProvider);

    try {
      await ref
          .read(chatServiceProvider)
          .prepareChatAccess(
            chatId: _chatIdFor(user.uid, widget.photo.senderId),
            senderId: user.uid,
            recipientId: widget.photo.senderId,
            currentUserName: user.displayName,
            currentUserAvatar: user.avatarUrl ?? '',
            recipientName: widget.photo.senderUser?.displayName ?? 'Bạn bè',
            recipientAvatar: widget.photo.senderUser?.avatarUrl ?? '',
          );
      final selfieUrl = await photoService.uploadPhoto(
        file: File(capturedPath),
        userId: user.uid,
      );

      await photoService.reactWithSelfie(
        photo: widget.photo,
        currentUser: user,
        selfieUrl: selfieUrl,
      );

      HapticHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi reaction selfie thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      HapticHelper.heavy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi reaction: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReacting = false);
    }
  }

  // Show Text Reaction Modal
  Future<void> _showTextReactionSheet() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null || !await _canInteract(user.uid)) return;
    if (!mounted) return;
    HapticHelper.selection();
    final lang = ref.read(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius2Xl),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceXl,
            left: AppDimens.spaceXl,
            right: AppDimens.spaceXl,
            top: AppDimens.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBorderLight
                      : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: AppDimens.spaceBase),

              Text(
                AppStrings.tr('photo_send_reaction', lang: lang),
                style: AppTypography.h3(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),

              const SizedBox(height: AppDimens.spaceLg),

              // Quick Emoji Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quickEmojis.map((emoji) {
                    return Padding(
                      padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _sendTextReaction(emoji);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                            border: Border.all(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppDimens.spaceLg),

              // Custom text input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textReactionController,
                      style: AppTypography.body(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn phản hồi...',
                        hintStyle: AppTypography.body(
                          color: AppColors.darkTextMuted,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusLg,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.send,
                      color: AppColors.primaryLight,
                    ),
                    onPressed: () {
                      final text = _textReactionController.text.trim();
                      if (text.isNotEmpty) {
                        _textReactionController.clear();
                        Navigator.pop(context);
                        _sendTextReaction(text);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendTextReaction(String text) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    if (!await _canInteract(user.uid)) return;

    if (ContentFilterService.isObjectionable(text)) {
      HapticHelper.heavy();
      if (!mounted) return;
      final lang = ref.read(settingsProvider).language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr('safety_objectionable_warning', lang: lang),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final photoService = ref.read(photoServiceProvider);
    try {
      await ref
          .read(chatServiceProvider)
          .prepareChatAccess(
            chatId: _chatIdFor(user.uid, widget.photo.senderId),
            senderId: user.uid,
            recipientId: widget.photo.senderId,
            currentUserName: user.displayName,
            currentUserAvatar: user.avatarUrl ?? '',
            recipientName: widget.photo.senderUser?.displayName ?? 'Bạn bè',
            recipientAvatar: widget.photo.senderUser?.avatarUrl ?? '',
          );
      await photoService.reactWithText(
        photo: widget.photo,
        currentUser: user,
        message: text,
      );
      HapticHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi phản hồi thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {}
  }

  Future<bool> _canInteract(String currentUid) async {
    final lang = ref.read(settingsProvider).language;
    try {
      final blocked = await ref
          .read(friendServiceProvider)
          .isInteractionBlocked(currentUid, widget.photo.senderId);
      if (!blocked) return true;
    } catch (_) {
      // Fail closed so a transient lookup error cannot bypass a block.
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr('safety_interaction_blocked', lang: lang),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return false;
  }

  String _chatIdFor(String firstUid, String secondUid) {
    final participants = [firstUid, secondUid]..sort();
    return participants.join('_');
  }

  bool _isDownloading = false;

  Future<void> _handleDownloadMedia() async {
    if (_isDownloading) return;
    HapticHelper.light();
    setState(() => _isDownloading = true);
    final lang = ref.read(settingsProvider).language;

    final url = widget.photo.isVideo
        ? (widget.photo.videoUrl ?? widget.photo.imageUrl)
        : widget.photo.imageUrl;

    try {
      final success = await MediaDownloaderService.saveRemoteMedia(
        url: url,
        isVideo: widget.photo.isVideo,
      );

      if (!mounted) return;
      if (success) {
        HapticHelper.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  LucideIcons.checkCircle2,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.photo.isVideo
                      ? AppStrings.tr('media_download_video_success', lang: lang)
                      : AppStrings.tr('media_download_photo_success', lang: lang),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        HapticHelper.heavy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.tr('media_download_permission_denied', lang: lang),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleDeletePhoto() async {
    HapticHelper.heavy();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa khoảnh khắc?',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Khoảnh khắc này sẽ bị xóa khỏi lịch sử của bạn vĩnh viễn.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(photoServiceProvider).deletePhoto(widget.photo.id);
        HapticHelper.success();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa ảnh: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showSafetyMenu(String senderName) {
    HapticHelper.light();
    final lang = ref.read(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius2Xl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.flag, color: AppColors.error),
                title: Text(
                  AppStrings.tr('safety_report_photo', lang: lang),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  AppStrings.tr('safety_report_photo_desc', lang: lang),
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ReportContentSheet.show(context, photo: widget.photo);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.userX, color: AppColors.error),
                title: Text(
                  '${AppStrings.tr('safety_menu_block', lang: lang)} $senderName',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  AppStrings.tr('safety_block_instant_notice', lang: lang),
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleBlockSender(senderName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBlockSender(String senderName) async {
    final lang = ref.read(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${AppStrings.tr('safety_menu_block', lang: lang)} $senderName?',
        ),
        content: Text(
          AppStrings.tr('safety_block_instant_notice', lang: lang),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(AppStrings.tr('safety_cancel', lang: lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(AppStrings.tr('safety_confirm', lang: lang)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(friendServiceProvider).blockUser(widget.photo.senderId);
      HapticHelper.success();
      if (!mounted) return;

      ref.invalidate(inboxPhotosProvider);
      ref.invalidate(userProfileProvider);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'vi'
                ? 'Đã chặn $senderName. Nội dung đã được gỡ bỏ khỏi bảng tin.'
                : 'Blocked $senderName. Content removed from your feed.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('safety_error', lang: lang)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final currentUser = ref.watch(userProfileProvider).value;
    final isMine = widget.photo.senderId == currentUser?.uid;

    final senderName = isMine
        ? (currentUser?.displayName ?? 'Tôi')
        : (widget.photo.senderUser?.displayName ?? 'Bạn bè');
    final senderAvatar = isMine
        ? currentUser?.avatarUrl
        : widget.photo.senderUser?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Full Screen Media
          Positioned.fill(
            child: widget.photo.isVideo
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      // Instant thumbnail background while video loads
                      MediaThumbnail(
                        photo: widget.photo,
                        fit: BoxFit.cover,
                        showPlayBadge: false,
                        memCacheWidth: 1080,
                      ),

                      if (_videoController != null &&
                          _videoController!.value.isInitialized)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPlaying = !_isPlaying;
                              if (_isPlaying) {
                                _videoController!.play();
                              } else {
                                _videoController!.pause();
                              }
                            });
                          },
                          child: Transform.scale(
                            scaleX: widget.photo.isMirrored ? -1.0 : 1.0,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          ),
                        )
                      else
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                    ],
                  )
                : Transform.scale(
                    scaleX: widget.photo.isMirrored ? -1.0 : 1.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.photo.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 1080,
                      fadeInDuration: const Duration(milliseconds: 100),
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          LucideIcons.image,
                          size: 48,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
          ),

          // Pause Indicator for Video
          if (widget.photo.isVideo && !_isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black45,
                ),
                child: const Icon(
                  LucideIcons.play,
                  color: AppColors.white,
                  size: 48,
                ),
              ),
            ),

          // Vignette Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x99000000),
                      Colors.transparent,
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.4, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // Top Bar with Sender info and Close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceSm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticHelper.light();
                      Navigator.of(context).pop();
                    },
                    child: FrostedContainer(
                      borderRadius: AppDimens.radiusFull,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        LucideIcons.x,
                        color: AppColors.white,
                        size: 22,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppDimens.spaceMd),

                  // Sender info
                  UserAvatar(
                    imageUrl: senderAvatar,
                    name: senderName,
                    size: 38,
                    hasBorder: true,
                    borderColor: AppColors.white,
                  ),

                  const SizedBox(width: AppDimens.spaceSm),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: AppTypography.bodyBold(color: AppColors.white),
                      ),
                      Text(
                        DateHelper.timeAgo(widget.photo.createdAt, lang: lang),
                        style: AppTypography.caption(color: Colors.white70),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Download / Save Media Button
                  GestureDetector(
                    onTap: _isDownloading ? null : _handleDownloadMedia,
                    child: FrostedContainer(
                      borderRadius: AppDimens.radiusFull,
                      padding: const EdgeInsets.all(10),
                      child: _isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              LucideIcons.arrowDownToLine,
                              color: AppColors.white,
                              size: 20,
                            ),
                    ),
                  ),

                  // Safety & Moderation Menu (Flag / Block) for received photos (Apple Guideline 1.2)
                  if (!isMine) ...[
                    const SizedBox(width: AppDimens.spaceSm),
                    GestureDetector(
                      onTap: () => _showSafetyMenu(senderName),
                      child: FrostedContainer(
                        borderRadius: AppDimens.radiusFull,
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          LucideIcons.moreVertical,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Caption
          if (widget.photo.caption != null && widget.photo.caption!.isNotEmpty)
            Positioned(
              bottom: 180,
              left: AppDimens.spaceLg,
              right: AppDimens.spaceLg,
              child: FrostedContainer(
                borderRadius: AppDimens.radiusLg,
                padding: const EdgeInsets.all(AppDimens.spaceBase),
                child: Text(
                  widget.photo.caption!,
                  style: AppTypography.body(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Selfie & Text Reactions Row
          if (widget.photo.reactions.isNotEmpty ||
              widget.photo.textReactions.isNotEmpty)
            Positioned(
              bottom: 120,
              left: AppDimens.spaceLg,
              right: AppDimens.spaceLg,
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Selfie Reactions
                    ...widget.photo.reactions.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selection();
                            setState(
                              () => _selectedEnlargedReaction = entry.value,
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: entry.value,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Text Reactions
                    ...widget.photo.textReactions.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusFull,
                          ),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Center(
                          child: Text(
                            entry.value,
                            style: AppTypography.medium.copyWith(
                              color: AppColors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // Bottom Reaction Actions
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceBase,
                ),
                child: isMine
                    ? Row(
                        children: [
                          // 1. Download Media Button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isDownloading ? null : _handleDownloadMedia,
                              child: FrostedContainer(
                                height: 50,
                                borderRadius: AppDimens.radiusFull,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _isDownloading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            LucideIcons.arrowDownToLine,
                                            color: AppColors.white,
                                            size: 18,
                                          ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppStrings.tr('media_download_btn', lang: lang),
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceMd),
                          // 2. Delete Photo Button
                          GestureDetector(
                            onTap: _handleDeletePhoto,
                            child: FrostedContainer(
                              height: 50,
                              borderRadius: AppDimens.radiusFull,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.trash2,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Xóa',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Selfie React Button
                          Expanded(
                            child: GradientButton(
                              text: AppStrings.tr(
                                'photo_selfie_react',
                                lang: lang,
                              ),
                              isLoading: _isReacting,
                              icon: const Icon(
                                LucideIcons.camera,
                                color: AppColors.white,
                                size: 18,
                              ),
                              onPressed: _handleSelfieReact,
                            ),
                          ),

                          const SizedBox(width: AppDimens.spaceMd),

                          // Text React Button
                          Expanded(
                            child: GestureDetector(
                              onTap: _showTextReactionSheet,
                              child: FrostedContainer(
                                height: 54,
                                borderRadius: AppDimens.radiusFull,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.messageSquare,
                                      color: AppColors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppDimens.spaceSm),
                                    Text(
                                      AppStrings.tr(
                                        'photo_text_react',
                                        lang: lang,
                                      ),
                                      style: AppTypography.button(
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Enlarged Selfie Reaction Dialog
          if (_selectedEnlargedReaction != null)
            GestureDetector(
              onTap: () => setState(() => _selectedEnlargedReaction = null),
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: CachedNetworkImage(
                        imageUrl: _selectedEnlargedReaction!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
