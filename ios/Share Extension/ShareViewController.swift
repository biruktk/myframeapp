import UIKit
import UniformTypeIdentifiers
import CoreImage
import CoreGraphics

/// Native MyFrame share sheet shown directly over the iOS Photos app.
///
/// - Presents a red-themed bottom sheet: "Sharing to MyFrame" header with a
///   Cancel button, photo count + scrolling thumbnail preview card, a "Send to"
///   frame card (red frame icon, frame name, device ID/SN, red checkmark
///   selection box), and a full-width rounded red Send button.
/// - Automatically transcodes every incoming image (HEIC, RAW/DNG, Display P3
///   PNG screenshots, alpha/16-bit PNG) into a standard 8-bit sRGB JPEG
///   (`UIImageJPEGRepresentation(image, 0.85)`).
/// - On Send, the bottom button turns into an inline progress state ("Uploading
///   1/2…" + a thin linear bar directly below the button) while the photos
///   upload **synchronously from the extension** (foreground session, [ShareUploader]).
///   The extension only dismisses after every image reaches the backend (2xx).
///   Failures surface inline as a status message with a Try Again button instead
///   of failing silently in the background.
///
/// This target is self-contained (no Flutter / CocoaPods dependency).
final class ShareViewController: UIViewController {
  // —— App Group / keys (keep in sync with Flutter ShareExtensionCache) ——
  private let appGroupIdKey = "AppGroupId"
  private let framesKey = "ShareExtensionFrames"
  private let selectedFramesKey = "ShareExtensionSelectedFrameIds"
  private let authTokenKey = "ShareExtensionAuthToken"

  // —— Brand red (#E53935) ——
  private static let brandRed = UIColor(red: 0.898, green: 0.224, blue: 0.208, alpha: 1)
  private static let brandRedTint = UIColor(red: 0.898, green: 0.224, blue: 0.208, alpha: 0.12)

  private let imageType = UTType.image.identifier
  private let jpegQuality: CGFloat = 0.85
  private let thumbnailSide: CGFloat = 72

  private var appGroupId = ""

  /// Cached frames (`id` / `name` / `mac` / `apiUrl` / `pairingToken`) written by the Flutter host.
  private var frames: [FrameInfo] = []
  /// Frame ids the user has chosen (persisted across shares).
  private var selectedFrameIds = Set<String>()

  private var attachmentProviders: [NSItemProvider] = []
  private var prepared: [PreparedItem] = []
  private var pending = 0
  private var hasFailedDecode = false
  private var isPreparing = false
  private var isSending = false

  // —— UI ——
  private let sheetView = UIView()
  private let thumbStack = UIStackView()
  private let frameStack = UIStackView()
  private let countLabel = UILabel()
  private let statusLabel = UILabel()
  private let sendButton = UIButton(type: .system)
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  /// Inline linear progress bar rendered just below the Send button during upload.
  private let uploadProgressBar = UIProgressView(progressViewStyle: .default)
  private var sheetBottomConstraint: NSLayoutConstraint?

  // Upload state retained so a failure can retry the same batch.
  private var currentTargets: [ShareUploader.Target] = []
  private var currentJpegURLs: [URL] = []
  private var currentAuthToken = ""

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    // Keep the root clear so the host's (Photos) dimmed sheet stays visible
    // behind our white bottom card.
    overrideUserInterfaceStyle = .light
    view.overrideUserInterfaceStyle = .light
    view.backgroundColor = .clear
    view.isOpaque = false

