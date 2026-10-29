import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyOverlay: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    showPrivacyCover()
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    showPrivacyCover()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    hidePrivacyCover()
  }

  private func showPrivacyCover() {
    guard privacyOverlay == nil, let window = self.window else { return }
    let cover = UIView(frame: window.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = UIColor(red: 0.984, green: 0.973, blue: 0.965, alpha: 1.0)
    window.addSubview(cover)
    window.bringSubviewToFront(cover)
    privacyOverlay = cover
  }

  private func hidePrivacyCover() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
