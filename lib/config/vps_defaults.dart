/// Single-tenant defaults for `biruktk` VPS (MQTT + HTTP API share this host).
class VpsDefaults {
  VpsDefaults._();

  static const String host = 'myframe.ink';
  static const int apiPort = 3001;

  /// Marketing hostname (same VPS when DNS works — often flaky on cellular).
  static const String hostnameInk = 'myframe.ink';

  /// Mobile uploads use the same HTTPS reverse proxy as the Mini-Program.
  static String get publicApiBase => 'https://myframe.ink';

  /// Alternate base if DNS resolves (`http://myframe.ink:3001`).
  /// Prefer [apiBase] (raw IP) for reliability (see pairing coercion).
  static String get apiBaseHostname => 'https://myframe.ink';
  static const int mqttPort = 1883;
  static const String mqttUser = 'device';
  static const String mqttPass = 'framepass2026';
  static const String pairingToken = 'framepass2026';

  /// Client API traffic uses HTTPS; firmware download URLs remain server-controlled.
  static String get apiBase => 'https://myframe.ink';

  static final Set<String> _dnsFragileHosts = {
    'myframe.ink',
    'www.myframe.ink',
    '47.76.164.162',
  };

  static bool shouldUseIpInsteadOfHostname(String host) =>
      _dnsFragileHosts.contains(host.trim().toLowerCase());

  /// Pairing QR may use http://MyFrame.ink:3001 — mobile DNS frequently fails ("No address associated with hostname").
  /// Same VPS is always reachable via [host]:[apiPort].
  static String coerceUploadBaseUri(String trimmed) {
    final u = Uri.tryParse(trimmed);
    if (u != null && u.host.isNotEmpty) {
      if (shouldUseIpInsteadOfHostname(u.host)) {
        return apiBase;
      }
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
