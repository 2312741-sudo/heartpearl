import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/camera_filters.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/media_helper.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/content_filter_service.dart';
import '../../common/frosted_container.dart';
import '../../common/gradient_button.dart';
import '../../common/user_avatar.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String filePath;
  final bool isVideo;
  final bool isMirrored;
  final BeautyFilter filter;

  const PreviewScreen({
    super.key,
    required this.filePath,
    required this.isVideo,
    required this.isMirrored,
    required this.filter,
  });

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final _captionController = TextEditingController();
  final Set<String> _selectedFriendIds = {};

  VideoPlayerController? _videoController;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _showFriendPicker = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.filePath));
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _handleSend(List<UserModel> friends) async {
    final user = ref.read(userProfileProvider).value;
    final lang = ref.read(settingsProvider).language;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đợi thông tin tài khoản được đồng bộ.'),
        ),
      );
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      HapticHelper.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('home_err_no_friend', lang: lang)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final caption = _captionController.text.trim();
    if (ContentFilterService.isObjectionable(caption)) {
      HapticHelper.heavy();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('safety_objectionable_warning', lang: lang)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final photoService = ref.read(photoServiceProvider);

    try {
      final allowedRecipientIds = await ref
          .read(friendServiceProvider)
          .filterAllowedRecipients(
            senderUid: user.uid,
            recipientUids: _selectedFriendIds,
          );
      if (allowedRecipientIds.isEmpty) {
        throw StateError(
          AppStrings.tr('safety_interaction_blocked', lang: lang),
        );
      }

      String mediaUrl;
      String? videoUrl;

      if (widget.isVideo) {
        // 1. Generate video review thumbnail frame using native AVAssetImageGenerator
        final thumbFile = await MediaHelper.generateVideoThumbnail(
          widget.filePath,
        );
        String? thumbUrl;
        if (thumbFile != null) {
          try {
            thumbUrl = await photoService.uploadPhoto(
              file: thumbFile,
              userId: user.uid,
            );
            // Clean up temporary thumbnail
            try {
              await thumbFile.delete();
            } catch (_) {}
          } catch (e) {
            debugPrint('Error uploading video thumbnail: $e');
          }
        }

        // 2. Hardware Video Compression (reducing from 35MB to ~2MB with fast-start streaming)
        File uploadVideoFile = File(widget.filePath);
        try {
          final compressedPath = await MediaHelper.compressVideo(
            widget.filePath,
          );
          if (compressedPath != null && compressedPath != widget.filePath) {
            uploadVideoFile = File(compressedPath);
          }
        } catch (e) {
          debugPrint('Video compression error: $e');
        }

        // 3. Upload video file with progress tracking
        videoUrl = await photoService.uploadVideo(
          file: uploadVideoFile,
          userId: user.uid,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );

        // Clean up temporary compressed file
        if (uploadVideoFile.path != widget.filePath) {
          try {
            await uploadVideoFile.delete();
          } catch (_) {}
        }

        // If thumbnail generation succeeded, use it for preview; otherwise fallback to videoUrl
        mediaUrl = thumbUrl ?? videoUrl;
      } else {
        mediaUrl = await photoService.uploadPhoto(
          file: File(widget.filePath),
          userId: user.uid,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      final finalRecipientIds = await ref
          .read(friendServiceProvider)
          .filterAllowedRecipients(
            senderUid: user.uid,
            recipientUids: allowedRecipientIds,
          );
      if (finalRecipientIds.isEmpty) {
        throw StateError(
          AppStrings.tr('safety_interaction_blocked', lang: lang),
        );
      }

      await photoService.sendPhoto(
        senderId: user.uid,
        recipientIds: finalRecipientIds,
        imageUrl: mediaUrl,
        videoUrl: videoUrl,
        caption: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
        mediaType: widget.isVideo ? 'video' : 'photo',
        isMirrored: widget.isMirrored,
        filter: widget.filter.type != BeautyFilterType.normal,
      );

      // Note: User's own sent photos are not saved to their own home widget (widgets only show photos from friends)

      HapticHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isVideo
                  ? AppStrings.tr('home_success_video', lang: lang)
                  : AppStrings.tr('home_success_photo', lang: lang),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      HapticHelper.heavy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final friendsAsync = ref.watch(friendsListProvider);
    final friends = friendsAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Cancel Button & Video Badge
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticHelper.light();
                      Navigator.of(context).pop();
                    },
                    child: FrostedContainer(
                      borderRadius: AppDimens.radiusFull,
                      padding: const EdgeInsets.all(10),
                      backgroundColor: isDark
                          ? const Color(0x331E0D26)
                          : AppColors.lightSurface.withValues(alpha: 0.9),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppColors.lightBorder.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      child: Icon(
                        LucideIcons.x,
                        color: isDark ? AppColors.white : AppColors.lightTextPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                  if (widget.isVideo)
                    FrostedContainer(
                      borderRadius: AppDimens.radiusFull,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      backgroundColor: isDark
                          ? const Color(0x331E0D26)
                          : AppColors.lightSurface.withValues(alpha: 0.9),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppColors.lightBorder.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.play,
                            color: isDark ? AppColors.white : AppColors.lightTextPrimary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.tr('home_video_badge', lang: lang),
                            style: AppTypography.bold.copyWith(
                              fontSize: 12,
                              color: isDark ? AppColors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 2. Center 3:4 Media Card (Matches Camera Viewfinder 1:1)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : AppColors.lightBorder,
                            width: 1.5,
                          ),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 2.1 Media (Photo / Video)
                            widget.isVideo
                                ? (_videoController != null &&
                                          _videoController!.value.isInitialized
                                      ? FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: _videoController!
                                                .value
                                                .size
                                                .width,
                                            height: _videoController!
                                                .value
                                                .size
                                                .height,
                                            child:
                                                widget.filter.colorFilter !=
                                                    null
                                                ? ColorFiltered(
                                                    colorFilter: widget
                                                        .filter
                                                        .colorFilter!,
                                                    child: VideoPlayer(
                                                      _videoController!,
                                                    ),
                                                  )
                                                : VideoPlayer(
                                                    _videoController!,
                                                  ),
                                          ),
                                        )
                                      : const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                          ),
                                        ))
                                : (widget.filter.colorFilter != null
                                      ? ColorFiltered(
                                          colorFilter:
                                              widget.filter.colorFilter!,
                                          child: Image.file(
                                            File(widget.filePath),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.file(
                                          File(widget.filePath),
                                          fit: BoxFit.cover,
                                        )),

                            // 2.2 TikTok Skin-Smoothing & Blemish Softening Diffusion Layer
                            if (widget.filter.blurSigma > 0)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: widget.filter.blurOpacity,
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: widget.filter.blurSigma,
                                        sigmaY: widget.filter.blurSigma,
                                      ),
                                      child: Container(
                                        color:
                                            widget.filter.overlayColor !=
                                                Colors.transparent
                                            ? widget.filter.overlayColor
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // 2.3 Beauty Filter Color Overlay
                            if (widget.filter.blurSigma == 0 &&
                                widget.filter.overlayColor !=
                                    Colors.transparent)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    color: widget.filter.overlayColor,
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

            const SizedBox(height: 12),

            // 3. Bottom Controls & Captions
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Caption Field
                  FrostedContainer(
                    borderRadius: AppDimens.radiusXl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceBase,
                      vertical: 4,
                    ),
                    backgroundColor: isDark
                        ? const Color(0x331E0D26)
                        : AppColors.lightSurface.withValues(alpha: 0.9),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.lightBorder.withValues(alpha: 0.6),
                      width: 1,
                    ),
                    child: TextField(
                      controller: _captionController,
                      style: AppTypography.body(
                        color: isDark ? AppColors.white : AppColors.lightTextPrimary,
                      ),
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: AppStrings.tr(
                          'home_caption_placeholder',
                          lang: lang,
                        ),
                        hintStyle: AppTypography.body(
                          color: isDark
                              ? AppColors.white.withValues(alpha: 0.6)
                              : AppColors.lightTextMuted,
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  // Friend Selector Toggle
                  GestureDetector(
                    onTap: () {
                      HapticHelper.selection();
                      setState(() => _showFriendPicker = !_showFriendPicker);
                    },
                    child: FrostedContainer(
                      borderRadius: AppDimens.radiusFull,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceLg,
                        vertical: 10,
                      ),
                      backgroundColor: isDark
                          ? const Color(0x331E0D26)
                          : AppColors.lightSurface.withValues(alpha: 0.9),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppColors.lightBorder.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.users,
                            color: AppColors.primaryLight,
                            size: 18,
                          ),
                          const SizedBox(width: AppDimens.spaceSm),
                          Text(
                            _selectedFriendIds.isEmpty
                                ? AppStrings.tr(
                                    'home_select_recipient',
                                    lang: lang,
                                  )
                                : '${_selectedFriendIds.length} ${AppStrings.tr('home_selected', lang: lang)}',
                            style: AppTypography.medium.copyWith(
                              color: isDark ? AppColors.white : AppColors.lightTextPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceSm),
                          Icon(
                            _showFriendPicker
                                ? LucideIcons.chevronDown
                                : LucideIcons.chevronUp,
                            color: isDark
                                ? AppColors.white.withValues(alpha: 0.7)
                                : AppColors.lightTextPrimary.withValues(alpha: 0.7),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Friend list picker
                  if (_showFriendPicker) ...[
                    const SizedBox(height: AppDimens.spaceSm),
                    FrostedContainer(
                      borderRadius: AppDimens.radiusLg,
                      padding: const EdgeInsets.all(AppDimens.spaceSm),
                      backgroundColor: isDark
                          ? const Color(0x331E0D26)
                          : AppColors.lightSurface.withValues(alpha: 0.95),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppColors.lightBorder.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Select All / Deselect All
                          if (friends.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${friends.length} bạn bè',
                                  style: AppTypography.caption(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    HapticHelper.selection();
                                    setState(() {
                                      if (_selectedFriendIds.length ==
                                          friends.length) {
                                        _selectedFriendIds.clear();
                                      } else {
                                        _selectedFriendIds.addAll(
                                          friends.map((f) => f.uid),
                                        );
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedFriendIds.length == friends.length
                                        ? AppStrings.tr(
                                            'home_deselect_all',
                                            lang: lang,
                                          )
                                        : AppStrings.tr(
                                            'home_select_all',
                                            lang: lang,
                                          ),
                                    style: AppTypography.bodyBold(
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (friends.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppDimens.spaceMd),
                              child: Text(
                                'Chưa có bạn bè. Hãy thêm bạn bè ở mục Bạn bè!',
                                style: AppTypography.caption(
                                  color: isDark
                                      ? AppColors.white.withValues(alpha: 0.7)
                                      : AppColors.lightTextMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: friends.length,
                                itemBuilder: (context, index) {
                                  final friend = friends[index];
                                  final isSelected = _selectedFriendIds
                                      .contains(friend.uid);

                                  return ListTile(
                                    dense: true,
                                    leading: UserAvatar(
                                      imageUrl: friend.avatarUrl,
                                      name: friend.displayName,
                                      size: 36,
                                    ),
                                    title: Text(
                                      friend.displayName,
                                      style: AppTypography.bodyBold(
                                        color: isDark
                                            ? AppColors.white
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            LucideIcons.checkCircle2,
                                            color: AppColors.primaryLight,
                                          )
                                        : Icon(
                                            LucideIcons.circle,
                                            color: isDark
                                                ? Colors.white38
                                                : AppColors.lightBorderLight,
                                          ),
                                    onTap: () {
                                      HapticHelper.selection();
                                      setState(() {
                                        if (isSelected) {
                                          _selectedFriendIds.remove(friend.uid);
                                        } else {
                                          _selectedFriendIds.add(friend.uid);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppDimens.spaceLg),

                  // Send Button
                  GradientButton(
                    text: _isUploading
                        ? '${(_uploadProgress * 100).toInt()}% ${AppStrings.tr('home_sending', lang: lang)}'
                        : AppStrings.tr('home_send', lang: lang),
                    isLoading: _isUploading,
                    icon: const Icon(
                      LucideIcons.send,
                      color: AppColors.white,
                      size: 20,
                    ),
                    onPressed: () => _handleSend(friends),
                  ),

                  const SizedBox(height: AppDimens.spaceBase),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
