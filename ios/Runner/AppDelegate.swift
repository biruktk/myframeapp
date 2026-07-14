import Flutter
import UIKit
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let registrar = registrar(forPlugin: "ICloudPhotosPlugin") {
      ICloudPhotosPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

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
            DispatchQueue.main.async {
              result(["enabled": enabled, "ssid": ssid])
            }
          }
        } else {
          result(["enabled": false, "ssid": ""])
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
