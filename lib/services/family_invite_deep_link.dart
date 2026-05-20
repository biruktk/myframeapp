import 'package:app_links/app_links.dart';

import 'family_group_store.dart';

/// Handles `myframe://…` and `https://myframe.ink/join?code=` style links for Family join.
class FamilyInviteDeepLink {
  FamilyInviteDeepLink._();

  static final AppLinks _links = AppLinks();
  static String? _pendingCode;

  static String? get peekPendingCode => _pendingCode;

  /// Call after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> bootstrap() async {
    try {
      _links.uriLinkStream.listen(_applyUri, onError: (_) {});
      await _hydrateColdStartLinks();
    } catch (_) {}
  }

  /// Intent launch URI (cold start misses [uriLinkStream] alone).
  static Future<void> _hydrateColdStartLinks() async {
    try {
      Uri? uri = await _links.getInitialLink();
      uri ??= await _links.getLatestLink();
      if (uri != null) {
        _applyUri(uri);
        return;
      }
      final raw = await _links.getInitialLinkString();
      if (raw != null && raw.trim().isNotEmpty) {
        final parsed = Uri.tryParse(raw.trim());
        if (parsed != null) _applyUri(parsed);
      }
    } catch (_) {}
  }

  static bool _isMyframeInkHost(String host) {
    final h = host.toLowerCase();
    return h == 'myframe.ink' || h == 'www.myframe.ink';
  }

  /// Matches `/join`, `/join/`, trailing slashes, and paths like `/en/join`.
  static bool _looksLikeJoinPath(String rawPath) {
    final collapsed = rawPath.replaceAll(RegExp(r'/+'), '/');
    final noTrail = collapsed.replaceAll(RegExp(r'/+$'), '');
    final parts = noTrail.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty && parts.last == 'join';
  }

  static void _applyUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path;

    final isHttpsJoin =
        scheme == 'https' && _isMyframeInkHost(host) && _looksLikeJoinPath(path);
    final customSchemeMyframe = scheme == 'myframe';

    if (!isHttpsJoin && !customSchemeMyframe) return;

    var code = uri.queryParameters['code'] ?? uri.queryParameters['family'];
    if ((code == null || code.isEmpty) && uri.fragment.contains('=')) {
      final qp = Uri.splitQueryString(uri.fragment);
      code = qp['code'] ?? qp['family'];
    }

    final norm = FamilyGroupStore.normalizeCode(code ?? '');
    if (norm.length >= 8) {
      _pendingCode = norm;
    }
  }

  /// Consume a pending code once (Family screen should open join sheet prefilled).
  static String? takePendingCode() {
    final v = _pendingCode;
    _pendingCode = null;
    return v;
  }
}
