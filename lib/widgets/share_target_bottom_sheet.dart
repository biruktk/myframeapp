import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';
import '../services/external_share_cast_service.dart';
import '../services/gallery_image_cache.dart';
import '../services/send_albums_store.dart';
import '../services/share_receiver_service.dart';
import '../services/sync_pipeline.dart';
import '../settings/app_settings.dart';

/// Result of [showShareTargetBottomSheet].
class ShareTargetSheetResult {
  const ShareTargetSheetResult({
    required this.paths,
    required this.frames,
    this.navigatedAway = false,
  });

  final List<String> paths;
  final List<PairedFrame> frames;
  final bool navigatedAway;
}

/// Aura-style “Sharing to MyFrame” destination picker + send progress.
Future<ShareTargetSheetResult?> showShareTargetBottomSheet(
  BuildContext context, {
  required List<SharedMediaItem> items,
}) {
  if (items.isEmpty) return Future.value(null);
  return showModalBottomSheet<ShareTargetSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ShareTargetBottomSheetWidget(items: items),
  );
}

class ShareTargetBottomSheetWidget extends StatefulWidget {
  const ShareTargetBottomSheetWidget({super.key, required this.items});

  final List<SharedMediaItem> items;

  @override
  State<ShareTargetBottomSheetWidget> createState() =>
      _ShareTargetBottomSheetWidgetState();
}

enum _ShareSheetPhase { pick, sending, done, failed }

