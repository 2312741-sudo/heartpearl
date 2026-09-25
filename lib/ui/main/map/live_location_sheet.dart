import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/location_sharing_duration.dart';

/// Bottom sheet allowing the user to start a Live Location session.
///
/// Presents three duration options. Selecting [LocationSharingDuration.unlimited]
/// additionally shows an explicit consent dialog — required for Apple review.
class LiveLocationSheet extends ConsumerWidget {
  const LiveLocationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceBase,
            AppDimens.spaceSm,
            AppDimens.spaceBase,
            AppDimens.spaceBase,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceBase),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.radio,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr('live_share_title', lang: lang),
                        style: AppTypography.h3(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.tr('live_share_subtitle', lang: lang),
                        style: AppTypography.caption(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.spaceBase),
            const Divider(height: 1),
            const SizedBox(height: AppDimens.spaceBase),

            // Duration options
            _DurationTile(
              duration: LocationSharingDuration.oneHour,
              icon: LucideIcons.clock,
              iconColor: Colors.blue,
              lang: lang,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            _DurationTile(
              duration: LocationSharingDuration.untilEndOfDay,
              icon: LucideIcons.sunset,
              iconColor: Colors.orange,
              lang: lang,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            _DurationTile(
              duration: LocationSharingDuration.unlimited,
              icon: LucideIcons.infinity,
              iconColor: AppColors.primary,
              lang: lang,
              isUnlimited: true,
            ),

            const SizedBox(height: AppDimens.spaceBase),

            // Privacy notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.shieldCheck, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.tr('live_mutual_friends_note', lang: lang),
                      style: AppTypography.micro(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.tr('safety_cancel', lang: lang)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _DurationTile extends ConsumerWidget {
  final LocationSharingDuration duration;
  final IconData icon;
  final Color iconColor;
  final String lang;
  final bool isUnlimited;

  const _DurationTile({
    required this.duration,
    required this.icon,
    required this.iconColor,
    required this.lang,
    this.isUnlimited = false,
  });

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    HapticHelper.selection();

    // For "unlimited", show an extra consent dialog before starting.
    if (isUnlimited) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.tr('live_confirm_unlimited_title', lang: lang)),
          content: Text(AppStrings.tr('live_confirm_unlimited_body', lang: lang)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.tr('safety_cancel', lang: lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.tr('live_confirm_btn', lang: lang)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!context.mounted) return;
    }

    // Close the sheet.
    if (context.mounted) Navigator.pop(context, duration);

    // Start the live session.
    try {
      await ref.read(locationServiceProvider).startLiveSharing(duration);
      HapticHelper.success();
    } catch (e) {
      // Errors surface via the status stream; map_screen will show the snackbar.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: () => _onTap(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceBase,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      duration.label(lang),
                      style: AppTypography.bodyBold(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      duration.subtitle(lang),
                      style: AppTypography.caption(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
