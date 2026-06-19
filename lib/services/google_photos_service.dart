import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_diag_log.dart';
import 'google_drive_service.dart';
import 'google_sign_in_factory.dart';

/// Upload processed photos to the user's Google Photos library.
class GooglePhotosService {
  GooglePhotosService._();

  static final GooglePhotosService instance = GooglePhotosService._();

  static const _kConnected = 'google_photos_connected';
  static const _kAlbumId = 'google_photos_myframe_album_id';
  static const _albumTitle = 'MyFrame';
  static const _photosScope =
      'https://www.googleapis.com/auth/photoslibrary.appendonly';

  late final GoogleSignIn _signIn = createGoogleSignIn(
    scopes: const [_photosScope],
  );

  bool _connected = false;
  String? _albumId;

  bool get isConnected => _connected;

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _connected = p.getBool(_kConnected) ?? false;
    _albumId = p.getString(_kAlbumId);
  }

  Future<bool> connect() async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return false;
      _connected = true;
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kConnected, true);
      AppDiagLog.log('[GooglePhotos] connected as ${account.email}');
      return true;
    } catch (e) {
      AppDiagLog.log('[GooglePhotos] connect failed: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _signIn.signOut();
    _connected = false;
    _albumId = null;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kConnected, false);
    await p.remove(_kAlbumId);
    AppDiagLog.log('[GooglePhotos] disconnected');
  }

  Future<String?> _accessToken() async {
    final account = _signIn.currentUser ?? await _signIn.signInSilently();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  Future<String?> _ensureAlbum(String token) async {
    if (_albumId != null && _albumId!.isNotEmpty) return _albumId;
    final res = await http.post(
      Uri.parse('https://photoslibrary.googleapis.com/v1/albums'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'album': {'title': _albumTitle},
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppDiagLog.log(
        '[GooglePhotos] album create failed ${res.statusCode} ${res.body}',
      );
      return null;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _albumId = data['id'] as String?;
    if (_albumId != null && _albumId!.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kAlbumId, _albumId!);
    }
    return _albumId;
  }

  Future<CloudUploadResult> uploadBytes({
    required Uint8List bytes,
    required String filename,
    String mimeType = 'image/jpeg',
  }) async {
    if (!_connected) {
      return const CloudUploadResult.failed('Google Photos is not connected.');
    }
    final token = await _accessToken();
    if (token == null) {
      return const CloudUploadResult.failed(
        'Google Photos sign-in expired. Connect again.',
      );
    }

    final uploadRes = await http.post(
      Uri.parse('https://photoslibrary.googleapis.com/v1/uploads'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
        'X-Goog-Upload-File-Name': filename,
        'X-Goog-Upload-Protocol': 'raw',
      },
      body: bytes,
    );
    if (uploadRes.statusCode < 200 || uploadRes.statusCode >= 300) {
      AppDiagLog.log(
        '[GooglePhotos] upload token failed ${uploadRes.statusCode} ${uploadRes.body}',
      );
      return CloudUploadResult.failed(
        'Google Photos upload failed (${uploadRes.statusCode}).',
      );
    }

    final uploadToken = uploadRes.body.trim();
    final albumId = await _ensureAlbum(token);
    final createBody = <String, dynamic>{
      if (albumId != null && albumId.isNotEmpty) 'albumId': albumId,
      'newMediaItems': [
        {
          'description': 'MyFrame photo',
          'simpleMediaItem': {'fileName': filename, 'uploadToken': uploadToken},
        },
      ],
    };

    final createRes = await http.post(
      Uri.parse(
        'https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(createBody),
    );
    if (createRes.statusCode < 200 || createRes.statusCode >= 300) {
      AppDiagLog.log(
        '[GooglePhotos] media create failed ${createRes.statusCode} ${createRes.body}',
      );
      return CloudUploadResult.failed(
        'Google Photos upload failed (${createRes.statusCode}).',
      );
    }

    final data = jsonDecode(createRes.body) as Map<String, dynamic>;
    final results = data['newMediaItemResults'] as List<dynamic>? ?? const [];
    final first = results.isNotEmpty
        ? results.first as Map<String, dynamic>
        : null;
    final status = first?['status'] as Map<String, dynamic>?;
    final code = status?['code'] as num?;
    if (code != null && code != 0) {
      final message =
          status?['message'] as String? ??
          'Google Photos rejected the media item.';
      AppDiagLog.log('[GooglePhotos] media item status $code $message');
      return CloudUploadResult.failed(message);
    }

    final mediaItem = first?['mediaItem'] as Map<String, dynamic>?;
    final id = mediaItem?['id'] as String? ?? '';
    final url = mediaItem?['productUrl'] as String? ?? '';
    AppDiagLog.log('[GooglePhotos] uploaded $filename id=$id');
    return CloudUploadResult.ok(
      fileId: id,
      webUrl: url,
      provider: 'Google Photos',
    );
  }
}
