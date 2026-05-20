import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/google_auth_config.dart';
import 'mobile_auth_deep_link.dart';

/// Google Sign-In via API-hosted page, then `myframe://auth/google` deep link.
/// Use [useCustomTab] (default) — Google blocks Sign-In inside embedded WebView.
class GoogleSignInBridge {
  GoogleSignInBridge._();

  static Uri signInPageUri() {
    final base = ApiConfig.mobileAuthBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/mobile/google-signin');
  }

  /// [useCustomTab] — Android Custom Tab / iOS SFSafariView (Google Sign-In works here).
  /// Embedded WebView is NOT supported by Google (button does nothing).
  static Future<MobileGoogleAuthResult> signIn({bool useCustomTab = true}) async {
    if (!GoogleAuthConfig.isConfigured) {
      throw StateError('google_not_configured');
    }
    final uri = signInPageUri();
    final wait = MobileAuthDeepLink.waitForGoogleAuth();
    final launched = useCustomTab
        ? await launchUrl(uri, mode: LaunchMode.inAppBrowserView)
        : await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
          );
    if (!launched) {
      MobileAuthDeepLink.cancelPendingGoogle();
      throw StateError('browser_launch_failed');
    }
    return wait;
  }

  static bool get supported => Platform.isAndroid || Platform.isIOS;
}
