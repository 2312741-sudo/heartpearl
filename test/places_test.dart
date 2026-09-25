import 'package:flutter_test/flutter_test.dart';
import 'package:heartpearl/models/location_model.dart';
import 'package:heartpearl/models/place_model.dart';
import 'package:heartpearl/services/location_policy.dart';
import 'package:heartpearl/services/places_service.dart';

void main() {
  LocationModel createTestLocation({
    String uid = 'test_user',
    double lat = 10.7769,
    double lng = 106.7009,
    DateTime? timestamp,
    double accuracy = 5.0,
    double speed = 0.0,
    bool isSharing = true,
    String? currentPlaceType,
    String? currentPlaceLabel,
    DateTime? arrivedAt,
  }) {
    return LocationModel(
      uid: uid,
      lat: lat,
      lng: lng,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: accuracy,
      speed: speed,
      isSharing: isSharing,
      currentPlaceType: currentPlaceType,
      currentPlaceLabel: currentPlaceLabel,
      arrivedAt: arrivedAt,
    );
  }

  group('PlaceType Tests', () {
    test('fromString parses correctly and handles fallback', () {
      expect(PlaceType.fromString('home'), PlaceType.home);
      expect(PlaceType.fromString('Home'), PlaceType.home);
      expect(PlaceType.fromString('work'), PlaceType.work);
      expect(PlaceType.fromString('WORK'), PlaceType.work);
      expect(PlaceType.fromString('school'), PlaceType.school);
      expect(PlaceType.fromString('custom'), PlaceType.custom);
      expect(PlaceType.fromString('unknown_type'), PlaceType.custom);
      expect(PlaceType.fromString(null), PlaceType.custom);
    });

    test('displayName and defaultEmoji return expected values', () {
      expect(PlaceType.home.displayName, 'Nhà');
      expect(PlaceType.home.defaultEmoji, '🏠');

      expect(PlaceType.work.displayName, 'Nơi làm việc');
      expect(PlaceType.work.defaultEmoji, '🏢');

      expect(PlaceType.school.displayName, 'Trường học');
      expect(PlaceType.school.defaultEmoji, '🏫');

      expect(PlaceType.custom.displayName, 'Địa điểm');
      expect(PlaceType.custom.defaultEmoji, '📍');
    });
  });

  group('PlaceModel Tests', () {
    final testDate = DateTime(2026, 9, 24, 8, 30, 0);

    test('Serialization toMap and fromMap', () {
      final place = PlaceModel(
        id: 'place_123',
        ownerUid: 'user_456',
        type: PlaceType.home,
        label: 'Nhà riêng',
        lat: 10.7769,
        lng: 106.7009,
        radiusMetres: 80.0,
        customIcon: '🏡',
        createdAt: testDate,
      );

      final map = place.toMap();
      expect(map['id'], 'place_123');
      expect(map['ownerUid'], 'user_456');
      expect(map['type'], 'home');
      expect(map['label'], 'Nhà riêng');
      expect(map['lat'], 10.7769);
      expect(map['lng'], 106.7009);
      expect(map['radiusMetres'], 80.0);
      expect(map['customIcon'], '🏡');
      expect(map['createdAt'], testDate.millisecondsSinceEpoch);

      final restored = PlaceModel.fromMap(map, id: 'place_123');
      expect(restored.id, 'place_123');
      expect(restored.ownerUid, 'user_456');
      expect(restored.type, PlaceType.home);
      expect(restored.label, 'Nhà riêng');
      expect(restored.lat, 10.7769);
      expect(restored.lng, 106.7009);
      expect(restored.radiusMetres, 80.0);
      expect(restored.customIcon, '🏡');
      expect(restored.emoji, '🏡');
    });

    test('emoji getter uses defaultEmoji when customIcon is null or empty', () {
      final place = PlaceModel(
        id: 'place_work',
        ownerUid: 'user_456',
        type: PlaceType.work,
        label: 'Công ty',
        lat: 10.7769,
        lng: 106.7009,
        createdAt: testDate,
      );
      expect(place.emoji, '🏢');

      final placeWithCustom = place.copyWith(customIcon: '💼');
      expect(placeWithCustom.emoji, '💼');
    });

    test('copyWith updates fields properly', () {
      final original = PlaceModel(
        id: 'p1',
        ownerUid: 'u1',
        type: PlaceType.school,
        label: 'Đại học Bách Khoa',
        lat: 10.77,
        lng: 106.65,
        createdAt: testDate,
      );

      final updated = original.copyWith(
        label: 'ĐH Khoa Học Tự Nhiên',
        type: PlaceType.school,
        radiusMetres: 100.0,
      );

      expect(updated.id, 'p1');
      expect(updated.label, 'ĐH Khoa Học Tự Nhiên');
      expect(updated.radiusMetres, 100.0);
      expect(updated.lat, 10.77);
    });
  });

  group('LocationModel Place & Dwell Time Tests', () {
    test('Serialization with place fields', () {
      final arrived = DateTime(2026, 9, 24, 10, 0, 0);
      final model = createTestLocation(
        uid: 'user_01',
        lat: 10.7769,
        lng: 106.7009,
        timestamp: DateTime(2026, 9, 24, 11, 0, 0),
        currentPlaceType: 'home',
        currentPlaceLabel: 'Nhà riêng',
        arrivedAt: arrived,
      );

      final map = model.toMap();
      expect(map['currentPlaceType'], 'home');
      expect(map['currentPlaceLabel'], 'Nhà riêng');
      expect(map['arrivedAt'], arrived.millisecondsSinceEpoch);

      final restored = LocationModel.fromMap(map);
      expect(restored.currentPlaceType, 'home');
      expect(restored.currentPlaceLabel, 'Nhà riêng');
      expect(restored.arrivedAt?.millisecondsSinceEpoch, arrived.millisecondsSinceEpoch);
      expect(restored.hasPlace, isTrue);
      expect(restored.placeEmoji, '🏠');
    });

    test('placeEmoji matches types correctly', () {
      final locHome = createTestLocation(currentPlaceType: 'home');
      expect(locHome.placeEmoji, '🏠');

      final locWork = locHome.copyWith(currentPlaceType: 'work');
      expect(locWork.placeEmoji, '🏢');

      final locSchool = locHome.copyWith(currentPlaceType: 'school');
      expect(locSchool.placeEmoji, '🏫');

      final locCustom = locHome.copyWith(currentPlaceType: 'custom');
      expect(locCustom.placeEmoji, '📍');

      final locNone = createTestLocation();
      expect(locNone.placeEmoji, isNull);
      expect(locNone.hasPlace, isFalse);
    });

    test('dwellDurationText formats duration correctly', () {
      final now = DateTime.now();

      // Arrived 30 seconds ago -> 'Vừa đến'
      final locJustArrived = createTestLocation(
        arrivedAt: now.subtract(const Duration(seconds: 30)),
      );
      expect(locJustArrived.dwellDurationText, 'Vừa đến');

      // Arrived 25 minutes ago -> '25 phút'
      final locMinutes = createTestLocation(
        arrivedAt: now.subtract(const Duration(minutes: 25)),
      );
      expect(locMinutes.dwellDurationText, '25 phút');

      // Arrived exactly 2 hours ago -> '2 giờ'
      final locExactHours = createTestLocation(
        arrivedAt: now.subtract(const Duration(hours: 2)),
      );
      expect(locExactHours.dwellDurationText, '2 giờ');

      // Arrived 2 hours and 15 minutes ago -> '2g 15p'
      final locHoursAndMinutes = createTestLocation(
        arrivedAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      );
      expect(locHoursAndMinutes.dwellDurationText, '2g 15p');

      // Arrived 3 days ago -> '3 ngày'
      final locDays = createTestLocation(
        arrivedAt: now.subtract(const Duration(days: 3)),
      );
      expect(locDays.dwellDurationText, '3 ngày');

      // arrivedAt is null -> null
      final locNull = createTestLocation();
      expect(locNull.dwellDurationText, isNull);
    });
  });

  group('PlacesService Geofencing & Hysteresis Tests', () {
    late PlacesService service;
    const homeLat = 10.7769;
    const homeLng = 106.7009;

    setUp(() {
      service = PlacesService();
      final homePlace = PlaceModel(
        id: 'home_place_1',
        ownerUid: 'uid_test',
        type: PlaceType.home,
        label: 'Nhà',
        lat: homeLat,
        lng: homeLng,
        radiusMetres: 80.0,
        createdAt: DateTime.now(),
      );
      service.cachedPlacesForTesting = [homePlace];
    });

    test('Entering place: within 80m matches the place', () {
      // Offset by approx 50m north: 1 deg lat ~ 111,320m -> 50m ~ 0.00045 deg
      final testLat = homeLat + 0.00045;
      final dist = LocationPolicy.distanceMetres(testLat, homeLng, homeLat, homeLng);
      expect(dist, lessThan(80.0));

      final match = service.findMatchingPlace(
        lat: testLat,
        lng: homeLng,
      );
      expect(match, isNotNull);
      expect(match!.id, 'home_place_1');
      expect(match.type, PlaceType.home);
    });

    test('Entering place: outside 80m (e.g. 100m) does not match if not currently there', () {
      // Offset by approx 100m north: 100m ~ 0.0009 deg
      final testLat = homeLat + 0.0009;
      final dist = LocationPolicy.distanceMetres(testLat, homeLng, homeLat, homeLng);
      expect(dist, greaterThan(80.0));
      expect(dist, lessThan(120.0)); // In hysteresis zone

      // When entering (currentPlaceId is null or different), should be outside 80m
      final match = service.findMatchingPlace(
        lat: testLat,
        lng: homeLng,
        currentPlaceId: null,
      );
      expect(match, isNull);
    });

    test('Hysteresis: stays inside place when distance is between 80m and 120m if currentPlaceId matches', () {
      // Offset by approx 100m north (inside the 120m hysteresis buffer)
      final testLat = homeLat + 0.0009;
      final dist = LocationPolicy.distanceMetres(testLat, homeLng, homeLat, homeLng);
      expect(dist, greaterThan(80.0));
      expect(dist, lessThan(120.0));

      final match = service.findMatchingPlace(
        lat: testLat,
        lng: homeLng,
        currentPlaceId: 'home_place_1', // Already inside
      );
      expect(match, isNotNull);
      expect(match!.id, 'home_place_1');
    });

    test('Leaves place when distance exceeds hysteresis radius (> 120m)', () {
      // Offset by approx 150m north: 150m ~ 0.00135 deg
      final testLat = homeLat + 0.00135;
      final dist = LocationPolicy.distanceMetres(testLat, homeLng, homeLat, homeLng);
      expect(dist, greaterThan(120.0));

      final match = service.findMatchingPlace(
        lat: testLat,
        lng: homeLng,
        currentPlaceId: 'home_place_1',
      );
      expect(match, isNull);
    });

    test('Returns null when cachedPlaces is empty', () {
      service.cachedPlacesForTesting = [];
      final match = service.findMatchingPlace(lat: homeLat, lng: homeLng);
      expect(match, isNull);
    });
  });
}
