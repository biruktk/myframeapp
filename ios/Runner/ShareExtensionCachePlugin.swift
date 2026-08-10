import Flutter
import UIKit

/// Bridges the Flutter host to the Share Extension's App Group defaults so the
/// native share sheet can:
///  - read the cached paired-frame list (written by [syncFrames]),
///  - read/write the user's last frame selection,
///  - consume the auto-send flag the extension sets when "Send" is tapped.
///
/// Keys live in `UserDefaults(suiteName: group.com.myframe)` — the same
/// container the Share Extension uses (see Share Extension/Info.plist).
final class ShareExtensionCachePlugin: NSObject, FlutterPlugin {
  static let channelName = "myframe/share_extension/cache"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = ShareExtensionCachePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var appGroupId: String {
    let custom = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
    if let custom, !custom.isEmpty { return custom }
    return "group.\(Bundle.main.bundleIdentifier ?? "")"
  }

  private func defaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "bad_args", message: "Expected arguments", details: nil))
      return
    }
    guard let key = args["key"] as? String, !key.isEmpty else {
      result(FlutterError(code: "bad_key", message: "Missing key", details: nil))
      return
    }
    guard let defaults = defaults() else {
      result(FlutterError(code: "no_app_group", message: "App Group unavailable", details: nil))
      return
    }

    switch call.method {
    case "getAppGroupId":
      result(appGroupId)

    case "write":
      if let value = args["value"] as? String {
        defaults.set(value, forKey: key)
      } else if let value = args["value"] as? Bool {
        defaults.set(value, forKey: key)
      } else if let value = args["value"] as? [String] {
        defaults.set(value, forKey: key)
      } else if let value = args["value"] as? Data {
        defaults.set(value, forKey: key)
      } else if args["value"] is NSNull {
        defaults.removeObject(forKey: key)
      } else {
        result(FlutterError(code: "bad_value", message: "Unsupported value type", details: nil))
        return
      }
      // Cross-process flush so the extension sees the value immediately.
      defaults.synchronize()
      result(nil)

    case "readString":
      result(defaults.string(forKey: key))

    case "readBool":
      result(defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key))

    case "readStringArray":
      result(defaults.stringArray(forKey: key))

    case "readData":
      result(defaults.data(forKey: key))

    case "remove":
      defaults.removeObject(forKey: key)
      defaults.synchronize()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
