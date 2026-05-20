import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'frame_ble_mac_slug.dart';
import 'device_store.dart';

/// Last slideshow playlist persisted per frame (BLE MAC slug).
class SlideshowPlaylistStore {
  SlideshowPlaylistStore._();
  static final SlideshowPlaylistStore instance = SlideshowPlaylistStore._();

  static String _key(String macSlug) => 'slideshow_playlist_$macSlug';

  Future<void> save({
    required PairedFrame? paired,
    required List<String> imageIds,
    required int intervalMinutes,
  }) async {
    final mac = frameBleMacSlug(paired);
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key(mac),
      jsonEncode({
        'imageIds': imageIds,
        'intervalMinutes': intervalMinutes,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<({List<String> imageIds, int intervalMinutes})?> load(PairedFrame? paired) async {
    final mac = frameBleMacSlug(paired);
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(mac));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ids = (map['imageIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final mins = map['intervalMinutes'] as int? ?? 60;
      return (imageIds: ids, intervalMinutes: mins);
    } catch (_) {
      return null;
    }
  }
}
