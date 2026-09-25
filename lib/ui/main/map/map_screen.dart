import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/location_model.dart';
import '../../../models/place_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/places_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/location_policy.dart';
import '../../../services/widget_service.dart';
import 'add_place_sheet.dart';
import 'live_location_sheet.dart';
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
  StreamSubscription<Position>? _locationServiceSub;

  bool _hasCentered = false;
  bool _isLocating = false;
  bool _isCheckingIn = false;
  MapStyle? _userMapStyle;

  Future<void> _performManualCheckIn() async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);
    HapticHelper.medium();

    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.checkIn();
      HapticHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã check-in thành công! Vị trí của bạn đang hiển thị cho bạn bè.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể check-in: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  Future<void> _clearCheckIn() async {
    HapticHelper.light();
    final lang = ref.read(settingsProvider).language;
    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.clearCheckIn();
      HapticHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr('location_clear_success', lang: lang)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Opens the Live Location sheet to start a timed session.
  Future<void> _showLiveSheet() async {
    HapticHelper.medium();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const LiveLocationSheet(),
    );
    if (result != null && mounted) {
      _positionSub?.cancel();
      _positionSub = null;
    }
  }

  /// Confirms and stops an active live session.
  Future<void> _stopLive() async {
    final lang = ref.read(settingsProvider).language;
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.tr('live_stop_btn', lang: lang)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticHelper.light();
    try {
      await ref.read(locationServiceProvider).stopLiveSharing(clearFirestore: true);
    } catch (e) {
      debugPrint('[MapScreen] _stopLive error: $e');
    }
    if (mounted) {
      _initUserLocation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('live_stopped', lang: lang)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initUserLocation();
    _loadSavedMapStyle();

    // Stream live position updates from LocationService for zero-latency local marker display
    _locationServiceSub = ref.read(locationServiceProvider).positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _myPosition = LatLng(pos.latitude, pos.longitude);
          _myAccuracy = pos.accuracy;
        });
        _cacheOwnPosition(pos.latitude, pos.longitude);
      }
    });
  }

  Future<void> _loadSavedMapStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('map_style');
      if (saved != null && mounted) {
        final style = MapStyle.values.where((s) => s.name == saved).firstOrNull;
        if (style != null) setState(() => _userMapStyle = style);
      }
    } catch (_) {}
  }

  Future<void> _saveMapStyle(MapStyle style) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('map_style', style.name);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationTimer?.cancel();
    _locationServiceSub?.cancel();
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
        _cacheOwnPosition(lastPos.latitude, lastPos.longitude);
        _centerOnMeOnce();
      }

      // 2. Query fresh GPS position (non-blocking: don't let GPS delay abort step 3)
      try {
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (mounted) {
          setState(() {
            _myPosition = LatLng(currentPos.latitude, currentPos.longitude);
            _myAccuracy = currentPos.accuracy;
          });
          _cacheOwnPosition(currentPos.latitude, currentPos.longitude);
          _centerOnMeOnce();
        }
      } catch (_) {}

      // If live sharing is active, LocationService already manages the native background stream.
      // Do NOT start a competing Geolocator.getPositionStream which would overwrite native AppleSettings.
      if (ref.read(locationServiceProvider).isLiveActive) {
        _positionSub?.cancel();
        _positionSub = null;
        return;
      }

      // 3. Listen to position changes for the local blue-dot display.
      //    medium accuracy is sufficient here — we're just drawing a marker,
      //    not sharing with friends. distanceFilter 20 m avoids micro-jitter.
      _positionSub?.cancel();
      final streamSettings = Platform.isIOS
          ? AppleSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 20,
              // pauseLocationUpdatesAutomatically: true is fine for the display
              // stream — when user leaves the map tab we cancel it in
              // didChangeAppLifecycleState anyway.
              pauseLocationUpdatesAutomatically: true,
              showBackgroundLocationIndicator: false,
              allowBackgroundLocationUpdates: false,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 20,
            );

      _positionSub = Geolocator.getPositionStream(
        locationSettings: streamSettings,
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _myPosition = LatLng(pos.latitude, pos.longitude);
            _myAccuracy = pos.accuracy;
          });
          _cacheOwnPosition(pos.latitude, pos.longitude);
        }
      });
    } catch (_) {}
  }

  void _cacheOwnPosition(double lat, double lng) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('last_own_lat', lat);
      prefs.setDouble('last_own_lng', lng);
    }).catchError((_) {});
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

  void _showAddPlaceSheet({double? lat, double? lng}) {
    HapticHelper.selection();
    final center = _mapController.camera.center;
    AddPlaceSheet.show(
      context,
      lat: lat ?? _myPosition?.latitude ?? center.latitude,
      lng: lng ?? _myPosition?.longitude ?? center.longitude,
    );
  }



  void _showMapStyleSheet() {
    HapticHelper.selection();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceBase),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Kiểu bản đồ',
                style: AppTypography.h3(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  LucideIcons.moon,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                title: Text(
                  'Giao diện tối (Dark Mode)',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: (_userMapStyle == MapStyle.dark ||
                        (_userMapStyle == null && isDark))
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _userMapStyle = MapStyle.dark);
                  _saveMapStyle(MapStyle.dark);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.map,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                title: Text(
                  'Đường phố (Google Maps)',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: (_userMapStyle == MapStyle.street ||
                        (_userMapStyle == null && !isDark))
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _userMapStyle = MapStyle.street);
                  _saveMapStyle(MapStyle.street);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.satellite,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                title: Text(
                  'Ảnh vệ tinh (Satellite)',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _userMapStyle == MapStyle.satellite
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _userMapStyle = MapStyle.satellite);
                  _saveMapStyle(MapStyle.satellite);
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

    var anyMoved = false;
    for (final item in locations) {
      final uid = item.friend.uid;
      final target = LatLng(item.location.lat, item.location.lng);
      _friendData[uid] = item;
      final prevTarget = _targetPositions[uid];
      if (prevTarget == null ||
          prevTarget.latitude != target.latitude ||
          prevTarget.longitude != target.longitude) {
        anyMoved = true;
      }
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

    // Skip the 1.2-second animation loop if none of the coordinates moved
    // (e.g. only battery level, speed, or timestamp was updated).
    if (!anyMoved) {
      if (mounted) setState(() {});
      return;
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

    ref.listen<AsyncValue<LocationTrackingStatus>>(
      locationTrackingStatusProvider,
      (previous, next) {
        final status = next.value;
        if (status == LocationTrackingStatus.serviceDisabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dịch vụ vị trí đang tắt. Vui lòng bật vị trí trong Cài đặt.'),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (status == LocationTrackingStatus.permissionDenied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quyền truy cập vị trí bị từ chối.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );

    ref.listen<AsyncValue<LocationModel?>>(ownLocationProvider, (previous, next) {
      final isSharing = next.value?.isSharing == true;
      if (isSharing && _positionSub != null) {
        _positionSub?.cancel();
        _positionSub = null;
      } else if (!isSharing && _positionSub == null) {
        // Live sharing stopped or inactive: ensure local GPS display stream is active
        _initUserLocation();
      }
    });

    final locationsAsync = ref.watch(friendLocationsProvider);
    final items = locationsAsync.value ?? const <FriendLocation>[];
    final isLoadingFriends = locationsAsync.isLoading && items.isEmpty;

    final userPlaces = ref.watch(userPlacesProvider).value ?? const <PlaceModel>[];
    final friendPlaces = ref.watch(friendsPlacesProvider).value ?? const <FriendPlace>[];

    final ownLocation = ref.watch(ownLocationProvider).value;
    final userProfile = ref.watch(userProfileProvider).value;
    final isSharing = ownLocation?.isSharing == true;
    final isLive = ownLocation?.isLive == true;
    final lang = ref.watch(settingsProvider).language;

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
      extendBodyBehindAppBar: true,
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
              onLongPress: (tapPos, latLng) {
                _showAddPlaceSheet(lat: latLng.latitude, lng: latLng.longitude);
              },
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
                  // Pinned Places: Own Places
                  for (final place in userPlaces)
                    Marker(
                      point: LatLng(place.lat, place.lng),
                      width: 80,
                      height: 70,
                      child: _PlaceMarkerWidget(
                        emoji: place.emoji,
                        label: place.label,
                        isOwn: true,
                        onTap: () => _showPlaceDetails(place: place),
                      ),
                    ),

                  // Pinned Places: Friends' Places
                  for (final fp in friendPlaces)
                    Marker(
                      point: LatLng(fp.place.lat, fp.place.lng),
                      width: 90,
                      height: 70,
                      child: _PlaceMarkerWidget(
                        emoji: fp.place.emoji,
                        label: fp.place.label,
                        isOwn: false,
                        friend: fp.friend,
                        onTap: () => _showPlaceDetails(
                          place: fp.place,
                          friend: fp.friend,
                        ),
                      ),
                    ),

                  // Own Location Marker ("Bạn")
                  if (_myPosition != null)
                    Marker(
                      point: _myPosition!,
                      width: 90,
                      height: 105,
                      child: _OwnMarkerWidget(
                        user: userProfile,
                        location: ownLocation,
                        isSharing: isSharing,
                        onTap: () => _showOwnDetails(userProfile, ownLocation),
                      ),
                    ),

                  // Friends' Markers
                  for (final item in items)
                    if (_displayPositions[item.friend.uid] case final position?)
                      Marker(
                        point: position,
                        width: 90,
                        height: 105,
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

          // 2. Top Header Overlay (title + live status + quick actions)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceBase,
                  AppDimens.spaceSm,
                  AppDimens.spaceBase,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Live banner (only when live is active)
                    if (isLive) ...[
                      _LiveBanner(
                        ownLocation: ownLocation,
                        lang: lang,
                        onStop: _stopLive,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Header pill: title + status + buttons
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.92)
                              : Colors.white.withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // Status dot + title
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLive
                                      ? Colors.red
                                      : isSharing
                                          ? AppColors.success
                                          : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isLive
                                      ? AppStrings.tr('live_share_title', lang: lang)
                                      : isSharing
                                          ? 'Check-in · Bạn bè'
                                          : 'Bản đồ bạn bè',
                                  style: AppTypography.caption(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              // Action buttons on the right
                              if (!isSharing) ...[
                                _ActionChip(
                                  label: 'Check-in',
                                  icon: LucideIcons.mapPin,
                                  color: AppColors.primary,
                                  loading: _isCheckingIn,
                                  onTap: _isCheckingIn ? null : _performManualCheckIn,
                                ),
                                const SizedBox(width: 6),
                                _ActionChip(
                                  label: 'Live',
                                  icon: LucideIcons.radio,
                                  color: Colors.red.shade600,
                                  onTap: _showLiveSheet,
                                ),
                              ] else if (isLive) ...[
                                _ActionChip(
                                  label: 'Dừng',
                                  icon: LucideIcons.squareX,
                                  color: Colors.red.shade600,
                                  onTap: _stopLive,
                                ),
                                const SizedBox(width: 4),
                                _MapIconButton(
                                  icon: LucideIcons.ghost,
                                  tooltip: 'Ẩn vị trí',
                                  isDark: isDark,
                                  onPressed: _clearCheckIn,
                                ),
                              ] else ...[
                                _ActionChip(
                                  label: 'Live',
                                  icon: LucideIcons.radio,
                                  color: Colors.red.shade600,
                                  onTap: _showLiveSheet,
                                ),
                                const SizedBox(width: 4),
                                _MapIconButton(
                                  icon: LucideIcons.ghost,
                                  tooltip: 'Ẩn vị trí',
                                  isDark: isDark,
                                  onPressed: _clearCheckIn,
                                ),
                              ],

                              const SizedBox(width: 6),

                              // Privacy settings
                              _MapIconButton(
                                icon: LucideIcons.shieldCheck,
                                tooltip: 'Cài đặt vị trí',
                                isDark: isDark,
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocationPrivacyScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Empty friends hint (subtle, bottom center)
          if (items.isEmpty && isSharing && !isLoadingFriends)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkSurface : Colors.white)
                          .withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.users, size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 8),
                        Text(
                          'Chưa có bạn bè nào chia sẻ vị trí',
                          style: AppTypography.caption(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Right side: Map controls (Sleek Glassmorphic Floating Stack)
          Positioned(
            right: AppDimens.spaceBase,
            bottom: items.isNotEmpty ? 112 : 36,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Re-center on Me
                  _FloatingMapButton(
                    icon: _isLocating
                        ? LucideIcons.loader2
                        : LucideIcons.locateFixed,
                    iconColor: AppColors.primary,
                    onPressed: _recenterOnMe,
                    tooltip: 'Về vị trí của tôi',
                  ),
                  const SizedBox(height: 10),

                  // Pin New Place (Nhà / Nơi làm việc / Trường học)
                  _FloatingMapButton(
                    icon: LucideIcons.mapPinPlus,
                    iconColor: const Color(0xFFFF4081),
                    onPressed: () => _showAddPlaceSheet(),
                    tooltip: 'Ghim địa điểm (Nhà, Cơ quan...)',
                  ),
                  const SizedBox(height: 10),

                  // Map Style Switcher (Layers)
                  _FloatingMapButton(
                    icon: LucideIcons.layers,
                    onPressed: _showMapStyleSheet,
                    tooltip: 'Kiểu bản đồ',
                  ),
                  const SizedBox(height: 10),

                  // Privacy / Ghost Mode
                  _FloatingMapButton(
                    icon: LucideIcons.shieldCheck,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocationPrivacyScreen(),
                      ),
                    ),
                    tooltip: 'Quyền riêng tư vị trí',
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
                top: false,
                child: SizedBox(
                  height: 96,
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
                        onLongPress: () => _showFriendDetails(item),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                  style: AppTypography.h3(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  location?.isSharing == true
                      ? 'Đang hiển thị vị trí (Check-in thủ công)'
                      : 'Đang ở chế độ riêng tư (Chưa Check-in)',
                  style: AppTypography.caption(
                    color: location?.isSharing == true
                        ? AppColors.success
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
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _performManualCheckIn();
                      },
                      icon: const Icon(LucideIcons.mapPin, size: 18),
                      label: Text(
                        location?.isSharing == true
                            ? 'Cập nhật Check-in'
                            : 'Check-in vị trí ngay',
                      ),
                    ),
                  ),
                  if (location?.isSharing == true) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearCheckIn();
                      },
                      icon: const Icon(LucideIcons.ghost, size: 18),
                      label: const Text('Ẩn vị trí'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
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
                label: const Text('Cài đặt quyền riêng tư vị trí'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showWidgetGuideSheet();
                },
                icon: const Icon(LucideIcons.layoutGrid),
                label: const Text('Hướng dẫn thêm Widget'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFriendDetails(FriendLocation item) {
    HapticHelper.selection();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  '${_movementLabel(item.location.speed)} · ${_relativeTime(item.location.timestamp)}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              if (item.location.hasPlace) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primaryDark.withValues(alpha: 0.25),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.white70,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          item.location.placeEmoji ?? '📍',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.location.placeEmoji ?? "📍"} ${item.location.currentPlaceLabel ?? item.location.currentPlaceType ?? "Địa điểm"}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.location.dwellDurationText != null
                                  ? 'Đã ở đây được ${item.location.dwellDurationText}'
                                  : 'Vừa mới đến',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              // Wake-up ping button (calls friend's device to refresh location on demand)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    HapticHelper.medium();
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đang gửi tín hiệu đánh thức vị trí của ${item.friend.displayName}...',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    try {
                      await ref
                          .read(locationServiceProvider)
                          .requestFriendLocationWakeup(
                            targetFriendUid: item.friend.uid,
                            friendName: item.friend.displayName,
                          );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã gửi tín hiệu tới ${item.friend.displayName}! Vị trí sẽ tự động cập nhật.',
                          ),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Không thể gửi tín hiệu: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.locateFixed, size: 18),
                  label: const Text('Đánh thức vị trí bạn bè'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mapController.move(
                          LatLng(item.location.lat, item.location.lng),
                          17.0,
                        );
                      },
                      icon: const Icon(LucideIcons.navigation, size: 18),
                      label: const Text('Phóng to'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        HapticHelper.medium();
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đang ghim vị trí của ${item.friend.displayName} lên Widget...',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        final ownLoc = _myPosition != null
                            ? LocationModel(
                                uid: '',
                                lat: _myPosition!.latitude,
                                lng: _myPosition!.longitude,
                                timestamp: DateTime.now(),
                                accuracy: _myAccuracy ?? 0,
                                speed: 0,
                                isSharing: true,
                              )
                            : null;
                        final ok =
                            await WidgetService.pinFriendLocationToWidget(
                          friend: item.friend,
                          location: item.location,
                          ownLocation: ownLoc,
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Đã ghim vị trí của ${item.friend.displayName} lên màn hình chính!'
                                    : 'Không thể cập nhật Widget. Vui lòng thử lại.',
                              ),
                              backgroundColor:
                                  ok ? AppColors.primary : Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.layoutGrid, size: 18),
                      label: const Text('Ghim lên Widget'),
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

  String _formatDistanceToPlace(double lat, double lng) {
    if (_myPosition == null) return '';
    final d = LocationPolicy.distanceMetres(
      _myPosition!.latitude,
      _myPosition!.longitude,
      lat,
      lng,
    );
    if (d < 1000) {
      return '${d.round()} m';
    }
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  void _showPlaceDetails({
    required PlaceModel place,
    UserModel? friend,
  }) {
    HapticHelper.selection();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwn = friend == null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(place.emoji, style: const TextStyle(fontSize: 26)),
                ),
                title: Text(
                  place.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  isOwn
                      ? 'Địa điểm đã ghim của bạn · ${place.type.displayName}'
                      : 'Địa điểm của ${friend.displayName} · ${place.type.displayName}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                trailing: isOwn
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Xóa địa điểm',
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Xóa địa điểm?'),
                              content: Text('Bạn có chắc muốn xóa "${place.label}" không?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(placesServiceProvider).deletePlace(place.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã xóa "${place.label}"'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          }
                        },
                      )
                    : null,
              ),

              const Divider(),
              const SizedBox(height: 8),

              // Location info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Tọa độ',
                    value:
                        '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}',
                    icon: LucideIcons.mapPin,
                  ),
                  _StatItem(
                    label: 'Bán kính',
                    value: '${place.radiusMetres.round()} m',
                    icon: LucideIcons.circleDot,
                  ),
                  if (_myPosition != null)
                    _StatItem(
                      label: 'Khoảng cách',
                      value: _formatDistanceToPlace(place.lat, place.lng),
                      icon: LucideIcons.navigation,
                    ),
                ],
              ),

              const SizedBox(height: 16),
              // Zoom into place button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _mapController.move(LatLng(place.lat, place.lng), 17.0);
                  },
                  icon: const Icon(LucideIcons.navigation, size: 18),
                  label: const Text('Xem trên bản đồ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWidgetGuideSheet() {
    HapticHelper.selection();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.layoutGrid,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tiện ích màn hình chính (Widget)',
                    style: AppTypography.h3(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Cách thêm và sử dụng tiện ích trên iOS:',
                style: AppTypography.caption(
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildGuideStep(
                number: '1',
                title: 'Thêm Widget vào màn hình chính',
                desc:
                    'Nhấn giữ màn hình chính iPhone -> Bấm dấu "+" góc trên -> Chọn HeartPearl -> Nhấn "Thêm tiện ích".',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildGuideStep(
                number: '2',
                title: 'Ghim vị trí bạn bè lên Widget',
                desc:
                    'Chạm vào bạn bè trên bản đồ này -> Chọn "Ghim lên Widget". Widget sẽ lập tức chuyển sang chế độ bản đồ định vị bạn bè!',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildGuideStep(
                number: '3',
                title: 'Xem ảnh khoảnh khắc',
                desc:
                    'Khi bạn bè gửi ảnh mới, widget sẽ tự động cập nhật ảnh mới nhất.',
                isDark: isDark,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await WidgetService.switchToPhotoMode();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Đã chuyển Widget về chế độ hiển thị Ảnh.'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.image, size: 18),
                  label: const Text('Chuyển Widget về chế độ Ảnh'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep({
    required String number,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Marker for current user ("Bạn")
class _OwnMarkerWidget extends StatelessWidget {
  final UserModel? user;
  final LocationModel? location;
  final bool isSharing;
  final VoidCallback onTap;

  const _OwnMarkerWidget({
    required this.user,
    this.location,
    required this.isSharing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl;
    final displayName = user?.displayName ?? 'Bạn';
    final hasPlace = location?.hasPlace == true;
    final dwell = location?.dwellDurationText;
    final placeEmoji = location?.placeEmoji ?? '📍';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zenly Floating Pill above avatar if at a place
          if (hasPlace && dwell != null)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xF0180716),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 0.8),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(placeEmoji, style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    dwell,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          Stack(
            clipBehavior: Clip.none,
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

              if (hasPlace)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Text(placeEmoji, style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
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
    final hasPlace = location.hasPlace;
    final dwell = location.dwellDurationText;
    final placeEmoji = location.placeEmoji ?? '📍';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zenly Floating Pill: Place + Dwell time or Speed
          if (hasPlace && dwell != null)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xF0180716),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 0.8),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(placeEmoji, style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    dwell,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (location.speed > 2.0)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xF0180716),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_movementIcon(location.speed), style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    '${(location.speed * 3.6).round()} km/h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Avatar with border & mini place badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: stale
                        ? Colors.grey
                        : (hasPlace ? const Color(0xFFFF5288) : AppColors.primary),
                    width: 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (stale ? Colors.black26 : AppColors.primary)
                          .withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
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

              // Mini Place Emoji Badge at bottom-right of avatar
              if (hasPlace)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Text(placeEmoji, style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 3),

          // Name pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xE6180716),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              friend.displayName.split(' ').last,
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

class _PlaceMarkerWidget extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isOwn;
  final UserModel? friend;
  final VoidCallback onTap;

  const _PlaceMarkerWidget({
    required this.emoji,
    required this.label,
    required this.isOwn,
    this.friend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark
        ? const Color(0xF0180716)
        : Colors.white.withValues(alpha: 0.95);
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji circle with optional friend badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF26232E) : Colors.white,
                  border: Border.all(
                    color: isOwn ? AppColors.primary : const Color(0xFF7C4DFF),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isOwn ? AppColors.primary : const Color(0xFF7C4DFF))
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),

              // Friend mini avatar badge on bottom right
              if (!isOwn && friend != null)
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: const Color(0xFF7C4DFF),
                      backgroundImage: (friend!.avatarUrl != null &&
                              friend!.avatarUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(friend!.avatarUrl!)
                          : null,
                      child: (friend!.avatarUrl == null ||
                              friend!.avatarUrl!.isEmpty)
                          ? Text(
                              friend!.displayName.isNotEmpty
                                  ? friend!.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),

          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.6,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              isOwn ? label : '${friend?.displayName.split(' ').last ?? ""}: $label',
              style: TextStyle(
                color: textColor,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  final String? tooltip;

  const _FloatingMapButton({
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
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
      ),
    );
  }
}

/// Compact icon button used inside the header pill.
class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onPressed;

  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
  final VoidCallback? onLongPress;

  const _FriendLocationCard({
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final stale = item.location.isStale();
    final hasPlace = item.location.hasPlace;
    final placeLabel = item.location.currentPlaceLabel ?? item.location.currentPlaceType ?? '';
    final dwell = item.location.dwellDurationText;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E1C24) : Colors.white).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                backgroundImage: item.friend.avatarUrl != null && item.friend.avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(item.friend.avatarUrl!)
                    : null,
                child: item.friend.avatarUrl == null || item.friend.avatarUrl!.isEmpty
                    ? Text(
                        item.friend.displayName.isNotEmpty
                            ? item.friend.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              // Name & Status
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.friend.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (item.location.batteryLevel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '🔋${item.location.batteryLevel}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (hasPlace) ...[
                        Text(
                          '${item.location.placeEmoji ?? '📍'} $placeLabel ${dwell != null ? '· $dwell' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ] else ...[
                        Text(
                          item.location.speed > 1.5
                              ? '⚡ ${(item.location.speed * 3.6).round()} km/h'
                              : _relativeTime(item.location.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: stale ? Colors.orange : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ],
                    ],
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


/// Red banner displayed above the main control bar when a live session is active.
class _LiveBanner extends StatefulWidget {
  final LocationModel? ownLocation;
  final String lang;
  final VoidCallback onStop;
  final bool isDark;

  const _LiveBanner({
    required this.ownLocation,
    required this.lang,
    required this.onStop,
    required this.isDark,
  });

  @override
  State<_LiveBanner> createState() => _LiveBannerState();
}

class _LiveBannerState extends State<_LiveBanner> {
  late Timer _ticker;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _update();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _update());
  }

  void _update() {
    final exp = widget.ownLocation?.shareExpiresAt;
    if (!mounted) return;
    if (exp == null) {
      setState(() => _countdown = '');
      return;
    }
    final diff = exp.difference(DateTime.now());
    if (diff.isNegative) {
      setState(() => _countdown = '');
      return;
    }
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (widget.lang == 'vi') {
      setState(() => _countdown = h > 0 ? '· Còn ${h}g ${m}p' : '· Còn ${m}p');
    } else {
      setState(() => _countdown = h > 0 ? '· ${h}h ${m}m left' : '· ${m}m left');
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: Colors.red.shade700.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            // Pulsing dot
            const _PulsingDot(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${AppStrings.tr('live_active_prefix', lang: widget.lang)} $_countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onStop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppStrings.tr('live_stop_btn', lang: widget.lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated pulsing red dot shown in the live banner.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Small pill-shaped action button for the control bar.
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: loading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
