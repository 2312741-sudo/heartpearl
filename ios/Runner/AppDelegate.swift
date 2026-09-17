import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Register for remote notifications to enable silent APNs token for seamless Phone Auth
    application.registerForRemoteNotifications()

    if let controller = window?.rootViewController as? FlutterViewController {
      // 1. Auth Config Channel
      let authChannel = FlutterMethodChannel(name: "com.heartpearl.app/auth_config", binaryMessenger: controller.binaryMessenger)
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

      // 2. Media Channel (Video Thumbnail Generator via native AVAssetImageGenerator)
      let mediaChannel = FlutterMethodChannel(name: "com.heartpearl.app/media", binaryMessenger: controller.binaryMessenger)
      mediaChannel.setMethodCallHandler { (call, result) in
        if call.method == "generateVideoThumbnail" {
          guard let args = call.arguments as? [String: Any],
                let videoPath = args["videoPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing videoPath parameter", details: nil))
            return
          }

          let videoUrl = URL(fileURLWithPath: videoPath)
          let asset = AVAsset(url: videoUrl)
          let imageGenerator = AVAssetImageGenerator(asset: asset)
          imageGenerator.appliesPreferredTrackTransform = true
          imageGenerator.maximumSize = CGSize(width: 720, height: 1280)
          let time = CMTime(seconds: 0.1, preferredTimescale: 600)

          DispatchQueue.global(qos: .userInitiated).async {
            do {
              let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
              let uiImage = UIImage(cgImage: cgImage)
              if let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
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
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
