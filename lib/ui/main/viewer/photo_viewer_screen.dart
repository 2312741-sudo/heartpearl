import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/photo_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/frosted_container.dart';
import '../../common/gradient_button.dart';
import '../../common/user_avatar.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  final PhotoModel photo;

  const PhotoViewerScreen({super.key, required this.photo});

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  VideoPlayerController? _videoController;
  final _picker = ImagePicker();
  final _textReactionController = TextEditingController();

  bool _isPlaying = true;
  bool _isReacting = false;
  String? _selectedEnlargedReaction;

  static const List<String> quickEmojis = [
    '❤️', '😍', '🔥', '😂', '🥺', '👏', 'Đẹp quá!', 'Thích!'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.photo.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.photo.videoUrl ?? widget.photo.imageUrl;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _textReactionController.dispose();
    super.dispose();
  }

  // Handle Selfie Reaction
  Future<void> _handleSelfieReact() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    HapticHelper.medium();
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() => _isReacting = true);
    final photoService = ref.read(photoServiceProvider);

    try {
      final selfieUrl = await photoService.uploadPhoto(
        file: File(picked.path),
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
            content: Text('✅ Đã gửi reaction selfie thành công!'),
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
  void _showTextReactionSheet() {
    HapticHelper.selection();
    final lang = ref.read(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radius2Xl)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceXl,
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
                  color: isDark ? AppColors.darkBorderLight : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: AppDimens.spaceBase),

              Text(
                AppStrings.tr('photo_send_reaction', lang: lang),
                style: AppTypography.h3(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                            border: Border.all(
                              color: AppColors.primaryLight.withValues(alpha: 0.3),
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
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn phản hồi...',
                        hintStyle: AppTypography.body(color: AppColors.darkTextMuted),
                        filled: true,
                        fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  IconButton(
                    icon: const Icon(LucideIcons.send, color: AppColors.primaryLight),
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

    final photoService = ref.read(photoServiceProvider);
    try {
      await photoService.reactWithText(
        photo: widget.photo,
        currentUser: user,
        message: text,
      );
      HapticHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã gửi phản hồi thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final senderName = widget.photo.senderUser?.displayName ?? 'Bạn bè';
    final senderAvatar = widget.photo.senderUser?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Full Screen Media
          Positioned.fill(
            child: widget.photo.isVideo
                ? (_videoController != null && _videoController!.value.isInitialized
                    ? GestureDetector(
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
                    : const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ))
                : Transform.scale(
                    scaleX: widget.photo.isMirrored ? -1.0 : 1.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.photo.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(LucideIcons.image, size: 48, color: Colors.white24),
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
                child: const Icon(LucideIcons.play, color: AppColors.white, size: 48),
              ),
            ),

          // Vignette Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x99000000), Colors.transparent, Color(0xCC000000)],
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
          if (widget.photo.reactions.isNotEmpty || widget.photo.textReactions.isNotEmpty)
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
                            setState(() => _selectedEnlargedReaction = entry.value);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
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
                child: Row(
                  children: [
                    // Selfie React Button
                    Expanded(
                      child: GradientButton(
                        text: AppStrings.tr('photo_selfie_react', lang: lang),
                        isLoading: _isReacting,
                        icon: const Icon(LucideIcons.camera, color: AppColors.white, size: 18),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.messageSquare, color: AppColors.white, size: 18),
                              const SizedBox(width: AppDimens.spaceSm),
                              Text(
                                AppStrings.tr('photo_text_react', lang: lang),
                                style: AppTypography.button(color: AppColors.white),
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
