import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/camera_filters.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../common/frosted_container.dart';

class CameraFilterBar extends StatelessWidget {
  final BeautyFilter selectedFilter;
  final FilterCategory selectedCategory;
  final double filterIntensity;
  final BeautySettings beauty;
  final bool isDark;
  final bool isRecording;
  final ValueChanged<BeautyFilter> onSelectFilter;
  final ValueChanged<FilterCategory> onSelectCategory;
  final ValueChanged<double> onIntensityChanged;
  final VoidCallback onReset;
  final VoidCallback onOpenBeauty;

  const CameraFilterBar({
    super.key,
    required this.selectedFilter,
    required this.selectedCategory,
    required this.filterIntensity,
    required this.beauty,
    required this.isDark,
    required this.isRecording,
    required this.onSelectFilter,
    required this.onSelectCategory,
    required this.onIntensityChanged,
    required this.onReset,
    required this.onOpenBeauty,
  });

  bool get hasActiveFilter => !selectedFilter.isOriginal || beauty.hasEffect;

  @override
  Widget build(BuildContext context) {
    if (isRecording) return const SizedBox.shrink();

    final categoryFilters = [
      if (selectedCategory == FilterCategory.natural) BeautyFilter.all.first,
      ...BeautyFilter.inCategory(selectedCategory),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Intensity Slider
        _buildIntensitySlider(context),

        const SizedBox(height: 6),

        // Filter Carousel for current category
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
            itemCount: categoryFilters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = categoryFilters[index];
              final isSelected = filter.type == selectedFilter.type;
              final swatchColors = filter.thumbnailColors.length >= 2
                  ? filter.thumbnailColors
                  : [filter.thumbnailColors.first, filter.thumbnailColors.first];

              return GestureDetector(
                onTap: () => onSelectFilter(filter),
                child: FrostedContainer(
                  borderRadius: AppDimens.radiusFull,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: isSelected
                      ? AppColors.primary.withValues(alpha: 0.85)
                      : (isDark
                            ? const Color(0x4D1E0D26)
                            : AppColors.lightSurface.withValues(alpha: 0.9)),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryLight
                        : (isDark ? Colors.white24 : AppColors.lightBorder),
                    width: isSelected ? 1.5 : 1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!filter.isOriginal) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: swatchColors),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white54,
                              width: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(filter.icon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        filter.name,
                        style: AppTypography.medium.copyWith(
                          color: isSelected
                              ? AppColors.white
                              : (isDark
                                    ? AppColors.white
                                    : AppColors.lightTextPrimary),
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        // Category Bar + Reset + Beauty Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Row(
            children: [
              // Reset button
              GestureDetector(
                onTap: () {
                  HapticHelper.light();
                  onReset();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0x4D1E0D26)
                        : AppColors.lightSurface.withValues(alpha: 0.9),
                    border: Border.all(
                      color: isDark ? Colors.white24 : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.rotateCcw,
                    size: 14,
                    color: isDark
                        ? Colors.white70
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Scrollable Category Chips
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: FilterCategory.values.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final category = FilterCategory.values[index];
                      final isSelected = category == selectedCategory;

                      return GestureDetector(
                        onTap: () {
                          HapticHelper.selection();
                          onSelectCategory(category);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isSelected
                                ? (isDark
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ))
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${category.icon} ${category.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? (isDark
                                        ? AppColors.white
                                        : AppColors.primary)
                                  : (isDark
                                        ? Colors.white60
                                        : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Beauty Settings Button
              GestureDetector(
                onTap: () {
                  HapticHelper.selection();
                  onOpenBeauty();
                },
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: beauty.hasEffect
                        ? AppColors.primary.withValues(alpha: 0.22)
                        : (isDark
                              ? const Color(0x4D1E0D26)
                              : AppColors.lightSurface.withValues(alpha: 0.9)),
                    border: Border.all(
                      color: beauty.hasEffect
                          ? AppColors.primary
                          : (isDark ? Colors.white24 : AppColors.lightBorder),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: beauty.hasEffect
                            ? AppColors.primaryLight
                            : (isDark
                                  ? Colors.white70
                                  : AppColors.lightTextSecondary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Làm đẹp',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: beauty.hasEffect
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: beauty.hasEffect
                              ? (isDark ? Colors.white : AppColors.primary)
                              : (isDark
                                    ? Colors.white70
                                    : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntensitySlider(BuildContext context) {
    return SizedBox(
      height: 36,
      child: AnimatedOpacity(
        opacity: hasActiveFilter && !isRecording ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !hasActiveFilter || isRecording,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 270),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: FrostedContainer(
                borderRadius: AppDimens.radiusFull,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                backgroundColor: isDark
                    ? const Color(0xCC1E0D26)
                    : AppColors.lightSurface.withValues(alpha: 0.95),
                border: Border.all(
                  color: isDark ? Colors.white24 : AppColors.lightBorder,
                  width: 1,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.slidersHorizontal,
                      size: 13,
                      color: isDark
                          ? Colors.white70
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Cường độ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: isDark
                              ? Colors.white24
                              : AppColors.lightBorder,
                          thumbColor: AppColors.primary,
                        ),
                        child: Slider(
                          value: filterIntensity,
                          min: 0.0,
                          max: 1.0,
                          onChanged: onIntensityChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${(filterIntensity * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
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
    );
  }
}
