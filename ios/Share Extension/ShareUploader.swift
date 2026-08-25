import Foundation
import CryptoKit

/// Uploads the transcoded JPEGs from the Share Extension **synchronously
/// (foreground)** while the progress HUD is on screen, replicating the exact
/// multipart contract of `FrameApiClient.uploadPhoto`:
///
///   POST {apiUrl}/api/frames/{macSlug}/upload
///   fields: mac, device_id, checksum(sha256), size, app_platform=flutter,
///           slideshow_style=classic, display_seconds, transport=wifi, skip_play=true
///   file:   photo (image/jpeg)
///   headers: x-pairing-token, Authorization: Bearer <jwt>
///
/// Routing matches the app's external-share flow:
///   - **1 image**   → single upload lands in the frame's "Personal"/direct
///                     collection (no playlist publish).
///   - **>1 images** → every image uploads, then the batch is published as a
///                     frame **Playlist** via `POST /api/frames/{mac}/slideshow`.
///
/// Uploads run on a foreground `URLSession` (not background), so HTTP status
/// codes and per-file progress arrive while the sheet is visible. The
/// extension is only dismissed after every image reaches the backend (2xx).
final class ShareUploader {
  static let shared = ShareUploader()

  /// A single target frame the user selected in the sheet.
  struct Target {
    let name: String
    /// Frame id shown in the UI (device id / SN).
    let deviceId: String
    /// Upload identity (station MAC preferred); sanitized to last 12 hex.
    let mac: String
    /// Base URL, e.g. `http://47.76.164.162:3001`.
    let apiUrl: String
    let pairingToken: String
  }

  /// Outcome for a single file → target upload request.
  struct FileResult {
    let filename: String
    let success: Bool
    let message: String
  }

  enum ShareUploadError: LocalizedError {
    case missingMacOrUrl
    case emptyBody
    case badResponse(status: Int, body: String)
    case network(String)

    var errorDescription: String? {
      switch self {
      case .missingMacOrUrl:
        return NSLocalizedString("Missing frame MAC or server URL.", comment: "Share upload error")
      case .emptyBody:
        return NSLocalizedString("Couldn't build the upload payload.", comment: "Share upload error")
      case .badResponse(let status, _):
        return String.localizedStringWithFormat(
          NSLocalizedString("The frame server returned HTTP %d.", comment: "Share upload error"),
          status
        )
      case .network(let message):
        return message
      }
    }
  }

  private let boundary = "MyFrameBoundary.\(UUID().uuidString)"

