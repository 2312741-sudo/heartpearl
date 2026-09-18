import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/photo_model.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/settings_provider.dart';

class ReportContentSheet extends ConsumerStatefulWidget {
  final PhotoModel photo;

  const ReportContentSheet({super.key, required this.photo});

  static Future<bool?> show(BuildContext context, {required PhotoModel photo}) {
    HapticHelper.medium();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportContentSheet(photo: photo),
    );
  }

  @override
  ConsumerState<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends ConsumerState<ReportContentSheet> {
  final _noteController = TextEditingController();
  String _reason = 'inappropriate_content';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final lang = ref.read(settingsProvider).language;

    try {
      await ref.read(friendServiceProvider).reportPhoto(
        photoId: widget.photo.id,
        targetUid: widget.photo.senderId,
        reason: _reason,
        note: _noteController.text,
      );
      if (!mounted) return;
      HapticHelper.success();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'vi'
                ? 'Đã gửi báo cáo khoảnh khắc. Đội ngũ kiểm duyệt sẽ xử lý trong vòng 24 giờ.'
                : 'Report submitted. Our moderation team will take action within 24 hours.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('safety_error', lang: lang)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = lang == 'vi';

    final senderName = widget.photo.senderUser?.displayName ??
        widget.photo.senderUser?.username ??
        'Người dùng';

    final reasons = <String, String>{
      'inappropriate_content': isVi
          ? 'Nội dung khiêu dâm / Không phù hợp'
          : 'Nudity / Inappropriate Content',
      'violence': isVi ? 'Bạo lực / Nguy hiểm' : 'Violence / Dangerous',
      'harassment': isVi ? 'Quấy rối / Xúc phạm' : 'Harassment / Bullying',
      'spam': isVi ? 'Spam / Giả mạo' : 'Spam / Scam',
      'other': isVi ? 'Lý do khác' : 'Other',
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius2Xl),
        ),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: EdgeInsets.only(
        left: AppDimens.spaceLg,
        right: AppDimens.spaceLg,
        top: AppDimens.spaceMd,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.spaceLg,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // Title & Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.flag,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tr('safety_report_photo', lang: lang),
                          style: AppTypography.h3(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'Từ: $senderName',
                          style: AppTypography.caption(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.spaceBase),

              // 24h Commitment Notice Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      color: AppColors.primaryLight,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.tr('safety_report_24h_notice', lang: lang),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimens.spaceBase),

              // Reason dropdown
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('safety_report_reason', lang: lang),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                ),
                items: reasons.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) setState(() => _reason = value);
                      },
              ),

              const SizedBox(height: AppDimens.spaceBase),

              // Note text field
              TextField(
                controller: _noteController,
                enabled: !_isSubmitting,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('safety_report_note', lang: lang),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                ),
              ),

              const SizedBox(height: AppDimens.spaceBase),

              // Submit Button
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        AppStrings.tr('safety_report_submit', lang: lang),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
