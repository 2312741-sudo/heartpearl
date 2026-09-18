import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String uid;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double accuracy;
  final double speed;
  final int? batteryLevel;
  final bool isSharing;
  final List<String> allowedViewers;

  const LocationModel({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.accuracy,
    required this.speed,
    required this.isSharing,
    this.batteryLevel,
    this.allowedViewers = const [],
  });

  factory LocationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return LocationModel.fromMap(doc.data() ?? const <String, dynamic>{}, uid: doc.id);
  }

  factory LocationModel.fromMap(Map<String, dynamic> data, {String uid = ''}) {
    final geo = data['geo'];
    final updatedAt = data['updatedAt'];
    final capturedAt = data['capturedAt'];

    DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(0);
    if (updatedAt is Timestamp) {
      timestamp = updatedAt.toDate();
    } else if (capturedAt is Timestamp) {
      timestamp = capturedAt.toDate();
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

    return LocationModel(
      uid: data['uid']?.toString() ?? data['ownerUid']?.toString() ?? uid,
      lat: lat,
      lng: lng,
      timestamp: timestamp,
      accuracy: _asDouble(data['accuracy']),
      speed: speed,
      batteryLevel: battery,
      isSharing: _asBool(data['isSharing']),
      allowedViewers: _readStringList(data['allowedViewers']),
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
      'allowedViewers': allowedViewers,
    };
  }

  bool get hasCoordinate =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
      !(lat == 0 && lng == 0);

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
      'allowedViewers': allowedViewers,
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
    List<String>? allowedViewers,
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
      allowedViewers: allowedViewers ?? this.allowedViewers,
    );
  }
}

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
