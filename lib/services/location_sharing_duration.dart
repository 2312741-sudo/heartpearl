/// Represents the duration a user chooses for Live Location Sharing.
///
/// Per Apple Guideline 5.1.2(i), selecting [unlimited] requires an explicit
/// consent dialog before any streaming begins.
enum LocationSharingDuration {
  /// Stream for exactly 1 hour from the moment of activation.
  oneHour,

  /// Stream until 23:59:59 of the current day (local time).
  untilEndOfDay,

  /// Stream indefinitely until the user manually stops (Ghost Mode).
  unlimited;

  /// Returns the expiry [DateTime] for this duration, or `null` for [unlimited].
  DateTime? expiresAt() {
    final now = DateTime.now();
    return switch (this) {
      LocationSharingDuration.oneHour => now.add(const Duration(hours: 1)),
      LocationSharingDuration.untilEndOfDay =>
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      LocationSharingDuration.unlimited => null,
    };
  }

  /// Human-readable label stored in Firestore for auditing / display.
  String get firestoreLabel => switch (this) {
        LocationSharingDuration.oneHour => '1h',
        LocationSharingDuration.untilEndOfDay => 'today',
        LocationSharingDuration.unlimited => 'unlimited',
      };

  /// Localized short label for the selection chip / button.
  String label(String lang) {
    if (lang == 'vi') {
      return switch (this) {
        LocationSharingDuration.oneHour => '1 giờ',
        LocationSharingDuration.untilEndOfDay => 'Hết hôm nay',
        LocationSharingDuration.unlimited => 'Vô hạn',
      };
    }
    return switch (this) {
      LocationSharingDuration.oneHour => '1 Hour',
      LocationSharingDuration.untilEndOfDay => 'Until end of day',
      LocationSharingDuration.unlimited => 'Unlimited',
    };
  }

  /// Localized subtitle describing when sharing stops.
  String subtitle(String lang) {
    if (lang == 'vi') {
      return switch (this) {
        LocationSharingDuration.oneHour =>
          'Tự động tắt sau 1 giờ',
        LocationSharingDuration.untilEndOfDay =>
          'Tắt lúc 23:59 hôm nay',
        LocationSharingDuration.unlimited =>
          'Cho đến khi bạn chủ động tắt',
      };
    }
    return switch (this) {
      LocationSharingDuration.oneHour =>
        'Stops automatically after 1 hour',
      LocationSharingDuration.untilEndOfDay =>
        'Stops at 23:59 tonight',
      LocationSharingDuration.unlimited =>
        'Until you manually stop sharing',
    };
  }

  /// Returns a formatted countdown string, e.g. "Còn 0g 45p" or "Còn 23g 12p".
  /// Returns null if [unlimited] or already expired.
  String? countdownLabel(String lang, {DateTime? now}) {
    final exp = expiresAt();
    if (exp == null) return null;
    final effective = now ?? DateTime.now();
    final diff = exp.difference(effective);
    if (diff.isNegative) return null;
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (lang == 'vi') {
      if (hours > 0) return 'Còn ${hours}g ${minutes}p';
      return 'Còn ${minutes}p';
    }
    if (hours > 0) return '${hours}h ${minutes}m left';
    return '${minutes}m left';
  }
}
