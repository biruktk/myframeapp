import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/gallery_send_flow.dart';
import '../services/gallery_photo_picker.dart';
import '../services/personal_gallery_store.dart';
import '../services/user_gallery_cloud_service.dart';
import '../services/frame_api_client.dart';
import '../settings/app_settings.dart';
import '../services/send_albums_store.dart';
import '../widgets/custom_segmented_toggle.dart';
import '../widgets/text_input_bottom_sheet.dart';
import 'album_detail_screen.dart';
import 'image_editor_screen.dart';

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
    final tok = AppSettingsScope.of(context).authToken;
    if (tok.trim().isNotEmpty) {
      unawaited(
        FrameApiClient().deleteUserAlbum(
          bearerToken: tok,
          albumId: album.id,
        ),
      );
    }
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
            child: CustomSegmentedToggle(
              selectedIndex: _tab,
              onTabChanged: (v) => setState(() => _tab = v),
              leftLabel: s.galleryPersonalTab,
              leftCount: paths.length,
              rightLabel: s.galleryAlbumsTab,
              rightCount: albums.length,
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
              final paths = PersonalGalleryStore.instance.paths;
              final path = (i >= 0 && i < paths.length) ? paths[i] : null;
              await PersonalGalleryStore.instance.removeAt(i);
              final tok = AppSettingsScope.of(context).authToken;
              if (tok.trim().isNotEmpty && path != null) {
                unawaited(
                  UserGalleryCloudService.instance.deletePhoto(
                    authToken: tok,
                    localPath: path,
                  ),
                );
              }
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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: albums.length + 1,
            itemBuilder: (context, index) {
              if (index == albums.length) {
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onCreateAlbum,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 36, color: colorScheme.primary),
                        const SizedBox(height: 6),
                        Text(strings.createNewAlbum, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: colorScheme.primary)),
                      ],
                    ),
                  ),
                );
              }
              final a = albums[index];
              final preview = previewFor(a);
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onAlbumTap(a),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              if (preview != null)
                                Image.file(File(preview), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                              else
                                Container(
                                  color: const Color(0xFFFFF0F0),
                                  child: const Center(
                                    child: Icon(Icons.collections_outlined, color: Color(0xFFE53935), size: 28),
                                  ),
                                ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => onDeleteAlbum(a),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.08),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      a.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      strings.photosCount(a.paths.length),
                                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
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
