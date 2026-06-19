import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let iCloudPhotosChannelName = "myframe/icloud_photos"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: iCloudPhotosChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "requestAddPermission":
          self?.requestPhotosAddPermission(result: result)
        case "saveImage":
          self?.saveImage(call: call, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func requestPhotosAddPermission(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        DispatchQueue.main.async {
          result(status == .authorized || status == .limited)
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          result(status == .authorized)
        }
      }
    }
  }

  private func saveImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let data = args["bytes"] as? FlutterStandardTypedData,
      let image = UIImage(data: data.data)
    else {
      result(FlutterError(code: "bad_args", message: "Image data is invalid.", details: nil))
      return
    }

    let saveChange = {
      var localIdentifier = ""
      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
        localIdentifier = request.placeholderForCreatedAsset?.localIdentifier ?? ""
      }, completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            result(localIdentifier)
          } else {
            result(FlutterError(
              code: "save_failed",
              message: error?.localizedDescription ?? "Could not save to Apple Photos.",
              details: nil
            ))
          }
        }
      })
    }

    if #available(iOS 14, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      if status == .authorized || status == .limited {
        saveChange()
      } else {
        requestPhotosAddPermission { allowed in
          if (allowed as? Bool) == true {
            saveChange()
          } else {
            result(FlutterError(
              code: "permission_denied",
              message: "Photos permission was denied.",
              details: nil
            ))
          }
        }
      }
    } else {
      let status = PHPhotoLibrary.authorizationStatus()
      if status == .authorized {
        saveChange()
      } else {
        requestPhotosAddPermission { allowed in
          if (allowed as? Bool) == true {
            saveChange()
          } else {
            result(FlutterError(
              code: "permission_denied",
              message: "Photos permission was denied.",
              details: nil
            ))
          }
        }
      }
    }
  }
}
