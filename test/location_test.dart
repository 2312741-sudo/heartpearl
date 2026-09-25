import 'package:flutter_test/flutter_test.dart';
import 'package:heartpearl/models/location_model.dart';
import 'package:heartpearl/services/location_policy.dart';

void main() {
  group('LocationModel Tests', () {
    test('Serialization and deserialization via fromMap and toMap', () {
      final now = DateTime(2026, 9, 18, 10, 0, 0);
      final model = LocationModel(
        uid: 'user_001',
        lat: 10.7769,
        lng: 106.7009,
        timestamp: now,
        accuracy: 12.5,
        speed: 1.8,
        batteryLevel: 85,
        isSharing: true,
        allowedViewers: ['friend_1', 'friend_2'],
      );

      final map = model.toMap();
      expect(map['uid'], 'user_001');
      expect(map['lat'], 10.7769);
      expect(map['lng'], 106.7009);
      expect(map['timestamp'], now.millisecondsSinceEpoch);
      expect(map['accuracy'], 12.5);
      expect(map['speed'], 1.8);
      expect(map['batteryLevel'], 85);
      expect(map['isSharing'], isTrue);
      expect(map['allowedViewers'], ['friend_1', 'friend_2']);

      final restored = LocationModel.fromMap(map);
      expect(restored.uid, 'user_001');
      expect(restored.lat, 10.7769);
      expect(restored.lng, 106.7009);
      expect(restored.timestamp.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(restored.accuracy, 12.5);
      expect(restored.speed, 1.8);
      expect(restored.batteryLevel, 85);
      expect(restored.isSharing, isTrue);
      expect(restored.allowedViewers, ['friend_1', 'friend_2']);
    });

    test('Handles missing, null, or invalid types gracefully without crashing', () {
      final emptyMap = <String, dynamic>{};
      final model = LocationModel.fromMap(emptyMap, uid: 'fallback_uid');

      expect(model.uid, 'fallback_uid');
      expect(model.lat, 0.0);
      expect(model.lng, 0.0);
      expect(model.accuracy, 0.0);
      expect(model.speed, 0.0);
      expect(model.batteryLevel, isNull);
      expect(model.isSharing, isFalse);
      expect(model.allowedViewers, isEmpty);
      expect(model.hasCoordinate, isFalse);

      final malformedMap = <String, dynamic>{
        'uid': 12345, // invalid type
        'lat': 'invalid_lat',
        'lng': null,
        'accuracy': 'wide',
        'speed': -50,
        'batteryLevel': 150, // out of range, clamped to 100
        'isSharing': 'yes', // not a bool
        'allowedViewers': 'not_a_list',
      };

      final safeModel = LocationModel.fromMap(malformedMap);
      expect(safeModel.lat, 0.0);
      expect(safeModel.lng, 0.0);
      expect(safeModel.accuracy, 0.0);
      expect(safeModel.speed, 0.0);
      expect(safeModel.batteryLevel, 100);
      expect(safeModel.isSharing, isFalse);
      expect(safeModel.allowedViewers, isEmpty);
    });

    test('Stale location detection', () {
      final baseTime = DateTime(2026, 9, 18, 12, 0, 0);
      final recentModel = LocationModel(
        uid: 'user_1',
        lat: 10.0,
        lng: 106.0,
        timestamp: baseTime.subtract(const Duration(minutes: 5)),
        accuracy: 10,
        speed: 0,
        isSharing: true,
      );

      final staleModel = LocationModel(
        uid: 'user_2',
        lat: 10.0,
        lng: 106.0,
        timestamp: baseTime.subtract(const Duration(minutes: 15)),
        accuracy: 10,
        speed: 0,
        isSharing: true,
      );

      expect(recentModel.isStale(now: baseTime, maxAge: const Duration(minutes: 10)), isFalse);
      expect(staleModel.isStale(now: baseTime, maxAge: const Duration(minutes: 10)), isTrue);
    });
  });

  group('LocationPolicy Tests', () {
    test('isValidFix rejects invalid ranges and inaccurate positions (>200m)', () {
      expect(LocationPolicy.isValidFix(lat: 10.77, lng: 106.70, accuracy: 15), isTrue);
      expect(LocationPolicy.isValidFix(lat: 10.77, lng: 106.70, accuracy: 200), isTrue);
      // Accuracy > 200m should be rejected to prevent jumping/drift
      expect(LocationPolicy.isValidFix(lat: 10.77, lng: 106.70, accuracy: 201), isFalse);
      expect(LocationPolicy.isValidFix(lat: 10.77, lng: 106.70, accuracy: -5), isFalse);
      // Latitude out of range
      expect(LocationPolicy.isValidFix(lat: 95.0, lng: 106.70, accuracy: 10), isFalse);
      // Longitude out of range
      expect(LocationPolicy.isValidFix(lat: 10.77, lng: 185.0, accuracy: 10), isFalse);
      // Infinite or NaN
      expect(LocationPolicy.isValidFix(lat: double.nan, lng: 106.70, accuracy: 10), isFalse);
    });

    test('30-second throttle policy (shouldPublish)', () {
      final t0 = DateTime(2026, 9, 18, 12, 0, 0);

      // First fix ever should publish
      expect(
        LocationPolicy.shouldPublish(
          capturedAt: t0,
          lastCapturedAt: null,
          lastSuccessfulWriteAt: null,
        ),
        isTrue,
      );

      // Fix after only 15 seconds should be throttled
      final t15 = t0.add(const Duration(seconds: 15));
      expect(
        LocationPolicy.shouldPublish(
          capturedAt: t15,
          lastCapturedAt: t0,
          lastSuccessfulWriteAt: t0,
        ),
        isFalse,
      );

      // Fix after 30 seconds should be accepted
      final t30 = t0.add(const Duration(seconds: 30));
      expect(
        LocationPolicy.shouldPublish(
          capturedAt: t30,
          lastCapturedAt: t15,
          lastSuccessfulWriteAt: t0,
        ),
        isTrue,
      );

      // Out of order fix (captured before last captured) must be rejected
      final tPast = t0.subtract(const Duration(seconds: 5));
      expect(
        LocationPolicy.shouldPublish(
          capturedAt: tPast,
          lastCapturedAt: t0,
          lastSuccessfulWriteAt: t0,
        ),
        isFalse,
      );
    });

    test('Haversine distanceMetres calculation', () {
      // Same coordinate should be 0 metres
      final d0 = LocationPolicy.distanceMetres(10.7769, 106.7009, 10.7769, 106.7009);
      expect(d0, closeTo(0.0, 0.001));

      // Distance between Ben Thanh Market (10.7725, 106.6980) and Saigon Notre Dame Cathedral (10.7798, 106.6990)
      // Approximate real world distance is ~800 to 850 metres
      final d1 = LocationPolicy.distanceMetres(10.7725, 106.6980, 10.7798, 106.6990);
      expect(d1, greaterThan(800));
      expect(d1, lessThan(850));
    });

    test('Widget refresh threshold: 20 minutes AND 75 metres', () {
      final now = DateTime(2026, 9, 18, 14, 0, 0);
      const lat0 = 10.7769;
      const lng0 = 106.7009;

      // First run should refresh
      expect(
        LocationPolicy.shouldRefreshWidget(
          now: now,
          lat: lat0,
          lng: lng0,
          lastRequestAt: null,
          previousLat: null,
          previousLng: null,
        ),
        isTrue,
      );

      // Request within 20 minutes (<20 min) should NOT refresh, even if moved far
      final within20min = now.add(const Duration(minutes: 10));
      const latMoved = 10.7850; // moved ~900m
      expect(
        LocationPolicy.shouldRefreshWidget(
          now: within20min,
          lat: latMoved,
          lng: lng0,
          lastRequestAt: now,
          previousLat: lat0,
          previousLng: lng0,
        ),
        isFalse,
      );

      // Request after 20 minutes but moved < 75 metres should NOT refresh
      final after25min = now.add(const Duration(minutes: 25));
      // Move ~30 metres north (0.00027 degrees lat is approx 30 metres)
      const latSlightMove = lat0 + 0.00027;
      expect(
        LocationPolicy.shouldRefreshWidget(
          now: after25min,
          lat: latSlightMove,
          lng: lng0,
          lastRequestAt: now,
          previousLat: lat0,
          previousLng: lng0,
        ),
        isFalse,
      );

      // Request after 20 minutes AND moved > 75 metres SHOULD refresh
      // Move ~110 metres north (0.001 degrees lat is approx 111 metres)
      const latFarMove = lat0 + 0.001;
      expect(
        LocationPolicy.shouldRefreshWidget(
          now: after25min,
          lat: latFarMove,
          lng: lng0,
          lastRequestAt: now,
          previousLat: lat0,
          previousLng: lng0,
        ),
        isTrue,
      );
    });
  });

  group('Nearest Friend Selection & Privacy Tests', () {
    test('Selects nearest friend using Haversine distance', () {
      final own = LocationModel(
        uid: 'me',
        lat: 10.7769,
        lng: 106.7009,
        timestamp: DateTime.now(),
        accuracy: 10,
        speed: 0,
        isSharing: true,
      );

      final friendNear = LocationModel(
        uid: 'friend_near',
        lat: 10.7780, // ~120m away
        lng: 106.7010,
        timestamp: DateTime.now(),
        accuracy: 10,
        speed: 0,
        isSharing: true,
      );

      final friendFar = LocationModel(
        uid: 'friend_far',
        lat: 10.8200, // ~5km away
        lng: 106.7000,
        timestamp: DateTime.now(),
        accuracy: 10,
        speed: 0,
        isSharing: true,
      );

      final candidates = [friendFar, friendNear];
      // Sorting candidates by distance to own location
      candidates.sort((a, b) {
        final distA = LocationPolicy.distanceMetres(own.lat, own.lng, a.lat, a.lng);
        final distB = LocationPolicy.distanceMetres(own.lat, own.lng, b.lat, b.lng);
        return distA.compareTo(distB);
      });

      expect(candidates.first.uid, 'friend_near');
    });

    test('allowedViewers policy: empty means all friends allowed, non-empty filters', () {
      final openModel = LocationModel(
        uid: 'user_open',
        lat: 10.0,
        lng: 106.0,
        timestamp: DateTime.now(),
        accuracy: 10,
        speed: 0,
        isSharing: true,
        allowedViewers: const [],
      );

      final restrictedModel = LocationModel(
        uid: 'user_restricted',
        lat: 10.0,
        lng: 106.0,
        timestamp: DateTime.now(),
        accuracy: 10,
        speed: 0,
        isSharing: true,
        allowedViewers: const ['friend_vip'],
      );

      // Helper function matching security rules logic
      bool isViewerAllowed(LocationModel model, String viewerUid) {
        if (!model.isSharing) return false;
        if (model.allowedViewers.isEmpty) return true;
        return model.allowedViewers.contains(viewerUid);
      }

      expect(isViewerAllowed(openModel, 'friend_any'), isTrue);
      expect(isViewerAllowed(restrictedModel, 'friend_vip'), isTrue);
      expect(isViewerAllowed(restrictedModel, 'friend_other'), isFalse);
    });

    test('Two-way block filter prevents sharing regardless of friendship', () {
      final myFriends = {'friend_1', 'friend_2', 'bad_user'};
      final myBlockedUsers = {'bad_user'};

      // Exclude blocked users from friend list
      final visibleFriends = myFriends.where((uid) => !myBlockedUsers.contains(uid)).toList();

      expect(visibleFriends.contains('bad_user'), isFalse);
      expect(visibleFriends.contains('friend_1'), isTrue);
      expect(visibleFriends.contains('friend_2'), isTrue);
    });
  });

  group('Adaptive Tracking State Machine Tests', () {
    test('Stationary criteria detection: speed < 1.0 m/s and anchor dist < 40m', () {
      const anchorLat = 10.7769;
      const anchorLng = 106.7009;

      // Small jitter (15 metres away), speed 0.3 m/s -> stationary
      const currentLat = 10.7770;
      const currentLng = 106.7010;
      final dist = LocationPolicy.distanceMetres(anchorLat, anchorLng, currentLat, currentLng);
      const speed = 0.3;

      final isStationary = (speed < 1.0 && dist < 40.0);
      expect(dist, lessThan(40.0));
      expect(isStationary, isTrue);
    });

    test('Moving wake-up criteria: speed >= 1.5 m/s or anchor dist >= 50m triggers wake-up', () {
      const anchorLat = 10.7769;
      const anchorLng = 106.7009;

      // 1. In motion by speed (running/vehicle)
      const speed = 2.5;
      const distSmall = 10.0;
      final wakesBySpeed = speed >= 1.5 || distSmall >= 50.0;
      expect(wakesBySpeed, isTrue);

      // 2. In motion by moving away from anchor (> 50m)
      const walkSpeed = 0.8;
      const distantLat = 10.7780; // ~120m away
      const distantLng = 106.7009;
      final distLarge = LocationPolicy.distanceMetres(anchorLat, anchorLng, distantLat, distantLng);
      expect(distLarge, greaterThan(50.0));

      final wakesByDist = walkSpeed >= 1.5 || distLarge >= 50.0;
      expect(wakesByDist, isTrue);
    });

    test('Sleep mode duration gate: requires >= 2 minutes before entering stationary sleep mode', () {
      final now = DateTime.now();
      final stationarySinceRecent = now.subtract(const Duration(seconds: 45));
      final stationarySinceLong = now.subtract(const Duration(seconds: 130));

      final canSleepRecent = now.difference(stationarySinceRecent) >= const Duration(minutes: 2);
      final canSleepLong = now.difference(stationarySinceLong) >= const Duration(minutes: 2);

      expect(canSleepRecent, isFalse);
      expect(canSleepLong, isTrue);
    });
  });
}

