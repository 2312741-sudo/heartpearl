import CoreLocation
import Foundation

/// Singleton that uses Significant-Change Location Service to keep a pending
/// location available in UserDefaults so the Dart layer can flush it to
/// Firebase when the app relaunches after iOS silently killed the background
/// process.
///
/// **Does NOT write to Firebase directly** — it only stores the fix in
/// UserDefaults and posts a local notification. The Dart layer is responsible
/// for reading and writing to RTDB/Firestore via `flushPendingBackgroundLocation`.
///
/// Constraint: iOS cannot recover from a user explicitly swiping the app away
/// (force-quit). Significant-change recovery only works when iOS kills the
/// process to reclaim memory.
final class BackgroundLocationRelay: NSObject, CLLocationManagerDelegate {

    static let shared = BackgroundLocationRelay()

    // Dedicated CLLocationManager — must NOT share with geolocator plugin to
    // avoid delegate/settings override.
    private let locationManager = CLLocationManager()

    // App Group used across all targets (Widget, Runner, …).
    private let defaults = UserDefaults(suiteName: "group.com.tamchau.app")

    private enum Keys {
        static let enabled  = "bg_location_relay_enabled"
        static let pending  = "bg_location_pending"
    }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Pause delivery when device is stationary to save battery.
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true
    }

    // MARK: – Public API

    /// Starts Significant-Change monitoring if "Always" authorisation is
    /// granted. No-ops otherwise.
    func startMonitoring() {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        guard status == .authorizedAlways else {
            // Don't start — relay requires background "Always" permission.
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
    }

    /// Stops Significant-Change monitoring.
    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: – CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }

        // Store compact JSON in UserDefaults so the Dart layer can read it.
        let payload: [String: Any] = [
            "lat":       loc.coordinate.latitude,
            "lng":       loc.coordinate.longitude,
            "accuracy":  loc.horizontalAccuracy,
            "speed":     max(loc.speed, 0),
            "timestamp": loc.timestamp.timeIntervalSince1970 * 1000, // epoch ms
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            defaults?.set(jsonString, forKey: Keys.pending)
            defaults?.synchronize()
        }

        // Notify any in-process observers (e.g. for future telemetry).
        NotificationCenter.default.post(
            name: Notification.Name("HeartPearlBackgroundLocationReceived"),
            object: nil,
            userInfo: payload
        )
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        // Silently ignore — relay is best-effort.
    }

    // MARK: – UserDefaults helpers (called from AppDelegate channel handler)

    func setEnabled(_ enabled: Bool) {
        defaults?.set(enabled, forKey: Keys.enabled)
        defaults?.synchronize()
    }

    var isEnabled: Bool {
        defaults?.bool(forKey: Keys.enabled) ?? false
    }

    func readPendingLocation() -> String? {
        defaults?.string(forKey: Keys.pending)
    }

    func clearPendingLocation() {
        defaults?.removeObject(forKey: Keys.pending)
        defaults?.synchronize()
    }
}
