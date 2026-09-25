import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationModel {
  final String uid;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double accuracy;
  final double speed;
  final int? batteryLevel;
  final bool isSharing;
  final bool isOnline;
  final List<String> allowedViewers;

  /// True while a timed Live Location session is actively streaming.
  final bool liveSessionActive;

  /// When the live session expires (null = unlimited / not live).
  final DateTime? shareExpiresAt;

  /// Pinned place metadata (Zenly Dwell Time)
  final String? currentPlaceType;
  final String? currentPlaceLabel;
  final DateTime? arrivedAt;

  const LocationModel({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.accuracy,
    required this.speed,
    required this.isSharing,
    this.isOnline = true,
    this.batteryLevel,
    this.allowedViewers = const [],
    this.liveSessionActive = false,
    this.shareExpiresAt,
    this.currentPlaceType,
    this.currentPlaceLabel,
    this.arrivedAt,
  });

  factory LocationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return LocationModel.fromMap(doc.data() ?? const <String, dynamic>{}, uid: doc.id);
  }

  factory LocationModel.fromRealtimeSnapshot(DataSnapshot snapshot) {
    final raw = snapshot.value;
    if (raw == null || raw is! Map) {
      return LocationModel(
        uid: snapshot.key ?? '',
        lat: 0.0,
        lng: 0.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        accuracy: 0.0,
        speed: 0.0,
        isSharing: false,
        isOnline: false,
      );
    }
    final data = Map<String, dynamic>.from(raw);
    return LocationModel.fromMap(data, uid: snapshot.key ?? '');
  }

  factory LocationModel.fromMap(Map<String, dynamic> data, {String uid = ''}) {
    final geo = data['geo'];
    final updatedAt = data['updatedAt'];
    final capturedAt = data['capturedAt'];

    DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(0);
    if (updatedAt is Timestamp) {
      timestamp = updatedAt.toDate();
    } else if (updatedAt is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    } else if (capturedAt is Timestamp) {
      timestamp = capturedAt.toDate();
    } else if (capturedAt is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(capturedAt);
    } else if (data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    } else if (data['timestamp'] is String) {
      timestamp = DateTime.tryParse(data['timestamp'] as String) ?? timestamp;
    }

    double lat = 0.0;
    double lng = 0.0;
    if (geo is GeoPoint) {
      lat = geo.latitude;
      lng = geo.longitude;
    } else {
      lat = _asDouble(data['lat']);
      lng = _asDouble(data['lng']);
    }

    final speed = _asDouble(data['speed']).clamp(0.0, 200.0);
    final battery = _asInt(data['batteryLevel'])?.clamp(0, 100);

    DateTime? shareExpiresAt;
    final raw = data['shareExpiresAt'];
    if (raw is Timestamp) {
      shareExpiresAt = raw.toDate();
    } else if (raw is int) {
      shareExpiresAt = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is String) {
      shareExpiresAt = DateTime.tryParse(raw);
    }

    DateTime? arrivedAt;
    final rawArrivedAt = data['arrivedAt'];
    if (rawArrivedAt is Timestamp) {
      arrivedAt = rawArrivedAt.toDate();
    } else if (rawArrivedAt is int) {
      arrivedAt = DateTime.fromMillisecondsSinceEpoch(rawArrivedAt);
    } else if (rawArrivedAt is String) {
      arrivedAt = DateTime.tryParse(rawArrivedAt);
    }

    final isOnline = data.containsKey('isOnline') ? _asBool(data['isOnline']) : true;

    return LocationModel(
      uid: data['uid']?.toString() ?? data['ownerUid']?.toString() ?? uid,
      lat: lat,
      lng: lng,
      timestamp: timestamp,
      accuracy: _asDouble(data['accuracy']),
      speed: speed,
      batteryLevel: battery,
      isSharing: _asBool(data['isSharing']),
      isOnline: isOnline,
      allowedViewers: _readStringList(data['allowedViewers']),
      liveSessionActive: _asBool(data['liveSessionActive']),
      shareExpiresAt: shareExpiresAt,
      currentPlaceType: data['currentPlaceType']?.toString(),
      currentPlaceLabel: data['currentPlaceLabel']?.toString(),
      arrivedAt: arrivedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'ownerUid': uid,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'accuracy': accuracy,
      'speed': speed,
      'batteryLevel': batteryLevel,
      'isSharing': isSharing,
      'isOnline': isOnline,
      'allowedViewers': allowedViewers,
      'liveSessionActive': liveSessionActive,
      'shareExpiresAt': shareExpiresAt?.millisecondsSinceEpoch,
      'currentPlaceType': currentPlaceType,
      'currentPlaceLabel': currentPlaceLabel,
      'arrivedAt': arrivedAt?.millisecondsSinceEpoch,
    };
  }

  bool get hasCoordinate =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
      !(lat == 0 && lng == 0);

  /// True when this model represents an active live streaming session.
  bool get isLive => isSharing && liveSessionActive;

  /// True when the live session has a deadline that has already passed.
  bool get isExpired {
    final exp = shareExpiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  bool get hasPlace => currentPlaceType != null || currentPlaceLabel != null;

  String? get placeEmoji {
    if (currentPlaceType == null) return null;
    switch (currentPlaceType!.toLowerCase()) {
      case 'home':
        return '🏠';
      case 'work':
        return '🏢';
      case 'school':
        return '🏫';
      default:
        return '📍';
    }
  }

  String? get dwellDurationText {
    final arr = arrivedAt;
    if (arr == null) return null;
    final diff = DateTime.now().difference(arr);
    if (diff.isNegative || diff.inMinutes < 1) return 'Vừa đến';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (minutes == 0) return '$hours giờ';
      return '${hours}g ${minutes}p';
    }
    return '${diff.inDays} ngày';
  }

  bool isStale({DateTime? now, Duration maxAge = const Duration(minutes: 10)}) {
    final effectiveNow = now ?? DateTime.now();
    return effectiveNow.difference(timestamp) > maxAge;
  }

  Map<String, dynamic> toFirestore({required DateTime capturedAt}) {
    return {
      'ownerUid': uid,
      'geo': GeoPoint(lat, lng),
      'updatedAt': FieldValue.serverTimestamp(),
      'capturedAt': Timestamp.fromDate(capturedAt),
      'accuracy': accuracy,
      'speed': speed,
      'batteryLevel': batteryLevel,
      'isSharing': isSharing,
      'isOnline': isOnline,
      'allowedViewers': allowedViewers,
      'liveSessionActive': liveSessionActive,
      'currentPlaceType': currentPlaceType,
      'currentPlaceLabel': currentPlaceLabel,
      'arrivedAt': arrivedAt != null ? Timestamp.fromDate(arrivedAt!) : null,
    };
  }

  LocationModel copyWith({
    double? lat,
    double? lng,
    DateTime? timestamp,
    double? accuracy,
    double? speed,
    int? batteryLevel,
    bool? isSharing,
    bool? isOnline,
    List<String>? allowedViewers,
    bool? liveSessionActive,
    Object? shareExpiresAt = _sentinel,
    Object? currentPlaceType = _sentinel,
    Object? currentPlaceLabel = _sentinel,
    Object? arrivedAt = _sentinel,
  }) {
    return LocationModel(
      uid: uid,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isSharing: isSharing ?? this.isSharing,
      isOnline: isOnline ?? this.isOnline,
      allowedViewers: allowedViewers ?? this.allowedViewers,
      liveSessionActive: liveSessionActive ?? this.liveSessionActive,
      shareExpiresAt: shareExpiresAt == _sentinel
          ? this.shareExpiresAt
          : shareExpiresAt as DateTime?,
      currentPlaceType: currentPlaceType == _sentinel
          ? this.currentPlaceType
          : currentPlaceType as String?,
      currentPlaceLabel: currentPlaceLabel == _sentinel
          ? this.currentPlaceLabel
          : currentPlaceLabel as String?,
      arrivedAt: arrivedAt == _sentinel
          ? this.arrivedAt
          : arrivedAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

List<String> _readStringList(dynamic value) {
  if (value is! Iterable) return const [];
  return value.whereType<String>().toSet().toList(growable: false);
}

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int? _asInt(dynamic value) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}
