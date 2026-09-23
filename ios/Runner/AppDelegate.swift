import Flutter
import UIKit
import AVFoundation
import WidgetKit
import UserNotifications
#if canImport(GoogleMaps)
import GoogleMaps
#endif
#if canImport(workmanager_apple)
import workmanager_apple
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // Clear app icon badge number when user opens or returns to the app
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      application.applicationIconBadgeNumber = 0
    }
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if canImport(GoogleMaps)
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String,
       !mapsApiKey.isEmpty,
       !mapsApiKey.contains("$(") {
      GMSServices.provideAPIKey(mapsApiKey)
    }
    #endif

    #if canImport(workmanager_apple)
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.heartpearl.heartpearl.locationWidgetRefresh")
    #endif

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Register for remote notifications to enable silent APNs token for seamless Phone Auth
    application.registerForRemoteNotifications()

    AppDelegate.registerPluginSafely(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      AppDelegate.setupCustomChannels(messenger: controller.binaryMessenger)
    }

    return result
  }

  private static var channelsConfigured = false

  static func setupCustomChannels(messenger: FlutterBinaryMessenger) {
    guard !channelsConfigured else { return }
    channelsConfigured = true

    // 1. Auth Config Channel
    let authChannel = FlutterMethodChannel(name: "com.heartpearl.app/auth_config", binaryMessenger: messenger)
    authChannel.setMethodCallHandler { (call, result) in
      if call.method == "isGoogleSignInConfigured" {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let clientId = dict["CLIENT_ID"] as? String,
           !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          result(true)
        } else {
          result(false)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // 2. Media Channel (Video Thumbnail Generator & Hardware Video Compressor)
    let mediaChannel = FlutterMethodChannel(name: "com.heartpearl.app/media", binaryMessenger: messenger)
    mediaChannel.setMethodCallHandler { (call, result) in
      if call.method == "generateVideoThumbnail" {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing videoPath parameter", details: nil))
          return
        }

        let videoUrl: URL
        if videoPath.hasPrefix("http://") || videoPath.hasPrefix("https://") {
          guard let parsed = URL(string: videoPath) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid remote URL", details: nil))
            return
          }
          videoUrl = parsed
        } else {
          videoUrl = URL(fileURLWithPath: videoPath)
        }

        let asset = AVAsset(url: videoUrl)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 720, height: 1280)
        imageGenerator.requestedTimeToleranceBefore = .positiveInfinity
        imageGenerator.requestedTimeToleranceAfter = .positiveInfinity
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)

        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            if let jpegData = uiImage.jpegData(compressionQuality: 0.82) {
              let tempDir = NSTemporaryDirectory()
              let thumbPath = (tempDir as NSString).appendingPathComponent("thumb_\(UUID().uuidString).jpg")
              try jpegData.write(to: URL(fileURLWithPath: thumbPath))
              DispatchQueue.main.async {
                result(thumbPath)
              }
              return
            }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "THUMBNAIL_FAILED", message: error.localizedDescription, details: nil))
            }
            return
          }
          DispatchQueue.main.async {
            result(FlutterError(code: "UNKNOWN", message: "Failed to generate thumbnail image", details: nil))
          }
        }
      } else if call.method == "compressVideo" {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing videoPath parameter", details: nil))
          return
        }

        let sourceUrl = URL(fileURLWithPath: videoPath)
        let asset = AVAsset(url: sourceUrl)

        // Export at 720p HD with MOOV atom at head for instant edge streaming
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
          result(videoPath)
          return
        }

        let tempDir = NSTemporaryDirectory()
        let outputUrl = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("opt_\(UUID().uuidString).mp4"))

        exportSession.outputURL = outputUrl
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
          DispatchQueue.main.async {
            switch exportSession.status {
            case .completed:
              result(outputUrl.path)
            default:
              // Fallback gracefully to original video if compression fails
              result(videoPath)
            }
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // 3. Badge Channel (Reset or set app icon badge number)
    let badgeChannel = FlutterMethodChannel(name: "com.heartpearl.app/badge", binaryMessenger: messenger)
    badgeChannel.setMethodCallHandler { (call, result) in
      if call.method == "clearBadge" {
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(0) { _ in
            result(true)
          }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = 0
          result(true)
        }
      } else if call.method == "setBadgeCount" {
        let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 0
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { _ in
            result(true)
          }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(true)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func registerPluginSafely(with registry: FlutterPluginRegistry) {
    let pluginKey = "HeartPearlCustomChannels"
    if !registry.hasPlugin(pluginKey) {
      if let registrar = registry.registrar(forPlugin: pluginKey) {
        setupCustomChannels(messenger: registrar.messenger())
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AppDelegate.registerPluginSafely(with: engineBridge.pluginRegistry)
  }

  // ─── Silent Push Handler for Widget Refresh ──────────────────────────────
  // Called by iOS when a data-only (content-available:1) push arrives even
  // while the app is in the background or suspended.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let type = userInfo["type"] as? String

    if type == "location_widget_update" {
      // Reload all WidgetKit timelines so the location widget refreshes now
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
      completionHandler(.newData)
      return
    }

    // Pass to Flutter / Firebase for other notification types
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }
}
