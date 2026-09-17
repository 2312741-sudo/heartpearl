import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/user_avatar.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final themeMode = ref.watch(settingsProvider).themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = ref.watch(userProfileProvider).value;
    final sentPhotos = ref.watch(sentPhotosProvider).value ?? [];

    int totalReactions = 0;
    for (final photo in sentPhotos) {
      totalReactions += photo.reactions.length;
      totalReactions += photo.textReactions.length;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.tr('profile_title', lang: lang),
          style: AppTypography.h2(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Column(
                children: [
                  // Profile Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimens.spaceXl),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? AppColors.darkCardGradient
                          : const LinearGradient(
                              colors: [AppColors.white, Color(0xFFFCE4EC)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                      borderRadius: BorderRadius.circular(AppDimens.radius2Xl),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      boxShadow: AppDimens.softCardShadow,
                    ),
                    child: Column(
                      children: [
                        UserAvatar(
                          imageUrl: user.avatarUrl,
                          name: user.displayName,
                          size: 88,
                          hasBorder: true,
                          borderColor: AppColors.primary,
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        Text(
                          user.displayName,
                          style: AppTypography.h2(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username}',
                          style: AppTypography.bodyBold(color: AppColors.primaryLight),
                        ),
                        if (user.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.email!,
                            style: AppTypography.caption(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],

                        const SizedBox(height: AppDimens.spaceLg),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: AppDimens.spaceSm),

                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              label: AppStrings.tr('profile_friends_stat', lang: lang),
                              value: user.friends.length.toString(),
                              isDark: isDark,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                            _buildStatItem(
                              label: AppStrings.tr('profile_sent_stat', lang: lang),
                              value: sentPhotos.length.toString(),
                              isDark: isDark,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                            _buildStatItem(
                              label: AppStrings.tr('profile_reactions_stat', lang: lang),
                              value: totalReactions.toString(),
                              isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: AppDimens.spaceLg),

                        // Edit profile button
                        OutlinedButton.icon(
                          onPressed: () {
                            HapticHelper.light();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppDimens.radius2Xl),
                                ),
                              ),
                              builder: (context) => EditProfileSheet(user: user),
                            );
                          },
                          icon: const Icon(LucideIcons.edit2, size: 16),
                          label: Text(AppStrings.tr('profile_edit', lang: lang)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryLight,
                            side: const BorderSide(color: AppColors.primaryLight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // Settings Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Share Account
                        ListTile(
                          leading: const Icon(LucideIcons.share2, color: AppColors.primaryLight),
                          title: Text(
                            AppStrings.tr('profile_share', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '@${user.username}',
                            style: AppTypography.caption(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          trailing: const Icon(LucideIcons.copy, size: 18),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: '@${user.username}'));
                            HapticHelper.selection();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép @username vào bộ nhớ tạm!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),

                        Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),

                        // Dark Mode Toggle
                        SwitchListTile(
                          secondary: Icon(
                            isDark ? LucideIcons.moon : LucideIcons.sun,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            AppStrings.tr('profile_dark_mode', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          value: themeMode == ThemeMode.dark,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            HapticHelper.selection();
                            ref.read(settingsProvider.notifier).toggleTheme();
                          },
                        ),

                        Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),

                        // Language Toggle
                        ListTile(
                          leading: const Icon(LucideIcons.globe, color: AppColors.primaryLight),
                          title: Text(
                            AppStrings.tr('profile_language', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            child: Text(
                              lang == 'vi' ? 'Tiếng Việt' : 'English',
                              style: AppTypography.bodyBold(color: AppColors.primaryLight),
                            ),
                          ),
                          onTap: () {
                            HapticHelper.selection();
                            ref
                                .read(settingsProvider.notifier)
                                .setLanguage(lang == 'vi' ? 'en' : 'vi');
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // Logout Button
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(LucideIcons.logOut, color: AppColors.error),
                      title: Text(
                        AppStrings.tr('profile_logout', lang: lang),
                        style: AppTypography.bodyBold(color: AppColors.error),
                      ),
                      onTap: () {
                        HapticHelper.medium();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface,
                            title: Text(AppStrings.tr('profile_logout', lang: lang)),
                            content: Text(AppStrings.tr('profile_confirm_logout', lang: lang)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref.read(authServiceProvider).signOut();
                                },
                                child: const Text(
                                  'Đăng xuất',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppDimens.space2Xl),

                  Text(
                    'HeartPearl v2.0 • Flutter Edition',
                    style: AppTypography.caption(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h2(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}
