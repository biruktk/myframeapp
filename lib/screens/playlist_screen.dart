import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/device_store.dart';
import '../services/frame_ble_mac_slug.dart';
import '../services/send_albums_store.dart';
import '../services/slideshow_photo_picker.dart';
import '../services/slideshow_playlist_store.dart';
import '../services/user_playlist_remote_api.dart';
import '../settings/app_settings.dart';
import '../widgets/text_input_bottom_sheet.dart';
import 'slideshow_batch_screen.dart';

/// Playlists are local albums; create like Gallery albums, then pick hours and send.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  var _loading = true;
  UserDashboardSnapshot? _dashboard;
  ({List<String> imageIds, int intervalMinutes})? _localSlideshow;
  List<SendAlbumEntry> _albums = [];

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await DeviceStore.instance.load();
    await SendAlbumsStore.instance.load();
    _albums = SendAlbumsStore.instance.albums;
    final paired = DeviceStore.instance.cached;
    _localSlideshow = await SlideshowPlaylistStore.instance.load(paired);

    final tok = AppSettingsScope.of(context).authToken.trim();
    if (tok.isNotEmpty) {
      _dashboard = await UserPlaylistRemoteApi(bearerToken: tok).fetchDashboard();
    } else {
      _dashboard = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createPlaylistLikeAlbum(AppStrings s) async {
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    if (paired == null || !paired.canUploadToServer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pairingNeedsApiUrl)),
      );
      return;
    }

    final title = await TextInputBottomSheet.show(
      context,
      title: s.createPlaylistFlowTitle,
      label: s.playlistNameLabel,
      confirmLabel: s.addPhotosToPlaylistCta,
    );
    if (title == null || title.trim().isEmpty || !mounted) return;

    final files = await SlideshowPhotoPicker.pickMulti(context);
    if (files.isEmpty || !mounted) return;

    await SendAlbumsStore.instance.createAlbum(
      title.trim(),
      files.map((f) => f.path).toList(),
    );
    await SendAlbumsStore.instance.load();
    if (SendAlbumsStore.instance.albums.isEmpty || !mounted) return;
    final album = SendAlbumsStore.instance.albums.first;
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SlideshowBatchScreen(
          imagePaths: List<String>.from(album.paths),
          playlistTitle: album.name,
          albumId: album.id,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _sendAlbum(SendAlbumEntry album) async {
    final s = AppStrings.of(context);
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    if (paired == null || !paired.canUploadToServer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pairingNeedsApiUrl)),
      );
      return;
    }
    final paths = album.paths.where((p) {
      try {
        return File(p).existsSync();
      } catch (_) {
        return false;
      }
    }).toList();
    if (paths.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.playlistNeedPhotos)),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SlideshowBatchScreen(
          imagePaths: paths,
          playlistTitle: album.name,
          albumId: album.id,
        ),
      ),
    );
    await _reload();
  }

  String _intervalLabel(int minutes) {
    return switch (minutes) {
      60 => '1 h',
      240 => '4 h',
      480 => '8 h',
      1440 => '24 h',
      _ => '$minutes min',
    };
  }

  static String? _firstPreviewPath(SendAlbumEntry a) {
    for (final p in a.paths) {
      try {
        if (File(p).existsSync()) return p;
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final paired = DeviceStore.instance.cached;
    final macSlug = frameBleMacSlug(paired);
    final local = _localSlideshow;
    final devices = _dashboard?.devices ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.navPlaylist),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: s.refreshAction,
            onPressed: _loading ? null : () => unawaited(_reload()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(s.slideshowBatchExplain, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
              const SizedBox(height: 16),
              Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.pairedFrameLabel,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        paired?.listDisplayTitle(s) ?? s.notPaired,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      if (macSlug.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(macSlug, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                      if (local != null && local.imageIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          s.playlistLocalStatus(
                            local.imageIds.length,
                            _intervalLabel(local.intervalMinutes),
                          ),
                          style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                        ),
                      ],
                      if (devices.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final d in devices)
                          Text(
                            s.playlistCloudDeviceStatus(
                              d.name.isNotEmpty ? d.name : d.id,
                              d.online,
                              d.slideshowImageCount,
                              _intervalLabel(d.slideshowIntervalMinutes),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => unawaited(_createPlaylistLikeAlbum(s)),
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(s.createPlaylist),
              ),
              const SizedBox(height: 24),
              Text(s.yourPlaylists,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (_albums.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    s.playlistAlbumsEmptyHint,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                  ),
                )
              else
                ..._albums.map((a) {
                  final preview = _firstPreviewPath(a);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      elevation: 1,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        onTap: () => unawaited(_sendAlbum(a)),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: preview != null
                                  ? Image.file(File(preview), fit: BoxFit.cover)
                                  : ColoredBox(
                                      color: cs.surfaceContainerHighest,
                                      child: Icon(Icons.photo_outlined, color: cs.outline),
                                    ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.playlistPhotoCount(a.paths.length),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.send_rounded, color: cs.primary),
                              tooltip: s.playlistSendToFrame,
                              onPressed: () => unawaited(_sendAlbum(a)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
