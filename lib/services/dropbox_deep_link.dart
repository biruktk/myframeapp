import 'package:app_links/app_links.dart';

import 'dropbox_service.dart';
import 'app_diag_log.dart';

/// Handles `myframe://dropbox-auth?code=...` after Dropbox OAuth in browser.
class DropboxDeepLink {
  DropboxDeepLink._();

  static final AppLinks _links = AppLinks();

  static Future<void> bootstrap() async {
    await DropboxService.instance.loadPrefs();
    final initial = await _links.getInitialLink();
    if (initial != null) {
      await _handle(initial);
    }
    _links.uriLinkStream.listen(_handle);
  }

  static Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'myframe') return;
    if (uri.host != 'dropbox-auth') return;
    final code = uri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) {
      AppDiagLog.log('[Dropbox] OAuth callback missing code');
      return;
    }
    AppDiagLog.log('[Dropbox] completing OAuth…');
    await DropboxService.instance.completeOAuth(code);
  }
}
