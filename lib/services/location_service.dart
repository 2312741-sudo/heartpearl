import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_model.dart';
import 'location_policy.dart';
import 'location_sharing_duration.dart';

enum LocationTrackingStatus {
  idle,
  requestingPermission,
  tracking,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationTrackingException implements Exception {
  final String message;
  final LocationTrackingStatus status;

  const LocationTrackingException(this.message, this.status);

  @override
  String toString() => message;
}

class LocationService {
  static const String collectionName = 'userLocations';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Battery _battery;
  final StreamController<LocationTrackingStatus> _statusController =
      StreamController<LocationTrackingStatus>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Position>? _liveSubscription;
  Timer? _expiryTimer;
  Timer? _heartbeatTimer;
  LocationSharingDuration? _currentDuration;
  DateTime? _lastBatteryReadAt;
  int? _cachedBatteryLevel;

  LocationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Battery? battery,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _battery = battery ?? Battery();

  Stream<LocationTrackingStatus> get statusStream => _statusController.stream;

  /// Whether a live streaming session is currently active in this service instance.
  bool get isLiveActive => _liveSubscription != null;

  /// Current authenticated user ID, if signed in.
  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _locationRef(String uid) =>
      _db.collection(collectionName).doc(uid);

  String _requireCurrentUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để chia sẻ vị trí.');
    }
    return uid;
  }

  Stream<LocationModel?> streamOwnLocation() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return Stream.value(null);
    return _locationRef(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return LocationModel.fromFirestore(snapshot);
    });
  }

  Stream<LocationModel?> streamFriendLocation(String friendUid) {
    final cleanUid = friendUid.trim();
    if (cleanUid.isEmpty) return Stream.value(null);
    return _locationRef(cleanUid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final location = LocationModel.fromFirestore(snapshot);
      // Respect expiry server-side: if expired, treat as not sharing.
      if (!location.isSharing || !location.hasCoordinate || location.isExpired) {
        return null;
      }
      return location;
    });
  }

  Future<LocationModel?> getOwnLocation() async {
    final snapshot = await _locationRef(_requireCurrentUid()).get();
    return snapshot.exists ? LocationModel.fromFirestore(snapshot) : null;
  }

  Future<LocationPermission> requestSharingPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _statusController.add(LocationTrackingStatus.serviceDisabled);
      throw const LocationTrackingException(
        'Dịch vụ vị trí đang tắt. Hãy bật vị trí trong Cài đặt.',
        LocationTrackingStatus.serviceDisabled,
      );
    }

    _statusController.add(LocationTrackingStatus.requestingPermission);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _statusController.add(LocationTrackingStatus.permissionDeniedForever);
      throw const LocationTrackingException(
        'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở Cài đặt ứng dụng.',
        LocationTrackingStatus.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      _statusController.add(LocationTrackingStatus.permissionDenied);
      throw const LocationTrackingException(
        'HeartPearl cần quyền vị trí để bật chia sẻ.',
        LocationTrackingStatus.permissionDenied,
      );
    }

    if (permission == LocationPermission.whileInUse) {
      try {
        final nextPermission = await Geolocator.requestPermission();
        if (nextPermission == LocationPermission.always) {
          permission = nextPermission;
        }
      } catch (_) {}
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      _statusController.add(LocationTrackingStatus.permissionDenied);
      throw const LocationTrackingException(
        'HeartPearl cần quyền vị trí để bật chia sẻ.',
        LocationTrackingStatus.permissionDenied,
      );
    }
    return permission;
  }

  Future<void> startSharing() => setSharingEnabled(true);
  Future<void> stopSharing() => setSharingEnabled(false);

  // ---------------------------------------------------------------------------
  // Manual Check-In (original behaviour — kept per Apple Guideline 5.1.2(i))
  // ---------------------------------------------------------------------------

  /// Manual Check-in: captures a single GPS fix on explicit user tap.
  Future<LocationModel> checkIn() async {
    final uid = _requireCurrentUid();
    await requestSharingPermission();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    if (!LocationPolicy.isValidFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
    )) {
      throw Exception('Tọa độ GPS không hợp lệ. Vui lòng kiểm tra lại kết nối GPS.');
    }

    final battery = await _readBatteryLevel();
    final now = DateTime.now();

    final data = <String, dynamic>{
      'ownerUid': uid,
      'isSharing': true,
      'liveSessionActive': false,
      'shareExpiresAt': FieldValue.delete(),
      'shareDurationLabel': FieldValue.delete(),
      'geo': GeoPoint(position.latitude, position.longitude),
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed.isFinite && position.speed > 0
          ? position.speed.clamp(0, 200).toDouble()
          : 0.0,
      'batteryLevel': ?battery,
      'capturedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _locationRef(uid).set(data, SetOptions(merge: true));

    final model = LocationModel(
      uid: uid,
      lat: position.latitude,
      lng: position.longitude,
      timestamp: now,
      accuracy: position.accuracy,
      speed: position.speed,
      batteryLevel: battery,
      isSharing: true,
      liveSessionActive: false,
    );

    _statusController.add(LocationTrackingStatus.tracking);
    return model;
  }

  // ---------------------------------------------------------------------------
  // Live Location Sharing (timed session)
  // ---------------------------------------------------------------------------

  /// Starts a live location streaming session for the chosen [duration].
  ///
  /// GPS positions are published to Firestore whenever the device moves ≥ 20m
  /// OR every 30 seconds (whichever comes first), whileInUse only.
  /// When the app enters background, iOS/Android suspend the stream; the last
  /// known coordinates remain on Firestore until the session expires or the
  /// user taps Ghost Mode.
  Future<void> startLiveSharing(LocationSharingDuration duration) async {
    // Stop any existing live session first.
    await stopLiveSharing(clearFirestore: false);

    final uid = _requireCurrentUid();
    await requestSharingPermission();

    // Get initial fix to write immediately.
    final initialPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    if (!LocationPolicy.isValidFix(
      lat: initialPosition.latitude,
      lng: initialPosition.longitude,
      accuracy: initialPosition.accuracy,
    )) {
      throw Exception('Tọa độ GPS không hợp lệ. Vui lòng kiểm tra lại kết nối GPS.');
    }

    final expiresAt = duration.expiresAt();
    _currentDuration = duration;

    // Write initial position + session metadata to Firestore.
    final battery = await _readBatteryLevel();
    await _writeLivePosition(uid, initialPosition, expiresAt, duration, battery);

    // Start streaming position updates.
    final settings = _buildLiveSettings();
    _liveSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) => _onLivePosition(uid, position, expiresAt, duration),
      onError: (Object error) {
        debugPrint('Live location stream error: $error');
        _statusController.add(LocationTrackingStatus.error);
      },
      cancelOnError: false,
    );

    _statusController.add(LocationTrackingStatus.tracking);

    // Heartbeat: every 60 s, force-write last known position to Firestore so friends
    // always see a fresh timestamp even when the user is stationary (no distanceFilter
    // events fire). This also acts as a liveness ping for the live session.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_liveSubscription == null) return; // session stopped
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) return;
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null &&
            LocationPolicy.isValidFix(
              lat: pos.latitude,
              lng: pos.longitude,
              accuracy: pos.accuracy,
            )) {
          final battery = await _readBatteryLevel();
          await _writeLivePosition(uid, pos, expiresAt, duration, battery);
        }
      } catch (_) {}
    });

    // Schedule local expiry timer if session is not unlimited.
    if (expiresAt != null) {
      final remaining = expiresAt.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _expiryTimer = Timer(remaining, () async {
          await stopLiveSharing(clearFirestore: true);
        });
      } else {
        await stopLiveSharing(clearFirestore: true);
      }
    }
  }

  /// Stops the live streaming session. If [clearFirestore] is true, also
  /// sets isSharing=false and purges coordinates (Ghost Mode behaviour).
  Future<void> stopLiveSharing({bool clearFirestore = true}) async {
    final sub = _liveSubscription;
    _liveSubscription = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _currentDuration = null;
    await sub?.cancel();

    if (clearFirestore) {
      try {
        final uid = _auth.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          await _locationRef(uid).set({
            'ownerUid': uid,
            'isSharing': false,
            'liveSessionActive': false,
            'shareExpiresAt': FieldValue.delete(),
            'shareDurationLabel': FieldValue.delete(),
            'geo': FieldValue.delete(),
            'lat': FieldValue.delete(),
            'lng': FieldValue.delete(),
            'capturedAt': FieldValue.delete(),
            'accuracy': FieldValue.delete(),
            'speed': FieldValue.delete(),
            'batteryLevel': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (error) {
        debugPrint('stopLiveSharing Firestore error: $error');
      }
      _statusController.add(LocationTrackingStatus.idle);
    }
  }

  /// Returns remaining time string for the active session, or null.
  String? liveCountdown(String lang) {
    return _currentDuration?.countdownLabel(lang);
  }

  // ---------------------------------------------------------------------------
  // Internal live streaming helpers
  // ---------------------------------------------------------------------------

  void _onLivePosition(
    String uid,
    Position position,
    DateTime? expiresAt,
    LocationSharingDuration duration,
  ) {
    // Auto-expire: if deadline passed, stop.
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      stopLiveSharing(clearFirestore: true);
      return;
    }
    if (!LocationPolicy.isValidFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
    )) { return; }

    _readBatteryLevel().then((battery) {
      _writeLivePosition(uid, position, expiresAt, duration, battery);
    });
  }

  Future<void> _writeLivePosition(
    String uid,
    Position position,
    DateTime? expiresAt,
    LocationSharingDuration duration,
    int? battery,
  ) async {
    try {
      final speed = position.speed.isFinite && position.speed > 0
          ? position.speed.clamp(0, 200).toDouble()
          : 0.0;
      final data = <String, dynamic>{
        'ownerUid': uid,
        'isSharing': true,
        'liveSessionActive': true,
        'shareDurationLabel': duration.firestoreLabel,
        'shareExpiresAt':
            expiresAt != null ? Timestamp.fromDate(expiresAt) : FieldValue.delete(),
        'geo': GeoPoint(position.latitude, position.longitude),
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': speed,
        'batteryLevel': ?battery,
        'capturedAt': Timestamp.fromDate(position.timestamp),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _locationRef(uid).set(data, SetOptions(merge: true));
      _statusController.add(LocationTrackingStatus.tracking);
    } catch (error) {
      debugPrint('Live write failed: $error');
      _statusController.add(LocationTrackingStatus.error);
    }
  }

  LocationSettings _buildLiveSettings() {
    const accuracy = LocationAccuracy.high;
    // 10 m is a good balance: fine-grained enough to show walking, but avoids
    // excessive writes when the user is truly stationary (heartbeat covers that).
    const distanceFilter = 10; // metres

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        // 20 s minimum interval between callbacks (even without moving 10 m)
        intervalDuration: const Duration(seconds: 20),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'HeartPearl Live',
          notificationText: 'Đang chia sẻ vị trí trực tiếp với bạn bè',
          notificationChannelName: 'Chia sẻ vị trí trực tiếp',
          enableWakeLock: false,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        // CRITICAL: false = iOS MUST NOT auto-pause the stream when stationary.
        // With true, iOS can silently kill the stream → friends see no movement.
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true, // Blue status bar pill in background
        allowBackgroundLocationUpdates: false, // Foreground-only (Apple 5.1.2(i))
      );
    }
    return const LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
  }

  // ---------------------------------------------------------------------------
  // Ghost Mode / Clear Check-In
  // ---------------------------------------------------------------------------

  /// Removes the user's location from the map (Ghost Mode).
  /// Also stops any active live session.
  Future<void> clearCheckIn() async {
    // Stop live session without clearing Firestore (we handle it below).
    if (isLiveActive) await stopLiveSharing(clearFirestore: false);

    final uid = _requireCurrentUid();
    await _locationRef(uid).set({
      'ownerUid': uid,
      'isSharing': false,
      'liveSessionActive': false,
      'shareExpiresAt': FieldValue.delete(),
      'shareDurationLabel': FieldValue.delete(),
      'geo': FieldValue.delete(),
      'lat': FieldValue.delete(),
      'lng': FieldValue.delete(),
      'capturedAt': FieldValue.delete(),
      'accuracy': FieldValue.delete(),
      'speed': FieldValue.delete(),
      'batteryLevel': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _statusController.add(LocationTrackingStatus.idle);
  }

  Future<void> setSharingEnabled(bool enabled) async {
    try {
      if (enabled) {
        await checkIn();
      } else {
        await clearCheckIn();
      }
    } on LocationTrackingException {
      rethrow;
    } catch (error) {
      _statusController.add(LocationTrackingStatus.error);
      throw Exception('Không thể cập nhật chia sẻ vị trí: $error');
    }
  }

  Future<void> setAllowedViewers(List<String> viewerUids) async {
    final uid = _requireCurrentUid();
    try {
      final profile = await _db.collection('users').doc(uid).get();
      final data = profile.data() ?? const <String, dynamic>{};
      final friends = (data['friends'] as Iterable? ?? const <dynamic>[])
          .whereType<String>()
          .toSet();
      final blocked = (data['blockedUsers'] as Iterable? ?? const <dynamic>[])
          .whereType<String>()
          .toSet();
      final selectable = friends.difference(blocked);
      final requested = viewerUids
          .map((value) => value.trim())
          .where(selectable.contains)
          .toSet();
      final stored = requested.length == selectable.length
          ? const <String>[]
          : requested.toList(growable: false);

      await _locationRef(uid).set({
        'ownerUid': uid,
        'allowedViewers': stored,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      throw Exception('Không thể cập nhật người được xem vị trí: $error');
    }
  }

  Future<void> startTracking() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final existing = await _locationRef(uid).get();
      final data = existing.data();
      if (existing.exists && data?['isSharing'] == true) {
        _statusController.add(LocationTrackingStatus.tracking);
        // If there was an active live session but the timer was lost (app restart),
        // check expiry and clear if past deadline.
        final rawExpiry = data?['shareExpiresAt'];
        if (rawExpiry is Timestamp) {
          final expiresAt = rawExpiry.toDate();
          if (DateTime.now().isAfter(expiresAt)) {
            await clearCheckIn();
            return;
          }
        }
      } else {
        _statusController.add(LocationTrackingStatus.idle);
      }
    } catch (_) {
      _statusController.add(LocationTrackingStatus.idle);
    }
  }

  Future<void> stopTracking() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
    _statusController.add(LocationTrackingStatus.idle);
  }

  Future<void> setBackgroundMode(bool background) async {
    // No-op per Apple Guideline 5.1.2(i): automatic background location is removed.
    // Live sessions pause naturally when the OS suspends the app.
  }

  Future<int?> _readBatteryLevel() async {
    final now = DateTime.now();
    if (_lastBatteryReadAt != null &&
        now.difference(_lastBatteryReadAt!) < const Duration(minutes: 5)) {
      return _cachedBatteryLevel;
    }
    try {
      _cachedBatteryLevel = (await _battery.batteryLevel).clamp(0, 100);
      _lastBatteryReadAt = now;
    } catch (_) {
      _cachedBatteryLevel = null;
    }
    return _cachedBatteryLevel;
  }

  Future<Map<String, LocationModel>> getVisibleFriendLocationsOnce() async {
    final uid = _requireCurrentUid();
    final profile = await _db.collection('users').doc(uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    final blocked = (data['blockedUsers'] as Iterable? ?? const <dynamic>[])
        .whereType<String>()
        .toSet();
    final friendIds = (data['friends'] as Iterable? ?? const <dynamic>[])
        .whereType<String>()
        .where((friendUid) => !blocked.contains(friendUid))
        .toSet();
    final results = <String, LocationModel>{};
    await Future.wait(friendIds.map((friendUid) async {
      try {
        final snapshot = await _locationRef(friendUid).get();
        if (!snapshot.exists) return;
        final location = LocationModel.fromFirestore(snapshot);
        if (location.isSharing && location.hasCoordinate && !location.isExpired) {
          results[friendUid] = location;
        }
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }));
    return results;
  }

  Future<String> getUserDisplayName(String uid) async {
    try {
      final snapshot = await _db.collection('users').doc(uid).get();
      final data = snapshot.data();
      return data?['displayName'] as String? ??
          data?['username'] as String? ??
          'Bạn bè';
    } catch (_) {
      return 'Bạn bè';
    }
  }

  Future<void> dispose() async {
    await stopLiveSharing(clearFirestore: false);
    await stopTracking();
    await _statusController.close();
  }
}
