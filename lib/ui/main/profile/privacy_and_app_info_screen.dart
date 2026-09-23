import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/eula_modal.dart';
import 'blocked_users_screen.dart';
import 'location_privacy_screen.dart';

class PrivacyAndAppInfoScreen extends ConsumerWidget {
  const PrivacyAndAppInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isVi = lang == 'vi';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isVi ? 'Quyền riêng tư & Thông tin' : 'Privacy & App Info',
          style: AppTypography.h3(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceMd,
        ),
        children: [
          // 1. App Header Card (Branding & Detailed App Info)
          _buildAppHeaderCard(context, isDark, isVi),

          const SizedBox(height: AppDimens.spaceXl),

          // 2. Device Permissions Section
          _buildSectionHeader(
            icon: LucideIcons.slidersHorizontal,
            title: isVi ? 'QUYỀN TRUY CẬP THIẾT BỊ' : 'DEVICE PERMISSIONS',
            isDark: isDark,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _buildPermissionsCard(context, isDark, isVi),

          const SizedBox(height: AppDimens.spaceXl),

          // 3. Privacy & Safety Management Section
          _buildSectionHeader(
            icon: LucideIcons.shieldCheck,
            title: isVi ? 'KIỂM SOÁT QUYỀN RIÊNG TƯ & AN TOÀN' : 'PRIVACY & SAFETY CONTROLS',
            isDark: isDark,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _buildPrivacyControlsCard(context, isDark, isVi),

          const SizedBox(height: AppDimens.spaceXl),

          // 4. Legal & Compliance Section
          _buildSectionHeader(
            icon: LucideIcons.fileCheck,
            title: isVi ? 'ĐIỀU KHOẢN & PHÁP LÝ (APPLE COMPLIANCE)' : 'LEGAL & POLICIES',
            isDark: isDark,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _buildLegalCard(context, isDark, isVi),

          const SizedBox(height: AppDimens.spaceXl),

          // 5. Support & Direct Contact Section
          _buildSectionHeader(
            icon: LucideIcons.headset,
            title: isVi ? 'HỖ TRỢ KỸ THUẬT & LIÊN HỆ' : 'SUPPORT & CONTACT',
            isDark: isDark,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _buildSupportCard(context, isDark, isVi),

          const SizedBox(height: AppDimens.spaceXl),

          // 6. Account Actions Section (Apple Guideline 5.1.1(v))
          _buildSectionHeader(
            icon: LucideIcons.userX,
            title: isVi ? 'QUẢN LÝ TÀI KHOẢN' : 'ACCOUNT MANAGEMENT',
            isDark: isDark,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _buildAccountCard(context, ref, isDark, isVi),

          const SizedBox(height: AppDimens.space2Xl),

          // Bottom copyright & build label
          Center(
            child: Column(
              children: [
                Text(
                  '${AppInfo.appName} v${AppInfo.appVersion} (Build ${AppInfo.buildNumber})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppInfo.copyright,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.7) : AppColors.lightTextMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // --- Section Header ---
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  // --- 1. App Header Card ---
  Widget _buildAppHeaderCard(BuildContext context, bool isDark, bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radius2Xl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.heartHandshake,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            AppInfo.appName,
            style: AppTypography.h2(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isVi ? AppInfo.appTaglineVi : AppInfo.appTaglineEn,
            style: AppTypography.caption(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildInfoBadge(
                label: 'Version ${AppInfo.appVersion}',
                isDark: isDark,
              ),
              _buildInfoBadge(
                label: 'Build ${AppInfo.buildNumber}',
                isDark: isDark,
              ),
              _buildInfoBadge(
                label: 'iOS & Android',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bundle ID: ${AppInfo.bundleId}',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge({required String label, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceLight
            : AppColors.lightSurfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }

  // --- 2. Device Permissions Section ---
  Widget _buildPermissionsCard(BuildContext context, bool isDark, bool isVi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          _buildPermissionTile(
            icon: LucideIcons.camera,
            title: isVi ? 'Máy ảnh (Camera)' : 'Camera',
            subtitle: isVi
                ? 'Chụp ảnh và quay video khoảnh khắc trực tiếp'
                : 'Capture photos and live video moments',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildPermissionTile(
            icon: LucideIcons.mic,
            title: isVi ? 'Microphone' : 'Microphone',
            subtitle: isVi
                ? 'Ghi âm âm thanh chân thực cho video khoảnh khắc'
                : 'Record authentic audio for live moments',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildPermissionTile(
            icon: LucideIcons.image,
            title: isVi ? 'Thư viện ảnh (Photo Library)' : 'Photo Library',
            subtitle: isVi
                ? 'Lưu ảnh/video về album máy và chọn ảnh đại diện'
                : 'Save moments to device album and select avatars',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildPermissionTile(
            icon: LucideIcons.mapPin,
            title: isVi ? 'Vị trí (Location)' : 'Location',
            subtitle: isVi
                ? 'Check-in thủ công & hiển thị vị trí trên bản đồ bạn bè'
                : 'Manual check-in and friends map radar (zero background drain)',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildPermissionTile(
            icon: LucideIcons.bell,
            title: isVi ? 'Thông báo (Notifications)' : 'Notifications',
            subtitle: isVi
                ? 'Nhận thông báo khi bạn bè gửi khoảnh khắc mới'
                : 'Receive alerts when close friends share moments',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          ListTile(
            leading: const Icon(LucideIcons.settings2, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Quản lý quyền trong Cài đặt hệ thống' : 'Open Device Settings',
              style: AppTypography.bodyBold(
                color: AppColors.primaryLight,
              ),
            ),
            subtitle: Text(
              isVi
                  ? 'Bật hoặc tắt quyền trực tiếp trên hệ điều hành thiết bị'
                  : 'Manage app permissions in iOS/Android Settings',
              style: AppTypography.caption(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: const Icon(LucideIcons.externalLink, size: 16, color: AppColors.primaryLight),
            onTap: () async {
              HapticHelper.light();
              try {
                await Geolocator.openAppSettings();
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryLight, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          height: 1.35,
        ),
      ),
    );
  }

  // --- 3. Privacy & Safety Management Section ---
  Widget _buildPrivacyControlsCard(BuildContext context, bool isDark, bool isVi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.mapPinCheck, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Quyền riêng tư vị trí & Chế độ ẩn danh' : 'Location Privacy & Ghost Mode',
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              isVi
                  ? 'Bật Ghost mode, quản lý danh sách bạn bè được xem vị trí'
                  : 'Toggle Ghost mode and select allowed friends',
              style: AppTypography.caption(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () {
              HapticHelper.light();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LocationPrivacyScreen(),
                ),
              );
            },
          ),
          _buildDivider(isDark),
          ListTile(
            leading: const Icon(LucideIcons.userRoundX, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Quản lý người dùng bị chặn' : 'Blocked Users',
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              isVi
                  ? 'Xem danh sách người bị chặn, bỏ chặn hoặc an toàn tài khoản'
                  : 'Manage two-way blocked contacts and safety',
              style: AppTypography.caption(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () {
              HapticHelper.light();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BlockedUsersScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 4. Legal & Compliance Section ---
  Widget _buildLegalCard(BuildContext context, bool isDark, bool isVi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.shieldCheck, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Chính sách quyền riêng tư (Privacy Policy)' : 'Privacy Policy',
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              isVi
                  ? 'Bảo vệ dữ liệu người dùng theo chuẩn Apple'
                  : 'User data protection and Apple compliance',
              style: AppTypography.caption(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: const Icon(LucideIcons.externalLink, size: 16, color: AppColors.primaryLight),
            onTap: () {
              HapticHelper.light();
              UrlLauncherHelper.openPrivacyPolicy();
            },
          ),
          _buildDivider(isDark),
          ListTile(
            leading: const Icon(LucideIcons.fileText, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Thỏa thuận người dùng (EULA - Apple 1.2)' : 'EULA & Community Standards',
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              isVi
                  ? 'Chính sách chống nội dung độc hại & quấy rối'
                  : 'Zero-tolerance policy against objectionable content',
              style: AppTypography.caption(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => EulaModal.show(context),
          ),
          _buildDivider(isDark),
          ListTile(
            leading: const Icon(LucideIcons.globe, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Yêu cầu xóa dữ liệu trực tuyến' : 'Online Account Deletion Portal',
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              isVi
                  ? 'Cổng web xóa vĩnh viễn dữ liệu theo Apple Guideline 5.1.1(v)'
                  : 'Web-based permanent account deletion portal',
              style: AppTypography.caption(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            trailing: const Icon(LucideIcons.externalLink, size: 16, color: AppColors.primaryLight),
            onTap: () {
              HapticHelper.light();
              UrlLauncherHelper.openDeleteAccount();
            },
          ),
        ],
      ),
    );
  }

  // --- 5. Support & Direct Contact Section ---
  Widget _buildSupportCard(BuildContext context, bool isDark, bool isVi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.mail, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Email hỗ trợ kỹ thuật' : 'Technical Support Email',
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              '${AppInfo.supportEmail}\n${isVi ? 'Cam kết giải quyết & phản hồi trong 24 giờ' : '24-hour response & content report resolution'}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryLight,
                height: 1.4,
              ),
            ),
            trailing: const Icon(LucideIcons.externalLink, size: 16, color: AppColors.primaryLight),
            onTap: () {
              HapticHelper.light();
              UrlLauncherHelper.openSupport(
                subject: isVi
                    ? '[HeartPearl] Yêu cầu hỗ trợ kỹ thuật & An toàn'
                    : '[HeartPearl] Technical Support & Safety Request',
              );
            },
          ),
          _buildDivider(isDark),
          ListTile(
            leading: const Icon(LucideIcons.globe2, color: AppColors.primaryLight),
            title: Text(
              isVi ? 'Cổng thông tin chính thức' : 'Official Web Portal',
              style: AppTypography.bodyBold(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              AppInfo.webPortal,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryLight,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primaryLight,
              ),
            ),
            trailing: const Icon(LucideIcons.externalLink, size: 16, color: AppColors.primaryLight),
            onTap: () {
              HapticHelper.light();
              UrlLauncherHelper.openWebPortal();
            },
          ),
        ],
      ),
    );
  }

  // --- 6. Account Management Section (Apple Guideline 5.1.1(v)) ---
  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isVi,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        leading: const Icon(LucideIcons.trash2, color: AppColors.error),
        title: Text(
          isVi ? 'Xóa tài khoản vĩnh viễn' : 'Delete Account Permanently',
          style: AppTypography.bodyBold(color: AppColors.error),
        ),
        subtitle: Text(
          isVi
              ? 'Xóa toàn bộ ảnh, video, bạn bè và dữ liệu (Apple Guideline 5.1.1(v))'
              : 'Permanently purge all photos, media & account data',
          style: AppTypography.caption(
            color: AppColors.error.withValues(alpha: 0.75),
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.error),
        onTap: () => _showDeleteDialog(context, ref, isDark, isVi),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      height: 1,
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isVi,
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
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
                  Expanded(
                    child: Text(
                      isVi ? 'Xóa tài khoản vĩnh viễn' : 'Permanently Delete Account',
                      style: const TextStyle(
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
                    Text(
                      isVi
                          ? 'Hành động này KHÔNG THỂ HOÀN TÁC. Toàn bộ dữ liệu của bạn trên HeartPearl sẽ bị xóa sạch khỏi hệ thống máy chủ, bao gồm:'
                          : 'This action CANNOT BE UNDONE. All your data on HeartPearl will be permanently erased from our servers, including:',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildWarningBullet(
                      isVi
                          ? 'Tất cả ảnh và video bạn đã chụp và gửi đi.'
                          : 'All photos and videos you have captured and sent.',
                      isDark,
                    ),
                    _buildWarningBullet(
                      isVi
                          ? 'Danh sách bạn bè và toàn bộ lời mời kết bạn.'
                          : 'Your friends list and all pending friend requests.',
                      isDark,
                    ),
                    _buildWarningBullet(
                      isVi
                          ? 'Toàn bộ tin nhắn và lịch sử trò chuyện.'
                          : 'All chat messages and conversations.',
                      isDark,
                    ),
                    _buildWarningBullet(
                      isVi
                          ? 'Tài khoản đăng nhập và dữ liệu tiện ích Home Widget.'
                          : 'Login credentials and Home Widget cached data.',
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isVi
                          ? 'Hoặc yêu cầu xóa tài khoản trực tuyến tại:'
                          : 'Or request online deletion at:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                                AppInfo.deleteAccountUrl,
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
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    isVi ? 'Hủy bỏ' : 'Cancel',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setState(() {
                            isDeleting = true;
                            errorText = null;
                          });
                          try {
                            await ref.read(authServiceProvider).deleteAccount();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          } catch (e) {
                            setState(() {
                              isDeleting = false;
                              errorText = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isVi ? 'Xác nhận xóa vĩnh viễn' : 'Delete Forever'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWarningBullet(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
