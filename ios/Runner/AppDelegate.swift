import Flutter
import UIKit
import NetworkExtension
import FirebaseCore

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
