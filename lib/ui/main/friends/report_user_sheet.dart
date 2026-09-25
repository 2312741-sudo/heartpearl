import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/settings_provider.dart';

class ReportUserSheet extends ConsumerStatefulWidget {
  final String targetUid;
  final String targetName;

  const ReportUserSheet({
    super.key,
    required this.targetUid,
    required this.targetName,
  });

  @override
  ConsumerState<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends ConsumerState<ReportUserSheet> {
  final _noteController = TextEditingController();
  String _reason = 'spam';
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
      await ref
          .read(friendServiceProvider)
          .reportUser(
            targetUid: widget.targetUid,
            reason: _reason,
            note: _noteController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('safety_report_success', lang: lang)),
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
    final reasons = <String, String>{
      'spam': AppStrings.tr('safety_report_spam', lang: lang),
      'harassment': AppStrings.tr('safety_report_harassment', lang: lang),
      'inappropriate_content': AppStrings.tr(
        'safety_report_inappropriate',
        lang: lang,
      ),
      'other': AppStrings.tr('safety_report_other', lang: lang),
    };

    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                AppStrings.tr('safety_report_title', lang: lang),
                style: AppTypography.h2(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                widget.targetName,
                style: AppTypography.body(color: AppColors.primaryLight),
              ),
              const SizedBox(height: AppDimens.spaceLg),
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
                        child: Text(entry.value),
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
              TextField(
                controller: _noteController,
                enabled: !_isSubmitting,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('safety_report_note', lang: lang),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                    : Text(AppStrings.tr('safety_report_submit', lang: lang)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
