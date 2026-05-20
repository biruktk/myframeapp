import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/google_auth_config.dart';
import 'mobile_auth_deep_link.dart';

/// Opens Google Sign-In in the system browser (GIS on API host), then waits for `myframe://auth/google`.
class GoogleSignInBridge {
  GoogleSignInBridge._();

  static Uri signInPageUri() {
    final base = ApiConfig.mobileAuthBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/mobile/google-signin');
  }

  static Future<MobileGoogleAuthResult> signIn() async {
    if (!GoogleAuthConfig.isConfigured) {
      throw StateError('google_not_configured');
    }
    final uri = signInPageUri();
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('browser_launch_failed');
    }
    try {
      return await MobileAuthDeepLink.waitForGoogleAuth();
    } catch (e) {
      rethrow;
    }
  }

  static bool get supported => Platform.isAndroid || Platform.isIOS;
}
