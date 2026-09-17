import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
import '../viewer/photo_viewer_screen.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProfileProvider).value;
    final inboxAsync = ref.watch(inboxPhotosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.tr('inbox_title', lang: lang),
          style: AppTypography.h2(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: inboxAsync.when(
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.image,
                    size: 64,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  const SizedBox(height: AppDimens.spaceBase),
                  Text(
                    AppStrings.tr('inbox_empty_title', lang: lang),
                    style: AppTypography.h3(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.space3Xl),
                    child: Text(
                      AppStrings.tr('inbox_empty_sub', lang: lang),
                      style: AppTypography.body(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(AppDimens.spaceBase),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppDimens.spaceBase,
              mainAxisSpacing: AppDimens.spaceBase,
              childAspectRatio: 0.8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final isNew = user != null && photo.seen[user.uid] != true;

              return _PhotoCard(
                photo: photo,
                isNew: isNew,
                onTap: () {
                  HapticHelper.light();
                  if (user != null) {
                    ref.read(photoServiceProvider).markPhotoAsSeen(photo.id, user.uid);
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PhotoViewerScreen(photo: photo),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Text('Lỗi: $err'),
        ),
      ),
    );
  }
}

class _PhotoCard extends ConsumerWidget {
  final PhotoModel photo;
  final bool isNew;
  final VoidCallback onTap;

  const _PhotoCard({
    required this.photo,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final senderName = photo.senderUser?.displayName ?? 'Bạn bè';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: isNew
                ? AppColors.primaryLight
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isNew ? 2 : 1,
          ),
          boxShadow: isNew
              ? AppDimens.glowShadow(AppColors.primary, opacity: 0.3)
              : AppDimens.softCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo or Video Thumbnail
              Transform.scale(
                scaleX: photo.isMirrored ? -1.0 : 1.0,
                child: CachedNetworkImage(
                  imageUrl: photo.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? AppColors.darkSurfaceLight : AppColors.lightSurfaceLight,
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(LucideIcons.image, color: Colors.white30),
                  ),
                ),
              ),

              // Filter color overlay if enabled
              if (photo.filter)
                Container(color: const Color(0x1FE8D8FF)),

              // Gradient vignette at bottom
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xCC000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.4, 1.0],
                  ),
                ),
              ),

              // "NEW" Badge
              if (isNew)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                    child: Text(
                      AppStrings.tr('inbox_new', lang: lang),
                      style: AppTypography.bold.copyWith(
                        color: AppColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

              // Video indicator icon
              if (photo.isVideo)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.play,
                      color: AppColors.white,
                      size: 12,
                    ),
                  ),
                ),

              // Bottom card info: Sender + Time
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyBold(color: AppColors.white),
                    ),
                    Text(
                      DateHelper.timeAgo(photo.createdAt, lang: lang),
                      style: AppTypography.caption(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
