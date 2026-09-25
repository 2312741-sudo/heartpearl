import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/user_model.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/skeleton_loader.dart';
import '../../common/user_avatar.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final Set<String> _pendingUserIds = {};

  Future<void> _unblock(UserModel user) async {
    if (_pendingUserIds.contains(user.uid)) return;
    final lang = ref.read(settingsProvider).language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.tr('safety_menu_unblock', lang: lang)),
        content: Text(user.displayName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.tr('safety_cancel', lang: lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.tr('safety_confirm', lang: lang)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _pendingUserIds.add(user.uid));
    try {
      await ref.read(friendServiceProvider).unblockUser(user.uid);
      HapticHelper.success();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('safety_unblock_success', lang: lang)),
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
      if (mounted) setState(() => _pendingUserIds.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockedUsers = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('safety_manage_blocks', lang: lang)),
      ),
      body: blockedUsers.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.userRoundCheck,
                      size: 56,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(height: AppDimens.spaceBase),
                    Text(
                      AppStrings.tr('safety_blocked_empty', lang: lang),
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.spaceBase),
            itemCount: users.length,
            separatorBuilder: (_, _) => Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            itemBuilder: (context, index) {
              final user = users[index];
              final isPending = _pendingUserIds.contains(user.uid);
              return ListTile(
                leading: UserAvatar(
                  imageUrl: user.avatarUrl,
                  name: user.displayName,
                  size: 46,
                ),
                title: Text(user.displayName),
                subtitle: Text('@${user.username}'),
                trailing: TextButton(
                  onPressed: isPending ? null : () => _unblock(user),
                  child: isPending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppStrings.tr('safety_menu_unblock', lang: lang)),
                ),
              );
            },
          );
        },
        loading: () => const SkeletonListView(count: 3),
        error: (_, _) =>
            Center(child: Text(AppStrings.tr('safety_error', lang: lang))),
      ),
    );
  }
}
