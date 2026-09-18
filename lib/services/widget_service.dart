import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import '../models/location_model.dart';
import 'location_policy.dart';
import 'location_service.dart';

@pragma('vm:entry-point')
void locationWidgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await WidgetService.initializeHomeWidget();
      if (task == WidgetService.locationWidgetTaskName ||
          task == WidgetService.locationWidgetUniqueName) {
        await WidgetService.updateLocationWidget();
      }
      return true;
    } catch (_) {
      return false;
    }
  });
}

class WidgetService {
  static const String appGroupId = 'group.com.tamchau.app';
  static const String androidWidgetName = 'TamChauWidget';
  static const String iOSWidgetName = 'widget';
  static const String locationWidgetTaskName = 'updateLocationWidget';
  static const String locationWidgetUniqueName =
      'com.heartpearl.heartpearl.locationWidgetRefresh';
  static const String _mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  /// Initialize HomeWidget App Group for iOS and periodic worker for Android
  static Future<void> initialize() async {
    await initializeHomeWidget();
    if (Platform.isAndroid) {
      try {
        await Workmanager().initialize(locationWidgetCallbackDispatcher);
        await Workmanager().registerPeriodicTask(
          locationWidgetUniqueName,
          locationWidgetTaskName,
          frequency: const Duration(minutes: 30),
          initialDelay: const Duration(minutes: 20),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        );
      } catch (e) {
        debugPrint('Workmanager Android init error: $e');
      }
    }
  }

  static Future<void> initializeHomeWidget() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
    } catch (e) {
      // Ignored if platform doesn't support
    }
  }

  /// Update home screen widget with latest received/sent photo
  static Future<void> updateLatestPhoto(
    String imageUrl, {
    File? localFile,
    String? senderName,
    String? caption,
    bool isMirrored = false,
  }) async {
    if (imageUrl.isEmpty && localFile == null) return;

    try {
      if (imageUrl.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('latestPhotoUrl', imageUrl);
      }
      await HomeWidget.saveWidgetData<String>('widgetMode', 'photo');
      if (senderName != null && senderName.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('senderName', senderName);
      }
      if (caption != null && caption.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('caption', caption);
      }
      await HomeWidget.saveWidgetData<bool>('isMirrored', isMirrored);
      await HomeWidget.saveWidgetData<int>(
        'updatedAt',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Save local file directly into App Group Shared Container if available
      if (localFile != null && await localFile.exists()) {
        try {
          final bytes = await localFile.readAsBytes();
          await HomeWidget.saveFile('latestPhoto', bytes, extension: 'jpg');
        } catch (_) {}
      }

      // Trigger widget update for iOS & Android
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {}
  }

  /// Clear widget so it never shows old/own photos when no friends photos are present
  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('latestPhotoUrl', '');
      await HomeWidget.saveWidgetData<String>('latestPhoto', '');
      await HomeWidget.saveWidgetData<String>('senderName', 'HeartPearl');
      await HomeWidget.saveWidgetData<String>('caption', '');
      await HomeWidget.saveWidgetData<int>('updatedAt', 0);
      await HomeWidget.saveWidgetData<String>('widgetMode', 'photo');
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {}
  }

  /// Updates the shared native widget with a cached Mapbox static image.
  /// Returns false when there is no authorized friend, token, or meaningful
  /// movement. Continuous tracking remains the responsibility of
  /// [LocationService], not WorkManager/BGTaskScheduler.
  static Future<bool> updateLocationWidget({LocationService? service}) async {
    if (_mapboxAccessToken.isEmpty) return false;
    final locationService = service ?? LocationService();
    try {
      final visibleLocations =
          await locationService.getVisibleFriendLocationsOnce();
      if (visibleLocations.isEmpty) return false;
      final ownLocation = await locationService.getOwnLocation();
      final selected = _selectNearestOrLatest(
        visibleLocations.values,
        ownLocation,
      );
      if (selected == null) return false;

      final preferences = await SharedPreferences.getInstance();
      final lastRequestMillis = preferences.getInt('locationMapRequestedAt');
      final lastRequestAt = lastRequestMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastRequestMillis);
      final previousLat = preferences.getDouble('locationMapLat');
      final previousLng = preferences.getDouble('locationMapLng');
      final now = DateTime.now();
      if (!LocationPolicy.shouldRefreshWidget(
        now: now,
        lat: selected.lat,
        lng: selected.lng,
        lastRequestAt: lastRequestAt,
        previousLat: previousLat,
        previousLng: previousLng,
      )) {
        return false;
      }

      final uri = _buildStaticMapUri(selected, ownLocation);
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Mapbox returned ${response.statusCode}');
      }

      final friendName = await locationService.getUserDisplayName(selected.uid);
      final distance = ownLocation?.hasCoordinate == true
          ? LocationPolicy.distanceMetres(
              ownLocation!.lat,
              ownLocation.lng,
              selected.lat,
              selected.lng,
            )
          : null;
      final summary = distance == null
          ? _relativeTime(selected.timestamp)
          : '${_formatDistance(distance)} · ${_relativeTime(selected.timestamp)}';

      await HomeWidget.saveFile(
        'locationMap',
        response.bodyBytes,
        extension: 'png',
      );
      await HomeWidget.saveWidgetData<String>('widgetMode', 'location');
      await HomeWidget.saveWidgetData<String>('locationFriend', friendName);
      await HomeWidget.saveWidgetData<String>('locationSummary', summary);
      await HomeWidget.saveWidgetData<int>(
        'locationUpdatedAt',
        selected.timestamp.millisecondsSinceEpoch,
      );
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
      await preferences.setInt(
        'locationMapRequestedAt',
        now.millisecondsSinceEpoch,
      );
      await preferences.setDouble('locationMapLat', selected.lat);
      await preferences.setDouble('locationMapLng', selected.lng);
      await preferences.setString('locationMapFriendUid', selected.uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  static LocationModel? _selectNearestOrLatest(
    Iterable<LocationModel> candidates,
    LocationModel? ownLocation,
  ) {
    final list = candidates.where((item) => item.hasCoordinate).toList();
    if (list.isEmpty) return null;
    if (ownLocation?.hasCoordinate != true) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.first;
    }
    list.sort((a, b) {
      final aDistance = LocationPolicy.distanceMetres(
        ownLocation!.lat,
        ownLocation.lng,
        a.lat,
        a.lng,
      );
      final bDistance = LocationPolicy.distanceMetres(
        ownLocation.lat,
        ownLocation.lng,
        b.lat,
        b.lng,
      );
      return aDistance.compareTo(bDistance);
    });
    return list.first;
  }

  static Uri _buildStaticMapUri(
    LocationModel friend,
    LocationModel? ownLocation,
  ) {
    final overlays = <String>['pin-s-heart+ff4a6e(${friend.lng},${friend.lat})'];
    if (ownLocation?.hasCoordinate == true) {
      overlays.add('pin-s+4264fb(${ownLocation!.lng},${ownLocation.lat})');
    }
    return Uri.https(
      'api.mapbox.com',
      '/styles/v1/mapbox/streets-v12/static/${overlays.join(',')}/auto/600x360@2x',
      {
        'access_token': _mapboxAccessToken,
        'padding': '60',
        'attribution': 'true',
        'logo': 'true',
      },
    );
  }

  static String _formatDistance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  static String _relativeTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'vừa cập nhật';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    return '${difference.inDays} ngày trước';
  }
}
