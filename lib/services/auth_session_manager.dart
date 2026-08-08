import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';
import 'app_diag_log.dart';

/// Global root navigator key — lets a non-widget service (the 401 handler)
/// pop the whole navigation stack back to [AppEntryScreen] (login UI).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Single-flight coordinator for expired/stale auth sessions.
///
/// When any HTTP call routed through [ApiClient] receives a `401 Unauthorized`
/// (and the request carried a Bearer JWT), [ApiClient] calls [handleUnauthorized].
///
/// The manager:
///  1. tries a silent token refresh — only when a [refreshToken] hook is
///     configured (the backend has no refresh-token endpoint today, so this is
///     a no-op and we fall through to reset);
///  2. on failure resets the authenticated state on [AppSettings] (clears the
///     JWT, marks signed-out, resets in-memory caches) — the root
///     [AppEntryScreen] listens to [AppSettings] and swaps to the login UI;
///  3. pops the root navigator back to [AppEntryScreen] so stale screens above
///     it (family, settings, …) are torn down;
///  4. shows a "Your session has expired. Please log in again." dialog.
///
/// During initial frame pairing (Wi-Fi + profile setup), API calls may return
/// 401 transiently (endpoint not deployed, token edge cases). Set
/// [suppressUnauthorizedHandling] to `true` during that flow to prevent
/// accidental logout.
class AuthSessionManager {
  AuthSessionManager._();
  static final AuthSessionManager instance = AuthSessionManager._();

  AppSettings? _settings;

  /// Optional JWT rotation hook (returns the new token, or `null` to abort).
  /// Not wired today — no refresh endpoint exists on the backend.
  Future<String?> Function()? _refreshToken;

  /// In-flight reset so concurrent 401s collapse into one.
  Future<void>? _inflight;

  /// When `true`, [handleUnauthorized] becomes a no-op (used during initial
  /// frame pairing where transient 401s must not log the user out).
  bool _suppressUnauthorizedHandling = false;

  /// The configured [AppSettings] instance, for internal use by services that
  /// need to trigger a sign-out (e.g., frame deletion).
  AppSettings? get settings => _settings;

  bool get isConfigured => _settings != null;

  /// Whether unauthorized handling is currently suppressed.
  bool get isSuppressed => _suppressUnauthorizedHandling;

  /// Set to `true` to prevent 401s from triggering session reset/logout.
  /// Use during initial frame pairing (Wi-Fi + profile setup) where
  /// transient 401s from pairing endpoints must not log the user out.
  void suppressUnauthorizedHandling(bool value) {
    _suppressUnauthorizedHandling = value;
  }

  /// Wire the manager to [settings]. Call once from `main()` after loading.
  void configure({
    required AppSettings settings,
    Future<String?> Function()? refreshToken,
  }) {
    _settings = settings;
    _refreshToken = refreshToken;
  }

  /// Try to rotate the JWT. Returns the new token, or `null` when no refresh
  /// flow is configured or the refresh failed.
  Future<String?> attemptRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) return null;
    try {
      final token = await refresh();
      if (token != null && token.trim().isNotEmpty) {
        final s = _settings;
        if (s != null && s.authUserId.trim().isNotEmpty) {
          await s.setAuthJwt(token: token.trim(), userId: s.authUserId);
        }
        AppDiagLog.verbose('[auth] token refreshed');
        return token.trim();
      }
    } catch (e, st) {
      AppDiagLog.verbose('[auth] token refresh failed: $e\n$st');
    }
    return null;
  }

  /// Handle a 401. Single-flight — concurrent 401s share the same reset.
  Future<void> handleUnauthorized() {
    if (_suppressUnauthorizedHandling) return Future.value();
    return _inflight ??= _handleUnauthorized();
  }

  Future<void> _handleUnauthorized() async {
    final s = _settings;
    try {
      if (s == null || !s.hasAuthenticatedSession) {
        // Already signed out (or never signed in) — nothing to reset, and do
        // not re-show the expired dialog for straggler 401s.
        return;
      }

      // 1) Attempt silent refresh (no-op when no refresh flow is configured).
      final refreshed = await attemptRefresh();
      if (refreshed != null) return;

      // 2) Reset the session: clears JWT + signed-in flag + memory caches and
      //    stops the background account sync (which could re-trigger 401s).
      await s.setSignedIn(value: false);
      AppDiagLog.verbose('[auth] session reset after 401');

      // 3) Pop back to the root route — after the reset [AppEntryScreen]
      //    renders the login UI instead of MainShell.
      final nav = appNavigatorKey.currentState;
      if (nav != null) {
        nav.popUntil((route) => route.isFirst);
      }

      // 4) Explain what happened on the now-visible login screen.
      _showExpiredDialog();
    } catch (e, st) {
      AppDiagLog.verbose('[auth] session reset failed: $e\n$st');
    } finally {
      _inflight = null;
    }
  }

  void _showExpiredDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = appNavigatorKey.currentState;
      final ctx = nav?.context;
      if (nav == null || ctx == null) return;
      final s = AppStrings.of(ctx);
      showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          icon: const Icon(Icons.lock_clock_outlined),
          title: Text(
            s.sessionExpiredTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(s.sessionExpiredMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(s.loginLabel),
            ),
          ],
        ),
      );
    });
  }
}
