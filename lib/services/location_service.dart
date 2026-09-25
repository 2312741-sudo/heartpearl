import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_model.dart';
import 'location_policy.dart';
import 'location_sharing_duration.dart';
import 'places_service.dart';

// MethodChannel bridge to the native Significant-Change relay (iOS only).
// All calls are fire-and-forget wrapped in try/catch — Android and Simulator
// will silently no-op when the channel is not implemented.
const MethodChannel _bgLocationChannel =
    MethodChannel('com.heartpearl.app/background_location');

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
  static const String rtdbUrl =
      'https://tamchau-865f3.asia-southeast1.firebasedatabase.app';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Battery _battery;
  final FirebaseDatabase _rtdb;
  final PlacesService _placesService;
  final StreamController<LocationTrackingStatus> _statusController =
      StreamController<LocationTrackingStatus>.broadcast();

  StreamSubscription<Position>? _liveSubscription;
  Timer? _expiryTimer;
  Timer? _heartbeatTimer;
  LocationSharingDuration? _currentDuration;
  DateTime? _currentExpiresAt;
  DateTime? _lastBatteryReadAt;
  int? _cachedBatteryLevel;
  double? _lastWrittenLat;
  double? _lastWrittenLng;
  DateTime? _lastWrittenAt;
  DateTime? _lastFirestoreSyncAt;

  // Zenly Dwell Time Engine State
  String? _currentPlaceId;
  String? _currentPlaceType;
  String? _currentPlaceLabel;
  DateTime? _arrivedAt;

  // Adaptive battery saver state (Zenly / Life360 pattern)
  bool _isStationary = false;
  Position? _stationaryAnchor;
  DateTime? _stationarySince;
  LocationPermission? _lastPermission;

  final _positionStreamController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionStreamController.stream;

  bool get isStationary => _isStationary;
  LocationPermission? get lastPermission => _lastPermission;

  /// Checks if background "Always" location permission is granted.
  Future<bool> hasAlwaysPermission() async {
    final perm = await Geolocator.checkPermission();
    _lastPermission = perm;
    return perm == LocationPermission.always;
  }

  /// Opens device App Settings so user can grant "Always" location permission.
  Future<bool> openLocationSettings() => Geolocator.openAppSettings();

  /// Safe status emitter — no-ops if the controller has already been closed.
  void _addStatus(LocationTrackingStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  LocationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Battery? battery,
    FirebaseDatabase? rtdb,
    PlacesService? placesService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _battery = battery ?? Battery(),
       _rtdb = rtdb ?? _initRtdb(),
       _placesService = placesService ?? PlacesService() {
    try {
      _rtdb.setPersistenceEnabled(true);
    } catch (_) {}
  }

  static FirebaseDatabase _initRtdb() {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: rtdbUrl,
        );
      }
      return FirebaseDatabase.instance;
    } catch (_) {
      return FirebaseDatabase.instance;
    }
  }

  Stream<LocationTrackingStatus> get statusStream => _statusController.stream;

  /// Whether a live streaming session is currently active in this service instance.
  bool get isLiveActive => _liveSubscription != null;

  /// Current authenticated user ID, if signed in.
  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _locationRef(String uid) =>
      _db.collection(collectionName).doc(uid);

  DatabaseReference _rtdbLocationRef(String uid) => _rtdb.ref('locations/$uid');

  String _requireCurrentUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để chia sẻ vị trí.');
    }
    return uid;
  }

  /// Evaluates whether coordinates match a pinned place and manages dwell arrival time.
  void _evaluateDwellPlace(double lat, double lng, double speed) {
    // If moving fast (> 15 km/h ~ 4.2 m/s), user is definitely in transit
    if (speed > 4.2) {
      _currentPlaceId = null;
      _currentPlaceType = null;
      _currentPlaceLabel = null;
      _arrivedAt = null;
      return;
    }

    final matched = _placesService.findMatchingPlace(
      lat: lat,
      lng: lng,
      currentPlaceId: _currentPlaceId,
    );

    if (matched != null) {
      if (_currentPlaceId == matched.id) {
        // Still at the same place: keep previous arrival timestamp!
      } else {
        // New place arrival
        _currentPlaceId = matched.id;
        _currentPlaceType = matched.type.name;
        _currentPlaceLabel = matched.label;
        _arrivedAt = DateTime.now();
      }
    } else {
      _currentPlaceId = null;
      _currentPlaceType = null;
      _currentPlaceLabel = null;
      _arrivedAt = null;
    }
  }

  /// Streams own location updates via Firebase Realtime Database.
  Stream<LocationModel?> streamOwnLocation() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return Stream.value(null);
    return _rtdbLocationRef(uid).onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return null;
      return LocationModel.fromRealtimeSnapshot(snapshot);
    });
  }

  /// Streams a friend's location updates via Firebase Realtime Database.
  /// Subscriptions receive low-latency (~30-50ms) push updates with onDisconnect awareness.
  Stream<LocationModel?> streamFriendLocation(String friendUid) {
    final cleanUid = friendUid.trim();
    if (cleanUid.isEmpty) return Stream.value(null);
    return _rtdbLocationRef(cleanUid).onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return null;
      final location = LocationModel.fromRealtimeSnapshot(snapshot);
      // Respect expiry server-side: if expired, treat as not sharing.
      if (!location.isSharing || !location.hasCoordinate || location.isExpired) {
        return null;
      }
      return location;
    });
  }

  Future<LocationModel?> getOwnLocation() async {
    final uid = _requireCurrentUid();
    final snapshot = await _rtdbLocationRef(uid).get();
    if (snapshot.exists && snapshot.value != null) {
      return LocationModel.fromRealtimeSnapshot(snapshot);
    }
    final doc = await _locationRef(uid).get();
    return doc.exists ? LocationModel.fromFirestore(doc) : null;
  }

  Future<LocationPermission> requestSharingPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _addStatus(LocationTrackingStatus.serviceDisabled);
      throw const LocationTrackingException(
        'Dịch vụ vị trí đang tắt. Hãy bật vị trí trong Cài đặt.',
        LocationTrackingStatus.serviceDisabled,
      );
    }

    _addStatus(LocationTrackingStatus.requestingPermission);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _lastPermission = permission;
      _addStatus(LocationTrackingStatus.permissionDeniedForever);
      throw const LocationTrackingException(
        'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở Cài đặt ứng dụng.',
        LocationTrackingStatus.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      _lastPermission = permission;
      _addStatus(LocationTrackingStatus.permissionDenied);
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
    _lastPermission = permission;
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      _addStatus(LocationTrackingStatus.permissionDenied);
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
  // Manual Check-In (per Apple Guideline 5.1.2(i))
  // ---------------------------------------------------------------------------

  /// Manual Check-in: captures a single GPS fix on explicit user tap.
  Future<LocationModel> checkIn() async {
    final uid = _requireCurrentUid();
    await requestSharingPermission();

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }

    if (position == null ||
        !LocationPolicy.isValidFix(
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
        )) {
      throw Exception('Tọa độ GPS không hợp lệ hoặc chưa sẵn sàng. Vui lòng thử lại.');
    }

    final battery = await _readBatteryLevel();
    final now = DateTime.now();
    final speed = position.speed.isFinite && position.speed > 0
        ? position.speed.clamp(0, 200).toDouble()
        : 0.0;

    _evaluateDwellPlace(position.latitude, position.longitude, speed);

    // 1. Setup onDisconnect & write to RTDB
    final rtdbRef = _rtdbLocationRef(uid);
    try {
      await rtdbRef.onDisconnect().update({
        'isOnline': false,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}

    await rtdbRef.update({
      'ownerUid': uid,
      'isSharing': true,
      'isOnline': true,
      'liveSessionActive': false,
      'shareExpiresAt': null,
      'shareDurationLabel': null,
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'speed': speed,
      'batteryLevel': battery,
      'capturedAt': now.millisecondsSinceEpoch,
      'updatedAt': ServerValue.timestamp,
      'currentPlaceType': _currentPlaceType,
      'currentPlaceLabel': _currentPlaceLabel,
      'arrivedAt': _arrivedAt?.millisecondsSinceEpoch,
    });

    // 2. Dual-write to Firestore for backward compatibility
    try {
      final firestoreData = <String, dynamic>{
        'ownerUid': uid,
        'isSharing': true,
        'isOnline': true,
        'liveSessionActive': false,
        'shareExpiresAt': FieldValue.delete(),
        'shareDurationLabel': FieldValue.delete(),
        'geo': GeoPoint(position.latitude, position.longitude),
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': speed,
        'batteryLevel': ?battery,
        'capturedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'currentPlaceType': _currentPlaceType,
        'currentPlaceLabel': _currentPlaceLabel,
        'arrivedAt': _arrivedAt != null ? Timestamp.fromDate(_arrivedAt!) : FieldValue.delete(),
      };
      await _locationRef(uid).set(firestoreData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore checkIn sync warning: $e');
    }

    _lastWrittenLat = position.latitude;
    _lastWrittenLng = position.longitude;
    _lastWrittenAt = now;

    final model = LocationModel(
      uid: uid,
      lat: position.latitude,
      lng: position.longitude,
      timestamp: now,
      accuracy: position.accuracy,
      speed: position.speed,
      batteryLevel: battery,
      isSharing: true,
      isOnline: true,
      liveSessionActive: false,
      currentPlaceType: _currentPlaceType,
      currentPlaceLabel: _currentPlaceLabel,
      arrivedAt: _arrivedAt,
    );

    _addStatus(LocationTrackingStatus.tracking);
    return model;
  }

  // ---------------------------------------------------------------------------
  // Live Location Sharing (Zenly Architecture via RTDB)
  // ---------------------------------------------------------------------------

  /// Starts a live location streaming session for the chosen [duration].
  Future<void> startLiveSharing(LocationSharingDuration duration) async {
    // Stop any existing live session first.
    await stopLiveSharing(clearFirestore: false);

    final uid = _requireCurrentUid();
    await requestSharingPermission();

    // Reset stationary tracking state
    _isStationary = false;
    _stationarySince = DateTime.now();

    // Get initial fix to write immediately with graceful fallback.
    Position? initialPosition;
    try {
      initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      initialPosition = await Geolocator.getLastKnownPosition();
    }

    if (initialPosition == null ||
        !LocationPolicy.isValidFix(
          lat: initialPosition.latitude,
          lng: initialPosition.longitude,
          accuracy: initialPosition.accuracy,
        )) {
      throw Exception('Tọa độ GPS không hợp lệ hoặc chưa sẵn sàng. Vui lòng kiểm tra lại GPS.');
    }

    _stationaryAnchor = initialPosition;
    final expiresAt = duration.expiresAt();

    // Broadcast initial position immediately for local map rendering
    _positionStreamController.add(initialPosition);

    // Write initial position + session metadata to RTDB & Firestore.
    final battery = await _readBatteryLevel();
    await _writeLivePosition(uid, initialPosition, expiresAt, duration, battery, forceFirestore: true);

    // Delegate all streaming / heartbeat / expiry wiring to shared helper.
    await _beginLiveStream(uid, expiresAt, duration);
  }

  /// Core live-stream wiring shared by [startLiveSharing] and
  /// [resumeLiveSharingIfNeeded].
  Future<void> _beginLiveStream(
    String uid,
    DateTime? expiresAt,
    LocationSharingDuration duration,
  ) async {
    _currentDuration = duration;
    _currentExpiresAt = expiresAt;

    // Register onDisconnect hook in RTDB
    try {
      await _rtdbLocationRef(uid).onDisconnect().update({
        'isOnline': false,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}

    // Activate native Significant-Change relay so iOS can recover the session
    // after a system-kill (best-effort — silently ignored on Android/Simulator).
    try {
      await _bgLocationChannel.invokeMethod<void>('startRelay');
    } catch (_) {}

    // Start streaming position updates (initially in active moving mode)
    _startLiveSubscription(uid, expiresAt, duration, isStationary: false);

    // Start heartbeat timer
    _armHeartbeatTimer(uid, expiresAt, duration, isStationary: false);

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

  void _startLiveSubscription(
    String uid,
    DateTime? expiresAt,
    LocationSharingDuration duration, {
    required bool isStationary,
  }) {
    _liveSubscription?.cancel();
    final settings = _buildLiveSettings(isStationary: isStationary);

    _liveSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) => _onLivePosition(uid, position, expiresAt, duration),
      onError: (Object error) {
        debugPrint('[LocationService] Live stream error: $error — restarting in 5s');
        _addStatus(LocationTrackingStatus.error);
        _liveSubscription?.cancel();
        _liveSubscription = null;
        if (_heartbeatTimer != null && _currentDuration != null) {
          Future.delayed(const Duration(seconds: 5), () {
            if (_heartbeatTimer != null && _currentDuration != null) {
              _startLiveSubscription(
                uid,
                expiresAt,
                duration,
                isStationary: _isStationary,
              );
            }
          });
        }
      },
      cancelOnError: true,
    );
    _addStatus(LocationTrackingStatus.tracking);
  }

  void _armHeartbeatTimer(
    String uid,
    DateTime? expiresAt,
    LocationSharingDuration duration, {
    required bool isStationary,
  }) {
    _heartbeatTimer?.cancel();
    // In stationary sleep mode: ping every 3 minutes.
    // In moving active mode: ping every 45 seconds.
    final interval = isStationary
        ? const Duration(minutes: 3)
        : const Duration(seconds: 45);

    _heartbeatTimer = Timer.periodic(interval, (_) async {
      if (_liveSubscription == null) return;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        await stopLiveSharing(clearFirestore: true);
        return;
      }
      try {
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: isStationary ? LocationAccuracy.medium : LocationAccuracy.high,
              timeLimit: const Duration(seconds: 8),
            ),
          );
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }
        if (pos != null &&
            LocationPolicy.isValidFix(
              lat: pos.latitude,
              lng: pos.longitude,
              accuracy: pos.accuracy,
            )) {
          final battery = await _readBatteryLevel();
          await _heartbeatWrite(uid, pos, expiresAt, duration, battery);
        }
      } catch (_) {}
    });
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
    _currentExpiresAt = null;
    _lastWrittenLat = null;
    _lastWrittenLng = null;
    _lastWrittenAt = null;
    _lastFirestoreSyncAt = null;
    _currentPlaceId = null;
    _currentPlaceType = null;
    _currentPlaceLabel = null;
    _arrivedAt = null;
    _isStationary = false;
    _stationaryAnchor = null;
    _stationarySince = null;
    await sub?.cancel();

    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _rtdbLocationRef(uid).onDisconnect().cancel();
      } catch (_) {}
    }

    // Stop native Significant-Change relay (best-effort — no-op on Android/Simulator).
    try {
      await _bgLocationChannel.invokeMethod<void>('stopRelay');
    } catch (_) {}

    if (clearFirestore && uid != null && uid.isNotEmpty) {
      // Clear RTDB
      try {
        await _rtdbLocationRef(uid).update({
          'ownerUid': uid,
          'isSharing': false,
          'isOnline': false,
          'liveSessionActive': false,
          'shareExpiresAt': null,
          'shareDurationLabel': null,
          'lat': null,
          'lng': null,
          'capturedAt': null,
          'accuracy': null,
          'speed': null,
          'batteryLevel': null,
          'currentPlaceType': null,
          'currentPlaceLabel': null,
          'arrivedAt': null,
          'updatedAt': ServerValue.timestamp,
        });
      } catch (error) {
        debugPrint('stopLiveSharing RTDB error: $error');
      }

      // Clear Firestore
      try {
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
          'currentPlaceType': FieldValue.delete(),
          'currentPlaceLabel': FieldValue.delete(),
          'arrivedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error) {
        debugPrint('stopLiveSharing Firestore error: $error');
      }
      _addStatus(LocationTrackingStatus.idle);
    }
  }

  /// Returns remaining time string for the active session, or null.
  String? liveCountdown(String lang) {
    return _currentDuration?.countdownLabel(lang, fixedExpiresAt: _currentExpiresAt);
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

    // Filter out noisy low-accuracy jitter (e.g. indoors/tunnels where error circle > 65m)
    if (position.accuracy > 65.0) {
      return;
    }

    final now = DateTime.now();
    final speed = position.speed.isFinite && position.speed > 0
        ? position.speed.clamp(0, 200).toDouble()
        : 0.0;

    _evaluateDwellPlace(position.latitude, position.longitude, speed);

    // Broadcast raw position immediately for zero-latency local map rendering
    _positionStreamController.add(position);

    // Anchor tracking for stationary sleep vs moving wake-up
    _stationaryAnchor ??= position;
    final distFromAnchor = LocationPolicy.distanceMetres(
      _stationaryAnchor!.latitude,
      _stationaryAnchor!.longitude,
      position.latitude,
      position.longitude,
    );

    // 1. Stationary vs Moving State Machine (Adaptive Battery Saver)
    final appearsStationary = speed < 0.6 && distFromAnchor < 25.0;

    if (appearsStationary) {
      _stationarySince ??= now;
      final stillFor = now.difference(_stationarySince!);

      // If still for >= 2 minutes, switch to low-power sleep mode
      if (!_isStationary && stillFor >= const Duration(minutes: 2)) {
        _isStationary = true;
        debugPrint('[LocationService] Switching to stationary sleep mode at '
            '(${position.latitude}, ${position.longitude})');
        _startLiveSubscription(uid, expiresAt, duration, isStationary: true);
        _armHeartbeatTimer(uid, expiresAt, duration, isStationary: true);
      }
    } else {
      // User is moving: walking speed (>= 0.8 m/s ~ 2.9 km/h) or moved > 25m from anchor
      final isMoving = speed >= 0.8 || distFromAnchor >= 25.0;
      if (isMoving) {
        _stationaryAnchor = position;
        _stationarySince = null;

        if (_isStationary) {
          // Wake up to high-accuracy moving mode!
          _isStationary = false;
          debugPrint('[LocationService] Waking up from sleep mode: motion detected '
              '(speed: ${speed.toStringAsFixed(1)} m/s, dist: ${distFromAnchor.toStringAsFixed(1)}m)');
          _startLiveSubscription(uid, expiresAt, duration, isStationary: false);
          _armHeartbeatTimer(uid, expiresAt, duration, isStationary: false);
        }
      }
    }

    // 2. Adaptive Motion & Distance Gate for writes:
    final lastLat = _lastWrittenLat;
    final lastLng = _lastWrittenLng;
    final lastAt = _lastWrittenAt;
    if (lastLat != null && lastLng != null && lastAt != null) {
      final dist = LocationPolicy.distanceMetres(
        lastLat,
        lastLng,
        position.latitude,
        position.longitude,
      );
      final elapsed = now.difference(lastAt);

      if (_isStationary) {
        // While stationary: update if moved >= 15m or every 45s
        if (dist < 15.0 && elapsed < const Duration(seconds: 45)) {
          return;
        }
      } else {
        // While moving: write if moved >= 5m OR every 4s
        if (dist < 5.0 && elapsed < const Duration(seconds: 4)) {
          return;
        }
      }
    }

    _readBatteryLevel().then((battery) {
      if (_liveSubscription == null) return;
      _writeLivePosition(uid, position, expiresAt, duration, battery);
    });
  }

  Future<void> _writeLivePosition(
    String uid,
    Position position,
    DateTime? expiresAt,
    LocationSharingDuration duration,
    int? battery, {
    bool forceFirestore = false,
  }) async {
    try {
      final speed = position.speed.isFinite && position.speed > 0
          ? position.speed.clamp(0, 200).toDouble()
          : 0.0;

      _evaluateDwellPlace(position.latitude, position.longitude, speed);

      // Ensure RTDB connection is active
      try {
        _rtdb.goOnline();
      } catch (_) {}

      // 1. Write to RTDB (Instant WebSocket ~30ms, no per-write cost) with 6s timeout
      await _rtdbLocationRef(uid).update({
        'ownerUid': uid,
        'isSharing': true,
        'isOnline': true,
        'liveSessionActive': true,
        'shareDurationLabel': duration.firestoreLabel,
        'shareExpiresAt': expiresAt?.millisecondsSinceEpoch,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': speed,
        'batteryLevel': battery,
        'capturedAt': position.timestamp.millisecondsSinceEpoch,
        'updatedAt': ServerValue.timestamp,
        'currentPlaceType': _currentPlaceType,
        'currentPlaceLabel': _currentPlaceLabel,
        'arrivedAt': _arrivedAt?.millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 6));

      _lastWrittenLat = position.latitude;
      _lastWrittenLng = position.longitude;
      final now = DateTime.now();
      _lastWrittenAt = now;
      _addStatus(LocationTrackingStatus.tracking);

      // 2. Dual-sync to Firestore only every 2 minutes or on session start
      if (forceFirestore ||
          _lastFirestoreSyncAt == null ||
          now.difference(_lastFirestoreSyncAt!) >= const Duration(minutes: 2)) {
        _lastFirestoreSyncAt = now;
        try {
          await _locationRef(uid).set({
            'ownerUid': uid,
            'isSharing': true,
            'isOnline': true,
            'liveSessionActive': true,
            'shareDurationLabel': duration.firestoreLabel,
            'shareExpiresAt':
                expiresAt != null ? Timestamp.fromDate(expiresAt) : FieldValue.delete(),
            'geo': GeoPoint(position.latitude, position.longitude),
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy': position.accuracy,
            'speed': speed,
            'batteryLevel': battery,
            'capturedAt': Timestamp.fromDate(position.timestamp),
            'updatedAt': FieldValue.serverTimestamp(),
            'currentPlaceType': _currentPlaceType,
            'currentPlaceLabel': _currentPlaceLabel,
            'arrivedAt': _arrivedAt != null ? Timestamp.fromDate(_arrivedAt!) : FieldValue.delete(),
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
        } catch (e) {
          debugPrint('Firestore dual-sync warning: $e');
        }
      }
    } catch (error) {
      debugPrint('Live write failed: $error');
      _addStatus(LocationTrackingStatus.error);
    }
  }

  /// Writes a fresh position to RTDB for heartbeat purposes.
  Future<void> _heartbeatWrite(
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

      _evaluateDwellPlace(position.latitude, position.longitude, speed);

      try {
        _rtdb.goOnline();
      } catch (_) {}

      await _rtdbLocationRef(uid).update({
        'ownerUid': uid,
        'isSharing': true,
        'isOnline': true,
        'liveSessionActive': true,
        'shareDurationLabel': duration.firestoreLabel,
        'shareExpiresAt': expiresAt?.millisecondsSinceEpoch,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': speed,
        'batteryLevel': battery,
        'capturedAt': position.timestamp.millisecondsSinceEpoch,
        'updatedAt': ServerValue.timestamp,
        'currentPlaceType': _currentPlaceType,
        'currentPlaceLabel': _currentPlaceLabel,
        'arrivedAt': _arrivedAt?.millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 6));
      _addStatus(LocationTrackingStatus.tracking);
    } catch (error) {
      debugPrint('Heartbeat write failed: $error');
    }
  }

  LocationSettings _buildLiveSettings({bool isStationary = false}) {
    final bool hasAlways = _lastPermission == LocationPermission.always;
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: isStationary ? LocationAccuracy.medium : LocationAccuracy.high,
        distanceFilter: isStationary ? 25 : 5,
        intervalDuration: Duration(seconds: isStationary ? 45 : 4),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'HeartPearl Live',
          notificationText: 'Đang chia sẻ vị trí trực tiếp với bạn bè',
          notificationChannelName: 'Chia sẻ vị trí trực tiếp',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: isStationary ? LocationAccuracy.medium : LocationAccuracy.bestForNavigation,
        distanceFilter: isStationary ? 25 : 5,
        activityType: isStationary ? ActivityType.other : ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: !hasAlways,
        allowBackgroundLocationUpdates: true,
      );
    }
    return LocationSettings(
      accuracy: isStationary ? LocationAccuracy.medium : LocationAccuracy.high,
      distanceFilter: isStationary ? 25 : 5,
    );
  }

  // ---------------------------------------------------------------------------
  // Ghost Mode / Clear Check-In
  // ---------------------------------------------------------------------------

  /// Removes the user's location from the map (Ghost Mode).
  /// Also stops any active live session.
  Future<void> clearCheckIn() async {
    if (isLiveActive) await stopLiveSharing(clearFirestore: false);
    _lastWrittenLat = null;
    _lastWrittenLng = null;
    _lastWrittenAt = null;
    _lastFirestoreSyncAt = null;
    _currentPlaceId = null;
    _currentPlaceType = null;
    _currentPlaceLabel = null;
    _arrivedAt = null;

    final uid = _requireCurrentUid();
    try {
      await _rtdbLocationRef(uid).onDisconnect().cancel();
    } catch (_) {}

    // Clear RTDB
    try {
      await _rtdbLocationRef(uid).update({
        'ownerUid': uid,
        'isSharing': false,
        'isOnline': false,
        'liveSessionActive': false,
        'shareExpiresAt': null,
        'shareDurationLabel': null,
        'lat': null,
        'lng': null,
        'capturedAt': null,
        'accuracy': null,
        'speed': null,
        'batteryLevel': null,
        'currentPlaceType': null,
        'currentPlaceLabel': null,
        'arrivedAt': null,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('clearCheckIn RTDB error: $e');
    }

    // Clear Firestore
    try {
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
        'currentPlaceType': FieldValue.delete(),
        'currentPlaceLabel': FieldValue.delete(),
        'arrivedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('clearCheckIn Firestore error: $e');
    }
    _addStatus(LocationTrackingStatus.idle);
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
      _addStatus(LocationTrackingStatus.error);
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

      try {
        await _rtdbLocationRef(uid).update({
          'ownerUid': uid,
          'allowedViewers': stored,
          'updatedAt': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('RTDB setAllowedViewers error: $e');
      }
    } catch (error) {
      throw Exception('Không thể cập nhật người được xem vị trí: $error');
    }
  }

  /// Resumes an active live session after app restart by re-opening the GPS
  /// position stream with the remaining expiry time.
  ///
  /// Called from [locationTrackingBootstrapProvider] at app startup. If no
  /// active session is found, emits [LocationTrackingStatus.idle].
  Future<void> resumeLiveSharingIfNeeded() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    // Don't open a second stream if one is already active.
    if (_liveSubscription != null) return;

    try {
      // ------ Try RTDB first (faster, cheaper) ------
      DateTime? expiresAt;
      String? durationLabel;
      bool found = false;

      final snapshot = await _rtdbLocationRef(uid).get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (data['isSharing'] == true) {
          final rawExpiry = data['shareExpiresAt'];
          if (rawExpiry is int) {
            expiresAt = DateTime.fromMillisecondsSinceEpoch(rawExpiry);
            if (DateTime.now().isAfter(expiresAt)) {
              await clearCheckIn();
              return;
            }
          }
          durationLabel = data['shareDurationLabel']?.toString();
          found = true;
        }
      }

      // ------ Fallback to Firestore ------
      if (!found) {
        final existing = await _locationRef(uid).get();
        final data = existing.data();
        if (existing.exists && data?['isSharing'] == true) {
          final rawExpiry = data?['shareExpiresAt'];
          if (rawExpiry is Timestamp) {
            expiresAt = rawExpiry.toDate();
            if (DateTime.now().isAfter(expiresAt)) {
              await clearCheckIn();
              return;
            }
          }
          durationLabel = data?['shareDurationLabel']?.toString();
          found = true;
        }
      }

      if (!found) {
        _addStatus(LocationTrackingStatus.idle);
        return;
      }

      // Resolve duration enum from persisted label
      final duration = switch (durationLabel) {
        '1h' => LocationSharingDuration.oneHour,
        'today' => LocationSharingDuration.untilEndOfDay,
        'unlimited' => LocationSharingDuration.unlimited,
        _ => LocationSharingDuration.unlimited,
      };

      // Ensure GPS permission is still granted
      await requestSharingPermission();

      // Flush any location captured by the native relay while the process was dead.
      // This updates RTDB/Firestore immediately so friends see the correct position.
      await flushPendingBackgroundLocation(uid, expiresAt, duration);

      // Reset stationary state
      _isStationary = false;
      _stationarySince = DateTime.now();
      _stationaryAnchor = null;

      // Re-open the live GPS stream with the remaining time
      await _beginLiveStream(uid, expiresAt, duration);
      debugPrint('[LocationService] Resumed live session — '
          'duration=$durationLabel, expiresAt=$expiresAt');
    } catch (e) {
      debugPrint('[LocationService] resumeLiveSharingIfNeeded error: $e');
      _addStatus(LocationTrackingStatus.idle);
    }
  }

  /// Reads the last position stored by [BackgroundLocationRelay] during a
  /// system-kill event and writes it to RTDB/Firestore.
  ///
  /// Only processes fixes that are less than 6 hours old. Clears the pending
  /// key from UserDefaults after a successful flush. Safe to call on Android
  /// or Simulator (will silently no-op if the channel is unavailable).
  Future<void> flushPendingBackgroundLocation(
    String uid,
    DateTime? expiresAt,
    LocationSharingDuration duration,
  ) async {
    try {
      final jsonString = await _bgLocationChannel
          .invokeMethod<String>('readPendingLocation');
      if (jsonString == null || jsonString.isEmpty) return;

      final Map<String, dynamic> payload =
          (jsonDecode(jsonString) as Map<Object?, Object?>)
              .map((k, v) => MapEntry(k.toString(), v));

      final double? lat   = (payload['lat']   as num?)?.toDouble();
      final double? lng   = (payload['lng']   as num?)?.toDouble();
      final double? acc   = (payload['accuracy'] as num?)?.toDouble();
      final double  spd   = ((payload['speed'] as num?) ?? 0).toDouble();
      final double? tsMs  = (payload['timestamp'] as num?)?.toDouble();

      if (lat == null || lng == null || acc == null || tsMs == null) return;

      final fixTime = DateTime.fromMillisecondsSinceEpoch(tsMs.toInt());
      final age     = DateTime.now().difference(fixTime);

      // Reject stale fixes (> 6 hours).
      if (age > const Duration(hours: 6)) {
        await _bgLocationChannel.invokeMethod<void>('clearPendingLocation');
        return;
      }

      // Reconstruct a Position-compatible object from the JSON payload.
      final position = Position(
        latitude:  lat,
        longitude: lng,
        accuracy:  acc,
        speed:     spd,
        heading:   0,
        altitude:  0,
        altitudeAccuracy: 0,
        headingAccuracy:  0,
        speedAccuracy:    0,
        timestamp: fixTime,
      );

      final battery = await _readBatteryLevel();
      await _writeLivePosition(
        uid, position, expiresAt, duration, battery,
        forceFirestore: true,
      );
      debugPrint('[LocationService] Flushed pending background location '
          '(age ${age.inMinutes}min) → ($lat, $lng)');

      await _bgLocationChannel.invokeMethod<void>('clearPendingLocation');
    } on MissingPluginException {
      // Channel not registered (Android, Simulator) — silently skip.
    } catch (e) {
      debugPrint('[LocationService] flushPendingBackgroundLocation error: $e');
    }
  }


  /// Legacy alias — forwards to [resumeLiveSharingIfNeeded].
  Future<void> startTracking() => resumeLiveSharingIfNeeded();

  Future<void> stopTracking() async {
    _addStatus(LocationTrackingStatus.idle);
  }

  Future<void> setBackgroundMode(bool background) async {
    if (!background && isLiveActive) {
      // Returned to foreground: ensure RTDB connection is online and sync latest fix
      try {
        _rtdb.goOnline();
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _currentDuration != null) {
          final uid = currentUid;
          if (uid != null) {
            final battery = await _readBatteryLevel();
            await _writeLivePosition(
              uid,
              lastKnown,
              _currentExpiresAt,
              _currentDuration!,
              battery,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<int?> _readBatteryLevel() async {
    final now = DateTime.now();
    if (_lastBatteryReadAt != null &&
        now.difference(_lastBatteryReadAt!) < const Duration(minutes: 15)) {
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
        final snapshot = await _rtdbLocationRef(friendUid).get();
        if (snapshot.exists && snapshot.value != null) {
          final location = LocationModel.fromRealtimeSnapshot(snapshot);
          if (location.isSharing && location.hasCoordinate && !location.isExpired) {
            results[friendUid] = location;
            return;
          }
        }
        final doc = await _locationRef(friendUid).get();
        if (doc.exists) {
          final location = LocationModel.fromFirestore(doc);
          if (location.isSharing && location.hasCoordinate && !location.isExpired) {
            results[friendUid] = location;
          }
        }
      } catch (error) {
        debugPrint('Error getting location for $friendUid: $error');
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
    await _positionStreamController.close();
  }
}