  /// Uploads every JPEG to every selected target sequentially (foreground
  /// session so results arrive while the sheet is on screen). Calls
  /// [onProgress] after every completed file→target upload so the HUD can
  /// render "Uploading X of Y…". Returns per-file results; the caller shows
  /// an error + retry when any result reports failure.
  func upload(
    targets: [Target],
    jpegFiles: [URL],
    authToken: String,
    onProgress: @escaping (_ completed: Int, _ total: Int, _ detail: String) -> Void
  ) async -> [FileResult] {
    let session = URLSession(
      configuration: .default,
      delegate: nil,
      delegateQueue: OperationQueue()
    )
    defer { session.invalidateAndCancel() }

    let total = jpegFiles.count * targets.count
    var completed = 0
    var results: [FileResult] = []

    // Read the user's saved global playback profile once (App Group defaults).
    let rules = Self.globalPlaybackRules()

    for target in targets {
      let rawApiUrl = target.apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
      var cleanUrl = rawApiUrl
      if !cleanUrl.isEmpty {
        if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
          cleanUrl = "http://" + cleanUrl
        }
        if cleanUrl.hasSuffix("/") {
          cleanUrl = String(cleanUrl.dropLast())
        }
      }

      let macSlug = Self.sanitizeMac(target.mac)
      guard !macSlug.isEmpty, let base = URL(string: cleanUrl) else {
        let msg = ShareUploadError.missingMacOrUrl.localizedDescription
        for file in jpegFiles {
          completed += 1
          onProgress(completed, total, "to \(target.name)")
          results.append(
            FileResult(filename: file.lastPathComponent, success: false, message: msg)
          )
        }
        continue
      }

      let endpoint = base.appendingPathComponent("api/frames/\(macSlug)/upload")
      var imageIds: [String] = []

      for file in jpegFiles {
        let detail = "to \(target.name) · \(file.lastPathComponent)"
        do {
          guard let bodyURL = makeMultipartBody(jpeg: file, target: target, macSlug: macSlug, totalFiles: jpegFiles.count, displaySeconds: rules.displaySeconds) else {
            throw ShareUploadError.emptyBody
          }
          let responseData = try await uploadOne(
            session: session,
            to: endpoint,
            bodyURL: bodyURL,
            target: target,
            authToken: authToken
          )
          if let id = Self.imageId(from: responseData), !imageIds.contains(id) {
            imageIds.append(id)
          }
          completed += 1
          onProgress(completed, total, detail)
          results.append(
            FileResult(filename: file.lastPathComponent, success: true, message: "")
          )
        } catch {
          completed += 1
          onProgress(completed, total, detail)
          let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
          results.append(
            FileResult(filename: file.lastPathComponent, success: false, message: msg)
          )
        }
      }

      // >1 images → assign the batch to a frame Playlist, mirroring
      // ExternalShareCastService._publishExternal (interval from the saved
      // global playback profile / sequential or random as configured).
      if imageIds.count > 1 {
        await publishPlaylist(
          session: session,
          target: target,
          macSlug: macSlug,
          imageIds: imageIds,
          authToken: authToken,
          rules: rules
        )
      }
    }
    return results
  }

  // MARK: - Upload request

  private func uploadOne(
    session: URLSession,
    to endpoint: URL,
    bodyURL: URL,
    target: Target,
    authToken: String
  ) async throws -> Data {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 90
    request.setValue(
      "multipart/form-data; boundary=\(boundary)",
      forHTTPHeaderField: "Content-Type"
    )
    if !target.pairingToken.isEmpty {
      request.setValue(target.pairingToken, forHTTPHeaderField: "x-pairing-token")
    }
    if !authToken.isEmpty {
      request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    }

    return try await withCheckedThrowingContinuation { continuation in
      let task = session.uploadTask(with: request, fromFile: bodyURL) { data, response, error in
        if let error {
          continuation.resume(
            throwing: ShareUploadError.network(error.localizedDescription)
          )
          return
        }
        guard let http = response as? HTTPURLResponse else {
          continuation.resume(
            throwing: ShareUploadError.network(NSLocalizedString("No server response.", comment: "Share upload error"))
          )
          return
        }
        // Success = 200 OK / 201 Created (matches FrameApiClient's 2xx check).
        guard (200...299).contains(http.statusCode) else {
          let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
          NSLog("[MyFrame Share] upload HTTP \(http.statusCode): \(body)")
          continuation.resume(
            throwing: ShareUploadError.badResponse(status: http.statusCode, body: body)
          )
          return
        }
        continuation.resume(returning: data ?? Data())
      }
      task.resume()
    }
  }

  // MARK: - Playlist publish (multi-image batches)

  private func publishPlaylist(
    session: URLSession,
    target: Target,
    macSlug: String,
    imageIds: [String],
    authToken: String,
    rules: PlaybackRules
  ) async {
    let rawApiUrl = target.apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    var cleanUrl = rawApiUrl
    if !cleanUrl.isEmpty {
      if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
        cleanUrl = "http://" + cleanUrl
      }
      if cleanUrl.hasSuffix("/") {
        cleanUrl = String(cleanUrl.dropLast())
      }
    }
    guard let base = URL(string: cleanUrl) else { return }
    let endpoint = base.appendingPathComponent("api/frames/\(macSlug)/slideshow")
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if !target.pairingToken.isEmpty {
      request.setValue(target.pairingToken, forHTTPHeaderField: "x-pairing-token")
    }
    if !authToken.isEmpty {
      request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    }

    let nowMs = String(Int(Date().timeIntervalSince1970 * 1000))
    let endtime = rules.durationHours > 0 ? String(Int(Date().timeIntervalSince1970 * 1000) + rules.durationHours * 3600 * 1000) : ""

    // CRITICAL: send `immediatePlay: true` so the backend dispatches a
    // standalone MQTT `play` command for imageIds[0] right after the
    // strategy_bin command. Without this, the device waits a full
    // intervalMinutes before rendering the first shared image — and the
    // share UI typically closes before that first tick, leaving the
    // device appearing unresponsive.
    let payload: [String: Any] = [
      "imageIds": imageIds,
      "intervalMinutes": rules.intervalMinutes,
      "strategy": rules.strategy,
      "begintime": nowMs,
      "endtime": endtime,
      "idle": 1,
      "skipPlay": true,
      "immediatePlay": true,
      "intervalUnit": "minute",
      "source": "direct_cast",
    ]
    request.httpBody = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()

    do {
      let (_, response) = try await session.data(for: request)
      if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
        NSLog("[MyFrame Share] playlist published for \(macSlug): \(imageIds.count) image(s) (immediatePlay=true)")
      } else {
        // Fallback: try the dedicated /cast/batch endpoint. It accepts
        // the same shape but is purpose-built for multi-image direct
        // share and guarantees an immediate first-photo push.
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        NSLog("[MyFrame Share] playlist publish HTTP \(status) for \(macSlug); falling back to /cast/batch")
        await publishBatchCast(
          session: session,
          target: target,
          macSlug: macSlug,
          imageIds: imageIds,
          authToken: authToken,
          rules: rules
        )
      }
    } catch {
      NSLog("[MyFrame Share] playlist publish failed for \(macSlug): \(error.localizedDescription); falling back to /cast/batch")
      await publishBatchCast(
        session: session,
        target: target,
        macSlug: macSlug,
        imageIds: imageIds,
        authToken: authToken,
        rules: rules
      )
    }
  }

  /// MARK: - Batch cast (fallback for /slideshow)
  ///
  /// POST /api/frames/{mac}/cast/batch — unified multi-image direct cast.
  /// Backend persists a transient slideshow marker AND dispatches the
  /// strategy_bin + an immediate play command for imageIds[0] so the
  /// device wakes up with the first shared image right away.
  private func publishBatchCast(
    session: URLSession,
    target: Target,
    macSlug: String,
    imageIds: [String],
    authToken: String,
    rules: PlaybackRules
  ) async {
    let rawApiUrl = target.apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    var cleanUrl = rawApiUrl
    if !cleanUrl.isEmpty {
      if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
        cleanUrl = "http://" + cleanUrl
      }
      if cleanUrl.hasSuffix("/") {
        cleanUrl = String(cleanUrl.dropLast())
      }
    }
    guard let base = URL(string: cleanUrl) else { return }
    let endpoint = base.appendingPathComponent("api/frames/\(macSlug)/cast/batch")
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if !target.pairingToken.isEmpty {
      request.setValue(target.pairingToken, forHTTPHeaderField: "x-pairing-token")
    }
    if !authToken.isEmpty {
      request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    }

    let payload: [String: Any] = [
      "photo_ids": imageIds,
      "intervalMinutes": rules.intervalMinutes,
      "strategy": rules.strategy,
      "idle": 1,
      "intervalUnit": "minute",
      "immediatePlay": true,
      "source": "direct_cast",
    ]
    request.httpBody = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()

    do {
      let (_, response) = try await session.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      if (200...299).contains(status) {
        NSLog("[MyFrame Share] batch cast published for \(macSlug) (HTTP \(status))")
      } else {
        NSLog("[MyFrame Share] batch cast HTTP \(status) for \(macSlug)")
      }
    } catch {
      NSLog("[MyFrame Share] batch cast failed for \(macSlug): \(error.localizedDescription)")
    }
  }

  // MARK: - Multipart body (temp file so large batches stay memory-safe)

  private func makeMultipartBody(
    jpeg: URL,
    target: Target,
    macSlug: String,
    totalFiles: Int,
    displaySeconds: Int
  ) -> URL? {
    guard let data = try? Data(contentsOf: jpeg), !data.isEmpty else { return nil }
    let checksum = SHA256.hash(data: data)
      .map { String(format: "%02x", $0) }
      .joined()

    let bodyURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("body_\(UUID().uuidString).bin")

    var body = Data()
    func field(_ name: String, _ value: String) {
      body.append("--\(boundary)\r\n")
      body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
      body.append(value)
      body.append("\r\n")
    }

    field("mac", macSlug)
    field("device_id", target.deviceId)
    field("checksum", checksum)
    field("size", "\(data.count)")
    field("app_platform", "flutter")
    field("slideshow_style", "classic")
    field("display_seconds", "\(displaySeconds)")
    field("transport", "wifi")
    // Single image uploads (count == 1) should play immediately (skip_play = false).
    // Multi-image batches (count > 1) upload silently (skip_play = true) first, then publish playlist.
    let isMultiImage = totalFiles > 1
    field("skip_play", isMultiImage ? "true" : "false")

    body.append("--\(boundary)\r\n")
    body.append(
      "Content-Disposition: form-data; name=\"photo\"; filename=\"\(jpeg.lastPathComponent)\"\r\n"
    )
    body.append("Content-Type: image/jpeg\r\n\r\n")
    body.append(data)
    body.append("\r\n")
    body.append("--\(boundary)--\r\n")

    do {
      try body.write(to: bodyURL, options: .atomic)
      return bodyURL
    } catch {
      NSLog("[MyFrame Share] write multipart body failed: \(error)")
      return nil
    }
  }

  // MARK: - Global playback profile (App Group)

  /// Saved global playback rules the extension applies to external shares.
  /// Falls back to the legacy 10 min / sequential / unlimited contract when
  /// the user never configured a profile.
  struct PlaybackRules {
    var intervalMinutes: Int = 10
    var strategy: Int = 1
    var durationHours: Int = 0
    var displaySeconds: Int { intervalMinutes * 60 }
  }

  /// Reads the user's playback profile from the App Group defaults mirrored by
  /// `FrameSettingsStore._syncGlobalPlaybackDefaults` (keys written by Flutter:
  /// `global_display_seconds`, `global_playback_mode`, `global_duration_type`).
  private static func globalPlaybackRules() -> PlaybackRules {
    var rules = PlaybackRules()
    let customGroupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
    let appGroupId = (customGroupId?.isEmpty == false) ? customGroupId! : "group.com.myframe"
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return rules }

    let displaySeconds = defaults.integer(forKey: "global_display_seconds")
    if displaySeconds > 0 {
      rules.intervalMinutes = max(1, displaySeconds / 60)
    }
    let playbackMode = defaults.string(forKey: "global_playback_mode")
    if let playbackMode, !playbackMode.isEmpty {
      rules.strategy = (playbackMode == "random") ? 2 : 1
    }
    rules.durationHours = durationHours(from: defaults.string(forKey: "global_duration_type"))
    return rules
  }

  /// Parses the `duration_type` value (e.g. `unlimited`, `6h`, `2d`) into hours.
  private static func durationHours(from type: String?) -> Int {
    guard let raw = type, !raw.isEmpty else { return 0 }
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if value == "unlimited" || value == "0" { return 0 }
    if value.hasSuffix("h") {
      return Int(value.dropLast()) ?? 0
    }
    if value.hasSuffix("d") {
      return (Int(value.dropLast()) ?? 0) * 24
    }
    return Int(value) ?? 0
  }

  /// Mirrors `FrameApiClient.uploadPhoto`'s MAC cleanup: keep the last 12 hex chars.
  private static func sanitizeMac(_ raw: String) -> String {
    let hex = raw.uppercased().filter { $0.isHexDigit }
    return hex.count >= 12 ? String(hex.suffix(12)) : hex
  }

  /// Mirrors `PhotoUploadResponse.vpsSlideshowImageId` — the image identity the
  /// server uses for playlist assignment.
  private static func imageId(from data: Data) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    let basename = (json["frame_play_basename"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let basename, !basename.isEmpty { return basename }

    if let stored = (json["stored_path"] as? String)?
      .split(separator: "/").last, !stored.isEmpty {
      return String(stored)
    }
    if let url = (json["image_url"] as? String)?
      .split(separator: "/").last, !url.isEmpty {
      return String(url)
    }
    let checksum = (json["checksum_sha256"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let checksum, !checksum.isEmpty { return checksum }
    return nil
  }
}

private extension Data {
  mutating func append(_ string: String) {
    if let data = string.data(using: .utf8) {
      append(data)
    }
  }
}
