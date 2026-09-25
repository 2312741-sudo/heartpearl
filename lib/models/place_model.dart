import 'package:cloud_firestore/cloud_firestore.dart';

enum PlaceType {
  home,
  work,
  school,
  custom;

  static PlaceType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'home':
        return PlaceType.home;
      case 'work':
        return PlaceType.work;
      case 'school':
        return PlaceType.school;
      default:
        return PlaceType.custom;
    }
  }

  String get displayName {
    switch (this) {
      case PlaceType.home:
        return 'Nhà';
      case PlaceType.work:
        return 'Nơi làm việc';
      case PlaceType.school:
        return 'Trường học';
      case PlaceType.custom:
        return 'Địa điểm';
    }
  }

  String get defaultEmoji {
    switch (this) {
      case PlaceType.home:
        return '🏠';
      case PlaceType.work:
        return '🏢';
      case PlaceType.school:
        return '🏫';
      case PlaceType.custom:
        return '📍';
    }
  }
}

class PlaceModel {
  final String id;
  final String ownerUid;
  final PlaceType type;
  final String label;
  final double lat;
  final double lng;
  final double radiusMetres;
  final String? customIcon;
  final DateTime createdAt;

  const PlaceModel({
    required this.id,
    required this.ownerUid,
    required this.type,
    required this.label,
    required this.lat,
    required this.lng,
    this.radiusMetres = 80.0,
    this.customIcon,
    required this.createdAt,
  });

  String get emoji => customIcon?.isNotEmpty == true ? customIcon! : type.defaultEmoji;

  factory PlaceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PlaceModel.fromMap(data, id: doc.id);
  }

  factory PlaceModel.fromMap(Map<String, dynamic> data, {String id = ''}) {
    DateTime createdAt = DateTime.now();
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? createdAt;
    }

    final rawLat = data['lat'];
    final rawLng = data['lng'];
    final lat = rawLat is num ? rawLat.toDouble() : 0.0;
    final lng = rawLng is num ? rawLng.toDouble() : 0.0;

    final rawRadius = data['radiusMetres'];
    final radius = rawRadius is num ? rawRadius.toDouble() : 80.0;

    return PlaceModel(
      id: data['id']?.toString() ?? id,
      ownerUid: data['ownerUid']?.toString() ?? '',
      type: PlaceType.fromString(data['type']?.toString()),
      label: data['label']?.toString() ?? '',
      lat: lat,
      lng: lng,
      radiusMetres: radius > 0 ? radius : 80.0,
      customIcon: data['customIcon']?.toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerUid': ownerUid,
      'type': type.name,
      'label': label,
      'lat': lat,
      'lng': lng,
      'radiusMetres': radiusMetres,
      'customIcon': customIcon,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'ownerUid': ownerUid,
      'type': type.name,
      'label': label,
      'lat': lat,
      'lng': lng,
      'radiusMetres': radiusMetres,
      'customIcon': customIcon,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PlaceModel copyWith({
    String? id,
    String? ownerUid,
    PlaceType? type,
    String? label,
    double? lat,
    double? lng,
    double? radiusMetres,
    String? customIcon,
    DateTime? createdAt,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      type: type ?? this.type,
      label: label ?? this.label,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMetres: radiusMetres ?? this.radiusMetres,
      customIcon: customIcon ?? this.customIcon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
