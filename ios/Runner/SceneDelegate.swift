import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let windowScene = scene as? UIWindowScene,
       let controller = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController as? FlutterViewController {
      AppDelegate.setupCustomChannels(messenger: controller.binaryMessenger)
    }
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    // Request background execution time from iOS so network writes and GPS fixes in flight complete cleanly
    backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "HeartPearlLocationKeepAlive") { [weak self] in
      guard let self = self else { return }
      if self.backgroundTaskId != .invalid {
        UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
        self.backgroundTaskId = .invalid
      }
    }
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    if backgroundTaskId != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTaskId)
      backgroundTaskId = .invalid
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
  }
}
