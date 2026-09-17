import 'dart:io';
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
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/settings_provider.dart';
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
        const SnackBar(content: Text('Vui lòng đợi thông tin tài khoản được đồng bộ.')),
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

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final photoService = ref.read(photoServiceProvider);

    try {
      String mediaUrl;
      String? videoUrl;

      if (widget.isVideo) {
        videoUrl = await photoService.uploadVideo(
          file: File(widget.filePath),
          userId: user.uid,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        mediaUrl = videoUrl; // Using video url or first frame thumbnail
      } else {
        mediaUrl = await photoService.uploadPhoto(
          file: File(widget.filePath),
          userId: user.uid,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      await photoService.sendPhoto(
        senderId: user.uid,
        recipientIds: _selectedFriendIds.toList(),
        imageUrl: mediaUrl,
        videoUrl: videoUrl,
        caption: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
        mediaType: widget.isVideo ? 'video' : 'photo',
        isMirrored: widget.isMirrored,
        filter: widget.filter.type != BeautyFilterType.normal,
      );

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

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Media Preview
          Positioned.fill(
            child: widget.isVideo
                ? (_videoController != null && _videoController!.value.isInitialized
                    ? Transform.scale(
                        scaleX: widget.isMirrored ? -1.0 : 1.0,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ))
                : Transform.scale(
                    scaleX: widget.isMirrored ? -1.0 : 1.0,
                    child: Image.file(
                      File(widget.filePath),
                      fit: BoxFit.cover,
                    ),
                  ),
          ),

          // Beauty Filter Overlay
          if (widget.filter.overlayColor != Colors.transparent)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: widget.filter.overlayColor),
              ),
            ),

          // Dark Gradient Vignette
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

          // Top Cancel Button
          SafeArea(
            child: Padding(
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
                      child: const Icon(
                        LucideIcons.x,
                        color: AppColors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  if (widget.isVideo)
                    FrostedContainer(
                      borderRadius: AppDimens.radiusFull,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.play, color: AppColors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.tr('home_video_badge', lang: lang),
                            style: AppTypography.bold.copyWith(
                              fontSize: 12,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Controls & Captions
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
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
                      child: TextField(
                        controller: _captionController,
                        style: AppTypography.body(color: AppColors.white),
                        maxLength: 100,
                        decoration: InputDecoration(
                          hintText: AppStrings.tr('home_caption_placeholder', lang: lang),
                          hintStyle: AppTypography.body(color: AppColors.white.withValues(alpha: 0.6)),
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
                                  ? AppStrings.tr('home_select_recipient', lang: lang)
                                  : '${_selectedFriendIds.length} ${AppStrings.tr('home_selected', lang: lang)}',
                              style: AppTypography.medium.copyWith(
                                color: AppColors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: AppDimens.spaceSm),
                            Icon(
                              _showFriendPicker
                                  ? LucideIcons.chevronDown
                                  : LucideIcons.chevronUp,
                              color: AppColors.white.withValues(alpha: 0.7),
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
                                    style: AppTypography.caption(color: AppColors.darkTextMuted),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      HapticHelper.selection();
                                      setState(() {
                                        if (_selectedFriendIds.length == friends.length) {
                                          _selectedFriendIds.clear();
                                        } else {
                                          _selectedFriendIds.addAll(friends.map((f) => f.uid));
                                        }
                                      });
                                    },
                                    child: Text(
                                      _selectedFriendIds.length == friends.length
                                          ? AppStrings.tr('home_deselect_all', lang: lang)
                                          : AppStrings.tr('home_select_all', lang: lang),
                                      style: AppTypography.bodyBold(color: AppColors.primaryLight),
                                    ),
                                  ),
                                ],
                              ),
                            if (friends.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(AppDimens.spaceMd),
                                child: Text(
                                  'Chưa có bạn bè. Hãy thêm bạn bè ở mục Bạn bè!',
                                  style: AppTypography.caption(color: AppColors.white.withValues(alpha: 0.7)),
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
                                    final isSelected = _selectedFriendIds.contains(friend.uid);

                                    return ListTile(
                                      dense: true,
                                      leading: UserAvatar(
                                        imageUrl: friend.avatarUrl,
                                        name: friend.displayName,
                                        size: 36,
                                      ),
                                      title: Text(
                                        friend.displayName,
                                        style: AppTypography.bodyBold(color: AppColors.white),
                                      ),
                                      trailing: isSelected
                                          ? const Icon(LucideIcons.checkCircle2, color: AppColors.primaryLight)
                                          : const Icon(LucideIcons.circle, color: Colors.white38),
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
                      icon: const Icon(LucideIcons.send, color: AppColors.white, size: 20),
                      onPressed: () => _handleSend(friends),
                    ),

                    const SizedBox(height: AppDimens.spaceBase),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
