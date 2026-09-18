import 'dart:math' as math;

class LocationPolicy {
  static const Duration minimumWriteInterval = Duration(seconds: 30);
  static const Duration minimumWidgetInterval = Duration(minutes: 20);
  static const double maximumPublishAccuracy = 200;
  static const double widgetRefreshDistanceMetres = 75;

  const LocationPolicy._();

  static bool isValidFix({
    required double lat,
    required double lng,
    required double accuracy,
  }) {
    return lat.isFinite &&
        lng.isFinite &&
        accuracy.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        accuracy > 0 &&
        accuracy <= maximumPublishAccuracy;
  }

  static bool shouldPublish({
    required DateTime capturedAt,
    DateTime? lastCapturedAt,
    DateTime? lastSuccessfulWriteAt,
  }) {
    if (lastCapturedAt != null && !capturedAt.isAfter(lastCapturedAt)) {
      return false;
    }
    if (lastSuccessfulWriteAt == null) return true;
    return capturedAt.difference(lastSuccessfulWriteAt) >= minimumWriteInterval;
  }

  static bool shouldRefreshWidget({
    required DateTime now,
    required double lat,
    required double lng,
    DateTime? lastRequestAt,
    double? previousLat,
    double? previousLng,
  }) {
    if (lastRequestAt != null &&
        now.difference(lastRequestAt) < minimumWidgetInterval) {
      return false;
    }
    if (previousLat == null || previousLng == null) return true;
    return distanceMetres(previousLat, previousLng, lat, lng) >=
        widgetRefreshDistanceMetres;
  }

  static double distanceMetres(
    double firstLat,
    double firstLng,
    double secondLat,
    double secondLng,
  ) {
    const earthRadius = 6371000.0;
    final lat1 = _radians(firstLat);
    final lat2 = _radians(secondLat);
    final deltaLat = _radians(secondLat - firstLat);
    final deltaLng = _radians(secondLng - firstLng);
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
