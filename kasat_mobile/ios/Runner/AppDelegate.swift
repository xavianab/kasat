import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Alternate icons declared via ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES
  /// in ios/Flutter/*.xcconfig. Kept here so the channel can answer
  /// "not_provisioned" instead of throwing when a build ships without them.
  private static let provisionedIcons: Set<String> = ["AltIconNotes", "AltIconCalculator"]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerDisguiseChannel(with: messenger)
    registerPrivacyChannel(with: messenger)
  }

  private func registerPrivacyChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.kasat/privacy", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "quickExitToHome":
        // Suspend straight to the iOS Home Screen without opening Safari
        // (avoids leaving any browser history entry).
        DispatchQueue.main.async {
          UIApplication.shared.perform(NSSelectorFromString("suspend"))
          result(true)
        }
      case "setSecureScreen":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerDisguiseChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.kasat/disguise", binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(UIApplication.shared.supportsAlternateIcons)

      case "setIcon":
        guard UIApplication.shared.supportsAlternateIcons else {
          result("unsupported")
          return
        }

        // A nil name restores the primary icon.
        let requested = (call.arguments as? [String: Any])?["name"] as? String

        if let name = requested, !AppDelegate.provisionedIcons.contains(name) {
          result("not_provisioned")
          return
        }

        if requested == UIApplication.shared.alternateIconName {
          result("applied")
          return
        }

        UIApplication.shared.setAlternateIconName(requested) { error in
          DispatchQueue.main.async {
            result(error == nil ? "applied" : "failed")
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
