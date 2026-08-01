/// Frame MAC from BLE advertised name (e.g. `MY_D0CF13F0161C` → `D0CF13F0161C`).
class FrameMacUtil {
  FrameMacUtil._();

  static const _framePrefixes = ['MY_', 'IJ_', 'MF_', 'LJ_'];

  static final _iosUuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

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
  /// Never derives a MAC from an iOS CoreBluetooth UUID (that caused false offline).
  static String? normalizeSlug(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (_iosUuid.hasMatch(t)) return null;
    final hex = t.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (hex.length == 12) return hex;
    // 32-char hex is almost always a UUID body without dashes — refuse.
    if (hex.length == 32) return null;
    if (hex.length > 12) return hex.substring(hex.length - 12);
    return null;
  }

  /// Best MAC for API: explicit `IJ_`/`MY_` name, else any 12-hex in text.
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

  /// All plausible ESP32 MACs (BLE ↔ STA ±2) to try for status/cast.
  static List<String> relatedMacCandidates(String? raw) {
    final n = normalizeSlug(raw ?? '') ??
        macFromBleName(raw ?? '') ??
        '';
    if (n.length != 12) return const [];
    final out = <String>{n};
    final v = int.tryParse(n, radix: 16);
    if (v != null) {
      if (v >= 2) {
        out.add((v - 2).toRadixString(16).toUpperCase().padLeft(12, '0'));
      }
      out.add((v + 2).toRadixString(16).toUpperCase().padLeft(12, '0'));
    }
    return out.toList();
  }
}
