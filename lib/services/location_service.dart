import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_model.dart';
import 'location_policy.dart';

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
      if (!location.isSharing || !location.hasCoordinate) return null;
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

    // On iOS/Android, whileInUse is granted first. We try requesting always,
    // but both whileInUse and always are fully supported for location tracking.
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

  /// Manual Check-in per Apple Guideline 5.1.2(i):
  /// Captures single current GPS fix and shares it with close friends on the map.
  /// No automatic check-in or continuous background loop.
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
    );

    _statusController.add(LocationTrackingStatus.tracking);
    return model;
  }

  /// Removes the user's location from the map (Ghost Mode / Clear Check-In).
  Future<void> clearCheckIn() async {
    final uid = _requireCurrentUid();
    await _locationRef(uid).set({
      'ownerUid': uid,
      'isSharing': false,
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
    // Per Apple Guideline 5.1.2(i), automatic continuous tracking is disabled.
    // Users must manually check in each time they wish to display location on a map.
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final existing = await _locationRef(uid).get();
      if (existing.exists && existing.data()?['isSharing'] == true) {
        _statusController.add(LocationTrackingStatus.tracking);
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
        if (location.isSharing && location.hasCoordinate) {
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
    await stopTracking();
    await _statusController.close();
  }
}
