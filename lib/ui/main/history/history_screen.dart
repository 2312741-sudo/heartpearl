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
import '../../../models/photo_model.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/media_downloader_service.dart';
import '../../common/media_thumbnail.dart';
import '../../common/skeleton_loader.dart';
import '../viewer/photo_viewer_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sentPhotosAsync = ref.watch(sentPhotosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.tr('history_title', lang: lang),
          style: AppTypography.h2(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          HapticHelper.light();
          ref.invalidate(sentPhotosProvider);
          try {
            await ref.read(sentPhotosProvider.future);
          } catch (_) {}
        },
        child: sentPhotosAsync.when(
          data: (photos) {
            if (photos.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
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
                              LucideIcons.calendarHeart,
                              size: 48,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceLg),
                          Text(
                            AppStrings.tr('history_empty', lang: lang),
                            style: AppTypography.h3(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
                  ),
                ),
              );
            }

            // Group photos by date
            final Map<String, List<PhotoModel>> grouped = {};
            for (final photo in photos) {
              final dateKey = DateHelper.formatDateGroup(photo.createdAt);
              grouped.putIfAbsent(dateKey, () => []).add(photo);
            }

            final dates = grouped.keys.toList();

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimens.spaceBase),
              itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final datePhotos = grouped[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
                    child: Text(
                      date,
                      style: AppTypography.bold.copyWith(
                        color: AppColors.primaryLight,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppDimens.spaceSm,
                      mainAxisSpacing: AppDimens.spaceSm,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: datePhotos.length,
                    itemBuilder: (context, photoIndex) {
                      final photo = datePhotos[photoIndex];
                      final reactionCount = photo.reactions.length;
                      final isMilestone = reactionCount >= 3 || (photoIndex == 0 && index == 0);

                      return GestureDetector(
                        onTap: () {
                          HapticHelper.light();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PhotoViewerScreen(photo: photo),
                            ),
                          );
                        },
                        onLongPress: () => _showPhotoActions(context, ref, photo),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                            gradient: isMilestone ? AppColors.pearlGlowGradient : null,
                            border: isMilestone
                                ? null
                                : Border.all(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                  ),
                            boxShadow: isMilestone
                                ? AppDimens.glowShadow(
                                    AppColors.primary,
                                    opacity: 0.35,
                                  )
                                : null,
                          ),
                          padding: isMilestone
                              ? const EdgeInsets.all(2.0)
                              : EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isMilestone
                                  ? AppDimens.radiusLg - 2
                                  : AppDimens.radiusLg - 1,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MediaThumbnail(
                                  photo: photo,
                                  fit: BoxFit.cover,
                                  showPlayBadge: true,
                                ),
                                if (isMilestone)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(
                                          AppDimens.radiusFull,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            LucideIcons.sparkles,
                                            size: 9,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'Kỷ niệm',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (reactionCount > 0)
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xB3000000),
                                        borderRadius: BorderRadius.circular(
                                          AppDimens.radiusFull,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            LucideIcons.heart,
                                            size: 10,
                                            color: AppColors.primaryLight,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            reactionCount.toString(),
                                            style: AppTypography.micro(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(
                        duration: 300.ms,
                        delay: (photoIndex.clamp(0, 8) * 40).ms,
                      ).scale(begin: const Offset(0.95, 0.95));
                    },
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                ],
              ).animate().fadeIn(
                duration: 300.ms,
                delay: (index.clamp(0, 8) * 50).ms,
              ).slideY(begin: 0.08, end: 0);
            },
          );
        },
        loading: () => const SkeletonGridView(childAspectRatio: 1.0),
        error: (err, stack) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: Text('Lỗi: $err')),
            ),
          ),
        ),
      ),
    ),
  );
  }

  void _showPhotoActions(BuildContext context, WidgetRef ref, PhotoModel photo) {
    HapticHelper.medium();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.read(settingsProvider).language;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radius2Xl)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(LucideIcons.arrowDownToLine, color: AppColors.primary),
                title: Text(
                  photo.isVideo ? 'Tải video về máy' : 'Tải ảnh về máy',
                  style: AppTypography.bodyBold(),
                ),
                subtitle: const Text('Lưu vào Thư viện ảnh của điện thoại'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  HapticHelper.light();
                  final url = photo.isVideo
                      ? (photo.videoUrl ?? photo.imageUrl)
                      : photo.imageUrl;
                  final success = await MediaDownloaderService.saveRemoteMedia(
                    url: url,
                    isVideo: photo.isVideo,
                  );
                  if (context.mounted) {
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
                                photo.isVideo
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
                  }
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.maximize2),
                title: const Text('Xem toàn màn hình'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PhotoViewerScreen(photo: photo),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: AppColors.error),
                title: Text(
                  'Xóa khoảnh khắc này',
                  style: AppTypography.bodyBold(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xóa khoảnh khắc?'),
                      content: const Text(
                        'Khoảnh khắc này sẽ bị xóa khỏi lịch sử của bạn vĩnh viễn.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            'Xóa',
                            style: AppTypography.bodyBold(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(photoServiceProvider).deletePhoto(photo.id);
                    HapticHelper.success();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
