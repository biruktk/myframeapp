import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
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
    final picker = ImagePicker();
    final list = await picker.pickMultiImage();
    await PersonalGalleryStore.instance.load();
    final before = Set<String>.from(PersonalGalleryStore.instance.paths);
    if (list.isEmpty) {
      final one = await picker.pickImage(source: ImageSource.gallery);
      if (one == null) return;
      await PersonalGalleryStore.instance.addPaths([one.path]);
    } else {
      await PersonalGalleryStore.instance.addPaths(list.map((e) => e.path).toList());
    }
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
          ),
          _AlbumsGrid(
            albums: albums,
            emptyHint: s.galleryAlbumsEmptyHint,
            strings: s,
            colorScheme: cs,
            onCreateAlbum: _showCreateAlbumDialog,
            onAlbumTap: _openAlbumDetail,
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
    required this.previewFor,
  });

  final List<SendAlbumEntry> albums;
  final String emptyHint;
  final AppStrings strings;
  final ColorScheme colorScheme;
  final VoidCallback onCreateAlbum;
  final void Function(SendAlbumEntry album) onAlbumTap;
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
  });

  final List<String> paths;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

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
                    );
                  },
                ),
        ),
      ],
    );
  }
}
