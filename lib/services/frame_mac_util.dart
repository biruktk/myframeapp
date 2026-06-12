/// Frame MAC from BLE advertised name (e.g. `MY_D0CF13F0161C` → `D0CF13F0161C`).
class FrameMacUtil {
  FrameMacUtil._();

  static const _framePrefixes = ['MY_', 'IJ_', 'MF_', 'LJ_'];

  /// MAC = 12 hex digits after a frame prefix in the BLE device name.
  static String? macFromBleName(String raw) {
    final t = raw.trim().toUpperCase();
    for (final prefix in _framePrefixes) {
      if (!t.startsWith(prefix)) continue;
      final hex =
          t.substring(prefix.length).replaceAll(RegExp(r'[^0-9A-F]'), '');
      if (hex.length == 12) return hex;
    }
    return null;
  }

  /// @deprecated Use [macFromBleName].
  static String? macFromIjBleName(String raw) => macFromBleName(raw);

  /// Normalized 12-hex slug for `/api/frames/:mac/*` paths.
  static String? normalizeSlug(String raw) {
    final hex = raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (hex.length == 12) return hex;
    if (hex.length > 12) return hex.substring(hex.length - 12);
    return null;
  }

  /// Best MAC for API: explicit `IJ_` name, else any 12-hex in text.
  static String? macFromBleIdentity({String? bleName, String? fallbackText}) {
    for (final text in [bleName, fallbackText]) {
      if (text == null || text.trim().isEmpty) continue;
      final fromName = macFromBleName(text);
      if (fromName != null) return fromName;
      final slug = normalizeSlug(text);
      if (slug != null) return slug;
    }
    return null;
  }
}
