import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_auth_config.dart';

/// Shared Google Sign-In config: iOS uses native client ID; Android uses
/// `default_web_client_id` + [serverClientId] (never pass the iOS client ID on Android).
GoogleSignIn createGoogleSignIn({List<String> scopes = const ['email', 'profile']}) {
  return GoogleSignIn(
    scopes: scopes,
    clientId: Platform.isIOS && GoogleAuthConfig.hasIosClientId
        ? GoogleAuthConfig.iosClientId
        : null,
    serverClientId: GoogleAuthConfig.serverClientId,
  );
}
