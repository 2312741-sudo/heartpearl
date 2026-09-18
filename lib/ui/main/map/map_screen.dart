import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/location_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/location_provider.dart';
import '../profile/location_privacy_screen.dart';

enum MapStyle { dark, street, satellite }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  static const _fallbackCenter = LatLng(10.7769, 106.7009); // TP. Hồ Chí Minh
  static const _animationDuration = Duration(milliseconds: 1200);

  final Map<String, LatLng> _displayPositions = {};
  final Map<String, LatLng> _startPositions = {};
  final Map<String, LatLng> _targetPositions = {};
  final Map<String, FriendLocation> _friendData = {};

  final MapController _mapController = MapController();
  Timer? _animationTimer;
  DateTime? _animationStartedAt;

  LatLng? _myPosition;
  double? _myAccuracy;
  StreamSubscription<Position>? _positionSub;

  bool _hasCentered = false;
  bool _isLocating = false;
  MapStyle? _userMapStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initUserLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationTimer?.cancel();
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Immediately cancel local GPS stream when app is not in foreground
      _positionSub?.cancel();
      _positionSub = null;
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) {
        _initUserLocation();
      }
    }
  }

  Future<void> _initUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      // 1. Get cached position fast
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        setState(() {
          _myPosition = LatLng(lastPos.latitude, lastPos.longitude);
          _myAccuracy = lastPos.accuracy;
        });
        _centerOnMeOnce();
      }

      // 2. Query fresh GPS position
      final currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _myPosition = LatLng(currentPos.latitude, currentPos.longitude);
          _myAccuracy = currentPos.accuracy;
        });
        _centerOnMeOnce();
      }

      // 3. Listen to live position changes while actively viewing the map
      _positionSub?.cancel();
      final streamSettings = Platform.isIOS
          ? AppleSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              pauseLocationUpdatesAutomatically: true,
              showBackgroundLocationIndicator: false,
              allowBackgroundLocationUpdates: false,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            );

      _positionSub = Geolocator.getPositionStream(
        locationSettings: streamSettings,
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _myPosition = LatLng(pos.latitude, pos.longitude);
            _myAccuracy = pos.accuracy;
          });
        }
      });
    } catch (_) {}
  }

  void _centerOnMeOnce() {
    if (!_hasCentered && _myPosition != null) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(_myPosition!, 15.0);
        } catch (_) {}
      });
    }
  }

  void _recenterOnMe() async {
    HapticHelper.light();
    if (_myPosition != null) {
      _mapController.move(_myPosition!, 16.0);
      return;
    }

    setState(() => _isLocating = true);
    await _initUserLocation();
    if (mounted) {
      setState(() => _isLocating = false);
      if (_myPosition != null) {
        _mapController.move(_myPosition!, 16.0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lấy được vị trí hiện tại. Hãy kiểm tra GPS.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _zoomIn() {
    HapticHelper.selection();
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(3.0, 18.5));
  }

  void _zoomOut() {
    HapticHelper.selection();
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(3.0, 18.5));
  }

  void _showMapStyleSheet() {
    HapticHelper.selection();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceBase,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kiểu bản đồ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(LucideIcons.moon),
                title: const Text('Giao diện tối (Dark Mode)'),
                trailing: (_userMapStyle == MapStyle.dark ||
                        (_userMapStyle == null && isDark))
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _userMapStyle = MapStyle.dark);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.map),
                title: const Text('Đường phố (Google Maps)'),
                trailing: (_userMapStyle == MapStyle.street ||
                        (_userMapStyle == null && !isDark))
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _userMapStyle = MapStyle.street);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.satellite),
                title: const Text('Ảnh vệ tinh (Satellite)'),
                trailing: _userMapStyle == MapStyle.satellite
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _userMapStyle = MapStyle.satellite);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _acceptLocations(List<FriendLocation> locations) {
    final nextIds = locations.map((item) => item.friend.uid).toSet();
    _friendData.removeWhere((uid, _) => !nextIds.contains(uid));
    _displayPositions.removeWhere((uid, _) => !nextIds.contains(uid));
    _targetPositions.removeWhere((uid, _) => !nextIds.contains(uid));

    for (final item in locations) {
      final uid = item.friend.uid;
      final target = LatLng(item.location.lat, item.location.lng);
      _friendData[uid] = item;
      _startPositions[uid] = _displayPositions[uid] ?? target;
      _targetPositions[uid] = target;
    }

    if (locations.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    // Center on friends only if we don't have our own position and haven't centered yet
    if (!_hasCentered && _myPosition == null) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(
            LatLng(locations.first.location.lat, locations.first.location.lng),
            14.0,
          );
        } catch (_) {}
      });
    }

    _animationStartedAt = DateTime.now();
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final startedAt = _animationStartedAt;
      if (startedAt == null || !mounted) return;
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final rawProgress = elapsed / _animationDuration.inMilliseconds;
      final progress = Curves.easeOutCubic.transform(rawProgress.clamp(0, 1));
      setState(() {
        for (final entry in _targetPositions.entries) {
          final start = _startPositions[entry.key] ?? entry.value;
          _displayPositions[entry.key] = LatLng(
            _lerp(start.latitude, entry.value.latitude, progress),
            _lerp(start.longitude, entry.value.longitude, progress),
          );
        }
      });
      if (rawProgress >= 1) timer.cancel();
    });
  }

  double _lerp(double start, double end, double progress) =>
      start + (end - start) * progress;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<FriendLocation>>>(friendLocationsProvider, (
      previous,
      next,
    ) {
      next.whenData(_acceptLocations);
    });

    final locationsAsync = ref.watch(friendLocationsProvider);
    final items = locationsAsync.value ?? const <FriendLocation>[];
    final isLoadingFriends = locationsAsync.isLoading && items.isEmpty;

    final ownLocation = ref.watch(ownLocationProvider).value;
    final userProfile = ref.watch(userProfileProvider).value;
    final status = ref.watch(locationTrackingStatusProvider).value;
    final isSharing = ownLocation?.isSharing == true;

    // Use own location from provider if local GPS hasn't updated yet
    if (_myPosition == null && ownLocation != null && ownLocation.hasCoordinate) {
      _myPosition = LatLng(ownLocation.lat, ownLocation.lng);
      _centerOnMeOnce();
    }

    final initialTarget = _myPosition ??
        (items.isNotEmpty
            ? LatLng(items.first.location.lat, items.first.location.lng)
            : _fallbackCenter);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeStyle = _userMapStyle ?? (isDark ? MapStyle.dark : MapStyle.street);
    final isDarkMode = activeStyle == MapStyle.dark;

    final String urlTemplate = switch (activeStyle) {
      MapStyle.dark || MapStyle.street =>
        'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      MapStyle.satellite =>
        'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    };
    final String fallbackUrl = switch (activeStyle) {
      MapStyle.dark || MapStyle.street =>
        'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
      MapStyle.satellite =>
        'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    };

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Bản đồ bạn bè'),
        actions: [
          _LiveStatus(
            status: status,
            isSharing: isSharing,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LocationPrivacyScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cài đặt vị trí',
            icon: const Icon(LucideIcons.shieldCheck, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LocationPrivacyScreen(),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceXs),
        ],
      ),
      body: Stack(
        children: [
          // 1. Unconditional Base Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialTarget,
              initialZoom: 14.5,
              minZoom: 3.0,
              maxZoom: 18.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: urlTemplate,
                fallbackUrl: fallbackUrl,
                subdomains: const ['0', '1', '2', '3'],
                tileBuilder: isDarkMode ? darkModeTileBuilder : null,
                maxZoom: 20,
                userAgentPackageName: 'com.heartpearl.heartpearl',
                evictErrorTileStrategy: EvictErrorTileStrategy.none,
                errorTileCallback: (tile, error, stackTrace) {
                  // Gracefully suppress network/DNS errors when offline
                },
              ),

              // Own location accuracy circle
              if (_myPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _myPosition!,
                      radius: (_myAccuracy != null && _myAccuracy! > 0)
                          ? _myAccuracy!.clamp(15.0, 100.0)
                          : 25.0,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderColor: AppColors.primary.withValues(alpha: 0.45),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // Own Location Marker ("Bạn")
                  if (_myPosition != null)
                    Marker(
                      point: _myPosition!,
                      width: 76,
                      height: 92,
                      child: _OwnMarkerWidget(
                        user: userProfile,
                        isSharing: isSharing,
                        onTap: () => _showOwnDetails(userProfile, ownLocation),
                      ),
                    ),

                  // Friends' Markers
                  for (final item in items)
                    if (_displayPositions[item.friend.uid] case final position?)
                      Marker(
                        point: position,
                        width: 80,
                        height: 96,
                        child: _FriendMarkerWidget(
                          friend: item.friend,
                          location: item.location,
                          onTap: () => _showFriendDetails(item),
                        ),
                      ),
                ],
              ),
            ],
          ),

          // 2. Top Warning Banner when sharing is OFF
          if (!isSharing)
            Positioned(
              top: AppDimens.spaceSm,
              left: AppDimens.spaceBase,
              right: AppDimens.spaceBase,
              child: SafeArea(
                bottom: false,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? AppColors.darkSurface.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocationPrivacyScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.mapPinOff,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Chia sẻ vị trí đang tắt',
                                  style: AppTypography.caption(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Bật chia sẻ để bạn bè thấy bạn trên bản đồ.',
                                  style: AppTypography.caption(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Bật ngay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 3. Subtle empty friends indicator
          if (items.isEmpty && isSharing)
            Positioned(
              top: AppDimens.spaceSm,
              left: AppDimens.spaceLg,
              right: AppDimens.spaceLg,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    color: (isDark ? AppColors.darkSurface : Colors.white)
                        .withValues(alpha: 0.92),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLoadingFriends
                                ? LucideIcons.loader2
                                : LucideIcons.users,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLoadingFriends
                                ? 'Đang cập nhật vị trí bạn bè...'
                                : 'Chưa có bạn bè nào chia sẻ vị trí',
                            style: AppTypography.caption(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. Floating Zoom & Recenter Controls (Right Side)
          Positioned(
            right: AppDimens.spaceBase,
            bottom: items.isNotEmpty ? 112 : 36,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Map Style Switcher (Layers)
                  _FloatingMapButton(
                    icon: LucideIcons.layers,
                    onPressed: _showMapStyleSheet,
                  ),
                  const SizedBox(height: 8),

                  // Zoom In
                  _FloatingMapButton(
                    icon: LucideIcons.plus,
                    onPressed: _zoomIn,
                  ),
                  const SizedBox(height: 8),

                  // Zoom Out
                  _FloatingMapButton(
                    icon: LucideIcons.minus,
                    onPressed: _zoomOut,
                  ),
                  const SizedBox(height: 12),

                  // Re-center on Me
                  _FloatingMapButton(
                    icon: _isLocating
                        ? LucideIcons.loader2
                        : LucideIcons.locateFixed,
                    iconColor: AppColors.primary,
                    onPressed: _recenterOnMe,
                  ),
                ],
              ),
            ),
          ),

          // 5. Friends Horizontal Carousel (Bottom)
          if (items.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: SizedBox(
                  height: 92,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceBase,
                      vertical: AppDimens.spaceSm,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppDimens.spaceSm),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _FriendLocationCard(
                        item: item,
                        onTap: () {
                          HapticHelper.selection();
                          _mapController.move(
                            LatLng(item.location.lat, item.location.lng),
                            16.0,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showOwnDetails(UserModel? user, LocationModel? location) {
    HapticHelper.selection();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary,
                  backgroundImage: user?.avatarUrl != null &&
                          user!.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                      ? Text(
                          (user?.displayName.isNotEmpty == true)
                              ? user!.displayName[0].toUpperCase()
                              : 'B',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  '${user?.displayName ?? "Bạn"} (Vị trí của bạn)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  location?.isSharing == true
                      ? 'Đang chia sẻ trực tiếp với bạn bè'
                      : 'Đang ở chế độ riêng tư (không chia sẻ)',
                  style: TextStyle(
                    color: location?.isSharing == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (_myPosition != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: 'Tọa độ',
                      value:
                          '${_myPosition!.latitude.toStringAsFixed(4)}, ${_myPosition!.longitude.toStringAsFixed(4)}',
                      icon: LucideIcons.mapPin,
                    ),
                    _StatItem(
                      label: 'Độ chính xác',
                      value: _myAccuracy != null
                          ? '±${_myAccuracy!.round()} m'
                          : '±10 m',
                      icon: LucideIcons.locateFixed,
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LocationPrivacyScreen(),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.shieldCheck),
                label: const Text('Cài đặt chia sẻ vị trí'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFriendDetails(FriendLocation item) {
    HapticHelper.selection();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    item.friend.displayName.isNotEmpty
                        ? item.friend.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  item.friend.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  '${_movementLabel(item.location.speed)} · ${_relativeTime(item.location.timestamp)}',
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Độ chính xác',
                    value: '±${item.location.accuracy.round()} m',
                    icon: LucideIcons.locateFixed,
                  ),
                  _StatItem(
                    label: 'Trạng thái pin',
                    value: item.location.batteryLevel != null
                        ? '${item.location.batteryLevel}%'
                        : 'Không rõ',
                    icon: LucideIcons.batteryMedium,
                  ),
                  _StatItem(
                    label: 'Vận tốc',
                    value: item.location.speed > 0
                        ? '${(item.location.speed * 3.6).toStringAsFixed(1)} km/h'
                        : '0 km/h',
                    icon: LucideIcons.gauge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _mapController.move(
                    LatLng(item.location.lat, item.location.lng),
                    17.0,
                  );
                },
                icon: const Icon(LucideIcons.navigation),
                label: const Text('Phóng to vị trí này'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marker for current user ("Bạn")
class _OwnMarkerWidget extends StatelessWidget {
  final UserModel? user;
  final bool isSharing;
  final VoidCallback onTap;

  const _OwnMarkerWidget({
    required this.user,
    required this.isSharing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl;
    final displayName = user?.displayName ?? 'Bạn';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSharing ? AppColors.primary : Colors.grey,
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSharing ? AppColors.primary : Colors.black)
                      .withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _InitialAvatar(displayName: displayName),
                      errorWidget: (_, _, _) => _InitialAvatar(displayName: displayName),
                    )
                  : _InitialAvatar(displayName: displayName),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isSharing ? AppColors.primary : const Color(0xE62A2A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, size: 9, color: Colors.white),
                SizedBox(width: 3),
                Text(
                  'Bạn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

class _FriendMarkerWidget extends StatelessWidget {
  final UserModel friend;
  final LocationModel location;
  final VoidCallback onTap;

  const _FriendMarkerWidget({
    required this.friend,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stale = location.isStale();
    final avatarUrl = friend.avatarUrl;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: stale ? Colors.grey : AppColors.primary,
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (stale ? Colors.black26 : AppColors.primary)
                      .withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _InitialAvatar(displayName: friend.displayName),
                      errorWidget: (_, _, _) => _InitialAvatar(displayName: friend.displayName),
                    )
                  : _InitialAvatar(displayName: friend.displayName),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xE6180716),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_movementIcon(location.speed)} ${friend.displayName.split(' ').last}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: stale ? Colors.white70 : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String displayName;
  const _InitialAvatar({required this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isEmpty ? '?' : displayName[0].toUpperCase();
    return Container(
      color: const Color(0xFF5B244D),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppColors.primaryLight),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;

  const _FloatingMapButton({
    required this.icon,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: isDark
          ? AppColors.darkSurface.withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.92),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: iconColor ??
                (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }
}

String _movementIcon(double speed) {
  if (speed < 0.5) return '●';
  if (speed < 3) return '🚶';
  return '🚗';
}

String _movementLabel(double speed) {
  if (speed < 0.5) return 'Đang đứng yên';
  if (speed < 3) return 'Đang đi bộ';
  return 'Đang đi xe';
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.isNegative || difference.inSeconds < 45) return 'vừa cập nhật';
  if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
  if (difference.inHours < 24) return '${difference.inHours} giờ trước';
  return '${difference.inDays} ngày trước';
}

class _FriendLocationCard extends StatelessWidget {
  final FriendLocation item;
  final VoidCallback onTap;

  const _FriendLocationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stale = item.location.isStale();
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(
                item.location.speed < 0.5
                    ? LucideIcons.circleDot
                    : item.location.speed < 3
                    ? LucideIcons.personStanding
                    : LucideIcons.car,
                size: 20,
                color: stale ? Colors.grey : AppColors.primaryLight,
              ),
              const SizedBox(width: 9),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.friend.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_relativeTime(item.location.timestamp)} · ±${item.location.accuracy.round()} m',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: stale ? Colors.orange : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  final LocationTrackingStatus? status;
  final bool isSharing;
  final VoidCallback onTap;

  const _LiveStatus({
    required this.status,
    required this.isSharing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final live = isSharing && status == LocationTrackingStatus.tracking;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: (live ? Colors.green : Colors.grey).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: live ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                live ? 'LIVE' : 'RIÊNG TƯ',
                style: TextStyle(
                  color: live ? Colors.green : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
