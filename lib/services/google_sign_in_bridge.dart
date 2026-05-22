import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'mobile_auth_deep_link.dart';

/// Google Sign-In via API-hosted page, then `myframe://auth/google` deep link.
/// Use [useCustomTab] (default) — Google blocks Sign-In inside embedded WebView.
class GoogleSignInBridge {
  GoogleSignInBridge._();

  /// OAuth redirect/callback use [portalGoogleBaseUrl]; API may still use VPS IP for other calls.
  static String get portalGoogleBaseUrl {
    const fromEnv = String.fromEnvironment('GOOGLE_SIGNIN_BASE');
    if (fromEnv.trim().isNotEmpty) {
      return fromEnv.trim().replaceAll(RegExp(r'/+$'), '');
    }
    return 'https://myframe.ink';
  }

  static Uri signInPageUri() {
    final base = portalGoogleBaseUrl;
    return Uri.parse('$base/mobile/google-signin');
  }

  /// [useCustomTab] — Android Custom Tab / iOS SFSafariView (Google Sign-In works here).
  /// Embedded WebView is NOT supported by Google (button does nothing).
  static Future<MobileGoogleAuthResult> signIn({
    bool useCustomTab = true,
    Duration timeout = const Duration(seconds: 75),
  }) async {
    final uri = signInPageUri();
    await _preflightSignInPage(uri);
    final wait = MobileAuthDeepLink.waitForGoogleAuth(timeout: timeout);
    final launched = useCustomTab
        ? await launchUrl(
            uri,
            mode: Platform.isIOS
                ? LaunchMode.externalApplication
                : LaunchMode.inAppBrowserView,
          )
        : await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration:
                const WebViewConfiguration(enableJavaScript: true),
          );
    if (!launched) {
      MobileAuthDeepLink.cancelPendingGoogle();
      throw StateError('browser_launch_failed');
    }
    return wait;
  }

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static Future<void> _preflightSignInPage(Uri uri) async {
    try {
      final res = await http.get(uri,
          headers: {'Accept': 'text/html'}).timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        throw StateError('google_hosted_route_missing');
      }
      if (res.statusCode == 503 &&
          res.body.contains('GOOGLE_OAUTH_CLIENT_SECRET')) {
        throw StateError('google_server_secret_missing');
      }
      if (res.statusCode >= 500) {
        throw StateError('google_server_unavailable');
      }
    } on StateError {
      rethrow;
    } catch (_) {
      // If preflight is blocked by the network, still let the browser attempt it.
    }
  }
}
