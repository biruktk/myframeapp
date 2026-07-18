/// Single-tenant defaults for `biruktk` VPS (MQTT + HTTP API share this host).
class VpsDefaults {
  VpsDefaults._();

  static const String host = 'myframe.ink';
  static const int apiPort = 3001;

  /// Marketing hostname (same VPS when DNS works — often flaky on cellular).
  static const String hostnameInk = 'myframe.ink';

  /// HTTP API via direct IP (avoids DNS flakiness + Cloudflare HTTPS for frame compatibility).
  static String get publicApiBase => 'http://$host:$apiPort';

  /// Alternate base if DNS resolves (`http://myframe.ink:3001`).
  /// Prefer [apiBase] (raw IP) for reliability (see pairing coercion).
  static String get apiBaseHostname => 'http://$hostnameInk:$apiPort';
  static const int mqttPort = 1883;
  static const String mqttUser = 'device';
  static const String mqttPass = 'framepass2026';
  static const String pairingToken = 'framepass2026';

  /// Use direct IP + HTTP for all API calls. Frames also get HTTP+IP for .bin downloads.
  static String get apiBase => 'http://$host:$apiPort';

  static final Set<String> _dnsFragileHosts = {
    'myframe.ink',
    'www.myframe.ink',
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
