import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'device_store.dart';
import 'frame_mac_util.dart';

class AccountSyncService {
  AccountSyncService._();
  static final instance = AccountSyncService._();

  static const _kApiBase = 'https://myframe.ink';
  static const _kTokenKey = 'settings_auth_token';

  http.Client? _http;
  http.Client get _client => _http ??= http.Client();

  void close() {
    _http?.close();
    _http = null;
  }

  Future<String> _authToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTokenKey) ?? '';
  }

  /// Fetch unified profile from GET /api/v1/user/profile
  /// and apply cloud state to local storage.
  Future<Map<String, dynamic>?> syncAccountState() async {
    final token = await _authToken();
    if (token.isEmpty) return null;

    try {
      final uri = Uri.parse('$_kApiBase/api/v1/user/profile');
      final res = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return null;

      final frames = (body['bound_frames'] as List?) ?? [];
      if (frames.isNotEmpty) {
        final store = DeviceStore.instance;
        for (final f in frames) {
          final mac = (f['ble_mac'] as String?) ?? '';
          final frameId = (f['frame_id'] as String?) ?? '';
          final rawMac = mac.isNotEmpty ? mac : frameId;
          final slug = FrameMacUtil.normalizeSlug(rawMac);
          if (slug != null) {
            await store.savePairedFrameMac(slug);
          }
        }
        await store.syncServerFrames();
      }

      return body;
    } catch (e) {
      return null;
    }
  }

  /// Delete a frame on the server and sync.
  Future<bool> deleteFrame(String frameId) async {
    final token = await _authToken();
    if (token.isEmpty) return false;

    try {
      final uri = Uri.parse('$_kApiBase/api/v1/user/frames/$frameId/unbind');
      final res = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      await syncAccountState();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sync uploads after a photo is sent.
  Future<void> afterUpload() async {
    await syncAccountState();
  }
}