class _ShareTargetBottomSheetWidgetState
    extends State<ShareTargetBottomSheetWidget> {
  final Set<String> _selectedIds = {};
  List<String> _paths = const [];
  _ShareSheetPhase _phase = _ShareSheetPhase.pick;
  double _progress = 0;
  String _status = '';
  bool _loadingPaths = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    final active = DeviceStore.instance.cached?.deviceId;
    if (frames.isNotEmpty) {
      final prefer = frames.any((f) => f.deviceId == active)
          ? active!
          : frames.first.deviceId;
      _selectedIds.add(prefer);
    }

    final raw = widget.items.map((e) => e.path).toList();
    // Strip file:// if the Share Extension stored absoluteString.
    final cleaned = raw.map((p) {
      if (p.startsWith('file://')) {
        return Uri.parse(p).toFilePath();
      }
      return p;
    }).toList();
    final persisted = await GalleryImageCache.persistPaths(cleaned);
    if (!mounted) return;
    setState(() {
      _paths = persisted.isNotEmpty ? persisted : cleaned;
      _loadingPaths = false;
    });
  }

  List<PairedFrame> get _frames => DeviceStore.instance.pairedFrames;

  List<PairedFrame> get _selectedFrames =>
      _frames.where((f) => _selectedIds.contains(f.deviceId)).toList();

  Future<void> _onSend() async {
    final s = AppStrings.of(context);
    if (_paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noImageSelected)),
      );
      return;
    }
    if (_selectedFrames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.shareIncomingConnectFrame)),
      );
      return;
    }

    // External shares upload immediately with the fixed external defaults
    // (10 min / sequential / 6 h) — no playlist/edit configuration screen.
    setState(() {
      _phase = _ShareSheetPhase.sending;
      _progress = 0.05;
      _status = s.shareSheetSending;
    });

    final app = AppSettingsScope.of(context);
    final summary = await ExternalShareCastService.instance.castToFrames(
      paths: _paths,
      frames: _selectedFrames,
      authToken: app.authToken,
      strings: s,
      onProgress: (frac, status) {
        if (!mounted) return;
        setState(() {
          _progress = frac.clamp(0.05, 1.0);
          if (status.trim().isNotEmpty) _status = status;
        });
      },
    );

    if (!mounted) return;
    if (summary.queued) {
      // Offline — persisted to the background retry queue.
      setState(() {
        _phase = _ShareSheetPhase.done;
        _progress = 1;
        _status = s.shareSheetQueuedOffline;
      });
    } else if (summary.sent > 0) {
      setState(() {
        _phase = _ShareSheetPhase.done;
        _progress = 1;
        _status = s.shareSheetPhotoSent;
      });
    } else {
      setState(() {
        _phase = _ShareSheetPhase.failed;
        _status = s.shareSheetErrorRetry;
      });
      return; // Keep the sheet open so the user can retry.
    }

    // Multi-image external shares are collected into a default "My Playlist"
    // album on the Playlist tab instead of spilling into loose Personal photos.
    unawaited(_routeToMyPlaylist(_paths, app.authToken));

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) {
      Navigator.pop(
        context,
        ShareTargetSheetResult(paths: _paths, frames: _selectedFrames),
      );
    }
  }

  /// Multi-image external shares land (and cloud-sync) in a default
  /// "My Playlist" album, keeping them out of loose Personal photos.
  Future<void> _routeToMyPlaylist(List<String> paths, String authToken) async {
    if (paths.length < 2) return;
    try {
      final playlistName = AppStrings.of(context).myPlaylistName;
      final name = playlistName.trim().toLowerCase();
      await SendAlbumsStore.instance.load();
      SendAlbumEntry? mine;
      for (final a in SendAlbumsStore.instance.albums) {
        if (a.name.trim().toLowerCase() == name) {
          mine = a;
          break;
        }
      }
      String id;
      if (mine == null) {
        await SendAlbumsStore.instance
            .createAlbum(playlistName, paths);
        await SendAlbumsStore.instance.load();
        id = SendAlbumsStore.instance.albums.first.id;
      } else {
        await SendAlbumsStore.instance.addPathsToAlbum(mine.id, paths);
        id = mine.id;
      }
      unawaited(SyncPipeline.instance.onAlbumsChanged(albumId: id));
    } catch (e, st) {
      AppDiagLog.verbose('[ShareSheet] route to My Playlist failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final photoCount = _paths.isNotEmpty ? _paths.length : widget.items.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: cs.surface,
          elevation: 10,
          shadowColor: Colors.black26,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.shareSheetTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _phase == _ShareSheetPhase.sending
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(s.cancel),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PhotoPreviewRow(
                  paths: _paths.isNotEmpty
                      ? _paths
                      : widget.items.map((e) {
                          final p = e.path;
                          return p.startsWith('file://')
                              ? Uri.parse(p).toFilePath()
                              : p;
                        }).toList(),
                  loading: _loadingPaths,
                  label: photoCount == 1
                      ? s.shareSheetOnePhoto
                      : s.shareSheetNPhotos(photoCount),
                ),
                const SizedBox(height: 18),
                Text(
                  s.shareSheetDestination,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (_frames.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      s.shareIncomingConnectFrame,
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.32,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _frames.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final f = _frames[i];
                        final selected = _selectedIds.contains(f.deviceId);
                        final title = f.frameName?.trim().isNotEmpty == true
                            ? f.frameName!.trim()
                            : f.listDisplayTitle(s);
                        return Material(
                          color: selected
                              ? cs.primary.withValues(alpha: 0.10)
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                          child: CheckboxListTile(
                            value: selected,
                            onChanged: _phase == _ShareSheetPhase.sending
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedIds.add(f.deviceId);
                                      } else {
                                        _selectedIds.remove(f.deviceId);
                                      }
                                    });
                                  },
                            controlAffinity: ListTileControlAffinity.trailing,
                            secondary: Icon(
                              Icons.photo_size_select_actual_outlined,
                              color: cs.primary,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              f.deviceId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_phase == _ShareSheetPhase.sending ||
                    _phase == _ShareSheetPhase.done ||
                    _phase == _ShareSheetPhase.failed) ...[
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _phase == _ShareSheetPhase.failed
                          ? cs.error
                          : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _phase == _ShareSheetPhase.sending
                          ? _progress.clamp(0.05, 1.0)
                          : (_phase == _ShareSheetPhase.done ? 1 : null),
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: (_phase == _ShareSheetPhase.sending ||
                          _loadingPaths ||
                          _frames.isEmpty ||
                          _selectedIds.isEmpty)
                      ? null
                      : _onSend,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _phase == _ShareSheetPhase.sending
                        ? s.shareSheetSending
                        : s.shareSheetSend,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPreviewRow extends StatelessWidget {
  const _PhotoPreviewRow({
    required this.paths,
    required this.label,
    required this.loading,
  });

  final List<String> paths;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final show = paths.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 56,
            width: 56.0 + (show.length > 1 ? (show.length - 1) * 18.0 : 0),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Stack(
                    children: [
                      for (var i = 0; i < show.length; i++)
                        Positioned(
                          left: i * 18.0,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.surface, width: 2),
                              image: DecorationImage(
                                image: FileImage(File(show[i])),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
