import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../widgets/shell_navigation.dart';
import 'family_group_store.dart';

/// Handles family invite deep links and notifies the UI to open Join Family.
///
/// Supported:
/// - `myframe://family/join?code=ABCD1234`
/// - `myframe://join?code=ABCD1234`
/// - `https://myframe.ink/join?code=ABCD1234` (+ www / locale prefixes)
class FamilyInviteDeepLink {
  FamilyInviteDeepLink._();

  static final AppLinks _links = AppLinks();
  static String? _pendingCode;

  /// Bumps whenever a valid invite code is received (cold start or warm).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

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

  /// Matches `/join`, `/join/`, `/en/join`, `/zh/join`, etc.
  static bool _looksLikeJoinPath(String rawPath) {
    final collapsed = rawPath.replaceAll(RegExp(r'/+'), '/');
    final noTrail = collapsed.replaceAll(RegExp(r'/+$'), '');
    final parts = noTrail.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty && parts.last == 'join';
  }

  /// `myframe://join…` or `myframe://family/join…`
  static bool _isCustomSchemeJoin(Uri uri) {
    if (uri.scheme.toLowerCase() != 'myframe') return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'join') return true;
    if (host == 'family' && _looksLikeJoinPath(path)) return true;
    // Rare: myframe:///family/join?code=
    if (host.isEmpty && path.contains('join')) return true;
    return false;
  }

  static void _applyUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path;

    final isHttpsJoin =
        scheme == 'https' && _isMyframeInkHost(host) && _looksLikeJoinPath(path);
    final isCustomJoin = _isCustomSchemeJoin(uri);

    if (!isHttpsJoin && !isCustomJoin) return;

    var code = uri.queryParameters['code'] ?? uri.queryParameters['family'];
    if ((code == null || code.isEmpty) && uri.fragment.contains('=')) {
      final qp = Uri.splitQueryString(uri.fragment);
      code = qp['code'] ?? qp['family'];
    }

    final norm = FamilyGroupStore.normalizeCode(code ?? '');
    if (norm.length < 8) return;

    _pendingCode = norm;
    revision.value++;

    // Switch to Family tab so Join sheet can open (works warm + after shell mounts).
    try {
      ShellNavigation.goToTab(3);
    } catch (_) {}
  }

  /// Consume a pending code once (Family screen should open join sheet prefilled).
  static String? takePendingCode() {
    final v = _pendingCode;
    _pendingCode = null;
    return v;
  }
}
