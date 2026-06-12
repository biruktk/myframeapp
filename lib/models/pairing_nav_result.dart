/// Result when leaving Wi‑Fi / BLE pairing flows.
class PairingNavResult {
  const PairingNavResult({
    required this.success,
    this.openSendGallery = false,
  });

  final bool success;

  /// After first-time setup (e.g. portrait chosen), open Send + photo picker.
  final bool openSendGallery;
}
