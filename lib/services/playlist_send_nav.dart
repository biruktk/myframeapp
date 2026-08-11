import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../screens/edit_color_grade_screen.dart';
import '../screens/image_editor_screen.dart';
import '../services/device_store.dart';
import '../services/frame_online_guard.dart';
import '../services/gallery_image_cache.dart';
import '../services/image_sanitizer.dart';
import '../settings/app_settings.dart';

/// Mini-app parity: after photo selection, open the send UI immediately.
/// Previews can keep decoding while the user sets interval / taps Send.
class PlaylistSendNav {
  PlaylistSendNav._();

  /// Default interval matches mini-app playlist create (10 minutes).
  static const int defaultIntervalSeconds = 600;

  static Future<bool> ensureReadyToSend(BuildContext context) async {
    final s = AppStrings.of(context);
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    if (paired == null || !paired.canUploadToServer) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.connectFrameFirst)));
      }
      return false;
    }
    if (!context.mounted) return false;
    return FrameOnlineGuard.ensureOnlineForSend(context, frame: paired);
  }

  /// Open playlist cast page (interval / mode / duration + send).
  static Future<void> openPlaylistSend(
    BuildContext context, {
    required List<String> paths,
    String? playlistName,
    String? albumId,
    int initialIntervalSeconds = defaultIntervalSeconds,
  }) async {
    // iOS PHPicker / image_picker hand out files under /tmp that can vanish
    // mid-flow — copy anything outside app documents before the send page reads it.
    List<String> durable;
    try {
      durable = await GalleryImageCache.persistPaths(
        paths,
        normalizeJpeg: false,
      );
    } catch (_) {
      durable = paths.where((p) {
        try {
          return File(p).existsSync();
        } catch (_) {
          return false;
        }
      }).toList();
    }
    final files = <File>[];
    for (final p in durable) {
      final t = p.trim();
      if (t.isEmpty) continue;
      try {
        if (File(t).existsSync()) files.add(File(t));
      } catch (_) {}
    }
    if (files.isEmpty || !context.mounted) return;
    final s = AppStrings.of(context);
    final name = (playlistName ?? '').trim().isEmpty
        ? s.myNewPlaylist
        : playlistName!.trim();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditColorGradeScreen(
          selectedImages: files,
          initialIntervalSeconds: initialIntervalSeconds,
          playlistName: name,
          albumId: albumId,
        ),
      ),
    );
  }

  /// Single photo → editor (mini-app). Multi → playlist send page.
  static Future<void> openAfterPick(
    BuildContext context, {
    required List<String> paths,
    String? playlistName,
    String? albumId,
  }) async {
    if (paths.isEmpty || !context.mounted) return;
    if (paths.length == 1) {
      final path = paths.first;
      late final Uint8List bytes;
      try {
        final safe = await ImageSanitizer.sanitize(path);
        final source = (safe == null || safe.isEmpty) ? path : safe;
        bytes = await File(source).readAsBytes();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).noImageSelected)),
          );
        }
        return;
      }
      if (!context.mounted) return;
      final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ImageEditorScreen(
            imageBytes: bytes,
            galleryPersistPath: path,
            slideshow: slideshow,
          ),
        ),
      );
      return;
    }
    await openPlaylistSend(
      context,
      paths: paths,
      playlistName: playlistName,
      albumId: albumId,
    );
  }
}
