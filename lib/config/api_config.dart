import 'vps_defaults.dart';

/// Resolved HTTP origin for `/api/*` calls (Flutter iOS/Android).
///
/// Uses compile-time **`API_BASE`** only when passed (e.g. `flutter run --dart-define=...`).
/// Otherwise defaults to **`VpsDefaults.apiBase`** — same VPS host/port without typing flags.
///
/// Note: Bare `myframe.ink` often fails DNS on phones; VPS IP `:3001` is the stable default ([VpsDefaults]).
/// Pairing payloads that use `myframe.ink` are coerced toward [VpsDefaults.apiBase] in [device_store].
class ApiConfig {
  ApiConfig._();

  static const String _fromDartDefine = String.fromEnvironment('API_BASE');

  static String get baseUrl {
    final d = _fromDartDefine.trim();
    if (d.isNotEmpty) return VpsDefaults.coerceUploadBaseUri(d);
    return VpsDefaults.apiBase.replaceAll(RegExp(r'/+$'), '');
  }

  /// Always hits Express :3001 (never marketing site :3000 without port).
  static String get mobileAuthBaseUrl => baseUrl;

  /// Pairing payloads sometimes ship `localhost` / `127.0.0.1` by mistake — those hosts
  /// route to the phone itself, so [FrameApiClient] must not treat them as a LAN backend.
  static bool isLoopbackApiBase(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final h = uri.host.toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '::1' || h == '[::1]' || h == '0:0:0:0:0:0:0:1';
  }
}