    loadAppGroupId()
    buildUI()
    loadCachedData()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // iOS 26 renders share-extension sheets with an opaque white background
    // even when the root view is `.clear`. Clearing every ancestor keeps the
    // presentation transparent so the host's dimmed Photos view shows through
    // above the white card.
    makeHierarchyTransparent()
  }

  /// iOS 26 workaround: walk the ancestor views and force them transparent.
  /// (The host presents the extension with its own `UISheetPresentationController`
  /// — `.medium()`/`.large()` detents and `modalPresentationStyle` set here are
  /// ignored by the host, so transparency is achieved by clearing the ancestors.)
  private func makeHierarchyTransparent() {
    var current: UIView? = view
    while let v = current {
      if v.backgroundColor != nil {
        v.backgroundColor = .clear
      }
      current = v.superview
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if prepared.isEmpty && !isPreparing {
      processAttachments()
    }
  }

  // MARK: - App Group resolution

  private func loadAppGroupId() {
    let custom = Bundle.main.object(forInfoDictionaryKey: appGroupIdKey) as? String
    appGroupId = (custom?.isEmpty == false) ? custom! : "group.com.myframe"
  }

  private func sharedDefaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  // MARK: - Cached frames & selection

  private func loadCachedData() {
    guard let defaults = sharedDefaults() else {
      NSLog("[MyFrame Share] no defaults for appGroupId=\(appGroupId)")
      return
    }

    // The host plugin stores frames/selection as strings via
    // `defaults.set(String, forKey:)`, so read with `string(forKey:)` — NOT
    // `data(forKey:)`, which returns nil for string values.
    let framesRaw = defaults.string(forKey: framesKey)
    NSLog("[MyFrame Share] appGroupId=\(appGroupId) framesRaw=\(framesRaw ?? "<nil>")")
    if let raw = framesRaw,
       let list = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [[String: Any]] {
      frames = list.compactMap { FrameInfo(row: $0) }
    }
    NSLog("[MyFrame Share] loaded \(frames.count) cached frame(s)")

    if let raw = defaults.string(forKey: selectedFramesKey),
       let ids = try? JSONDecoder().decode([String].self, from: Data(raw.utf8)) {
      selectedFrameIds = Set(ids.filter { id in
        if id.trimmedNonEmpty == nil { return false }
        // Keep in selection only if online
        return frames.first(where: { $0.id == id })?.isOnline ?? false
      })
    }

    // Pre-select the last used frame (if online); fall back to the first online cached frame.
    if selectedFrameIds.isEmpty, let firstOnline = frames.first(where: { $0.isOnline }) {
      selectedFrameIds.insert(firstOnline.id)
    }
    rebuildFrameList()
  }

  private func persistSelection() {
    guard let defaults = sharedDefaults() else { return }
    // Store as a JSON string to match the host's writeSelectedFrameIds format,
    // which the sheet reads back with `string(forKey:)`.
    let encoded = (try? JSONEncoder().encode(Array(selectedFrameIds)))
      .flatMap { String(data: $0, encoding: .utf8) }
    defaults.set(encoded ?? "[]", forKey: selectedFramesKey)
  }

  // MARK: - Attachment processing (transcoding & iCloud resolution)

  private func processAttachments() {
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
          let attachments = item.attachments else {
      showNoImages()
      return
    }

    let supportedUTIs = [
      UTType.image.identifier,
      "public.image",
      "public.jpeg",
      "public.png",
      "public.heic",
      UTType.url.identifier,
      "public.file-url"
    ]

    attachmentProviders = attachments.filter { provider in
      for uti in supportedUTIs {
        if provider.hasItemConformingToTypeIdentifier(uti) {
          return true
        }
      }
      return false
    }

    guard !attachmentProviders.isEmpty else {
      showNoImages()
      return
    }

    isPreparing = true
    updateSendEnabled()
    setStatus(nil, showSpinner: true)

    pending = attachmentProviders.count

    for provider in attachmentProviders {
      // Determine conforming type identifier
      let typeId: String
      if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        typeId = UTType.image.identifier
      } else if provider.hasItemConformingToTypeIdentifier("public.image") {
        typeId = "public.image"
      } else if provider.hasItemConformingToTypeIdentifier("public.jpeg") {
        typeId = "public.jpeg"
      } else if provider.hasItemConformingToTypeIdentifier("public.png") {
        typeId = "public.png"
      } else if provider.hasItemConformingToTypeIdentifier("public.heic") {
        typeId = "public.heic"
      } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        typeId = UTType.url.identifier
      } else {
        typeId = UTType.image.identifier
      }

      // Asynchronous iCloud Resolution: loadFileRepresentation fetches iCloud offloaded images automatically
      provider.loadFileRepresentation(forTypeIdentifier: typeId) { [weak self] url, error in
        if let url = url, error == nil {
          self?.prepareImage(from: url)
          self?.finishOne()
        } else {
          // Fallback to loadInPlaceFileRepresentation
          provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeId) { [weak self] url, _, error in
            if let url = url, error == nil {
              self?.prepareImage(from: url)
              self?.finishOne()
            } else {
              // Final fallback to loadItem
              provider.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] item, error in
                defer { self?.finishOne() }
                guard let self = self, error == nil else {
                  self?.hasFailedDecode = true
                  return
                }
                if let url = item as? URL {
                  self.prepareImage(from: url)
                } else if let image = item as? UIImage {
                  self.prepareImage(image, nameHint: "image.jpg")
                } else if let data = item as? Data {
                  self.prepareImage(data)
                } else {
                  self.hasFailedDecode = true
                }
              }
            }
          }
        }
      }
    }
  }

  private func finishOne() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.pending -= 1
      if self.pending <= 0 {
        self.finishPreparing()
      }
    }
  }

  private func finishPreparing() {
    isPreparing = false
    let count = prepared.count
    if count == 0 {
      setStatus(NSLocalizedString("Couldn't read these images.", comment: ""), showSpinner: false)
    } else {
      setStatus(nil, showSpinner: false)
      countLabel.text = count == 1
        ? NSLocalizedString("1 Photo", comment: "Share sheet photo count")
        : String.localizedStringWithFormat(
            NSLocalizedString("%d Photos", comment: "Share sheet photo count"), count)
    }
    rebuildThumbnails()
    updateSendEnabled()
  }

  private func prepareImage(from url: URL) {
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      hasFailedDecode = true
      return
    }

    let uploadDir = container.appendingPathComponent("Uploads", isDirectory: true)
    try? FileManager.default.createDirectory(at: uploadDir, withIntermediateDirectories: true)

    let filename = "share_\(UUID().uuidString).jpg"
    let destinationURL = uploadDir.appendingPathComponent(filename)

    // Downsample using CGImageSource (Memory-efficient: max pixel size 2048 to prevent 120MB Extension Jetsam crash)
    if let downsampledImage = downsample(imageAt: url, toMaxPixelSize: 2048) {
      saveAndPrepare(image: downsampledImage, destinationURL: destinationURL, filename: filename)
      return
    }

    // Fallback: decodeImage
    if let fallbackImage = decodeImage(url: url) {
      saveAndPrepare(image: fallbackImage, destinationURL: destinationURL, filename: filename)
      return
    }

    hasFailedDecode = true
  }

  private func prepareImage(_ image: UIImage, nameHint: String) {
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      hasFailedDecode = true
      return
    }

    let uploadDir = container.appendingPathComponent("Uploads", isDirectory: true)
    try? FileManager.default.createDirectory(at: uploadDir, withIntermediateDirectories: true)

    let filename = "share_\(UUID().uuidString).jpg"
    let destinationURL = uploadDir.appendingPathComponent(filename)

    saveAndPrepare(image: image, destinationURL: destinationURL, filename: filename)
  }

  private func prepareImage(_ data: Data) {
    guard let image = UIImage(data: data) else {
      hasFailedDecode = true
      return
    }
    prepareImage(image, nameHint: "image.jpg")
  }

  /// Memory-efficient downsampling via CGImageSource to prevent 120MB Extension Jetsam crash.
  private func downsample(imageAt imageURL: URL, toMaxPixelSize maxPixelSize: CGFloat) -> UIImage? {
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
      return nil
    }

    let downsampleOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ] as CFDictionary

    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
      return nil
    }

    return UIImage(cgImage: downsampledImage)
  }

  private func saveAndPrepare(image: UIImage, destinationURL: URL, filename: String) {
    let size = image.size
    guard size.width > 0, size.height > 0 else {
      hasFailedDecode = true
      return
    }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.preferredRange = .standard
    let rgb = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }

    guard let jpegData = rgb.jpegData(compressionQuality: jpegQuality) else {
      hasFailedDecode = true
      return
    }

    do {
      try jpegData.write(to: destinationURL, options: .atomic)
      let thumb = makeThumbnail(rgb)
      prepared.append(
        PreparedItem(
          thumb: thumb,
          fileURL: destinationURL,
          filename: filename
        )
      )
    } catch {
      hasFailedDecode = true
    }
  }

  /// Decodes HEIC, JPEG, PNG (incl. Display P3) and RAW/DNG files.
  private func decodeImage(url: URL) -> UIImage? {
    if let image = UIImage(contentsOfFile: url.path) {
      return image
    }
    // RAW (DNG) fallback: render through Core Image into sRGB. Cap the render
    // size so large RAW frames do not exhaust the extension memory budget.
    guard let ci = CIImage(
      contentsOf: url,
      options: [.applyOrientationProperty: true]
    ) ?? CIImage(contentsOf: url) else {
      return nil
    }
    let extent = ci.extent
    guard extent.width > 0, extent.height > 0 else { return nil }
    let maxSide: CGFloat = 2048
    var scale: CGFloat = 1
    if max(extent.width, extent.height) > maxSide {
      scale = maxSide / max(extent.width, extent.height)
    }
    let renderRect = extent.applying(CGAffineTransform(scaleX: scale, y: scale))
    let context = CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? NSNull(),
      .useSoftwareRenderer: true,
    ])
    guard let cg = context.createCGImage(ci, from: renderRect) else { return nil }
    return UIImage(cgImage: cg)
  }

  private func makeThumbnail(_ image: UIImage) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: thumbnailSide, height: thumbnailSide))
    return renderer.image { _ in
      let scale = max(thumbnailSide / image.size.width, thumbnailSide / image.size.height)
      let w = image.size.width * scale
      let h = image.size.height * scale
      image.draw(in: CGRect(
        x: (thumbnailSide - w) / 2,
        y: (thumbnailSide - h) / 2,
        width: w,
        height: h
      ))
    }
  }

  // MARK: - Upload Trigger

  @objc private func onSendTapped() {
    guard !isSending, !selectedFrameIds.isEmpty, !prepared.isEmpty else { return }
    isSending = true
    updateSendEnabled()
    persistSelection()
    let total = selectedFrameIds.count * prepared.count
    showInlineProgress(
      completed: 0,
      total: total,
      detail: NSLocalizedString("Preparing…", comment: "Share sheet preparing")
    )
    DispatchQueue.main.async { [weak self] in
      self?.prepareAndStartUpload()
    }
  }

  private func prepareAndStartUpload() {
    guard !prepared.isEmpty else {
      failSend()
      return
    }

    var jpegURLs: [URL] = []
    for item in prepared {
      if FileManager.default.fileExists(atPath: item.fileURL.path) {
        jpegURLs.append(item.fileURL)
      }
    }

    guard !jpegURLs.isEmpty else {
      failSend()
      return
    }

    currentTargets = frames
      .filter { selectedFrameIds.contains($0.id) }
      .map {
        ShareUploader.Target(
          name: $0.name,
          deviceId: $0.id,
          mac: $0.mac,
          apiUrl: $0.apiUrl,
          pairingToken: $0.pairingToken
        )
      }

    guard !currentTargets.isEmpty else {
      failSend()
      return
    }

    currentJpegURLs = jpegURLs
    currentAuthToken = sharedDefaults()?.string(forKey: authTokenKey) ?? ""
    startUpload()
  }

  private func startUpload() {
    showInlineProgress(
      completed: 0,
      total: currentTargets.count * currentJpegURLs.count,
      detail: ""
    )

    // Local copies so the detached Task doesn't capture the view controller.
    let targets = currentTargets
    let files = currentJpegURLs
    let token = currentAuthToken

    Task {
      let results = await ShareUploader.shared.upload(
        targets: targets,
        jpegFiles: files,
        authToken: token
      ) { [weak self] completed, total, detail in
        DispatchQueue.main.async {
          self?.showInlineProgress(completed: completed, total: total, detail: detail)
        }
      }
      DispatchQueue.main.async { [weak self] in
        self?.finishUpload(results)
      }
    }
  }

  private func finishUpload(_ results: [ShareUploader.FileResult]) {
    let failures = results.filter { !$0.success }
    guard failures.isEmpty else {
      var message: String
      if failures.count == results.count {
        message = NSLocalizedString(
          "We couldn't upload the photos. Check your connection and try again.",
          comment: "Share sheet upload error"
        )
      } else {
        message = String.localizedStringWithFormat(
          NSLocalizedString(
            "Only %d of %d photos uploaded. Check your connection and try again.",
            comment: "Share sheet partial upload error"
          ),
          results.count - failures.count,
          results.count
        )
      }
      let detail = failures.first?.message ?? ""
      showInlineError(message: detail.isEmpty ? message : "\(message)\n\(detail)")
      return
    }

    // All images reached the backend — Success! state, then auto-close.
    cleanUpUploadFiles()
    uploadProgressBar.setProgress(1, animated: true)
    sendButton.isEnabled = false
    sendButton.backgroundColor = Self.brandRed
    sendButton.setImage(
      UIImage(systemName: "checkmark.circle.fill"),
      for: .normal
    )
    sendButton.imageView?.tintColor = .white
    sendButton.setTitle(NSLocalizedString("Success!", comment: "Share sheet success"), for: .normal)
    statusLabel.text = NSLocalizedString(
      "Photos sent to your frame.",
      comment: "Share sheet success detail"
    )
    activityIndicator.stopAnimating()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.completeAndClose()
    }
  }

  /// Turns the Send button into a disabled progress state with a live step
  /// label and a smoothly filling linear bar directly below the button.
  private func showInlineProgress(completed: Int, total: Int, detail: String) {
    sendButton.isEnabled = false
    sendButton.backgroundColor = Self.brandRed
    sendButton.setImage(nil, for: .normal)
    sendButton.setTitle(
      String.localizedStringWithFormat(
        NSLocalizedString("Uploading %d/%d…", comment: "Share sheet upload progress"),
        completed,
        total
      ),
      for: .normal
    )
    uploadProgressBar.isHidden = false
    uploadProgressBar.setProgress(total > 0 ? Float(completed) / Float(total) : 0, animated: true)
    statusLabel.text = detail.isEmpty ? nil : detail
    activityIndicator.stopAnimating()
  }

  /// Inline failure handling: status message + Try Again button (no popup).
  private func showInlineError(message: String) {
    isSending = false
    uploadProgressBar.isHidden = true
    sendButton.isEnabled = true
    sendButton.backgroundColor = Self.brandRed
    sendButton.setImage(nil, for: .normal)
    sendButton.setTitle(NSLocalizedString("Try Again", comment: "Share sheet retry"), for: .normal)
    statusLabel.text = message
    activityIndicator.stopAnimating()
  }

  private func cleanUpUploadFiles() {
    guard let container = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
    let uploadDir = container.appendingPathComponent("Uploads", isDirectory: true)
    try? FileManager.default.removeItem(at: uploadDir)
  }

  private func failSend() {
    setStatus(
      NSLocalizedString("Couldn't prepare these photos.", comment: "Share sheet failure"),
      showSpinner: false
    )
    isSending = false
    updateSendEnabled()
  }

  private func completeAndClose() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  // MARK: - UI

  private func buildUI() {
    // Root stays clear — the OS (Photos) already dims behind the white card.
    view.backgroundColor = .clear

    let panelHeight = min(560, UIScreen.main.bounds.height * 0.6)

    // Bright bottom-sheet card.
    sheetView.translatesAutoresizingMaskIntoConstraints = false
    sheetView.backgroundColor = .white
    sheetView.layer.cornerRadius = 24
    sheetView.layer.cornerCurve = .continuous
    sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    sheetView.layer.shadowColor = UIColor.black.cgColor
    sheetView.layer.shadowOpacity = 0.12
    sheetView.layer.shadowRadius = 12
    sheetView.layer.shadowOffset = CGSize(width: 0, height: -2)
    view.addSubview(sheetView)

    let content = UIView()
    content.translatesAutoresizingMaskIntoConstraints = false
    sheetView.addSubview(content)

    let sheetHeight = sheetView.heightAnchor.constraint(equalToConstant: panelHeight)
    sheetHeight.priority = .defaultHigh
    NSLayoutConstraint.activate([
      sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      sheetView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.7),
      sheetHeight,

      content.topAnchor.constraint(equalTo: sheetView.topAnchor),
      content.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor),
      content.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
    ])
    let bottom = sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    sheetBottomConstraint = bottom
    NSLayoutConstraint.activate([bottom])

    buildSheetContent(content)

    // Slide-in animation.
    view.layoutIfNeeded()
    sheetBottomConstraint?.constant = panelHeight
    view.layoutIfNeeded()
    sheetBottomConstraint?.constant = 0
    UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
      self.view.layoutIfNeeded()
    }
  }

  private func buildSheetContent(_ content: UIView) {
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.alwaysBounceVertical = false
    content.addSubview(scroll)

    let column = UIStackView()
    column.translatesAutoresizingMaskIntoConstraints = false
    column.axis = .vertical
    column.spacing = 14
    column.layoutMargins = UIEdgeInsets(top: 10, left: 20, bottom: 16, right: 20)
    column.isLayoutMarginsRelativeArrangement = true
    scroll.addSubview(column)

    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: content.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),

      column.topAnchor.constraint(equalTo: scroll.topAnchor),
      column.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
      column.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
      column.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
      column.widthAnchor.constraint(equalTo: scroll.widthAnchor),
    ])

    // Drag handle (wrapped so the 42pt pill doesn't fight the stack's fill alignment).
    let handle = UIView()
    handle.translatesAutoresizingMaskIntoConstraints = false
    handle.backgroundColor = UIColor.systemFill
    handle.layer.cornerRadius = 2.5
    let handleWrap = UIView()
    handleWrap.translatesAutoresizingMaskIntoConstraints = false
    handleWrap.addSubview(handle)
    column.addArrangedSubview(handleWrap)
    NSLayoutConstraint.activate([
      handleWrap.heightAnchor.constraint(equalToConstant: 5),
      handle.centerXAnchor.constraint(equalTo: handleWrap.centerXAnchor),
      handle.centerYAnchor.constraint(equalTo: handleWrap.centerYAnchor),
      handle.widthAnchor.constraint(equalToConstant: 42),
      handle.heightAnchor.constraint(equalToConstant: 5),
    ])

    // Header: title left, light Cancel button right.
    let header = UIView()
    header.translatesAutoresizingMaskIntoConstraints = false
    let title = UILabel()
    title.translatesAutoresizingMaskIntoConstraints = false
    title.text = NSLocalizedString("Sharing to MyFrame", comment: "Share sheet title")
    title.font = .systemFont(ofSize: 20, weight: .bold)
    title.adjustsFontForContentSizeCategory = true
    header.addSubview(title)

    let cancel = UIButton(type: .system)
    cancel.translatesAutoresizingMaskIntoConstraints = false
    cancel.setTitle(NSLocalizedString("Cancel", comment: "Cancel share"), for: .normal)
    cancel.setTitleColor(.secondaryLabel, for: .normal)
    cancel.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
    cancel.addTarget(self, action: #selector(onCancel), for: .touchUpInside)
    header.addSubview(cancel)

    NSLayoutConstraint.activate([
      header.heightAnchor.constraint(equalToConstant: 36),
      title.leadingAnchor.constraint(equalTo: header.leadingAnchor),
      title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
      cancel.trailingAnchor.constraint(equalTo: header.trailingAnchor),
      cancel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
      cancel.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 8),
      cancel.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
    ])
    column.addArrangedSubview(header)

    // Media section.
    let photoLabel = UILabel()
    photoLabel.translatesAutoresizingMaskIntoConstraints = false
    photoLabel.text = NSLocalizedString("Photos", comment: "Share sheet section")
    photoLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    photoLabel.textColor = .secondaryLabel
    photoLabel.adjustsFontForContentSizeCategory = true
    column.addArrangedSubview(photoLabel)

    countLabel.translatesAutoresizingMaskIntoConstraints = false
    countLabel.text = NSLocalizedString("Preparing…", comment: "Share sheet preparing")
    countLabel.font = .systemFont(ofSize: 15, weight: .semibold)
    countLabel.adjustsFontForContentSizeCategory = true
    column.addArrangedSubview(countLabel)

    // Thumbnail preview card.
    let strip = UIScrollView()
    strip.translatesAutoresizingMaskIntoConstraints = false
    strip.backgroundColor = UIColor.secondarySystemBackground
    strip.layer.cornerRadius = 16
    strip.clipsToBounds = true
    strip.alwaysBounceHorizontal = true
    strip.showsHorizontalScrollIndicator = false
    column.addArrangedSubview(strip)

    thumbStack.translatesAutoresizingMaskIntoConstraints = false
    thumbStack.axis = .horizontal
    thumbStack.spacing = 8
    thumbStack.alignment = .center
    thumbStack.distribution = .fill
    strip.addSubview(thumbStack)

    NSLayoutConstraint.activate([
      strip.heightAnchor.constraint(equalToConstant: thumbnailSide + 24),
      thumbStack.topAnchor.constraint(equalTo: strip.topAnchor, constant: 12),
      thumbStack.bottomAnchor.constraint(equalTo: strip.bottomAnchor, constant: -12),
      thumbStack.leadingAnchor.constraint(equalTo: strip.leadingAnchor, constant: 10),
      thumbStack.trailingAnchor.constraint(equalTo: strip.trailingAnchor, constant: -10),
    ])

    // Status line.
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.font = .systemFont(ofSize: 13)
    statusLabel.textColor = .secondaryLabel
    statusLabel.numberOfLines = 0
    statusLabel.adjustsFontForContentSizeCategory = true
    column.addArrangedSubview(statusLabel)

    // Destination section.
    let destinationLabel = UILabel()
    destinationLabel.translatesAutoresizingMaskIntoConstraints = false
    destinationLabel.text = NSLocalizedString("Send to", comment: "Share sheet destination")
    destinationLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    destinationLabel.textColor = .secondaryLabel
    destinationLabel.adjustsFontForContentSizeCategory = true
    column.addArrangedSubview(destinationLabel)

    frameStack.translatesAutoresizingMaskIntoConstraints = false
    frameStack.axis = .vertical
    frameStack.spacing = 8
    column.addArrangedSubview(frameStack)
    column.setCustomSpacing(18, after: frameStack)

    // Red Send button.
    sendButton.translatesAutoresizingMaskIntoConstraints = false
    sendButton.setTitle(NSLocalizedString("Send", comment: "Share sheet send"), for: .normal)
    sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
    sendButton.setTitleColor(.white, for: .normal)
    sendButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
    sendButton.layer.cornerRadius = 16
    sendButton.layer.cornerCurve = .continuous
    sendButton.clipsToBounds = true
    sendButton.backgroundColor = Self.brandRed
    sendButton.addTarget(self, action: #selector(onSendTapped), for: .touchUpInside)
    sendButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
    column.addArrangedSubview(sendButton)

    sendButton.addSubview(activityIndicator)
    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    activityIndicator.color = .white
    activityIndicator.hidesWhenStopped = true
    NSLayoutConstraint.activate([
      activityIndicator.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
      activityIndicator.trailingAnchor.constraint(equalTo: sendButton.trailingAnchor, constant: -18),
    ])

    // Inline linear progress bar pinned just below the Send button.
    uploadProgressBar.translatesAutoresizingMaskIntoConstraints = false
    uploadProgressBar.progressTintColor = Self.brandRed
    uploadProgressBar.trackTintColor = Self.brandRed.withAlphaComponent(0.15)
    uploadProgressBar.layer.cornerRadius = 2.5
    uploadProgressBar.clipsToBounds = true
    uploadProgressBar.isHidden = true
    column.addArrangedSubview(uploadProgressBar)
    uploadProgressBar.heightAnchor.constraint(equalToConstant: 4).isActive = true
    column.setCustomSpacing(10, after: uploadProgressBar)
  }

  // MARK: - Frame list

  private func rebuildFrameList() {
    for arranged in frameStack.arrangedSubviews {
      frameStack.removeArrangedSubview(arranged)
      arranged.removeFromSuperview()
    }

    if frames.isEmpty {
      let hint = UILabel()
      hint.translatesAutoresizingMaskIntoConstraints = false
      hint.text = NSLocalizedString(
        "Connect a frame in MyFrame first, then share again to upload.",
        comment: "Share sheet no frames"
      )
      hint.font = .systemFont(ofSize: 14)
      hint.textColor = .secondaryLabel
      hint.numberOfLines = 0
      hint.adjustsFontForContentSizeCategory = true
      frameStack.addArrangedSubview(hint)
      updateSendEnabled()
      return
    }

    for frame in frames {
      let row = makeFrameRow(frame)
      frameStack.addArrangedSubview(row)
    }
    updateSendEnabled()
  }

  private func makeFrameRow(_ frame: FrameInfo) -> UIView {
    let isSelected = selectedFrameIds.contains(frame.id) && frame.isOnline

    let row = UIControl()
    row.translatesAutoresizingMaskIntoConstraints = false
    row.isUserInteractionEnabled = true
    row.accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    row.accessibilityLabel = frame.name
    row.accessibilityValue = isSelected ? "1" : "0"

    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.isUserInteractionEnabled = false
    container.backgroundColor = isSelected
      ? Self.brandRedTint
      : UIColor.secondarySystemBackground
    container.layer.cornerRadius = 14
    container.layer.cornerCurve = .continuous
    row.addSubview(container)

    // Red frame icon.
    let iconWrap = UIView()
    iconWrap.translatesAutoresizingMaskIntoConstraints = false
    iconWrap.backgroundColor = Self.brandRedTint
    iconWrap.layer.cornerRadius = 10
    iconWrap.layer.cornerCurve = .continuous
    container.addSubview(iconWrap)

    let icon = UIImageView(image: UIImage(systemName: "rectangle.portrait"))
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.tintColor = Self.brandRed
    icon.contentMode = .scaleAspectFit
    iconWrap.addSubview(icon)

    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = frame.name
    label.font = .systemFont(ofSize: 15, weight: .semibold)
    label.adjustsFontForContentSizeCategory = true
    container.addSubview(label)

    let subtitle = UILabel()
    subtitle.translatesAutoresizingMaskIntoConstraints = false
    subtitle.text = frame.id
    subtitle.font = .systemFont(ofSize: 12)
    subtitle.textColor = .secondaryLabel
    subtitle.adjustsFontForContentSizeCategory = true
    container.addSubview(subtitle)

    // Offline Badge / Label
    let statusLabel = UILabel()
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.font = .systemFont(ofSize: 11, weight: .bold)
    statusLabel.textColor = .white
    statusLabel.text = "Offline"
    statusLabel.backgroundColor = .systemGray
    statusLabel.layer.cornerRadius = 4
    statusLabel.clipsToBounds = true
    statusLabel.textAlignment = .center
    statusLabel.isHidden = frame.isOnline
    container.addSubview(statusLabel)

    // Red checkmark selection box.
    let checkBox = UIView()
    checkBox.translatesAutoresizingMaskIntoConstraints = false
    checkBox.layer.cornerRadius = 7
    checkBox.layer.cornerCurve = .continuous
    checkBox.layer.borderWidth = 1.5
    checkBox.layer.borderColor = isSelected
      ? Self.brandRed.cgColor
      : Self.brandRed.withAlphaComponent(0.5).cgColor
    checkBox.backgroundColor = isSelected ? Self.brandRed : .clear
    checkBox.isHidden = !frame.isOnline
    container.addSubview(checkBox)

    let check = UIImageView(image: UIImage(systemName: "checkmark"))
    check.translatesAutoresizingMaskIntoConstraints = false
    check.tintColor = .white
    check.isHidden = !isSelected
    check.contentMode = .scaleAspectFit
    checkBox.addSubview(check)

    if !frame.isOnline {
      row.alpha = 0.5
    }

    NSLayoutConstraint.activate([
      row.heightAnchor.constraint(equalToConstant: 68),
      container.topAnchor.constraint(equalTo: row.topAnchor),
      container.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      container.leadingAnchor.constraint(equalTo: row.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: row.trailingAnchor),

      iconWrap.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
      iconWrap.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      iconWrap.widthAnchor.constraint(equalToConstant: 40),
      iconWrap.heightAnchor.constraint(equalToConstant: 40),
      icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 22),
      icon.heightAnchor.constraint(equalToConstant: 22),

      label.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: 12),
      label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
      label.trailingAnchor.constraint(lessThanOrEqualTo: frame.isOnline ? checkBox.leadingAnchor : statusLabel.leadingAnchor, constant: -10),

      subtitle.leadingAnchor.constraint(equalTo: label.leadingAnchor),
      subtitle.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2),
      subtitle.trailingAnchor.constraint(lessThanOrEqualTo: frame.isOnline ? checkBox.leadingAnchor : statusLabel.leadingAnchor, constant: -10),

      statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      statusLabel.widthAnchor.constraint(equalToConstant: 54),
      statusLabel.heightAnchor.constraint(equalToConstant: 20),

      checkBox.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      checkBox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      checkBox.widthAnchor.constraint(equalToConstant: 26),
      checkBox.heightAnchor.constraint(equalToConstant: 26),
      check.centerXAnchor.constraint(equalTo: checkBox.centerXAnchor),
      check.centerYAnchor.constraint(equalTo: checkBox.centerYAnchor),
      check.widthAnchor.constraint(equalToConstant: 15),
      check.heightAnchor.constraint(equalToConstant: 15),
    ])

    row.addTarget(self, action: #selector(onFrameTapped(_:)), for: .touchUpInside)
    row.tag = frameStack.arrangedSubviews.count
    return row
  }

  @objc private func onFrameTapped(_ sender: UIControl) {
    guard !isSending, sender.tag < frames.count else { return }
    let frame = frames[sender.tag]
    if !frame.isOnline {
      let alert = UIAlertController(
        title: NSLocalizedString("Frame Offline", comment: ""),
        message: NSLocalizedString("This frame is currently offline and cannot receive photos.", comment: ""),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
      present(alert, animated: true, completion: nil)
      return
    }
    let id = frame.id
    if selectedFrameIds.contains(id) {
      selectedFrameIds.remove(id)
    } else {
      selectedFrameIds.insert(id)
    }
    rebuildFrameList()
  }

  private func rebuildThumbnails() {
    for arranged in thumbStack.arrangedSubviews {
      thumbStack.removeArrangedSubview(arranged)
      arranged.removeFromSuperview()
    }
    guard !prepared.isEmpty else {
      let placeholder = UIView()
      placeholder.translatesAutoresizingMaskIntoConstraints = false
      placeholder.backgroundColor = UIColor.systemFill
      placeholder.layer.cornerRadius = 10
      placeholder.widthAnchor.constraint(equalToConstant: thumbnailSide).isActive = true
      placeholder.heightAnchor.constraint(equalToConstant: thumbnailSide).isActive = true
      thumbStack.addArrangedSubview(placeholder)
      return
    }
    for item in prepared {
      let imageView = UIImageView(image: item.thumb)
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.contentMode = .scaleAspectFill
      imageView.layer.cornerRadius = 8
      imageView.layer.cornerCurve = .continuous
      imageView.clipsToBounds = true
      // Strict 1:1 square tiles — required size constraints + high resistance
      // prevent the horizontal stack from ever stretching them wide/flat.
      imageView.widthAnchor.constraint(equalToConstant: thumbnailSide).isActive = true
      imageView.heightAnchor.constraint(equalToConstant: thumbnailSide).isActive = true
      imageView.setContentHuggingPriority(.required, for: .horizontal)
      imageView.setContentHuggingPriority(.required, for: .vertical)
      imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
      thumbStack.addArrangedSubview(imageView)
    }
  }

  private func updateSendEnabled() {
    let onlineSelected = selectedFrameIds.filter { id in
      frames.first(where: { $0.id == id })?.isOnline ?? false
    }
    let enabled = !isPreparing && !isSending && !onlineSelected.isEmpty && !prepared.isEmpty
    sendButton.isEnabled = enabled
    sendButton.backgroundColor = enabled ? Self.brandRed : .systemGray3
    if enabled {
      sendButton.setImage(nil, for: .normal)
      sendButton.setTitle(NSLocalizedString("Send", comment: "Share sheet send"), for: .normal)
      uploadProgressBar.isHidden = true
    }
  }

  private func setStatus(_ text: String?, showSpinner: Bool) {
    statusLabel.text = text
    if showSpinner {
      activityIndicator.startAnimating()
    } else {
      activityIndicator.stopAnimating()
    }
  }

  private func showNoImages() {
    setStatus(
      NSLocalizedString("No supported images to share.", comment: "Share sheet empty"),
      showSpinner: false
    )
  }

  @objc private func onCancel() {
    // Block Cancel while uploads are actively running. Once a share finishes
    // (or fails back to the "Try Again" state) the sheet can be dismissed.
    guard !isSending else { return }
    cleanUpUploadFiles()
    completeAndClose()
  }
}

