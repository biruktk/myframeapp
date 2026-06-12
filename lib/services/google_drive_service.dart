import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'google_sign_in_factory.dart';
import 'app_diag_log.dart';

/// Upload processed photos to the user's Google Drive (MyFrame folder).
class GoogleDriveService {
  GoogleDriveService._();

  static final GoogleDriveService instance = GoogleDriveService._();

  static const _kConnected = 'google_drive_connected';
  static const _kFolderId = 'google_drive_myframe_folder_id';
  static const _folderName = 'MyFrame';
  static const _driveScope = 'https://www.googleapis.com/auth/drive.file';

  late final GoogleSignIn _signIn = createGoogleSignIn(
    scopes: const [_driveScope],
  );

  bool _connected = false;
  String? _folderId;

  bool get isConnected => _connected;

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _connected = p.getBool(_kConnected) ?? false;
    _folderId = p.getString(_kFolderId);
  }

  Future<bool> connect() async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return false;
      _connected = true;
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kConnected, true);
      AppDiagLog.log('[Drive] connected as ${account.email}');
      return true;
    } catch (e) {
      AppDiagLog.log('[Drive] connect failed: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _signIn.signOut();
    _connected = false;
    _folderId = null;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kConnected, false);
    await p.remove(_kFolderId);
    AppDiagLog.log('[Drive] disconnected');
  }

  Future<String?> _accessToken() async {
    final account = _signIn.currentUser ?? await _signIn.signInSilently();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  Future<String?> _ensureFolder(String token) async {
    if (_folderId != null && _folderId!.isNotEmpty) return _folderId;
    final q = Uri.encodeQueryComponent(
      "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
    );
    final listUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files?q=$q&spaces=drive&fields=files(id,name)',
    );
    final listRes = await http.get(
      listUri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (listRes.statusCode == 200) {
      final data = jsonDecode(listRes.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];
      if (files.isNotEmpty) {
        _folderId = (files.first as Map<String, dynamic>)['id'] as String?;
        if (_folderId != null) {
          final p = await SharedPreferences.getInstance();
          await p.setString(_kFolderId, _folderId!);
        }
        return _folderId;
      }
    }
    final createRes = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': _folderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    if (createRes.statusCode >= 200 && createRes.statusCode < 300) {
      final data = jsonDecode(createRes.body) as Map<String, dynamic>;
      _folderId = data['id'] as String?;
      if (_folderId != null) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kFolderId, _folderId!);
      }
      return _folderId;
    }
    AppDiagLog.log('[Drive] folder create failed ${createRes.statusCode}');
    return null;
  }

  /// Upload bytes; returns a view/download link when possible.
  Future<CloudUploadResult> uploadBytes({
    required Uint8List bytes,
    required String filename,
    String mimeType = 'application/octet-stream',
  }) async {
    if (!_connected) {
      return const CloudUploadResult.failed('Google Drive is not connected.');
    }
    final token = await _accessToken();
    if (token == null) {
      return const CloudUploadResult.failed('Google Drive sign-in expired. Connect again.');
    }
    final folderId = await _ensureFolder(token);
    if (folderId == null) {
      return const CloudUploadResult.failed('Could not create MyFrame folder on Drive.');
    }

    final boundary = 'myframe_${DateTime.now().millisecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': filename,
      'parents': [folderId],
    });
    final body = <int>[
      ...utf8.encode('--$boundary\r\n'),
      ...utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'),
      ...utf8.encode(metadata),
      ...utf8.encode('\r\n--$boundary\r\n'),
      ...utf8.encode('Content-Type: $mimeType\r\n\r\n'),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];

    final res = await http.post(
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink,webContentLink',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppDiagLog.log('[Drive] upload failed ${res.statusCode} ${res.body}');
      return CloudUploadResult.failed('Google Drive upload failed (${res.statusCode}).');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final link = (data['webContentLink'] ?? data['webViewLink']) as String?;
    AppDiagLog.log('[Drive] uploaded $filename id=${data['id']}');
    return CloudUploadResult.ok(
      fileId: data['id'] as String? ?? '',
      webUrl: link ?? '',
      provider: 'Google Drive',
    );
  }
}

class CloudUploadResult {
  const CloudUploadResult._({
    required this.ok,
    this.fileId = '',
    this.webUrl = '',
    this.provider = '',
    this.error = '',
  });

  const CloudUploadResult.ok({
    required String fileId,
    required String webUrl,
    required String provider,
  }) : this._(ok: true, fileId: fileId, webUrl: webUrl, provider: provider);

  const CloudUploadResult.failed(String message)
      : this._(ok: false, error: message);

  final bool ok;
  final String fileId;
  final String webUrl;
  final String provider;
  final String error;
}
