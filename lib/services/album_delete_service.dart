import 'dart:async';

import 'album_cloud_sync.dart';
import 'device_store.dart';
import 'frame_api_client.dart';
import 'frame_ble_mac_slug.dart';
import 'frame_settings_store.dart';
import 'send_albums_store.dart';
import 'slideshow_playlist_store.dart';

/// Powerful album delete — low-power firmware protocol.
///
/// Unlike the old flow (which pulled the whole library and MQTT-stopped every
/// affected frame with a fallback), deletion now runs off the UI thread and
/// sends an `ALBUM_DELETE_SYNC` to the backend carrying the *updated* active
/// image list and frame playback strategy. The backend updates the manifest
/// and notifies each frame via MQTT so it drops the deleted images from its
/// local flash and continues autonomous local playback with what remains.
class AlbumDeleteService {
  AlbumDeleteService._();

  static Future<void> deletePowerful({
    required String albumId,
    String? bearerToken,
  }) async {
    final id = albumId.trim();
    if (id.isEmpty) return;

    await SendAlbumsStore.instance.load();
    final resolvedId = SendAlbumsStore.instance.resolveAlbumId(id);

    // Local tombstone first — blocks applyPlaylistsMeta from re-adding.
    await SendAlbumsStore.instance.deleteAlbum(resolvedId);
    if (id != resolvedId) await SendAlbumsStore.instance.tombstoneAlbumId(id);

    final tok = (bearerToken ?? '').trim();
    if (tok.isEmpty) return;

    // Off-the-ui-thread dispatch of the sync so the app never freezes. The
    // local delete above already finished; the frame sync is background work.
    unawaited(_syncAfterDelete(resolvedId, tok));
  }

  static Future<void> _syncAfterDelete(String albumId, String tok) async {
    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    final targets = frames.isNotEmpty
        ? frames
        : [
            if (DeviceStore.instance.cached != null)
              DeviceStore.instance.cached!,
          ];
    if (targets.isEmpty) return;

    // One ALBUM_DELETE_SYNC for the album: drive it from the active frame's
    // updated active list + playback strategy, and target every paired frame
    // so each drops the deleted images and continues autonomous playback.
    final active = targets.first;
    final macSlugs = <String>[];
    for (final frame in targets) {
      final macSlug = frameBleMacSlug(frame);
      if (macSlug.isNotEmpty && macSlug != 'FRAME') macSlugs.add(macSlug);
    }
    final profile = await FrameSettingsStore.instance.load(active);
    final stored = await SlideshowPlaylistStore.instance.load(active);
    final remainingIds = stored?.imageIds ?? const <String>[];

    await FrameApiClient().deleteUserAlbumSync(
      bearerToken: tok,
      albumId: albumId,
      imageIds: remainingIds,
      intervalMinutes: profile.intervalMinutes,
      strategy: profile.strategy,
      durationHours: profile.durationHours,
      macSlugs: macSlugs,
    );

    // Refresh local album mirrors in the background so the deleted album is
    // not resurrected by a stale pull (fire-and-forget, low power).
    try {
      await AlbumCloudSync.instance.syncAll(tok, pushLocal: false);
    } catch (_) {}
  }
}