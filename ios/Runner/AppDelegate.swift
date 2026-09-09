import Flutter
import UIKit
import NetworkExtension
import FirebaseCore
import Intents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Must run before any Firebase* plugin registers (Messaging logs I-COR000003 otherwise).
  private static func configureFirebaseIfNeeded() {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    Self.configureFirebaseIfNeeded()
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    // Register after Firebase is configured so Messaging can attach cleanly.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // With FlutterImplicitEngineDelegate this can run before/during didFinishLaunching.
    Self.configureFirebaseIfNeeded()
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let cacheRegistrar = engineBridge.pluginRegistry
      .registrar(forPlugin: "ShareExtensionCachePlugin") {
      ShareExtensionCachePlugin.register(with: cacheRegistrar)
    }

    if let shortcutRegistrar = engineBridge.pluginRegistry
      .registrar(forPlugin: "FrameShortcutPlugin") {
      FrameShortcutPlugin.register(with: shortcutRegistrar)
    }

    if let icloud = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudPhotosPlugin") {
      ICloudPhotosPlugin.register(with: icloud)
    }

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeBlePlugin")!
    let channel = FlutterMethodChannel(
      name: "myframe/native_ble/methods",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getWifiInfo":
        if #available(iOS 14.0, *) {
          NEHotspotNetwork.fetchCurrent { network in
            let ssid = network?.ssid ?? ""
            let enabled = !ssid.isEmpty
            NSLog("[myframe] getWifiInfo: ssid='\(ssid)' enabled=\(enabled) hasNetwork=\(network != nil)")
            DispatchQueue.main.async {
              result(["enabled": enabled, "ssid": ssid])
            }
          }
        } else {
          NSLog("[myframe] getWifiInfo: iOS < 14, returning empty")
          result(["enabled": false, "ssid": ""])
        }
      case "scanWifiNetworks":
        // Apple does not expose a public API to list nearby SSIDs without
        // Hotspot Helper entitlement (Apple approval). Return empty; Flutter
        // shows the current network + manual SSID entry.
        NSLog("[myframe] scanWifiNetworks: iOS cannot list nearby SSIDs")
        result([])
      case "sanitizeImageToJPEG":
        guard
          let args = call.arguments as? [String: Any],
          let filePath = args["filePath"] as? String,
          let out = Self.sanitizeImageToJPEG(filePath: filePath)
        else {
          result(nil)
          return
        }
        result(out)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Converts any incoming image (including Display P3 / 16-bit PNG / HEIC
  /// screenshots) into a plain 8‑bit sRGB JPEG written to a temp `.jpg` file.
  ///
  /// Drawing into a bitmap context with `image.draw` forces CoreGraphics to
  /// color-manage Display P3 → sRGB and strips the alpha channel (JPEG has
  /// none), so Flutter's `instantiateImageCodec` never chokes on the source.
  /// Returns the temp path, or `nil` when the file cannot be decoded.
  static func sanitizeImageToJPEG(filePath: String) -> String? {
    guard let image = UIImage(contentsOfFile: filePath) else {
      NSLog("[myframe] sanitizeImageToJPEG: could not load \(filePath)")
      return nil
    }
    let size = image.size
    guard size.width > 0, size.height > 0 else { return nil }
    let scale = image.scale
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    image.draw(in: CGRect(origin: .zero, size: size))
    let normalized = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    guard
      let normalized = normalized,
      let jpegData = normalized.jpegData(compressionQuality: 0.88)
    else {
      NSLog("[myframe] sanitizeImageToJPEG: re-encode failed for \(filePath)")
      return nil
    }

    let tempPath = NSTemporaryDirectory() + UUID().uuidString + ".jpg"
    do {
      try jpegData.write(to: URL(fileURLWithPath: tempPath))
      return tempPath
    } catch {
      NSLog("[myframe] sanitizeImageToJPEG: write failed \(error)")
      return nil
    }
  }
}

/// Donates iOS `INInteraction` shortcuts so MyFrame frame targets can appear in
/// the native Share Sheet suggestion row. Kept in AppDelegate.swift so it is
/// guaranteed to be part of the existing Runner target.
final class FrameShortcutPlugin: NSObject, FlutterPlugin {
  static let channelName = "myframe/frame_shortcuts"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = FrameShortcutPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "donateFrame", "donateFrameSelected":
      guard let args = call.arguments as? [String: Any],
            let frameName = args["frameName"] as? String,
            let frameMac = args["frameMac"] as? String else {
        result(FlutterError(code: "bad_args", message: "frameName/frameMac required", details: nil))
        return
      }
      donateFrame(
        frameName: frameName,
        frameMac: frameMac,
        withAppIcon: call.method == "donateFrameSelected",
        result: result
      )
    case "deleteAllDonations":
      if #available(iOS 12.0, *) {
        INInteraction.deleteAll { error in
          if let error = error {
            result(FlutterError(code: "donation_clear_failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      } else {
        result(FlutterError(code: "unsupported", message: "iOS < 12", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func donateFrame(
    frameName: String,
    frameMac: String,
    withAppIcon: Bool,
    result: @escaping FlutterResult
  ) {
    let cleanName = frameName.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = cleanName.isEmpty ? "MyFrame" : cleanName
    let mac = frameMac.trimmingCharacters(in: .whitespacesAndNewlines)
    let handle = INPersonHandle(value: mac.isEmpty ? name : mac, type: .unknown)
    let image: INImage?
    if withAppIcon,
       let icon = UIImage(named: "AppIcon") ?? Bundle.main.frameShortcutIcon(),
       let data = icon.pngData() {
      image = INImage(imageData: data)
    } else {
      image = nil
    }
    var nameComponents = PersonNameComponents()
    nameComponents.givenName = name
    let recipient = INPerson(
      personHandle: handle,
      nameComponents: nameComponents,
      displayName: name,
      image: image,
      contactIdentifier: nil,
      customIdentifier: mac.isEmpty ? nil : mac
    )

    guard #available(iOS 14.0, *) else {
      result(FlutterError(code: "unsupported", message: "Direct share targets require iOS 14+", details: nil))
      return
    }
    let intent = INSendMessageIntent(
      recipients: [recipient],
      outgoingMessageType: .outgoingMessageText,
      content: name,
      speakableGroupName: INSpeakableString(spokenPhrase: name),
      conversationIdentifier: mac.isEmpty ? name : mac,
      serviceName: nil,
      sender: nil,
      attachments: nil
    )
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.direction = INInteractionDirection.outgoing
    interaction.donate { error in
      if let error = error {
        result(FlutterError(code: "donation_failed", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }
}

private extension Bundle {
  func frameShortcutIcon() -> UIImage? {
    guard let icons = object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
          let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
          let files = primary["CFBundleIconFiles"] as? [String],
          let last = files.last else { return nil }
    return UIImage(named: last)
  }
}
