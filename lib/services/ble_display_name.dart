import 'ble_frame_scan_filter.dart';

/// Bluetooth display naming for Ink-Screen frames advertising as **lj_…** or **MY_…**.
class BleDisplayName {
  BleDisplayName._();

  /// Extract last 4 hex chars from BLE address like `AA:BB:CC:DD:EE:FF` or `AA-BB-...`.
  static String macSuffixHex4(String remoteId) {
    final hex = remoteId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.isEmpty) return '0000';
    if (hex.length <= 4) return hex.toUpperCase();
    return hex.substring(hex.length - 4).toUpperCase();
  }

  /// Pairing scan: frame-like BLE names (shared rules with [BleFrameScanFilter]).
  static bool isPairableFrameBleName(String advertisedName) =>
      BleFrameScanFilter.matchesAdvertisedName(advertisedName);

  /// List row title when name is missing or not yet resolved.
  static String fallbackTitle(String remoteId) => 'MY-${macSuffixHex4(remoteId)}';

  /// Prefer human-readable BLE name when it matches the filter; else short MAC-based label.
  static String displayTitle(String remoteId, String effectiveName) {
    final e = effectiveName.trim();
    if (e.isNotEmpty && isPairableFrameBleName(e)) return e;
    return fallbackTitle(remoteId);
  }
}
