import 'package:flutter/material.dart';
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
import '../../common/media_thumbnail.dart';
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
      body: sentPhotosAsync.when(
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.calendarHeart,
                    size: 64,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  const SizedBox(height: AppDimens.spaceBase),
                  Text(
                    AppStrings.tr('history_empty', lang: lang),
                    style: AppTypography.h3(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
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

                      return GestureDetector(
                        onTap: () {
                          HapticHelper.light();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PhotoViewerScreen(photo: photo),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppDimens.radiusLg - 1),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MediaThumbnail(
                                  photo: photo,
                                  fit: BoxFit.cover,
                                  showPlayBadge: true,
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
                                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
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
                                            style: const TextStyle(
                                              fontSize: 10,
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
                      );
                    },
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                ],
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
