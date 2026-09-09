import Intents

/// Implements `INSendMessageIntentHandling` so the system knows a MyFrame
/// frame recipient (an `INPerson` donated by the main app) can receive shared
/// image files (`public.image`). This is the Intents Extension companion to
/// `FrameShortcutPlugin` (donation) — it confirms intent metadata + hands the
/// selected recipient back so the existing MyFrame Share Extension can pick it
/// up and upload to `/api/v1/frames/:mac/push`.
///
/// The Intents Extension target must be added in Xcode (see README in this
/// folder) and configured with:
///   - an App Group shared with the main Runner and Share Extension
///     (`group.com.myframe.app` / `group.com.myframe`), and
///   - `NSExtensionPrincipalClass` = `IntentHandler`,
///     `NSExtensionPointIdentifier` = `com.apple.intents-service`.
class IntentHandler: INExtension, INSendMessageIntentHandling {

  /// The frame MAC from the donated intent. Written to the App Group so the
  /// Main app's share flow knows the pre-selected recipient.
  private var appGroupId: String {
    // Read from the extension's Info.plist to avoid drift with the Runner app.
    let custom = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
    if let custom, !custom.isEmpty { return custom }
    return "group.com.myframe"
  }

  private func defaults() -> UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  // MARK: - INSendMessageIntentHandling

  /// Always confirm — a message-less share to a frame is a valid send.
  func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
    let recipients = intent.recipients ?? []
    guard recipients.first != nil else {
      completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
      return
    }
    // .success means the recipient is resolvable and can accept files.
    completion(INSendMessageIntentResponse(code: .success, userActivity: nil))
  }

  /// Persist the chosen recipient (frame MAC) to the shared App Group so the
  /// Share Extension / main app routes the image to that frame.
  func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
    let recipient = intent.recipients?.first
    let handle = recipient?.personHandle?.value ?? recipient?.customIdentifier ?? ""
    let name = recipient?.displayName ?? "MyFrame"

    // Save the pre-selected target to the App Group the Share Extension reads.
    if let defaults = defaults() {
      defaults.set(name, forKey: "intent_selected_frame_name")
      defaults.set(handle, forKey: "intent_selected_frame_mac")
      defaults.synchronize()
    }

    NSLog("[MyFrame Intents] handled share-to-frame '%@' (%@)", name, handle)
    completion(INSendMessageIntentResponse(code: .success, userActivity: nil))
  }

  // Optionally resolve the recipients — use the donated frame directly, or
  // ask for a value when the intent has none.
  func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
    let recipients = intent.recipients ?? []
    if recipients.isEmpty {
      completion([.needsValue()])
    } else {
      completion(recipients.map { .success(with: $0) })
    }
  }
}
