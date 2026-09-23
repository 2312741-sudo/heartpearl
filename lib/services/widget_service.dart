import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
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
      } else if (imageUrl.isNotEmpty) {
        // No local file → download from URL and cache into App Group.
        // CRITICAL: Firebase Storage URLs expire quickly and iOS WidgetKit
        // cannot use auth tokens, so we MUST save a persistent local copy.
        try {
          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 12));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            await HomeWidget.saveFile(
              'latestPhoto',
              response.bodyBytes,
              extension: 'jpg',
            );
          }
        } catch (_) {
          // Network error — widget will fall back to showing empty state
        }
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

  /// Switch widget mode back to photo display
  static Future<void> switchToPhotoMode() async {
    try {
      await HomeWidget.saveWidgetData<String>('widgetMode', 'photo');
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {}
  }

  /// Explicitly pins a friend's live location to the home screen widget
  static Future<bool> pinFriendLocationToWidget({
    required UserModel friend,
    required LocationModel location,
    LocationModel? ownLocation,
  }) async {
    try {
      ownLocation ??= await _tryGetOwnLocation();
      final friendName = friend.displayName.isNotEmpty
          ? friend.displayName
          : 'Bạn bè';
      final distance = ownLocation?.hasCoordinate == true
          ? LocationPolicy.distanceMetres(
              ownLocation!.lat,
              ownLocation.lng,
              location.lat,
              location.lng,
            )
          : null;
      final summary = distance == null
          ? _relativeTime(location.timestamp)
          : '${_formatDistance(distance)} · ${_relativeTime(location.timestamp)}';

      Uint8List? mapBytes;
      if (_mapboxAccessToken.isNotEmpty) {
        try {
          final uri = _buildStaticMapUri(location, ownLocation);
          final response =
              await http.get(uri).timeout(const Duration(seconds: 8));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            mapBytes = response.bodyBytes;
          }
        } catch (_) {}
      }

      mapBytes ??= await generateRadarMapImage(
        friendName: friendName,
        friendLat: location.lat,
        friendLng: location.lng,
        ownLat: ownLocation?.lat,
        ownLng: ownLocation?.lng,
      );

      // Write map image bytes to a stable file and store path in UserDefaults
      // so iOS WidgetKit (UIImage(contentsOfFile:)) can load it reliably.
      await _saveMapFile('locationMap', mapBytes);
      await HomeWidget.saveWidgetData<String>('widgetMode', 'location');
      await HomeWidget.saveWidgetData<String>('locationFriend', friendName);
      await HomeWidget.saveWidgetData<String>('locationSummary', summary);
      await HomeWidget.saveWidgetData<int>(
        'locationUpdatedAt',
        location.timestamp.millisecondsSinceEpoch,
      );
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );

      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        'locationMapRequestedAt',
        DateTime.now().millisecondsSinceEpoch,
      );
      await preferences.setDouble('locationMapLat', location.lat);
      await preferences.setDouble('locationMapLng', location.lng);
      await preferences.setString('locationMapFriendUid', friend.uid);
      return true;
    } catch (e) {
      debugPrint('[WidgetService] pinFriendLocationToWidget error: $e');
      return false;
    }
  }

  /// Updates the shared native widget with Mapbox static image or native radar snapshot.
  static Future<bool> updateLocationWidget({LocationService? service}) async {
    final locationService = service ?? LocationService();
    try {
      final visibleLocations =
          await locationService.getVisibleFriendLocationsOnce();
      if (visibleLocations.isEmpty) return false;
      final ownLocation = await _tryGetOwnLocation(locationService);
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

      Uint8List? mapBytes;
      if (_mapboxAccessToken.isNotEmpty) {
        try {
          final uri = _buildStaticMapUri(selected, ownLocation);
          final response =
              await http.get(uri).timeout(const Duration(seconds: 12));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            mapBytes = response.bodyBytes;
          }
        } catch (_) {}
      }

      final friendName =
          await locationService.getUserDisplayName(selected.uid);

      mapBytes ??= await generateRadarMapImage(
        friendName: friendName,
        friendLat: selected.lat,
        friendLng: selected.lng,
        ownLat: ownLocation?.lat,
        ownLng: ownLocation?.lng,
      );

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

      await _saveMapFile('locationMap', mapBytes);
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

  /// High-resolution on-device dark radar snapshot rendered via dart:ui Canvas
  static Future<Uint8List> generateRadarMapImage({
    required String friendName,
    required double friendLat,
    required double friendLng,
    double? ownLat,
    double? ownLng,
    int width = 600,
    int height = 360,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // 1. Dark obsidian background gradient
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width * 0.5, height * 0.45),
        width * 0.75,
        [
          const Color(0xFF231230),
          const Color(0xFF13091A),
          const Color(0xFF09040D),
        ],
        [0.0, 0.6, 1.0],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      bgPaint,
    );

    // 2. Decorative subtle grid
    final gridPaint = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = 1.0;
    for (double x = 40; x < width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, height.toDouble()), gridPaint);
    }
    for (double y = 40; y < height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(width.toDouble(), y), gridPaint);
    }

    final hasOwn = ownLat != null && ownLng != null;
    final center = hasOwn
        ? Offset(width * 0.5, height * 0.48)
        : Offset(width * 0.5, height * 0.45);

    // 3. Concentric radar range rings
    final radarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x24FF4A6E);
    for (final r in [50.0, 95.0, 145.0, 195.0]) {
      canvas.drawCircle(center, r, radarPaint);
    }

    // 4. Coordinates / positions
    final friendPos = hasOwn
        ? Offset(width * 0.65, height * 0.40)
        : Offset(width * 0.5, height * 0.42);
    final ownPos = hasOwn ? Offset(width * 0.32, height * 0.58) : null;

    if (hasOwn && ownPos != null) {
      // Connecting dashed glow line
      final dist =
          LocationPolicy.distanceMetres(ownLat, ownLng, friendLat, friendLng);
      final linePaint = Paint()
        ..color = const Color(0x66FF4A6E)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(ownPos, friendPos, linePaint);

      // Distance bubble on the line
      final midPoint = Offset(
        (ownPos.dx + friendPos.dx) / 2,
        (ownPos.dy + friendPos.dy) / 2,
      );
      final distText = _formatDistance(dist);
      _drawBadge(
        canvas: canvas,
        center: midPoint,
        text: distText,
        bgColor: const Color(0xE6251230),
        borderColor: const Color(0x99FF4A6E),
        textColor: Colors.white,
        fontSize: 12,
      );

      // User ("Bạn") marker
      final ownGlow = Paint()
        ..color = const Color(0x444264FB)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(ownPos, 20, ownGlow);

      final ownCircle = Paint()
        ..color = const Color(0xFF4264FB)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(ownPos, 14, ownCircle);

      final ownBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(ownPos, 14, ownBorder);

      _drawText(
        canvas: canvas,
        center: Offset(ownPos.dx, ownPos.dy + 24),
        text: 'Bạn',
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFE0E0FF),
      );
    }

    // Friend marker (Hot pink with pulsating glow)
    final friendGlow = Paint()
      ..color = const Color(0x77FF4A6E)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(friendPos, 28, friendGlow);

    final friendFill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(friendPos.dx - 18, friendPos.dy - 18),
        Offset(friendPos.dx + 18, friendPos.dy + 18),
        [const Color(0xFFFF6584), const Color(0xFFFF2A55)],
      );
    canvas.drawCircle(friendPos, 20, friendFill);

    final friendBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(friendPos, 20, friendBorder);

    // Initial letter or heart in friend marker
    final initial =
        friendName.isNotEmpty ? friendName.trim()[0].toUpperCase() : '♥';
    _drawText(
      canvas: canvas,
      center: friendPos,
      text: initial,
      fontSize: 16,
      fontWeight: FontWeight.w900,
      color: Colors.white,
    );

    // Friend name badge
    _drawBadge(
      canvas: canvas,
      center: Offset(friendPos.dx, friendPos.dy - 32),
      text: friendName,
      bgColor: const Color(0xE61E0D27),
      borderColor: const Color(0xCCFF4A6E),
      textColor: Colors.white,
      fontSize: 13,
      isBold: true,
    );

    // Top Right Radar Indicator
    _drawText(
      canvas: canvas,
      center: const Offset(520, 24),
      text: 'LIVE RADAR',
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: const Color(0x99FF4A6E),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawText({
    required ui.Canvas canvas,
    required Offset center,
    required String text,
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.white,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  static void _drawBadge({
    required ui.Canvas canvas,
    required Offset center,
    required String text,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required double fontSize,
    bool isBold = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 16,
      height: tp.height + 8,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rrect, borderPaint);

    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
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

  /// Attempts to obtain the device's actual GPS position first (via last-known
  /// or fast position lookup), falling back to Firestore ownLocation or cached
  /// coordinates in SharedPreferences.
  static Future<LocationModel?> _tryGetOwnLocation([
    LocationService? service,
  ]) async {
    final locationService = service ?? LocationService();

    // 1. Try GPS cached/last known position from OS (instant, zero battery cost)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          LocationPolicy.isValidFix(
            lat: lastKnown.latitude,
            lng: lastKnown.longitude,
            accuracy: lastKnown.accuracy,
          )) {
        return LocationModel(
          uid: locationService.currentUid ?? 'me',
          lat: lastKnown.latitude,
          lng: lastKnown.longitude,
          timestamp: lastKnown.timestamp,
          accuracy: lastKnown.accuracy,
          speed: lastKnown.speed,
          isSharing: true,
        );
      }
    } catch (_) {}

    // 2. Try fast GPS fix with 3-second timeout if app is running foreground
    try {
      final currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
      if (LocationPolicy.isValidFix(
        lat: currentPos.latitude,
        lng: currentPos.longitude,
        accuracy: currentPos.accuracy,
      )) {
        return LocationModel(
          uid: locationService.currentUid ?? 'me',
          lat: currentPos.latitude,
          lng: currentPos.longitude,
          timestamp: currentPos.timestamp,
          accuracy: currentPos.accuracy,
          speed: currentPos.speed,
          isSharing: true,
        );
      }
    } catch (_) {}

    // 3. Fallback: Firestore ownLocation
    try {
      final own = await locationService.getOwnLocation();
      if (own != null && own.hasCoordinate) return own;
    } catch (_) {}

    // 4. Fallback: cached coordinates in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_own_lat');
      final lng = prefs.getDouble('last_own_lng');
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        return LocationModel(
          uid: locationService.currentUid ?? 'me',
          lat: lat,
          lng: lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          speed: 0,
          isSharing: true,
        );
      }
    } catch (_) {}

    return null;
  }

  /// Saves [bytes] (PNG) into the App Group container (iOS) or app directory
  /// (Android), then writes the file path into UserDefaults under [key] so
  /// native WidgetKit code can load the image via `UIImage(contentsOfFile:)`.
  static Future<void> _saveMapFile(String key, Uint8List bytes) async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      await HomeWidget.saveFile(
        key,
        bytes,
        extension: 'png',
        appGroupId: Platform.isIOS ? appGroupId : null,
      );
    } catch (e) {
      debugPrint('[WidgetService] _saveMapFile error: $e');
    }
  }
}
