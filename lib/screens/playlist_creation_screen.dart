import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/device_store.dart';
import '../services/frame_online_guard.dart';
import '../services/gallery_photo_picker.dart';
import '../services/gallery_image_cache.dart';
import '../services/send_albums_store.dart';
import 'image_editor_screen.dart';

class PlaylistCreationScreen extends StatefulWidget {
  const PlaylistCreationScreen({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  State<PlaylistCreationScreen> createState() => _PlaylistCreationScreenState();
}

class _PlaylistCreationScreenState extends State<PlaylistCreationScreen> {
  static const _maxPhotos = 10;

  final _nameController = TextEditingController(text: 'My New Playlist');
  var _selectedInterval = 10;
  late List<String> _paths;
  var _isUploading = false;

  final _intervalOptions = [5, 10, 30, 60, 300];

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.imagePaths);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) return '$seconds Seconds';
    final m = seconds ~/ 60;
    return '$m Minute${m > 1 ? 's' : ''}';
  }

  void _removeImage(int index) {
    setState(() => _paths.removeAt(index));
    if (_paths.isEmpty && mounted) Navigator.pop(context);
  }

  Future<void> _addMore() async {
    final remaining = _maxPhotos - _paths.length;
    if (remaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $_maxPhotos photos allowed.')),
        );
      }
      return;
    }

    final files = await GalleryPhotoPicker.pickMulti(context);
    if (files.isEmpty || !mounted) return;

    final stored = await GalleryImageCache.persistPaths(files.map((f) => f.path));
    final allowed = stored.take(remaining).toList();
    if (stored.length > remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only $remaining more allowed (max $_maxPhotos).')),
      );
    }
    setState(() => _paths.addAll(allowed));
  }

  Future<void> _submit() async {
    if (_paths.isEmpty) return;
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    if (paired == null || !paired.canUploadToServer) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please connect a frame first.')),
      );
      return;
    }
    if (!await FrameOnlineGuard.ensureOnlineForSend(context, frame: paired)) {
      return;
    }

    setState(() => _isUploading = true);

    final name = _nameController.text.trim().isEmpty
        ? 'My New Playlist'
        : _nameController.text.trim();

    final allBytes = <Uint8List>[];
    for (final path in _paths) {
      allBytes.add(await File(path).readAsBytes());
    }

    await SendAlbumsStore.instance.createAlbum(name, _paths);
    await SendAlbumsStore.instance.load();
    String? albumId;
    if (SendAlbumsStore.instance.albums.isNotEmpty) {
      albumId = SendAlbumsStore.instance.albums.first.id;
    }
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(
          imageBytes: allBytes.first,
          playlistImages: allBytes.length > 1 ? allBytes : null,
          playlistPaths: _paths,
          playlistTitle: name,
          displaySeconds: _selectedInterval,
          albumId: albumId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Create Playlist',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: cs.primary),
                  const SizedBox(height: 16),
                  Text('Preparing Playlist...',
                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Playlist Name',
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Display Interval',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedInterval,
                          isExpanded: true,
                          dropdownColor: cs.surface,
                          items: _intervalOptions.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(_formatInterval(s), style: TextStyle(color: cs.onSurface)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedInterval = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Photos (${_paths.length}/$_maxPhotos)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        if (_paths.length < _maxPhotos)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add More'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.onSurface,
                              side: BorderSide(color: cs.primary, width: 1.5),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _addMore,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _paths.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_paths[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Send Playlist to Frame',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
