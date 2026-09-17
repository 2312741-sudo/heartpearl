import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool hasBorder;
  final Color borderColor;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48.0,
    this.hasBorder = false,
    this.borderColor = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget avatarContent;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      avatarContent = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: AppColors.darkSurfaceLight,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryLight,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildInitials(initial),
      );
    } else {
      avatarContent = _buildInitials(initial);
    }

    Widget result = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatarContent,
      ),
    );

    if (hasBorder) {
      result = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: result,
      );
    }

    if (onTap != null) {
      result = GestureDetector(onTap: onTap, child: result);
    }

    return result;
  }

  Widget _buildInitials(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.bold.copyWith(
            color: AppColors.white,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}
