import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/media_helper.dart';
import '../../models/photo_model.dart';

/// High-performance media thumbnail widget that handles:
/// 1. Photos via CachedNetworkImage
/// 2. Videos with image thumbnails
/// 3. Videos without image thumbnails (auto-extracting keyframe via native generator)
/// 4. Optional video play indicator badge
class MediaThumbnail extends StatelessWidget {
  final PhotoModel photo;
  final BoxFit fit;
  final bool showPlayBadge;
  final int? memCacheWidth;

  const MediaThumbnail({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.showPlayBadge = true,
    this.memCacheWidth = 400,
  });

  bool get _isMp4Url {
    final lower = photo.imageUrl.toLowerCase();
    return lower.endsWith('.mp4') || lower.contains('.mp4?');
  }

  @override
  Widget build(BuildContext context) {
    final isMirrored = photo.isMirrored;

    Widget imageWidget;

    if (photo.isVideo && _isMp4Url) {
      // Legacy video upload where imageUrl is an .mp4 file: auto-extract frame
      final videoUrl = photo.videoUrl ?? photo.imageUrl;
      imageWidget = FutureBuilder<File?>(
        future: MediaHelper.generateVideoThumbnail(videoUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
            return Image.file(
              snapshot.data!,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(),
            );
          }
          return _buildFallbackPlaceholder();
        },
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: photo.imageUrl,
        fit: fit,
        memCacheWidth: memCacheWidth,
        fadeInDuration: const Duration(milliseconds: 80),
        placeholder: (context, url) => Container(
          color: const Color(0xFF1E0D26),
        ),
        errorWidget: (context, url, error) {
          if (photo.isVideo) {
            // If image load failed on video, try extracting thumbnail from videoUrl
            final vUrl = photo.videoUrl;
            if (vUrl != null && vUrl.isNotEmpty) {
              return FutureBuilder<File?>(
                future: MediaHelper.generateVideoThumbnail(vUrl),
                builder: (context, snapshot) {
                  if (snapshot.data != null) {
                    return Image.file(snapshot.data!, fit: fit);
                  }
                  return _buildFallbackPlaceholder();
                },
              );
            }
          }
          return _buildFallbackPlaceholder();
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scaleX: isMirrored ? -1.0 : 1.0,
          child: imageWidget,
        ),
        if (photo.isVideo && showPlayBadge)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                LucideIcons.play,
                color: AppColors.white,
                size: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackPlaceholder() {
    return Container(
      color: const Color(0xFF1E0D26),
      child: Center(
        child: Icon(
          photo.isVideo ? LucideIcons.video : LucideIcons.image,
          color: Colors.white24,
          size: 24,
        ),
      ),
    );
  }
}
