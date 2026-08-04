import UIKit
import UniformTypeIdentifiers

/// Standalone Share Extension (no Flutter / CocoaPods dependency).
/// Writes shared images into the App Group and opens the host via
/// `ShareMedia-<bundleId>:share`, matching `receive_sharing_intent`.
class ShareViewController: UIViewController {
  private let appGroupIdKey = "AppGroupId"
  private let userDefaultsKey = "ShareKey"
  private let schemePrefix = "ShareMedia"
  private let imageType = UTType.image.identifier

  private var hostAppBundleIdentifier = ""
  private var appGroupId = ""
  private var pending = 0
  private var shared: [[String: Any]] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    loadIds()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    processAttachments()
  }

  private func loadIds() {
    let extId = Bundle.main.bundleIdentifier ?? ""
    if let idx = extId.lastIndex(of: ".") {
      hostAppBundleIdentifier = String(extId[..<idx])
    }
    let custom = Bundle.main.object(forInfoDictionaryKey: appGroupIdKey) as? String
    appGroupId = (custom?.isEmpty == false) ? custom! : "group.\(hostAppBundleIdentifier)"
  }

  private func processAttachments() {
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
          let attachments = item.attachments, !attachments.isEmpty else {
      completeAndClose()
      return
    }

    pending = attachments.count
    for attachment in attachments {
      if attachment.hasItemConformingToTypeIdentifier(imageType) {
        attachment.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] data, error in
          defer { self?.finishOne() }
          guard let self, error == nil else { return }
          if let url = data as? URL {
            self.copyFile(url)
          } else if let image = data as? UIImage {
            self.writeImage(image)
          }
        }
      } else {
        finishOne()
      }
    }
  }

  private func finishOne() {
    pending -= 1
    if pending <= 0 {
      DispatchQueue.main.async { [weak self] in
        self?.saveAndRedirect()
      }
    }
  }

  private func containerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
  }

  private func copyFile(_ src: URL) {
    guard let container = containerURL() else { return }
    let name = src.lastPathComponent.isEmpty
      ? "\(UUID().uuidString).jpg"
      : src.lastPathComponent
    let dest = container.appendingPathComponent(name)
    do {
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: src, to: dest)
      let path = dest.absoluteString.removingPercentEncoding ?? dest.absoluteString
      shared.append([
        "path": path,
        "mimeType": mimeType(for: dest),
        "type": "image",
      ])
    } catch {
      NSLog("[MyFrame Share] copy failed: \(error)")
    }
  }

  private func writeImage(_ image: UIImage) {
    guard let container = containerURL(),
          let data = image.jpegData(compressionQuality: 0.92) else { return }
    let dest = container.appendingPathComponent("\(UUID().uuidString).jpg")
    do {
      try data.write(to: dest, options: .atomic)
      let path = dest.absoluteString.removingPercentEncoding ?? dest.absoluteString
      shared.append([
        "path": path,
        "mimeType": "image/jpeg",
        "type": "image",
      ])
    } catch {
      NSLog("[MyFrame Share] write image failed: \(error)")
    }
  }

  private func mimeType(for url: URL) -> String {
    if let t = UTType(filenameExtension: url.pathExtension),
       let mime = t.preferredMIMEType {
      return mime
    }
    return "image/jpeg"
  }

  private func saveAndRedirect() {
    let defaults = UserDefaults(suiteName: appGroupId)
    if let data = try? JSONSerialization.data(withJSONObject: shared, options: []) {
      defaults?.set(data, forKey: userDefaultsKey)
      defaults?.synchronize()
    }
    redirectToHostApp()
  }

  private func redirectToHostApp() {
    loadIds()
    guard let url = URL(string: "\(schemePrefix)-\(hostAppBundleIdentifier):share") else {
      completeAndClose()
      return
    }

    var responder: UIResponder? = self
    if #available(iOS 18.0, *) {
      while responder != nil {
        if let application = responder as? UIApplication {
          application.open(url, options: [:], completionHandler: nil)
          break
        }
        responder = responder?.next
      }
    } else {
      let selector = sel_registerName("openURL:")
      while let r = responder {
        if r.responds(to: selector) {
          _ = r.perform(selector, with: url)
        }
        responder = r.next
      }
    }
    completeAndClose()
  }

  private func completeAndClose() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }
}
