import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.securevault/disguise", binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "setAlternateIcon":
        if let args = call.arguments as? [String: Any],
           let iconName = args["iconName"] as? String {
          self?.setAlternateIcon(iconName: iconName, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "iconName is required", details: nil))
        }
      case "supportsAlternateIcons":
        result(UIApplication.shared.supportsAlternateIcons)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setAlternateIcon(iconName: String, result: @escaping FlutterResult) {
    guard UIApplication.shared.supportsAlternateIcons else {
      result(FlutterError(code: "NOT_SUPPORTED", message: "Alternate icons not supported", details: nil))
      return
    }
    
    let newIconName: String? = iconName == "default" ? nil : iconName
    
    UIApplication.shared.setAlternateIconName(newIconName) { error in
      if let error = error {
        result(FlutterError(code: "ICON_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result(true)
      }
    }
  }
}
