import Flutter
import Photos
import UIKit

final class ICloudPhotosPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "myframe/icloud_photos",
      binaryMessenger: registrar.messenger()
    )
    let instance = ICloudPhotosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestAddPermission":
      requestPhotosAddPermission(result: result)
    case "saveImage":
      saveImage(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
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
