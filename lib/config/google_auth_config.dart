/// Google Sign-In OAuth client IDs from Google Cloud Console.
///
/// Android needs [serverClientId] = **Web application** client ID so `idToken` is returned.
/// iOS native Sign-In needs [iosClientId] from an iOS OAuth client; when absent,
/// the app uses the hosted Google flow instead of showing a configuration error.
/// Override at build time:
/// `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=OTHER_ID.apps.googleusercontent.com`
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const String _defaultWebClientId =
      '824694546060-rjs2fvoshtngpprrbbtedda9uda28qsm.apps.googleusercontent.com';

  static const String _defaultIosClientId =
      '824694546060-bot3gdoo5mc5pvb2u26jksp3djt43i6q.apps.googleusercontent.com';

  /// Web OAuth client ID (type: Web application).
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  /// iOS OAuth client ID (type: iOS application).
  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: _defaultIosClientId,
  );

  static bool get hasServerClientId => serverClientId.trim().isNotEmpty;
  static bool get hasIosClientId => iosClientId.trim().isNotEmpty;
}
