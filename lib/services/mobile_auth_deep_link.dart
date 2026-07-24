import 'dart:async';

import 'package:app_links/app_links.dart';

/// Result from `myframe://auth/google#token=…&userId=…&email=…&name=…` after browser sign-in.
class MobileGoogleAuthResult {
  const MobileGoogleAuthResult({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
  });

  final String token;
  final String userId;
  final String email;
  final String name;
}

/// Result from `myframe://auth/reset-password#token=…`.
class MobileResetPasswordResult {
  const MobileResetPasswordResult({required this.token});

  final String token;
}

class MobileVerifyEmailResult {
  const MobileVerifyEmailResult({required this.token});

  final String token;
}

/// Waits for Google auth deep links opened by [GoogleSignInBridge].
class MobileAuthDeepLink {
  MobileAuthDeepLink._();

  static final AppLinks _links = AppLinks();
  static Completer<MobileGoogleAuthResult>? _pendingGoogle;
  static Completer<MobileResetPasswordResult>? _pendingResetPassword;
  static Completer<MobileVerifyEmailResult>? _pendingVerifyEmail;

  static Future<void> bootstrap() async {
    try {
      _links.uriLinkStream.listen(_applyUri, onError: (_) {});
      await _hydrateColdStart();
    } catch (_) {}
  }

  /// Call when app returns from Custom Tab — catches `myframe://auth/google` if stream missed it.
  static Future<void> pumpLatestLink() async {
    try {
      final uri = await _links.getLatestLink();
      if (uri != null) _applyUri(uri);
    } catch (_) {}
  }

  static Future<void> _hydrateColdStart() async {
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

  static Future<MobileGoogleAuthResult> waitForGoogleAuth({
    Duration timeout = const Duration(minutes: 8),
  }) {
    _pendingGoogle?.completeError(StateError('replaced'));
    final c = Completer<MobileGoogleAuthResult>();
    _pendingGoogle = c;
    return c.future.timeout(timeout);
  }

  static void cancelPendingGoogle() {
    final c = _pendingGoogle;
    _pendingGoogle = null;
    if (c != null && !c.isCompleted) {
      c.completeError(StateError('cancelled'));
    }
  }

  static Future<MobileResetPasswordResult> waitForResetPassword({
    Duration timeout = const Duration(minutes: 8),
  }) {
    _pendingResetPassword?.completeError(StateError('replaced'));
    final c = Completer<MobileResetPasswordResult>();
    _pendingResetPassword = c;
    return c.future.timeout(timeout);
  }

  static void cancelPendingResetPassword() {
    final c = _pendingResetPassword;
    _pendingResetPassword = null;
    if (c != null && !c.isCompleted) {
      c.completeError(StateError('cancelled'));
    }
  }

  static Future<MobileVerifyEmailResult> waitForVerifyEmail({
    Duration timeout = const Duration(minutes: 8),
  }) {
    _pendingVerifyEmail?.completeError(StateError('replaced'));
    final c = Completer<MobileVerifyEmailResult>();
    _pendingVerifyEmail = c;
    return c.future.timeout(timeout);
  }

  static void cancelPendingVerifyEmail() {
    final c = _pendingVerifyEmail;
    _pendingVerifyEmail = null;
    if (c != null && !c.isCompleted) {
      c.completeError(StateError('cancelled'));
    }
  }

  static Map<String, String> _params(Uri uri) {
    if (uri.queryParameters.isNotEmpty) return uri.queryParameters;
    if (uri.fragment.isEmpty) return const {};
    return Uri.splitQueryString(uri.fragment);
  }

  static bool _isGoogleAuthUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'myframe') return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == 'auth' && path == '/google';
  }

  static bool _isResetPasswordUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'myframe') return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == 'auth' && path == '/reset-password';
  }

  static bool _isVerifyEmailUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'myframe') return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == 'auth' && path == '/verify-email';
  }

  static void _applyUri(Uri uri) {
    if (_isGoogleAuthUri(uri)) {
      _applyGoogleAuth(uri);
      return;
    }
    if (_isResetPasswordUri(uri)) {
      _applyResetPassword(uri);
      return;
    }
    if (_isVerifyEmailUri(uri)) {
      _applyVerifyEmail(uri);
      return;
    }
  }

  static void _applyGoogleAuth(Uri uri) {
    final p = _params(uri);
    final token = (p['token'] ?? '').trim();
    final userId = (p['userId'] ?? p['user_id'] ?? '').trim();
    final email = (p['email'] ?? '').trim();
    final name = (p['name'] ?? '').trim();
    if (token.isEmpty || userId.isEmpty) return;

    final result = MobileGoogleAuthResult(
      token: token,
      userId: userId,
      email: email,
      name: name.isNotEmpty ? name : email.split('@').first,
    );
    final c = _pendingGoogle;
    _pendingGoogle = null;
    if (c != null && !c.isCompleted) {
      c.complete(result);
    }
  }

  static void _applyResetPassword(Uri uri) {
    final p = _params(uri);
    final token = (p['token'] ?? '').trim();
    if (token.isEmpty) return;

    final result = MobileResetPasswordResult(token: token);
    final c = _pendingResetPassword;
    _pendingResetPassword = null;
    if (c != null && !c.isCompleted) {
      c.complete(result);
    }
  }

  static void _applyVerifyEmail(Uri uri) {
    final p = _params(uri);
    final token = (p['token'] ?? '').trim();
    if (token.isEmpty) return;

    final result = MobileVerifyEmailResult(token: token);
    final c = _pendingVerifyEmail;
    _pendingVerifyEmail = null;
    if (c != null && !c.isCompleted) {
      c.complete(result);
    }
  }
}
