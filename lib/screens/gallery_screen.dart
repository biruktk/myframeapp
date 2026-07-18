import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/gallery_send_flow.dart';
import '../services/gallery_photo_picker.dart';
import '../services/personal_gallery_store.dart';
import '../services/user_gallery_cloud_service.dart';
import '../settings/app_settings.dart';
import '../services/send_albums_store.dart';
import '../widgets/text_input_bottom_sheet.dart';
import 'album_detail_screen.dart';

/// Personal photo grid + named albums (no social).
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with AutomaticKeepAliveClientMixin {
  int _tab = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    PersonalGalleryStore.instance.revision.addListener(_onPersonalGalleryChanged);
    _reload();
  }

  @override
  void dispose() {
    PersonalGalleryStore.instance.revision.removeListener(_onPersonalGalleryChanged);
    super.dispose();
  }

  void _onPersonalGalleryChanged() {
    if (!mounted) return;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    await PersonalGalleryStore.instance.load();
    await SendAlbumsStore.instance.load();
    if (mounted) setState(() {});
  }

  Future<void> _confirmDeleteAlbum(SendAlbumEntry album) async {
    final s = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deleteAction),
        content: Text('${s.albumRemoveFromAlbumTitle}\n"${album.name}" (${album.paths.length} photos)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.deleteAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SendAlbumsStore.instance.deleteAlbum(album.id);
    await _reload();
  }

  Future<void> _showCreateAlbumDialog() async {
    final s = AppStrings.of(context);
    final name = await TextInputBottomSheet.show(
      context,
      title: s.createNewAlbum,
      label: s.newAlbumNameHint,
      confirmLabel: s.nextLabel,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await SendAlbumsStore.instance.createAlbum(name.trim(), const <String>[]);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.albumCreatedMessage(name.trim()))),
    );
  }

  Future<void> _addFromPicker() async {
    final list = await GalleryPhotoPicker.pickMulti(context);
    await PersonalGalleryStore.instance.load();
    final before = Set<String>.from(PersonalGalleryStore.instance.paths);
    if (list.isEmpty) return;
    await PersonalGalleryStore.instance.addPaths(list.map((e) => e.path).toList());
    if (!mounted) return;
    final tok = AppSettingsScope.of(context).authToken;
    if (tok.trim().isNotEmpty) {
      for (final path in PersonalGalleryStore.instance.paths) {
        if (before.contains(path)) continue;
        await UserGalleryCloudService.instance.uploadFile(
          authToken: tok,
          localPath: path,
        );
      }
    }
    await _reload();
  }

  Future<void> _openAlbumDetail(SendAlbumEntry album) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => AlbumDetailScreen(albumId: album.id),
      ),
    );
    await _reload();
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
    super.build(context);
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final paths = PersonalGalleryStore.instance.paths;
    final albums = SendAlbumsStore.instance.albums;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.navGallery),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text('${s.galleryPersonalTab} · ${paths.length}'),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('${s.galleryAlbumsTab} · ${albums.length}'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _PersonalGrid(
            paths: paths,
            onAdd: _addFromPicker,
            onRemove: (i) async {
              await PersonalGalleryStore.instance.removeAt(i);
              await _reload();
            },
            onSendToFrame: (path) => sendGalleryPhotoToFrame(context, path: path),
          ),
          _AlbumsGrid(
            albums: albums,
            emptyHint: s.galleryAlbumsEmptyHint,
            strings: s,
            colorScheme: cs,
            onCreateAlbum: _showCreateAlbumDialog,
            onAlbumTap: _openAlbumDetail,
            onDeleteAlbum: _confirmDeleteAlbum,
            previewFor: _firstPreviewPath,
          ),
        ],
      ),
    );
  }
}

class _AlbumsGrid extends StatelessWidget {
  const _AlbumsGrid({
    required this.albums,
    required this.emptyHint,
    required this.strings,
    required this.colorScheme,
    required this.onCreateAlbum,
    required this.onAlbumTap,
    required this.onDeleteAlbum,
    required this.previewFor,
  });

  final List<SendAlbumEntry> albums;
  final String emptyHint;
  final AppStrings strings;
  final ColorScheme colorScheme;
  final VoidCallback onCreateAlbum;
  final void Function(SendAlbumEntry album) onAlbumTap;
  final void Function(SendAlbumEntry album) onDeleteAlbum;
  final String? Function(SendAlbumEntry) previewFor;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(emptyHint, style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateAlbum,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(strings.createNewAlbum),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.88,
            ),
            itemCount: albums.length + 1,
            itemBuilder: (context, index) {
              if (index == albums.length) {
                return Material(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onCreateAlbum,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 40, color: colorScheme.primary),
                        const SizedBox(height: 8),
                        Text(strings.createNewAlbum, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.primary)),
                      ],
                    ),
                  ),
                );
              }
              final a = albums[index];
              final preview = previewFor(a);
              return Material(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                elevation: 1,
                shadowColor: Colors.black26,
                child: InkWell(
                  onTap: () => onAlbumTap(a),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (preview != null)
                        Image.file(File(preview), fit: BoxFit.cover)
                      else
                        ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.photo_outlined, size: 48, color: colorScheme.outline),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.65),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  strings.photosCount(a.paths.length),
                                  style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => onDeleteAlbum(a),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PersonalGrid extends StatelessWidget {
  const _PersonalGrid({
    required this.paths,
    required this.onAdd,
    required this.onRemove,
    required this.onSendToFrame,
  });

  final List<String> paths;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final Future<void> Function(String path) onSendToFrame;

  Future<void> _openViewer(BuildContext context, int initialIndex) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => _PersonalPhotoViewerScreen(
          paths: paths,
          initialIndex: initialIndex,
          onSendToFrame: onSendToFrame,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(s.galleryAddPhotos),
          ),
        ),
        Expanded(
          child: paths.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(s.galleryEmptyHint, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: paths.length,
                  itemBuilder: (context, i) {
                    final path = paths[i];
                    return Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openViewer(context, i),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: cs.surfaceContainerHighest,
                                child: Icon(Icons.broken_image_outlined, color: cs.error),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => onRemove(i),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PersonalPhotoViewerScreen extends StatefulWidget {
  const _PersonalPhotoViewerScreen({
    required this.paths,
    required this.initialIndex,
    required this.onSendToFrame,
  });

  final List<String> paths;
  final int initialIndex;
  final Future<void> Function(String path) onSendToFrame;

  @override
  State<_PersonalPhotoViewerScreen> createState() => _PersonalPhotoViewerScreenState();
}

class _PersonalPhotoViewerScreenState extends State<_PersonalPhotoViewerScreen> {
  late PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.paths.isEmpty ? 0 : widget.paths.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _sendCurrent() async {
    if (widget.paths.isEmpty) return;
    final path = widget.paths[_index];
    await widget.onSendToFrame(path);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final paths = widget.paths;
    if (paths.isEmpty) {
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
        title: Text('${_index + 1} / ${paths.length}'),
        actions: [
          IconButton(
            tooltip: s.sendToFrame,
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _sendCurrent,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: paths.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final p = paths[i];
          final ok = File(p).existsSync();
          return Center(
            child: ok
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.file(File(p), fit: BoxFit.contain),
                  )
                : Icon(Icons.broken_image_outlined, color: cs.outline, size: 48),
          );
        },
      ),
    );
  }
}
