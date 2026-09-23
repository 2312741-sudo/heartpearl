import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../common/app_text_field.dart';
import '../../common/gradient_button.dart';
import '../../common/user_avatar.dart';
import '../chat/chat_room_screen.dart';
import 'report_user_sheet.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const FriendsScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<UserModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    setState(() => _isSearching = true);

    try {
      final results = await ref
          .read(friendServiceProvider)
          .searchUserByUsername(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results
            .where(
              (result) =>
                  result.uid != user.uid &&
                  !user.blockedUsers.contains(result.uid),
            )
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(String toUid) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final lang = ref.read(settingsProvider).language;

    HapticHelper.medium();
    try {
      await ref
          .read(friendServiceProvider)
          .sendFriendRequest(fromUid: user.uid, toUid: toUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi lời mời kết bạn!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr('safety_interaction_blocked', lang: lang),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmBlockFriend(UserModel friend) async {
    final lang = ref.read(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${AppStrings.tr('safety_menu_block', lang: lang)} ${friend.displayName}?'),
        content: Text(
          AppStrings.tr('safety_block_instant_notice', lang: lang),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.tr('safety_cancel', lang: lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.tr('safety_confirm', lang: lang)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(friendServiceProvider).blockUser(friend.uid);
      HapticHelper.success();
      if (!mounted) return;
      ref.invalidate(userProfileProvider);
      ref.invalidate(friendsListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('safety_block_success', lang: lang)),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendsAsync = ref.watch(friendsListProvider);
    final requestsAsync = ref.watch(friendRequestsProvider);

    final requestsCount = requestsAsync.value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  LucideIcons.arrowLeft,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          AppStrings.tr('friends_title', lang: lang),
          style: AppTypography.h2(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: isDark
              ? AppColors.darkTextMuted
              : AppColors.lightTextMuted,
          labelStyle: AppTypography.bodyBold(),
          tabs: [
            Tab(text: AppStrings.tr('friends_tab_friends', lang: lang)),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppStrings.tr('friends_tab_requests', lang: lang)),
                  if (requestsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        requestsCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: AppStrings.tr('friends_tab_search', lang: lang)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Friends List Tab
          friendsAsync.when(
            data: (friends) {
              if (friends.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.users,
                        size: 56,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: AppDimens.spaceBase),
                      Text(
                        AppStrings.tr('friends_empty', lang: lang),
                        style: AppTypography.h3(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppDimens.spaceBase),
                itemCount: friends.length,
                separatorBuilder: (context, index) => Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  height: 1,
                  indent: 68,
                ),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    leading: UserAvatar(
                      imageUrl: friend.avatarUrl,
                      name: friend.displayName,
                      size: 48,
                    ),
                    title: Text(
                      friend.displayName,
                      style: AppTypography.bodyBold(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '@${friend.username}',
                      style: AppTypography.caption(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(LucideIcons.moreVertical, size: 20),
                      onSelected: (val) {
                        if (val == 'chat') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(
                                friendId: friend.uid,
                                friendName: friend.displayName,
                                friendAvatar: friend.avatarUrl,
                              ),
                            ),
                          );
                        } else if (val == 'report') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ReportUserSheet(
                              targetUid: friend.uid,
                              targetName: friend.displayName,
                            ),
                          );
                        } else if (val == 'block') {
                          _confirmBlockFriend(friend);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'chat',
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.messageCircle,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              const SizedBox(width: 10),
                              const Text('Nhắn tin'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.flag,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 10),
                              Text(AppStrings.tr('safety_menu_report', lang: lang)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.userX,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppStrings.tr('safety_menu_block', lang: lang),
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, stack) => Center(child: Text('Lỗi: $err')),
          ),

          // 2. Friend Requests Tab
          requestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.mail,
                        size: 56,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: AppDimens.spaceBase),
                      Text(
                        'Không có lời mời nào',
                        style: AppTypography.h3(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppDimens.spaceBase),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final senderName = req.fromUser?.displayName ?? 'Người dùng';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    padding: const EdgeInsets.all(AppDimens.spaceBase),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          imageUrl: req.fromUser?.avatarUrl,
                          name: senderName,
                          size: 46,
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: AppTypography.bodyBold(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                '@${req.fromUser?.username ?? "user"} muốn kết bạn',
                                style: AppTypography.caption(
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Actions: Accept & Decline
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                LucideIcons.check,
                                color: AppColors.success,
                              ),
                              onPressed: () async {
                                HapticHelper.medium();
                                await ref
                                    .read(friendServiceProvider)
                                    .acceptFriendRequest(
                                      requestId: req.id,
                                      fromUid: req.from,
                                      toUid: req.to,
                                    );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.x,
                                color: AppColors.error,
                              ),
                              onPressed: () async {
                                HapticHelper.light();
                                await ref
                                    .read(friendServiceProvider)
                                    .rejectFriendRequest(req.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, stack) => Center(child: Text('Lỗi: $err')),
          ),

          // 3. Search Tab
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceBase),
            child: Column(
              children: [
                // Search Input
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _searchController,
                        hintText: AppStrings.tr(
                          'friends_search_placeholder',
                          lang: lang,
                        ),
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: 20,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                        onSubmitted: (_) => _handleSearch(),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    GradientButton(
                      text: 'Tìm',
                      width: 76,
                      height: 52,
                      isLoading: _isSearching,
                      onPressed: _handleSearch,
                    ),
                  ],
                ),

                const SizedBox(height: AppDimens.spaceBase),

                // Search Results
                Expanded(
                  child: _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'Nhập username để tìm kiếm bạn bè',
                            style: AppTypography.body(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppDimens.spaceSm),
                          itemBuilder: (context, index) {
                            final foundUser = _searchResults[index];

                            return Container(
                              padding: const EdgeInsets.all(AppDimens.spaceMd),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusLg,
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    imageUrl: foundUser.avatarUrl,
                                    name: foundUser.displayName,
                                    size: 44,
                                  ),
                                  const SizedBox(width: AppDimens.spaceMd),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          foundUser.displayName,
                                          style: AppTypography.bodyBold(
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          '@${foundUser.username}',
                                          style: AppTypography.caption(
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GradientButton(
                                    text: AppStrings.tr(
                                      'friends_add_btn',
                                      lang: lang,
                                    ),
                                    width: 104,
                                    height: 38,
                                    onPressed: () =>
                                        _sendRequest(foundUser.uid),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
