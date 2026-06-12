import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/dropbox_config.dart';
import 'app_diag_log.dart';
import 'google_drive_service.dart';

/// Upload processed photos to the user's Dropbox (Apps/MyFrame).
class DropboxService {
  DropboxService._();

  static final DropboxService instance = DropboxService._();

  static const _kConnected = 'dropbox_connected';
  static const _kRefreshToken = 'dropbox_refresh_token';
  static const _kAccountName = 'dropbox_account_name';
  static const _folderPath = '/MyFrame';

  bool _connected = false;
  String? _refreshToken;
  String? _accountName;

  bool get isConnected => _connected;
  String? get accountName => _accountName;

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _connected = p.getBool(_kConnected) ?? false;
    _refreshToken = p.getString(_kRefreshToken);
    _accountName = p.getString(_kAccountName);
  }

  Future<bool> connect() async {
    if (!DropboxConfig.isConfigured) {
      throw StateError(
        'Dropbox app key missing. Set DROPBOX_APP_KEY via --dart-define.',
      );
    }
    final uri = Uri.parse(
      'https://www.dropbox.com/oauth2/authorize'
      '?client_id=${Uri.encodeComponent(DropboxConfig.appKey)}'
      '&response_type=code'
      '&redirect_uri=${Uri.encodeComponent(DropboxConfig.redirectUri)}'
      '&token_access_type=offline',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Could not open Dropbox sign-in.');
    }
    AppDiagLog.log('[Dropbox] opened OAuth — complete sign-in in browser');
    return false;
  }

  /// Called from deep link handler when `myframe://dropbox-auth?code=...` arrives.
  Future<bool> completeOAuth(String code) async {
    if (!DropboxConfig.isConfigured) return false;
    final res = await http.post(
      Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': DropboxConfig.appKey,
        'redirect_uri': DropboxConfig.redirectUri,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppDiagLog.log('[Dropbox] token exchange failed ${res.statusCode}');
      return false;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _refreshToken = data['refresh_token'] as String? ?? data['access_token'] as String?;
    _connected = _refreshToken != null && _refreshToken!.isNotEmpty;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kConnected, _connected);
    if (_refreshToken != null) {
      await p.setString(_kRefreshToken, _refreshToken!);
    }
    await _fetchAccountName();
    AppDiagLog.log('[Dropbox] connected $_accountName');
    return _connected;
  }

  Future<void> _fetchAccountName() async {
    final token = await _accessToken();
    if (token == null) return;
    final res = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/users/get_current_account'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _accountName = data['name']?['display_name'] as String?;
      if (_accountName != null) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kAccountName, _accountName!);
      }
    }
  }

  Future<String?> _accessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return null;
    final res = await http.post(
      Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
        'client_id': DropboxConfig.appKey,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['access_token'] as String?;
  }

  Future<void> disconnect() async {
    _connected = false;
    _refreshToken = null;
    _accountName = null;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kConnected, false);
    await p.remove(_kRefreshToken);
    await p.remove(_kAccountName);
    AppDiagLog.log('[Dropbox] disconnected');
  }

  Future<CloudUploadResult> uploadBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!_connected) {
      return const CloudUploadResult.failed('Dropbox is not connected.');
    }
    final token = await _accessToken();
    if (token == null) {
      return const CloudUploadResult.failed('Dropbox sign-in expired. Connect again.');
    }

    final path = '$_folderPath/$filename';
    final res = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({
          'path': path,
          'mode': 'add',
          'autorename': true,
          'mute': false,
        }),
      },
      body: bytes,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppDiagLog.log('[Dropbox] upload failed ${res.statusCode} ${res.body}');
      return CloudUploadResult.failed('Dropbox upload failed (${res.statusCode}).');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final id = data['id'] as String? ?? '';

    final linkRes = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path}),
    );
    String webUrl = '';
    if (linkRes.statusCode == 200) {
      final linkData = jsonDecode(linkRes.body) as Map<String, dynamic>;
      webUrl = linkData['url'] as String? ?? '';
    }

    AppDiagLog.log('[Dropbox] uploaded $filename');
    return CloudUploadResult.ok(
      fileId: id,
      webUrl: webUrl,
      provider: 'Dropbox',
    );
  }
}
