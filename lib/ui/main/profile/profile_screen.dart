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

import 'package:firebase_auth/firebase_auth.dart';

import '../../common/eula_modal.dart';
import '../../common/user_avatar.dart';
import 'blocked_users_screen.dart';
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
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
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
                            _buildStatItem(
                              label: AppStrings.tr(
                                'profile_friends_stat',
                                lang: lang,
                              ),
                              value: user.friends.length.toString(),
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

                        ListTile(
                          leading: const Icon(
                            LucideIcons.userRoundX,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            AppStrings.tr('safety_manage_blocks', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            AppStrings.tr(
                              'safety_manage_blocks_subtitle',
                              lang: lang,
                            ),
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
                                builder: (_) => const BlockedUsersScreen(),
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

                        // Privacy Policy
                        ListTile(
                          leading: const Icon(
                            LucideIcons.shieldCheck,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            'Quyền riêng tư & Bảo mật',
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Tiêu chuẩn bảo mật Apple & HeartPearl',
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
                          onTap: () => _showPrivacyPolicyDialog(
                            context,
                            ref,
                            lang,
                            isDark,
                          ),
                        ),

                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          height: 1,
                        ),

                        // EULA & Community Standards (Apple Guideline 1.2)
                        ListTile(
                          leading: const Icon(
                            LucideIcons.fileText,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(
                            AppStrings.tr('profile_terms_eula', lang: lang),
                            style: AppTypography.bodyBold(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            AppStrings.tr('profile_terms_eula_sub', lang: lang),
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
                          onTap: () => EulaModal.show(context),
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
                        // Standalone Delete Account Option (Apple Guideline 5.1.1(v))
                        ListTile(
                          leading: const Icon(
                            LucideIcons.trash2,
                            color: AppColors.error,
                          ),
                          title: Text(
                            AppStrings.tr('profile_delete_account', lang: lang),
                            style: AppTypography.bodyBold(
                              color: AppColors.error,
                            ),
                          ),
                          subtitle: Text(
                            AppStrings.tr(
                              'profile_delete_account_sub',
                              lang: lang,
                            ),
                            style: AppTypography.caption(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: AppColors.error,
                          ),
                          onTap: () => _showDeleteAccountDialog(
                            context,
                            ref,
                            lang,
                            isDark,
                          ),
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
                    'HeartPearl v2.0 • Flutter Edition',
                    style: AppTypography.caption(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
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
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radius2Xl),
                side: const BorderSide(color: AppColors.error, width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.alertTriangle,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Xóa tài khoản vĩnh viễn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
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
                    const Text(
                      'Theo tiêu chuẩn quyền riêng tư của Apple, toàn bộ dữ liệu của bạn sẽ bị xóa hoàn toàn khỏi hệ thống HeartPearl và không thể hoàn tác:',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    _buildDeleteWarningItem(
                      'Toàn bộ ảnh và video khoảnh khắc bạn đã đăng.',
                    ),
                    _buildDeleteWarningItem(
                      'Hồ sơ cá nhân, tên người dùng và ảnh đại diện.',
                    ),
                    _buildDeleteWarningItem(
                      'Danh sách bạn bè và mọi lời mời kết bạn.',
                    ),
                    _buildDeleteWarningItem(
                      'Toàn bộ tin nhắn và lịch sử trò chuyện.',
                    ),
                    _buildDeleteWarningItem(
                      'Tài khoản đăng nhập và dữ liệu tiện ích Home Widget.',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hoặc yêu cầu xóa tài khoản trực tuyến tại:\nhttps://tamchau-865f3.web.app/delete-account.html',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryLight,
                        height: 1.35,
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
                    child: const Text('Hủy bỏ'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
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
                                const SnackBar(
                                  content: Text(
                                    'Tài khoản và toàn bộ dữ liệu của bạn đã được xóa hoàn tất.',
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
                                  errorText = 'Để bảo vệ tài khoản, Apple & Firebase yêu cầu bạn phải vừa đăng nhập mới có thể xóa. Vui lòng đăng xuất, đăng nhập lại và thực hiện lại thao tác xóa này.';
                                } else {
                                  errorText = 'Lỗi: ${e.message ?? e.code}';
                                }
                              });
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setState(() {
                                isDeleting = false;
                                errorText =
                                    'Lỗi xóa tài khoản: ${e.toString()}';
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
                      : const Text(
                          'Xác nhận xóa',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
              color: AppColors.error,
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

  void _showPrivacyPolicyDialog(
    BuildContext context,
    WidgetRef ref,
    String lang,
    bool isDark,
  ) {
    HapticHelper.light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius2Xl),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        title: const Row(
          children: [
            Icon(LucideIcons.shieldCheck, color: AppColors.primaryLight),
            SizedBox(width: 10),
            Text('Quyền riêng tư & Bảo mật'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HeartPearl cam kết bảo vệ dữ liệu cá nhân theo tiêu chuẩn của Apple App Store:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Ảnh & Video: Chỉ chia sẻ trực tiếp với bạn bè mà bạn kết nối.',
              ),
              const SizedBox(height: 6),
              const Text(
                '• Máy ảnh & Micrô: Chỉ hoạt động khi bạn chủ động chụp ảnh hoặc quay video.',
              ),
              const SizedBox(height: 6),
              const Text(
                '• Widget màn hình chính: Cập nhật tự động những khoảnh khắc mới nhất từ bạn bè.',
              ),
              const SizedBox(height: 6),
              const Text(
                '• Quyền làm chủ dữ liệu: Bạn có toàn quyền quản lý, xóa khoảnh khắc hoặc xóa vĩnh viễn tài khoản.',
              ),
              const SizedBox(height: 14),
              const Text(
                'Trang chính sách trực tuyến:\nhttps://tamchau-865f3.web.app/privacy-policy.html',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Yêu cầu xóa dữ liệu trực tuyến:\nhttps://tamchau-865f3.web.app/delete-account.html',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryLight,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),

              // Danger Zone: Account Deletion (Apple Guideline 5.1.1(v))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          color: AppColors.error,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Quản lý tài khoản',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Nếu không còn nhu cầu sử dụng, bạn có thể xóa vĩnh viễn tài khoản và toàn bộ dữ liệu theo Apple Guideline 5.1.1(v).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(LucideIcons.trash2, size: 14),
                        label: const Text(
                          'Xóa tài khoản vĩnh viễn',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDeleteAccountDialog(context, ref, lang, isDark);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
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
