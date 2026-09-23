import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/haptic_helper.dart';
import '../../core/utils/url_launcher_helper.dart';
import '../../providers/settings_provider.dart';

class EulaModal extends ConsumerWidget {
  final VoidCallback? onAgree;

  const EulaModal({super.key, this.onAgree});

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onAgree,
  }) {
    HapticHelper.light();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EulaModal(onAgree: onAgree),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = lang == 'vi';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius2Xl),
        ),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
              vertical: AppDimens.spaceSm,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.shieldAlert,
                    color: AppColors.primaryLight,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr('eula_title', lang: lang),
                        style: AppTypography.h3(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        isVi
                            ? 'Tiêu chuẩn cộng đồng & An toàn nội dung'
                            : 'Community Standards & Content Safety',
                        style: AppTypography.caption(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Zero Tolerance Banner (Apple Guideline 1.2 Mandatory)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimens.spaceBase),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.alertOctagon,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isVi
                                  ? 'CHÍNH SÁCH KHÔNG KHOAN NHƯỢNG (ZERO TOLERANCE)'
                                  : 'ZERO TOLERANCE POLICY',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isVi
                              ? 'HeartPearl tuyệt đối KHÔNG KHOAN NHƯỢNG đối với bất kỳ nội dung phản cảm hoặc người dùng có hành vi lạm dụng nào. Mọi hình thức khiêu dâm, bạo lực, quấy rối, ngôn từ thù địch, xúc phạm đều bị nghiêm cấm hoàn toàn.'
                              : 'HeartPearl has ZERO TOLERANCE for objectionable content or abusive users. Any pornography, violence, harassment, hate speech, or offensive content is strictly prohibited.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceLg),

                  // 2. 24-Hour Moderation Commitment
                  _buildSection(
                    icon: LucideIcons.clock,
                    title: isVi
                        ? '1. Cam kết Xử lý trong vòng 24 giờ (24-Hour Moderation)'
                        : '1. 24-Hour Moderation Commitment',
                    body: isVi
                        ? 'Đội ngũ kiểm duyệt HeartPearl cam kết xử lý tất cả các báo cáo vi phạm trong vòng 24 giờ. Nội dung vi phạm sẽ bị gỡ bỏ ngay lập tức và tài khoản người dùng vi phạm sẽ bị khóa vĩnh viễn khỏi nền tảng.'
                        : 'HeartPearl moderation team commits to act on objectionable content reports within 24 hours by removing the offending content and ejecting/banning the offending user.',
                    isDark: isDark,
                  ),

                  // 3. User Reporting (Flagging) Mechanism
                  _buildSection(
                    icon: LucideIcons.flag,
                    title: isVi
                        ? '2. Cơ chế Báo cáo (Flagging)'
                        : '2. Reporting (Flagging) Mechanism',
                    body: isVi
                        ? 'Bạn có thể báo cáo (flag) bất kỳ khoảnh khắc (ảnh/video) hoặc tin nhắn nào không phù hợp bằng cách bấm vào biểu tượng ba chấm hoặc biểu tượng lá cờ. Báo cáo sẽ được chuyển trực tiếp đến hệ thống kiểm duyệt để xử lý khẩn cấp.'
                        : 'Users can flag any objectionable photo, video, or chat message by tapping the three-dot or flag button. Reports are immediately routed to our moderation queue for urgent action.',
                    isDark: isDark,
                  ),

                  // 4. Instant Blocking & Feed Removal
                  _buildSection(
                    icon: LucideIcons.userX,
                    title: isVi
                        ? '3. Cơ chế Chặn & Gỡ nội dung tức thì (Instant Blocking)'
                        : '3. Instant Blocking & Feed Removal',
                    body: isVi
                        ? 'Bạn có quyền chặn bất kỳ người dùng nào bất kỳ lúc nào. Khi bạn chặn một người dùng, toàn bộ nội dung của họ sẽ bị gỡ bỏ ngay lập tức khỏi bảng tin và tiện ích màn hình của bạn. Đồng thời, hệ thống sẽ tự động gửi thông báo vi phạm tới nhà phát triển.'
                        : 'Users can block abusive users anytime. When blocked, the offending user’s content is instantly removed from your feed and widgets, and an incident report is automatically dispatched to the developer.',
                    isDark: isDark,
                  ),

                  // 5. Automated Content Filtering
                  _buildSection(
                    icon: LucideIcons.filter,
                    title: isVi
                        ? '4. Bộ lọc Nội dung Tự động'
                        : '4. Automated Content Filtering',
                    body: isVi
                        ? 'HeartPearl tích hợp bộ lọc từ ngữ phản cảm và kiểm duyệt tự động để ngăn chặn các nội dung độc hại trước khi được truyền tải.'
                        : 'HeartPearl employs automated content filters and text moderation algorithms to prevent objectionable material before it is shared.',
                    isDark: isDark,
                  ),

                  // 5. Account Deletion Rights (Apple Guideline 5.1.1(v))
                  _buildSection(
                    icon: LucideIcons.trash2,
                    title: isVi
                        ? '5. Quyền Xóa Tài khoản & Dữ liệu (Apple Guideline 5.1.1(v))'
                        : '5. Account Deletion Rights (Guideline 5.1.1(v))',
                    body: isVi
                        ? 'Bạn có quyền xóa vĩnh viễn tài khoản và toàn bộ dữ liệu (ảnh, video, tin nhắn, bạn bè) bất cứ lúc nào trực tiếp trong phần Cài đặt Hồ sơ, hoặc thông qua trang web hỗ trợ:'
                        : 'You have full rights to permanently delete your account and all associated data anytime directly in Profile Settings, or via our web portal:',
                    linkUrl: UrlLauncherHelper.deleteAccountUrl,
                    isDark: isDark,
                  ),

                  const SizedBox(height: AppDimens.spaceLg),
                ],
              ),
            ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticHelper.medium();
                    Navigator.of(context).pop(true);
                    onAgree?.call();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusLg,
                      ),
                    ),
                  ),
                  child: Text(
                    isVi ? 'Tôi đồng ý & Tiếp tục' : 'I Agree & Continue',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String body,
    required bool isDark,
    String? linkUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceBase),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.45,
                  ),
                ),
                if (linkUrl != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      HapticHelper.light();
                      UrlLauncherHelper.openUrl(linkUrl);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              linkUrl,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.primaryLight,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primaryLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            LucideIcons.externalLink,
                            size: 13,
                            color: AppColors.primaryLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
