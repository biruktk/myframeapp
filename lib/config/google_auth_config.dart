/// Google Sign-In OAuth client IDs from Google Cloud Console.
///
/// Android needs [serverClientId] = **Web application** client ID so `idToken` is returned.
/// The Android OAuth client ID still belongs in the Google Cloud credential set
/// for package/SHA matching; it is recorded here so diagnostics and native
/// resource checks stay aligned with the APK you ship.
/// iOS native Sign-In needs [iosClientId] from an iOS OAuth client; when absent,
/// the app uses the hosted Google flow instead of showing a configuration error.
/// Override at build time:
/// `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=OTHER_ID.apps.googleusercontent.com`
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const String _defaultWebClientId =
      '35227816140-is97hmj34o8h3t0erdnd0r10d1k0ajld.apps.googleusercontent.com';

  static const String _defaultAndroidClientId =
      '824694546060-9rlpc8r18kv38t0lvdkktbeai8nn7s58.apps.googleusercontent.com';

  static const String _defaultIosClientId =
      '824694546060-bot3gdoo5mc5pvb2u26jksp3djt43i6q.apps.googleusercontent.com';

  /// Web OAuth client ID (type: Web application).
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  /// iOS OAuth client ID (type: iOS application). Never pass this on Android.
  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: _defaultIosClientId,
  );

  /// Android OAuth client ID (type: Android application).
  static const String androidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: _defaultAndroidClientId,
  );

  static bool get hasServerClientId => serverClientId.trim().isNotEmpty;
  static bool get hasIosClientId => iosClientId.trim().isNotEmpty;
  static bool get hasAndroidClientId => androidClientId.trim().isNotEmpty;

  /// Android package registered in Google Cloud Console OAuth client.
  static const String androidPackageName = 'com.myframe.minyuex';
}
