/// Google Sign-In OAuth client IDs from Google Cloud Console.
///
/// Android needs [serverClientId] = **Web application** client ID so `idToken` is returned.
/// Override at build time:
/// `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=OTHER_ID.apps.googleusercontent.com`
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const String _defaultWebClientId =
      '824694546060-9rlpc8r18kv38t0lvdkktbeai8nn7s58.apps.googleusercontent.com';

  /// Web OAuth client ID (type: Web application).
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  static bool get isConfigured => serverClientId.trim().isNotEmpty;
}
