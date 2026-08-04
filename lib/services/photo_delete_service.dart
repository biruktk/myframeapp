import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'personal_gallery_store.dart';
import 'send_albums_store.dart';
import 'sync_pipeline.dart';
import 'user_gallery_cloud_service.dart';

/// Permanently erase a photo everywhere: local files, personal library,
/// every album, cloud gallery, and id↔path cache. Does not stop frame playback
/// (album/playlist delete handles that).
class PhotoDeleteService {
  PhotoDeleteService._();

  static Future<void> deleteCompletely({
    required String path,
    String? bearerToken,
  }) async {
    final target = path.trim();
    if (target.isEmpty) return;

    final tok = (bearerToken ?? '').trim();

    // Cloud first (tombstone + DELETE) so a concurrent sync cannot resurrect it.
    if (tok.isNotEmpty) {
      try {
        await UserGalleryCloudService.instance.deletePhoto(
          authToken: tok,
          localPath: target,
        );
      } catch (e) {
        debugPrint('[PhotoDelete] cloud delete failed: $e');
      }
    }

    await SendAlbumsStore.instance.removePathFromAllAlbums(target);
    await PersonalGalleryStore.instance.removePaths([target]);

    // Wipe the bytes on disk (cache / staged pick / downloaded cloud file).
    try {
      final f = File(target);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[PhotoDelete] local file delete failed: $e');
    }

    // Drop any in-memory decoded frames for this path.
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    // Refresh library from server without re-uploading deleted locals.
    if (tok.isNotEmpty) {
      try {
        await UserGalleryCloudService.instance.syncFromServer(
          tok,
          uploadLocalFirst: false,
        );
      } catch (_) {}
    } else {
      try {
        await SyncPipeline.instance.onGalleryLocalChanged();
      } catch (_) {}
    }
  }

  static Future<void> deleteMany({
    required Iterable<String> paths,
    String? bearerToken,
  }) async {
    final unique = <String>{};
    for (final p in paths) {
      final t = p.trim();
      if (t.isNotEmpty) unique.add(t);
    }
    for (final p in unique) {
      await deleteCompletely(path: p, bearerToken: bearerToken);
    }
  }
}
