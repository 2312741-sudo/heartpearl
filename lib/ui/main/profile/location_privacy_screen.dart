import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/user_model.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/location_sharing_duration.dart';
import '../../common/user_avatar.dart';

class LocationPrivacyScreen extends ConsumerStatefulWidget {
  const LocationPrivacyScreen({super.key});

  @override
  ConsumerState<LocationPrivacyScreen> createState() =>
      _LocationPrivacyScreenState();
}

class _LocationPrivacyScreenState
    extends ConsumerState<LocationPrivacyScreen> {
  bool _savingSharing = false;
  final Set<String> _savingViewers = {};

  Future<void> _changeSharing(bool enabled) async {
    if (_savingSharing) return;
    final lang = ref.read(settingsProvider).language;
    if (enabled) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppStrings.tr('location_disclosure_title', lang: lang)),
          content: Text(
            AppStrings.tr('location_disclosure_body', lang: lang),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.tr('safety_cancel', lang: lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppStrings.tr('location_allow', lang: lang)),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }

    setState(() => _savingSharing = true);
    try {
      await ref.read(locationServiceProvider).setSharingEnabled(enabled);
      HapticHelper.success();
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _savingSharing = false);
    }
  }

  Future<void> _changeViewer({
    required UserModel friend,
    required bool enabled,
    required List<UserModel> friends,
    required Set<String> selected,
    required bool sharing,
  }) async {
    if (_savingViewers.contains(friend.uid)) return;
    final next = {...selected};
    if (enabled) {
      next.add(friend.uid);
    } else {
      next.remove(friend.uid);
    }

    setState(() => _savingViewers.add(friend.uid));
    try {
      if (next.isEmpty && sharing) {
        // Empty allowedViewers deliberately means all friends. Turning off the
        // final viewer must therefore enter ghost mode instead of saving [].
        await ref.read(locationServiceProvider).setSharingEnabled(false);
      } else {
        await ref
            .read(locationServiceProvider)
            .setAllowedViewers(next.toList(growable: false));
      }
      HapticHelper.selection();
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _savingViewers.remove(friend.uid));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final ownLocation = ref.watch(ownLocationProvider).value;
    final friendsAsync = ref.watch(friendsListProvider);
    final sharing = ownLocation?.isSharing == true;
    final isLive = ownLocation?.isLive == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('location_privacy_title', lang: lang)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceBase),
        children: [
          // Manual Check-in Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceBase),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPinCheck, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.tr('location_disclosure_title', lang: lang),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.tr('location_disclosure_body', lang: lang),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _savingSharing
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _savingSharing = true);
                              try {
                                await ref.read(locationServiceProvider).checkIn();
                                HapticHelper.success();
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppStrings.tr('location_checkin_success', lang: lang),
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) _showError(e.toString());
                              } finally {
                                if (mounted) setState(() => _savingSharing = false);
                              }
                            },
                      icon: const Icon(LucideIcons.mapPin, size: 18),
                      label: Text(AppStrings.tr('location_checkin_btn', lang: lang)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),

          // Live Location Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceBase),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.radio,
                        color: isLive ? Colors.red : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.tr('live_section_title', lang: lang),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '● LIVE',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.tr('live_share_subtitle', lang: lang),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (isLive) ...[
                    // Currently live: show stop button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(AppStrings.tr('live_stop_title', lang: lang)),
                              content: Text(AppStrings.tr('live_stop_body', lang: lang)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(AppStrings.tr('safety_cancel', lang: lang)),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(AppStrings.tr('live_stop_btn', lang: lang)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !mounted) return;
                          await ref.read(locationServiceProvider).stopLiveSharing(clearFirestore: true);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(AppStrings.tr('live_stopped', lang: lang))),
                            );
                          }
                        },
                        icon: const Icon(LucideIcons.squareX, size: 18),
                        label: Text(AppStrings.tr('live_stop_btn', lang: lang)),
                      ),
                    ),
                  ] else ...[
                    // Not live: show duration options
                    for (final dur in LocationSharingDuration.values) ...[
                      _LiveOptionTile(duration: dur, lang: lang),
                      if (dur != LocationSharingDuration.values.last)
                        const Divider(height: 1),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                sharing ? LucideIcons.mapPin : LucideIcons.ghost,
                color: sharing ? Colors.green : AppColors.primaryLight,
              ),
              title: Text(
                AppStrings.tr('location_ghost_mode', lang: lang),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                sharing
                    ? AppStrings.tr('location_sharing_on', lang: lang)
                    : AppStrings.tr('location_sharing_off', lang: lang),
              ),
              value: !sharing,
              onChanged: _savingSharing
                  ? null
                  : (ghostMode) => _changeSharing(!ghostMode),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            child: Text(
              AppStrings.tr('location_viewers_explanation', lang: lang),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppDimens.spaceBase),
          Text(
            AppStrings.tr('location_allowed_viewers', lang: lang),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          friendsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (friends) {
              if (friends.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    AppStrings.tr('friends_empty', lang: lang),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final allowed = ownLocation?.allowedViewers ?? const <String>[];
              final selected = allowed.isEmpty
                  ? friends.map((friend) => friend.uid).toSet()
                  : allowed.toSet();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < friends.length; index++) ...[
                      SwitchListTile(
                        secondary: UserAvatar(
                          imageUrl: friends[index].avatarUrl,
                          name: friends[index].displayName,
                          size: 42,
                        ),
                        title: Text(friends[index].displayName),
                        subtitle: Text('@${friends[index].username}'),
                        value: selected.contains(friends[index].uid),
                        onChanged: _savingViewers.contains(friends[index].uid)
                            ? null
                            : (enabled) => _changeViewer(
                                friend: friends[index],
                                enabled: enabled,
                                friends: friends,
                                selected: selected,
                                sharing: sharing,
                              ),
                      ),
                      if (index < friends.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppDimens.spaceBase),
          ListTile(
            leading: const Icon(LucideIcons.shieldCheck),
            title: Text(AppStrings.tr('location_privacy_note', lang: lang)),
            subtitle: Text(AppStrings.tr('location_no_history', lang: lang)),
          ),
        ],
      ),
    );
  }
}

/// Compact tile for a single duration option inside the Live Location card.
class _LiveOptionTile extends ConsumerWidget {
  final LocationSharingDuration duration;
  final String lang;

  const _LiveOptionTile({required this.duration, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = switch (duration) {
      LocationSharingDuration.oneHour => (LucideIcons.clock, Colors.blue),
      LocationSharingDuration.untilEndOfDay => (LucideIcons.sunset, Colors.orange),
      LocationSharingDuration.unlimited => (LucideIcons.infinity, AppColors.primary),
    };

    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(duration.label(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(duration.subtitle(lang), style: const TextStyle(fontSize: 12)),
      trailing: Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: () async {
        HapticHelper.selection();
        // Unlimited requires explicit consent dialog.
        if (duration == LocationSharingDuration.unlimited) {
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
          if (confirmed != true || !context.mounted) return;
        }
        try {
          await ref.read(locationServiceProvider).startLiveSharing(duration);
          HapticHelper.success();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.tr('live_started', lang: lang)),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
            );
          }
        }
      },
    );
  }
}