// MARK: - Model

private struct FrameInfo {
  let id: String
  let name: String
  let mac: String
  let apiUrl: String
  let pairingToken: String
  let isOnline: Bool

  init?(row: [String: Any]) {
    guard let id = (row["id"] as? String)?.trimmedNonEmpty else { return nil }
    self.id = id
    name = (row["name"] as? String)?.trimmedNonEmpty ?? id
    mac = (row["mac"] as? String)?.trimmedNonEmpty ?? id
    
    let rawApiUrl = (row["apiUrl"] as? String) ?? ""
    var cleanUrl = rawApiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    if !cleanUrl.isEmpty {
      if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
        cleanUrl = "http://" + cleanUrl
      }
      if cleanUrl.hasSuffix("/") {
        cleanUrl = String(cleanUrl.dropLast())
      }
    }
    apiUrl = cleanUrl
    
    pairingToken = (row["pairingToken"] as? String) ?? ""
    isOnline = (row["is_online"] as? Bool) ?? false
  }
}

private final class PreparedItem {
  let thumb: UIImage
  let fileURL: URL
  let filename: String

  init(thumb: UIImage, fileURL: URL, filename: String) {
    self.thumb = thumb
    self.fileURL = fileURL
    self.filename = filename
  }
}

private extension String {
  var trimmedNonEmpty: String? {
    let t = trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? nil : t
  }
}
