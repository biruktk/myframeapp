import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/gallery_photo_picker.dart';
import '../services/personal_gallery_store.dart';
import '../services/send_albums_store.dart';
import '../services/gallery_send_flow.dart';
import '../widgets/pick_personal_photos_dialog.dart';

bool _localFileExists(String path) {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

/// Full-screen album: grid like Personal, tap to view, add via FAB, single / multi delete.
class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

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
    _reload();
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
    if (!mounted) return;
    setState(() => _editingTitle = false);
    await _reload();
  }

  Future<void> _reload() async {
    await SendAlbumsStore.instance.load();
    if (!mounted) return;
    SendAlbumEntry? found;
    for (final x in SendAlbumsStore.instance.albums) {
      if (x.id == widget.albumId) {
        found = x;
        break;
      }
    }
    if (found == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _album = found;
      _selected.removeWhere((p) => !found!.paths.contains(p));
      if (!_editingTitle) {
        _titleCtrl.text = found!.name;
      }
    });
  }

  Future<void> _addNewPhotos() async {
    final albumId = widget.albumId;
    final list = await GalleryPhotoPicker.pickMulti(context);
    if (list.isEmpty) return;
    final paths = list.map((e) => e.path).toList();
    await PersonalGalleryStore.instance.addPaths(paths);
    await SendAlbumsStore.instance.addPathsToAlbum(albumId, paths);
    await _reload();
    if (!mounted) return;
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.albumAddedCount(paths.length))));
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
    await SendAlbumsStore.instance.addPathsToAlbum(widget.albumId, picked);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.albumAddedCount(picked.length))));
    }
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.albumRemoveFromAlbumTitle),
        content: Text(s.albumRemoveFromAlbumBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.remove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SendAlbumsStore.instance.removePathsFromAlbum(widget.albumId, list);
    setState(() {
      _selected.removeWhere(list.contains);
      if (_selected.isEmpty) _selecting = false;
    });
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.albumRemovedFromAlbumCount(list.length))),
    );
  }

  Future<void> _confirmDeleteAlbum() async {
    final s = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deleteAction),
        content: Text('Delete "${_album?.name ?? ''}" and all its photos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.deleteAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SendAlbumsStore.instance.deleteAlbum(widget.albumId);
    if (!mounted) return;
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
                        color: cs.primaryContainer.withValues(alpha: 0.35),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            child: Text(
                              s.albumSelectedCount(_selected.length),
                              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: paths.length,
      itemBuilder: (context, i) {
        final path = paths[i];
        final exists = _localFileExists(path);
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
                if (exists)
                  Image.file(File(path), fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.broken_image_outlined, color: cs.outline),
                  ),
                if (_selecting && selected)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.primary, width: 3),
                      color: cs.primary.withValues(alpha: 0.22),
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
    final path = _paths[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.albumRemoveFromAlbumTitle),
        content: Text(s.albumRemoveFromAlbumBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.remove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SendAlbumsStore.instance.removePathsFromAlbum(widget.albumId, [path]);
    if (!mounted) return;
    setState(() {
      _paths.removeAt(_index);
    });
    if (_paths.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (_index >= _paths.length) {
      _index = _paths.length - 1;
    }
    _pageController.jumpToPage(_index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.albumRemovedFromAlbumCount(1))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
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
        title: Text('${_index + 1} / ${_paths.length}'),
        actions: [
          IconButton(
            tooltip: s.sendToFrame,
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              if (_paths.isEmpty) return;
              unawaited(sendGalleryPhotoToFrame(context, path: _paths[_index]));
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
        controller: _pageController,
        itemCount: _paths.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final p = _paths[i];
          final ok = _localFileExists(p);
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
