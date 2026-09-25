import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'frosted_container.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppDimens.radiusMd,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0x2AFFFFFF)
        : AppColors.lightBorder.withValues(alpha: 0.5);
    final shimmerColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.65);

    return FrostedContainer(
      width: width,
      height: height,
      margin: margin,
      borderRadius: borderRadius,
      backgroundColor: baseColor,
      border: Border.all(
        color: isDark
            ? Colors.white10
            : AppColors.lightBorder.withValues(alpha: 0.3),
      ),
      child: const SizedBox.expand(),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
      duration: 1200.ms,
      color: shimmerColor,
    );
  }
}

class SkeletonGridView extends StatelessWidget {
  final int count;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;

  const SkeletonGridView({
    super.key,
    this.count = 6,
    this.childAspectRatio = 0.8,
    this.padding = const EdgeInsets.all(AppDimens.spaceBase),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimens.spaceBase,
        mainAxisSpacing: AppDimens.spaceBase,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return const SkeletonBox(
          borderRadius: AppDimens.radiusLg,
        );
      },
    );
  }
}

class SkeletonListView extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const SkeletonListView({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimens.spaceBase,
      vertical: AppDimens.spaceSm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding,
      itemCount: count,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: FrostedContainer(
            borderRadius: AppDimens.radiusLg,
            padding: const EdgeInsets.all(12),
            backgroundColor: isDark
                ? const Color(0x1AFFFFFF)
                : AppColors.lightSurface.withValues(alpha: 0.8),
            child: const Row(
              children: [
                SkeletonBox(
                  width: 48,
                  height: 48,
                  borderRadius: AppDimens.radiusFull,
                ),
                SizedBox(width: AppDimens.spaceBase),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SkeletonBox(
                        width: 140,
                        height: 14,
                        borderRadius: AppDimens.radiusSm,
                      ),
                      SizedBox(height: 8),
                      SkeletonBox(
                        width: 90,
                        height: 10,
                        borderRadius: AppDimens.radiusSm,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        children: [
          FrostedContainer(
            borderRadius: AppDimens.radius2Xl,
            padding: const EdgeInsets.all(AppDimens.spaceXl),
            backgroundColor: isDark
                ? const Color(0x1AFFFFFF)
                : AppColors.lightSurface.withValues(alpha: 0.8),
            child: const Column(
              children: [
                SkeletonBox(
                  width: 88,
                  height: 88,
                  borderRadius: AppDimens.radiusFull,
                ),
                SizedBox(height: AppDimens.spaceBase),
                SkeletonBox(
                  width: 140,
                  height: 18,
                  borderRadius: AppDimens.radiusSm,
                ),
                SizedBox(height: 8),
                SkeletonBox(
                  width: 100,
                  height: 14,
                  borderRadius: AppDimens.radiusSm,
                ),
                SizedBox(height: AppDimens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SkeletonBox(
                      width: 60,
                      height: 40,
                      borderRadius: AppDimens.radiusMd,
                    ),
                    SkeletonBox(
                      width: 60,
                      height: 40,
                      borderRadius: AppDimens.radiusMd,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          const SkeletonListView(count: 4, padding: EdgeInsets.zero),
        ],
      ),
    );
  }
}
