import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';

/// Maps [PlatformException] from `google_sign_in` to user-facing setup hints.
String googleSignInErrorMessage(Object error, AppStrings strings) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    final detail = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();

  if (code == 'sign_in_failed' ||
        detail.contains('developer_error') ||
        detail.contains(' apiexception: 10') ||
        detail.contains('api10') ||
        detail.contains(': 10') ||
        detail.contains('error 10')) {
      return strings.authGoogleAndroidSetup;
    }
    if (code == 'network_error' || detail.contains('network')) {
      return strings.authErrorNetwork;
    }
    if (code == 'sign_in_canceled' || code == 'canceled') {
      return strings.authGoogleCanceled;
    }
    final msg = error.message?.trim();
    if (msg != null && msg.isNotEmpty) {
      return '${strings.authGoogleSignInFailed}\n$msg';
    }
  }
  return strings.authGoogleSignInFailed;
}
