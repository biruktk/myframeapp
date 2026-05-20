import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';

/// True when native SDK needs Android OAuth + SHA-1 in Google Cloud (error 10).
bool isGoogleNativeSetupError(Object error) {
  if (error is! PlatformException) return false;
  final code = error.code.toLowerCase();
  final detail = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();
  return code == 'sign_in_failed' ||
      detail.contains('developer_error') ||
      detail.contains(' apiexception: 10') ||
      detail.contains('api10') ||
      detail.contains(': 10') ||
      detail.contains('error 10');
}

/// Maps [PlatformException] from `google_sign_in` to user-facing setup hints.
String googleSignInErrorMessage(Object error, AppStrings strings) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    final detail = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();

    if (isGoogleNativeSetupError(error)) {
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
