import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/gallery_photo_picker.dart';
import '../services/personal_gallery_store.dart';
import '../services/photo_delete_service.dart';
import '../services/send_albums_store.dart';
import '../services/gallery_send_flow.dart';
import '../services/album_delete_service.dart';
import '../services/playlist_send_nav.dart';
import '../services/sync_pipeline.dart';
import '../settings/app_settings.dart';
import '../widgets/app_status_toast.dart';
import '../widgets/busy_status_dialog.dart';
import '../widgets/pick_personal_photos_dialog.dart';
import '../widgets/safe_render_boundary.dart';

/// Full-screen album: grid like Personal, tap to view, add via FAB, single / multi delete.
class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    this.autoPromptAddPhotos = false,
  });

  final String albumId;

  /// After create: open the system photo picker as soon as the detail loads.
  final bool autoPromptAddPhotos;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  SendAlbumEntry? _album;
  bool _selecting = false;
  final Set<String> _selected = {};
  final TextEditingController _titleCtrl = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  bool _editingTitle = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onTitleFocusChanged);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _reload();
    if (!mounted || !widget.autoPromptAddPhotos) return;
    await _addNewPhotos();
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onTitleFocusChanged);
    _titleFocus.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onTitleFocusChanged() {
    if (!_titleFocus.hasFocus && _editingTitle && mounted) {
      Future.microtask(() {
        if (mounted) _commitInlineTitle();
      });
    }
  }

  void _beginTitleEdit() {
    final a = _album;
    if (a == null || _selecting) return;
    _titleCtrl.text = a.name;
    setState(() => _editingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _titleFocus.requestFocus();
      _titleCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _titleCtrl.text.length);
    });
  }

  Future<void> _commitInlineTitle() async {
    if (!_editingTitle) return;
    final a = _album;
    if (a == null) return;
    final raw = _titleCtrl.text.trim();
    final next = raw.isEmpty ? 'Album' : raw;
    if (next == a.name) {
      if (mounted) setState(() => _editingTitle = false);
      return;
    }
    await SendAlbumsStore.instance.renameAlbum(widget.albumId, next);
    unawaited(SyncPipeline.instance.onAlbumsChanged(albumId: widget.albumId));
    if (!mounted) return;
    setState(() => _editingTitle = false);
    await _reload();
  }

  Future<void> _reload() async {
    await SendAlbumsStore.instance.load();
    if (!mounted) return;
    final found = SendAlbumsStore.instance.albumById(widget.albumId);
    if (found == null) {
      // Album was deleted (e.g. during a failed legacy resend). Pop safely
      // after this frame so we never race Navigator during a parent popUntil.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    setState(() {
      _album = found;
      _selected.removeWhere((p) => !found.paths.contains(p));
      if (!_editingTitle) {
        _titleCtrl.text = found.name;
      }
    });
  }

  /// Instantly show newly picked paths in the grid (before persist/sync).
  void _applyOptimisticPaths(List<String> newPaths) {
    final a = _album;
    if (a == null || !mounted || newPaths.isEmpty) return;
    final merged = List<String>.from(a.paths);
    for (final p in newPaths) {
      final t = p.trim();
      if (t.isEmpty || merged.contains(t)) continue;
      merged.add(t);
    }
    setState(() {
      _album = SendAlbumEntry(id: a.id, name: a.name, paths: merged);
    });
    _prefetchThumbs(newPaths);
  }

  void _prefetchThumbs(List<String> paths) {
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Decode near cell size (~1/3 screen width) so thumbs paint fast.
    final cachePx = (MediaQuery.sizeOf(context).width / 3 * dpr).round().clamp(120, 512);
    for (final path in paths) {
      try {
        final provider = ResizeImage(FileImage(File(path)), width: cachePx);
        unawaited(precacheImage(provider, context));
      } catch (_) {}
    }
  }

  void _syncAlbumInBackground(String albumId) {
    // Only push this album — do not await a full gallery download/sync (was ~30s).
    unawaited(() async {
      try {
        await SyncPipeline.instance.onAlbumsChanged(albumId: albumId);
      } catch (_) {}
    }());
  }

  Future<void> _addNewPhotos() async {
    final albumId = widget.albumId;
    final list = await GalleryPhotoPicker.pickMulti(context);
    if (list.isEmpty) return;
    final paths = list.map((e) => e.path).toList();

    _applyOptimisticPaths(paths);

    await PersonalGalleryStore.instance.addPaths(paths);
    await SendAlbumsStore.instance.addPathsToAlbum(albumId, paths);
    _syncAlbumInBackground(albumId);

    if (!mounted) return;
    // Mini-app: after selection, open send page immediately (previews can load later).
    final sendPaths = List<String>.from(_album?.paths ?? paths);
    if (sendPaths.length >= 2) {
      await PlaylistSendNav.openPlaylistSend(
        context,
        paths: sendPaths,
        playlistName: _album?.name,
        albumId: albumId,
      );
    } else {
      await PlaylistSendNav.openAfterPick(
        context,
        paths: sendPaths,
        playlistName: _album?.name,
        albumId: albumId,
      );
    }
    if (mounted) await _reload();
  }

  Future<void> _addFromPersonal() async {
    final s = AppStrings.of(context);
    await PersonalGalleryStore.instance.load();
    await SendAlbumsStore.instance.load();
    final a = _album;
    if (a == null || !mounted) return;
    final personal = PersonalGalleryStore.instance.paths;
    final inAlbum = a.paths.toSet();
    final available = <String>[];
    for (final p in personal) {
      final t = p.trim();
      if (t.isEmpty || inAlbum.contains(t)) continue;
      try {
        if (File(t).existsSync()) available.add(t);
      } catch (_) {}
    }
    if (!mounted) return;
    if (personal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.albumPersonalLibraryEmpty)));
      return;
    }
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.albumNothingLeftToAdd)));
      return;
    }
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => PickPersonalPhotosDialog(available: available, strings: s),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    _applyOptimisticPaths(picked);

    await SendAlbumsStore.instance.addPathsToAlbum(widget.albumId, picked);
    _syncAlbumInBackground(widget.albumId);

    if (!mounted) return;
    final sendPaths = List<String>.from(_album?.paths ?? picked);
    if (sendPaths.length >= 2) {
      await PlaylistSendNav.openPlaylistSend(
        context,
        paths: sendPaths,
        playlistName: _album?.name,
        albumId: widget.albumId,
      );
    } else {
      await PlaylistSendNav.openAfterPick(
        context,
        paths: sendPaths,
        playlistName: _album?.name,
        albumId: widget.albumId,
      );
    }
    if (mounted) await _reload();
  }

  Future<void> _sendPlaylist() async {
    final a = _album;
    if (a == null) return;
    final s = AppStrings.of(context);
    if (_editingTitle) await _commitInlineTitle();
    if (!mounted) return;

    if (!await PlaylistSendNav.ensureReadyToSend(context)) return;
    if (!mounted) return;

    final paths = a.paths.where((p) {
      try {
        return File(p).existsSync();
      } catch (_) {
        return false;
      }
    }).toList();
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.playlistAddPhotosBeforeSend)),
      );
      return;
    }

    await PlaylistSendNav.openPlaylistSend(
      context,
      paths: paths,
      playlistName: a.name,
      albumId: a.id,
    );
    await _reload();
  }

  void _showAddSheet() {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.collections_outlined),
              title: Text(s.albumAddFromPersonal),
              onTap: () {
                Navigator.pop(ctx);
                _addFromPersonal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: Text(s.albumAddNewPhotos),
              onTap: () {
                Navigator.pop(ctx);
                _addNewPhotos();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemovePaths(Iterable<String> paths) async {
    final list = paths.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return;
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deletePhotoTitle),
        content: Text(s.deletePhotoAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.deleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final tok = AppSettingsScope.of(context).authToken;
    await PhotoDeleteService.deleteMany(paths: list, bearerToken: tok);
    setState(() {
      _selected.removeWhere(list.contains);
      if (_selected.isEmpty) _selecting = false;
    });
    await _reload();
    if (!mounted) return;
    AppStatusToast.show(
      context,
      title: s.photoDeletedToast,
      message: s.deletePhotoAccountBody,
      tone: AppStatusTone.info,
      icon: Icons.delete_outline_rounded,
    );
  }

  Future<void> _confirmDeleteAlbum() async {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final name = _album?.name ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deleteAlbumTitle),
        content: Text(s.deleteAlbumConfirmDetail(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.deleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final tok = AppSettingsScope.of(context).authToken;
    await BusyStatusDialog.run<void>(
      context,
      message: s.deletingAlbum,
      action: () async {
        await AlbumDeleteService.deletePowerful(
          albumId: widget.albumId,
          bearerToken: tok,
        );
      },
    );
    if (!mounted) return;
    AppStatusToast.show(
      context,
      title: s.albumDeletedToast,
      message: s.deleteAlbumStopsPlaylistBody,
      tone: AppStatusTone.success,
      icon: Icons.delete_outline_rounded,
    );
    Navigator.of(context).pop();
  }

  Future<void> _openViewer(int initialIndex) async {
    final a = _album;
    if (a == null || a.paths.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => _AlbumPhotoViewerScreen(
          albumId: widget.albumId,
          initialPaths: List<String>.from(a.paths),
          initialIndex: initialIndex,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final a = _album;
    if (a == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final paths = a.paths;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_editingTitle,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _commitInlineTitle();
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _albumAppBarTitle(theme, cs),
          actions: [
            if (_selecting) ...[
              if (_selected.isNotEmpty)
                IconButton(
                  tooltip: s.remove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmRemovePaths(_selected),
                ),
              TextButton(
                onPressed: () => setState(() {
                  _selecting = false;
                  _selected.clear();
                }),
                child: Text(s.cancel),
              ),
            ] else ...[
              IconButton(
                tooltip: s.sendPlaylistToFrame,
                icon: const Icon(Icons.cast_connected_outlined),
                onPressed: () => unawaited(_sendPlaylist()),
              ),
              IconButton(
                tooltip: s.albumDetailSelect,
                icon: const Icon(Icons.checklist_outlined),
                onPressed: () async {
                  if (_editingTitle) await _commitInlineTitle();
                  if (!context.mounted) return;
                  setState(() => _selecting = true);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _confirmDeleteAlbum();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'delete', child: Text(s.deleteAction)),
                ],
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddSheet,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(s.albumDetailAddPhotosHint),
        ),
        body: paths.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(s.albumEmptyInAlbum, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              )
            : _selecting && _selected.isNotEmpty
                ? Column(
                    children: [
                      Material(
                        color: cs.surfaceContainerHigh,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            child: Text(
                              s.albumSelectedCount(_selected.length),
                              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: _buildGrid(paths, cs)),
                    ],
                  )
                : _buildGrid(paths, cs),
      ),
    );
  }

  Widget _albumAppBarTitle(ThemeData theme, ColorScheme cs) {
    final a = _album!;
    final titleStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
    if (_selecting) {
      return Text(
        a.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      );
    }
    final maxW = MediaQuery.sizeOf(context).width * 0.52;
    if (_editingTitle) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            style: titleStyle,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.only(bottom: 6, top: 2),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.38)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.38)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _commitInlineTitle(),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: InkWell(
          onTap: _beginTitleEdit,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<String> paths, ColorScheme cs) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (MediaQuery.sizeOf(context).width / 3 * dpr).round().clamp(120, 512);
    return GridView.builder(
      key: ValueKey('album-grid-${widget.albumId}-${paths.length}-${paths.join('|').hashCode}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: paths.length,
      itemBuilder: (context, i) {
        if (i < 0 || i >= paths.length) {
          return ColoredBox(
            color: cs.surfaceContainerHighest,
            child: Icon(Icons.broken_image_outlined, color: cs.outline),
          );
        }
        final path = paths[i];
        final selected = _selected.contains(path);
        return Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (_selecting) {
                setState(() {
                  if (selected) {
                    _selected.remove(path);
                  } else {
                    _selected.add(path);
                  }
                });
              } else {
                _openViewer(i);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                SafeFileImage(
                  key: ValueKey(path),
                  path: path,
                  fit: BoxFit.cover,
                  cacheWidth: cachePx,
                ),
                if (_selecting && selected)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.primary, width: 3),
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
                if (_selecting && selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.check_circle, color: cs.primary, size: 22),
                  ),
                if (!_selecting)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _confirmRemovePaths([path]),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

}

class _AlbumPhotoViewerScreen extends StatefulWidget {
  const _AlbumPhotoViewerScreen({
    required this.albumId,
    required this.initialPaths,
    required this.initialIndex,
  });

  final String albumId;
  final List<String> initialPaths;
  final int initialIndex;

  @override
  State<_AlbumPhotoViewerScreen> createState() => _AlbumPhotoViewerScreenState();
}

class _AlbumPhotoViewerScreenState extends State<_AlbumPhotoViewerScreen> {
  late PageController _pageController;
  late List<String> _paths;
  late int _index;

  @override
  void initState() {
    super.initState();
    _paths = List<String>.from(widget.initialPaths);
    _index = widget.initialIndex.clamp(0, _paths.isEmpty ? 0 : _paths.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _removeCurrent() async {
    if (_paths.isEmpty) return;
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final path = _paths[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deletePhotoTitle),
        content: Text(s.deletePhotoAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.deleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final tok = AppSettingsScope.of(context).authToken;
    await PhotoDeleteService.deleteCompletely(path: path, bearerToken: tok);
    if (!mounted) return;
    setState(() {
      _paths.removeAt(_index);
    });
    if (_paths.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    _index = clampImageIndex(_index, _paths.length);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_index);
    }
    if (!mounted) return;
    AppStatusToast.show(
      context,
      title: s.photoDeletedToast,
      message: s.deletePhotoAccountBody,
      tone: AppStatusTone.info,
      icon: Icons.delete_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (_paths.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: const SizedBox.shrink(),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${clampImageIndex(_index, _paths.length) + 1} / ${_paths.length}'),
        actions: [
          IconButton(
            tooltip: s.sendToFrame,
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              if (_paths.isEmpty) return;
              final i = clampImageIndex(_index, _paths.length);
              unawaited(sendGalleryPhotoToFrame(context, path: _paths[i]));
            },
          ),
          IconButton(
            tooltip: s.remove,
            icon: const Icon(Icons.delete_outline),
            onPressed: _removeCurrent,
          ),
        ],
      ),
      body: PageView.builder(
        key: ValueKey('album-viewer-${widget.albumId}-${_paths.length}-${_paths.join('|').hashCode}'),
        controller: _pageController,
        itemCount: _paths.length,
        onPageChanged: (i) => setState(() => _index = clampImageIndex(i, _paths.length)),
        itemBuilder: (context, i) {
          if (i < 0 || i >= _paths.length) {
            return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48));
          }
          final p = _paths[i];
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: SafeFileImage(
                key: ValueKey(p),
                path: p,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
