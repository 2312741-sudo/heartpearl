import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
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
}
