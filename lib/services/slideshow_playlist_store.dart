import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'frame_ble_mac_slug.dart';
import 'device_store.dart';
import 'local_storage_service.dart';

/// Last slideshow playlist persisted per frame (BLE MAC slug), scoped to user.
class SlideshowPlaylistStore {
  SlideshowPlaylistStore._();
  static final SlideshowPlaylistStore instance = SlideshowPlaylistStore._();

  Future<String> _key(String macSlug, {String? userId}) =>
      LocalStorageService.instance.slideshowScopedKey(macSlug, userId: userId);

  Future<void> save({
    required PairedFrame? paired,
    required List<String> imageIds,
    required int intervalMinutes,
    String? albumId,
  }) async {
    final mac = frameBleMacSlug(paired);
    final p = await SharedPreferences.getInstance();
    await p.setString(
      await _key(mac),
      jsonEncode({
        'imageIds': imageIds,
        'intervalMinutes': intervalMinutes,
        if (albumId != null && albumId.trim().isNotEmpty) 'albumId': albumId.trim(),
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<({List<String> imageIds, int intervalMinutes, String? albumId})?> load(
    PairedFrame? paired,
  ) async {
    final mac = frameBleMacSlug(paired);
    final p = await SharedPreferences.getInstance();
    var raw = p.getString(await _key(mac));
    // One-time read of pre-isolation key (not written again).
    if (raw == null || raw.isEmpty) {
      raw = p.getString('slideshow_playlist_$mac');
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ids =
          (map['imageIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [];
      final mins = map['intervalMinutes'] as int? ?? 60;
      final albumId = map['albumId'] as String?;
      return (
        imageIds: ids,
        intervalMinutes: mins,
        albumId: (albumId == null || albumId.isEmpty) ? null : albumId,
      );
    } catch (_) {
      return null;
    }
  }
}
