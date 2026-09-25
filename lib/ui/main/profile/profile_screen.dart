import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/settings_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../common/skeleton_loader.dart';
import '../../common/user_avatar.dart';
import '../../../core/constants/app_info.dart';
import 'edit_profile_sheet.dart';
import 'privacy_and_app_info_screen.dart';
import '../friends/friends_screen.dart';

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
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: user == null
          ? const SkeletonProfile()
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
                              colors: [AppColors.white, AppColors.lightSurfaceLight],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                      borderRadius: BorderRadius.circular(AppDimens.radius2Xl),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
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
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username}',
                          style: AppTypography.bodyBold(
                            color: AppColors.primaryLight,
                          ),
                        ),
                        if (user.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.email!,
                            style: AppTypography.caption(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                        if (user.phone != null && user.phone!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.phone,
                                size: 12,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.phone!,
                                style: AppTypography.caption(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
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
                                builder: (context) =>
                                    EditProfileSheet(user: user),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusFull,
                                ),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.phone,
                                    size: 12,
                                    color: AppColors.primaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Thêm số điện thoại',
                                    style: AppTypography.caption(
                                      color: AppColors.primaryLight,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
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
                            GestureDetector(
                              onTap: () {
                                HapticHelper.selection();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const FriendsScreen(),
                                  ),
                                );
                              },
                              child: _buildStatItem(
                                label: AppStrings.tr(
                                  'profile_friends_stat',
                                  lang: lang,
                                ),
                                value: user.friends.length.toString(),
                                isDark: isDark,
                              ),
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                            _buildStatItem(
                              label: AppStrings.tr(
                                'profile_sent_stat',
                                lang: lang,
                              ),
                              value: sentPhotos.length.toString(),
                              isDark: isDark,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                            _buildStatItem(
                              label: AppStrings.tr(
                                'profile_reactions_stat',
                                lang: lang,
                              ),
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
                              builder: (context) =>
                                  EditProfileSheet(user: user),
                            );
                          },
                          icon: const Icon(LucideIcons.edit2, size: 16),
                          label: Text(
                            AppStrings.tr('profile_edit', lang: lang),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryLight,
                            side: const BorderSide(
                              color: AppColors.primaryLight,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusFull,
                              ),
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
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Share Account
                        ListTile(
                          leading: const Icon(
                            LucideIcons.share2,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            AppStrings.tr('profile_share', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '@${user.username}',
                            style: AppTypography.caption(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          trailing: const Icon(LucideIcons.copy, size: 18),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: '@${user.username}'),
                            );
                            HapticHelper.selection();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã sao chép @username vào bộ nhớ tạm!',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),

                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          height: 1,
                        ),

                        // Phone Number
                        ListTile(
                          leading: const Icon(
                            LucideIcons.phone,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            'Số điện thoại',
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            user.phone != null && user.phone!.isNotEmpty
                                ? user.phone!
                                : 'Chưa liên kết (Bấm để thêm)',
                            style: AppTypography.caption(
                              color:
                                  user.phone != null && user.phone!.isNotEmpty
                                  ? (isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted)
                                  : AppColors.primaryLight,
                            ),
                          ),
                          trailing: const Icon(LucideIcons.edit2, size: 16),
                          onTap: () {
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
                              builder: (context) =>
                                  EditProfileSheet(user: user),
                            );
                          },
                        ),

                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          height: 1,
                        ),

                        // Dark Mode Toggle
                        SwitchListTile(
                          secondary: Icon(
                            isDark ? LucideIcons.moon : LucideIcons.sun,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            AppStrings.tr('profile_dark_mode', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          value: themeMode == ThemeMode.dark,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            HapticHelper.selection();
                            ref.read(settingsProvider.notifier).toggleTheme();
                          },
                        ),

                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          height: 1,
                        ),

                        // Language Toggle
                        ListTile(
                          leading: const Icon(
                            LucideIcons.globe,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            AppStrings.tr('profile_language', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusFull,
                              ),
                            ),
                            child: Text(
                              lang == 'vi' ? 'Tiếng Việt' : 'English',
                              style: AppTypography.bodyBold(
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                          onTap: () {
                            HapticHelper.selection();
                            ref
                                .read(settingsProvider.notifier)
                                .setLanguage(lang == 'vi' ? 'en' : 'vi');
                          },
                        ),

                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          height: 1,
                        ),

                        // Consolidated: Quyền riêng tư & Thông tin ứng dụng
                        ListTile(
                          leading: const Icon(
                            LucideIcons.shieldCheck,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            lang == 'vi'
                                ? 'Quyền riêng tư & Thông tin ứng dụng'
                                : 'Privacy & App Information',
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            lang == 'vi'
                                ? 'Vị trí, Chặn, Quyền hệ thống, Điều khoản & v${AppInfo.appVersion}'
                                : 'Location, Blocks, System Permissions & v${AppInfo.appVersion}',
                            style: AppTypography.caption(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                          ),
                          onTap: () {
                            HapticHelper.light();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyAndAppInfoScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // Account Actions Card (Delete Account & Logout per Apple Guideline 5.1.1(v))
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Delete Account Permanently (Apple Guideline 5.1.1(v))
                        ListTile(
                          leading: const Icon(
                            LucideIcons.trash2,
                            color: AppColors.errorBrand,
                          ),
                          title: Text(
                            lang == 'vi'
                                ? 'Xóa tài khoản vĩnh viễn'
                                : 'Delete Account Permanently',
                            style: AppTypography.bodyBold(
                              color: AppColors.errorBrand,
                            ),
                          ),
                          subtitle: Text(
                            lang == 'vi'
                                ? 'Xóa toàn bộ ảnh, video, bạn bè và dữ liệu'
                                : 'Permanently purge all photos, media & account',
                            style: AppTypography.caption(
                              color: AppColors.errorBrand.withValues(alpha: 0.75),
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            color: AppColors.errorBrand,
                            size: 18,
                          ),
                          onTap: () => _showDeleteAccountDialog(context, ref, lang, isDark),
                        ),

                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          height: 1,
                        ),

                        // Logout
                        ListTile(
                          leading: const Icon(
                            LucideIcons.logOut,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            AppStrings.tr('profile_logout', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          onTap: () {
                            HapticHelper.medium();
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                title: Text(
                                  AppStrings.tr('profile_logout', lang: lang),
                                ),
                                content: Text(
                                  AppStrings.tr(
                                    'profile_confirm_logout',
                                    lang: lang,
                                  ),
                                ),
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
                                      style: TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.space2Xl),

                  Text(
                    '${AppInfo.appName} v${AppInfo.appVersion} (Build ${AppInfo.buildNumber})',
                    style: AppTypography.caption(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppInfo.copyright,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted.withValues(alpha: 0.6)
                          : AppColors.lightTextMuted.withValues(alpha: 0.6),
                    ),
                  ),

                  // Bottom padding to clear floating navigation bar
                  const SizedBox(height: 120),
                ],
              ),
            ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
    String lang,
    bool isDark,
  ) {
    HapticHelper.heavy();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final isVi = lang == 'vi';
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radius2Xl),
                side: const BorderSide(color: AppColors.errorBrand, width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorBrand.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.alertTriangle,
                      color: AppColors.errorBrand,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isVi ? 'Xóa tài khoản vĩnh viễn' : 'Permanently Delete Account',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.errorBrand,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi
                          ? 'Theo tiêu chuẩn quyền riêng tư của Apple, toàn bộ dữ liệu của bạn sẽ bị xóa hoàn toàn khỏi hệ thống HeartPearl và không thể hoàn tác:'
                          : 'In compliance with Apple privacy guidelines, all your personal data will be permanently and irreversibly deleted from HeartPearl:',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    _buildDeleteWarningItem(
                      isVi
                          ? 'Toàn bộ ảnh và video khoảnh khắc bạn đã đăng.'
                          : 'All posted photos and video moments.',
                    ),
                    _buildDeleteWarningItem(
                      isVi
                          ? 'Hồ sơ cá nhân, tên người dùng và ảnh đại diện.'
                          : 'Personal profile, username, and avatar.',
                    ),
                    _buildDeleteWarningItem(
                      isVi
                          ? 'Danh sách bạn bè và mọi lời mời kết bạn.'
                          : 'Friends list and all friend requests.',
                    ),
                    _buildDeleteWarningItem(
                      isVi
                          ? 'Toàn bộ tin nhắn và lịch sử trò chuyện.'
                          : 'All chat messages and conversations.',
                    ),
                    _buildDeleteWarningItem(
                      isVi
                          ? 'Tài khoản đăng nhập và dữ liệu tiện ích Home Widget.'
                          : 'Login credentials and Home Widget cached data.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isVi
                          ? 'Hoặc yêu cầu xóa tài khoản trực tuyến tại:'
                          : 'Or request online deletion at:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        HapticHelper.light();
                        UrlLauncherHelper.openDeleteAccount();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                UrlLauncherHelper.deleteAccountUrl,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryLight,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              LucideIcons.externalLink,
                              size: 13,
                              color: AppColors.primaryLight,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isDeleting)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(isVi ? 'Hủy bỏ' : 'Cancel'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorBrand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setState(() {
                            isDeleting = true;
                            errorText = null;
                          });
                          HapticHelper.heavy();

                          try {
                            final authService = ref.read(authServiceProvider);
                            await authService.deleteAccount();

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (context.mounted) {
                              Navigator.of(context)
                                   .popUntil((route) => route.isFirst);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isVi
                                        ? 'Tài khoản và toàn bộ dữ liệu của bạn đã được xóa hoàn tất.'
                                        : 'Your account and all associated data have been permanently deleted.',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            if (ctx.mounted) {
                              setState(() {
                                isDeleting = false;
                                if (e.code == 'requires-recent-login') {
                                  errorText = isVi
                                      ? 'Để bảo vệ tài khoản, Apple & Firebase yêu cầu bạn phải vừa đăng nhập mới có thể xóa. Vui lòng đăng xuất, đăng nhập lại và thực hiện lại thao tác xóa này.'
                                      : 'For security reasons, Apple & Firebase require a recent sign-in before deleting your account. Please log out, log back in, and try again.';
                                } else {
                                  errorText = isVi ? 'Lỗi: ${e.message ?? e.code}' : 'Error: ${e.message ?? e.code}';
                                }
                              });
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setState(() {
                                isDeleting = false;
                                errorText = isVi
                                    ? 'Lỗi xóa tài khoản: ${e.toString()}'
                                    : 'Account deletion error: ${e.toString()}';
                              });
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isVi ? 'Xác nhận xóa' : 'Confirm Delete',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeleteWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppColors.errorBrand,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
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
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
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
