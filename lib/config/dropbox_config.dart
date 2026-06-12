/// Dropbox OAuth app key from Dropbox App Console.
/// Override: `--dart-define=DROPBOX_APP_KEY=your_key`
class DropboxConfig {
  DropboxConfig._();

  static const String appKey = String.fromEnvironment(
    'DROPBOX_APP_KEY',
    defaultValue: '',
  );

  static const String redirectUri = 'myframe://dropbox-auth';

  static bool get isConfigured => appKey.trim().isNotEmpty;
}
