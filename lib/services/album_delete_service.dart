import 'package:flutter/foundation.dart';

import 'album_cloud_sync.dart';
import 'device_store.dart';
import 'frame_api_client.dart';
import 'frame_mac_util.dart';
import 'send_albums_store.dart';
import 'slideshow_remote_api.dart';

/// Powerful album delete — mirrors WeChat mini-app:
/// 1) Local delete + tombstone (so pull cannot resurrect)
/// 2) Cloud `DELETE /api/v1/user/albums/:id` (server MQTT-stops frames)
/// 3) Belt-and-suspenders: POST stop-playlist for each paired frame MAC
/// 4) Pull cloud albums with pushLocal:false so a stale push cannot recreate it
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
    SendAlbumEntry? album;
    for (final a in SendAlbumsStore.instance.albums) {
      if (a.id == resolvedId || a.id == id) {
        album = a;
        break;
      }
    }
    final exclude = <String>[
      for (final p in album?.paths ?? const <String>[])
        if (p.trim().isNotEmpty) p.split(RegExp(r'[/\\]')).last,
    ];
    final albumName = album?.name.trim() ?? '';

    // Local tombstone first — blocks applyPlaylistsMeta from re-adding.
    await SendAlbumsStore.instance.deleteAlbum(resolvedId);
    if (id != resolvedId) await SendAlbumsStore.instance.tombstoneAlbumId(id);

    final tok = (bearerToken ?? '').trim();
    final idsToDelete = <String>{id, resolvedId};

    if (tok.isNotEmpty) {
      try {
        // If the local id was rebound, also delete any remote album with the
        // same title that still exists (covers pre-rebind deletes).
        final remote = await FrameApiClient().fetchUserAlbums(bearerToken: tok);
        final localLooksEphemeral = RegExp(r'^\d{10,}$').hasMatch(id);
        for (final row in remote) {
          final rid = '${row['id'] ?? ''}'.trim();
          final rname = '${row['name'] ?? row['title'] ?? ''}'.trim();
          if (rid.isEmpty) continue;
          if (rid == id) {
            idsToDelete.add(rid);
            continue;
          }
          // Only name-match when deleting a pre-rebind local timestamp id.
          if (localLooksEphemeral &&
              albumName.isNotEmpty &&
              rname == albumName) {
            idsToDelete.add(rid);
          }
        }
      } catch (e) {
        debugPrint('[AlbumDelete] list remote failed: $e');
      }

      for (final delId in idsToDelete) {
        try {
          await FrameApiClient().deleteUserAlbum(
            bearerToken: tok,
            albumId: delId,
          );
          // Ensure every attempted id is tombstoned locally.
          await SendAlbumsStore.instance.tombstoneAlbumId(delId);
        } catch (e) {
          debugPrint('[AlbumDelete] cloud delete failed ($delId): $e');
        }
      }

      // Pull without pushing locals — prevents resurrecting the deleted album.
      try {
        await AlbumCloudSync.instance.syncAll(tok, pushLocal: false);
      } catch (e) {
        debugPrint('[AlbumDelete] post-delete pull failed: $e');
      }
    }

    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    final targets = frames.isNotEmpty
        ? frames
        : [
            if (DeviceStore.instance.cached != null) DeviceStore.instance.cached!,
          ];

    for (final frame in targets) {
      await _stopFrame(
        frame,
        bearerToken: tok,
        excludeImageIds: exclude,
      );
    }
  }

  static String _macSlugForFrame(PairedFrame frame) {
    for (final c in frame.resolvedFrameTargetCandidates) {
      final slug = FrameMacUtil.normalizeSlug(c);
      if (slug != null && slug.length == 12) return slug;
    }
    final fromId = FrameMacUtil.normalizeSlug(frame.deviceId);
    if (fromId != null) return fromId;
    return frame.deviceId.replaceAll(RegExp(r'[^\w\-]'), '');
  }

  static Future<void> _stopFrame(
    PairedFrame frame, {
    required String bearerToken,
    required List<String> excludeImageIds,
  }) async {
    final mac = _macSlugForFrame(frame);
    if (mac.isEmpty || mac == 'FRAME') return;

    final pairing = frame.resolvedPairingToken?.trim() ?? '';
    try {
      await SlideshowRemoteApi().stopPlaylist(
        bearerToken: bearerToken.isNotEmpty ? bearerToken : null,
        pairingToken: pairing.isNotEmpty ? pairing : null,
        macSlug: mac,
        excludeImageIds: excludeImageIds,
      );
    } catch (e) {
      debugPrint('[AlbumDelete] frame stop failed ($mac): $e');
    }
  }
}
