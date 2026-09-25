import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/feed_provider.dart';
import '../../providers/location_provider.dart';
import '../common/app_badge.dart';
import '../common/frosted_container.dart';
import 'history/history_screen.dart';
import 'home/camera_screen.dart';
import 'inbox/inbox_screen.dart';
import 'map/map_screen.dart';
import 'profile/profile_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _cameraTrigger = 0;
  StreamSubscription<Uri?>? _widgetSub;
  DateTime? _lastWidgetUriTime;
  String? _lastWidgetUriStr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Register tab-switch callback so notification handler can jump to any tab
    // without pushing a new route (avoids Navigator stack pollution).
    AppNavigation.registerTabSwitchCallback((index) {
      if (mounted) setState(() => _currentIndex = index);
    });
    _initWidgetLaunch();
  }

  void _initWidgetLaunch() {
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (uri != null) _handleWidgetUri(uri);
      });
      _widgetSub = HomeWidget.widgetClicked.listen((uri) {
        if (uri != null) _handleWidgetUri(uri);
      });
    } catch (_) {}
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    if (uri.scheme == 'heartpearl' ||
        uri.host == 'map' ||
        uri.path.contains('map') ||
        uri.host == 'camera' ||
        uri.path.contains('camera')) {
      _handleWidgetUri(uri);
      return true;
    }
    return super.didPushRouteInformation(routeInformation);
  }

  void _handleWidgetUri(Uri uri) {
    final now = DateTime.now();
    final uriStr = uri.toString();
    if (_lastWidgetUriTime != null &&
        now.difference(_lastWidgetUriTime!) < const Duration(milliseconds: 750) &&
        _lastWidgetUriStr == uriStr) {
      return;
    }
    _lastWidgetUriTime = now;
    _lastWidgetUriStr = uriStr;

    // Pop any open sheets, dialogs, or subroutes back to root so tabs don't stack
    AppNavigation.popToRoot();

    if (uri.host == 'map' || uri.path.contains('map')) {
      if (mounted) {
        setState(() => _currentIndex = 2);
      }
    } else if (uri.host == 'camera' || uri.path.contains('camera')) {
      if (mounted) {
        setState(() {
          _currentIndex = 0;
          _cameraTrigger++;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused;
    ref.read(locationServiceProvider).setBackgroundMode(background);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(locationTrackingBootstrapProvider);
    final unreadPhotos = ref.watch(unreadPhotosCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CameraScreen(
            isActive: _currentIndex == 0,
            cameraTrigger: _cameraTrigger,
          ),
          const InboxScreen(),
          const MapScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceSm,
          ),
          child: FrostedContainer(
            borderRadius: AppDimens.radiusFull,
            height: 64,
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.85)
                : AppColors.lightSurface.withValues(alpha: 0.9),
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: LucideIcons.camera,
                  hasHeart: true,
                ),
                _buildNavItem(
                  index: 1,
                  icon: LucideIcons.image,
                  badgeCount: unreadPhotos,
                ),
                _buildNavItem(
                  index: 2,
                  icon: LucideIcons.mapPinned,
                ),
                _buildNavItem(
                  index: 3,
                  icon: LucideIcons.calendarHeart,
                ),
                _buildNavItem(
                  index: 4,
                  icon: LucideIcons.userCircle2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    bool hasHeart = false,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticHelper.selection();
        setState(() => _currentIndex = index);
      },
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: isSelected ? 26 : 22,
                      color: isSelected
                          ? AppColors.primaryLight
                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                    if (hasHeart)
                      Positioned(
                        bottom: -2,
                        right: -4,
                        child: Icon(
                          LucideIcons.heart,
                          size: 10,
                          color: isSelected ? AppColors.primaryLight : AppColors.darkTextMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 5 : 0,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                top: 4,
                right: 2,
                child: AppBadge(count: badgeCount),
              ),
          ],
        ),
      ),
    );
  }
}
