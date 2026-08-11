import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/frame_online_guard.dart';
import '../services/gallery_image_cache.dart';
import '../services/gallery_photo_picker.dart';
import 'edit_color_grade_screen.dart';

class CreatePlaylistScreen extends StatefulWidget {
  final List<String> imagePaths;

  const CreatePlaylistScreen({super.key, required this.imagePaths});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final _playlistNameController = TextEditingController();
  int _selectedIntervalSeconds = 300;
  late List<File> _images;

  static const int _maxPhotos = 10;
  static const List<int> _intervalSecondsList = [60, 120, 300, 600, 1800, 3600];

  @override
  void initState() {
    super.initState();
    _images = widget.imagePaths.map((p) => File(p)).toList();
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
    if (_images.isEmpty && mounted) Navigator.pop(context);
  }

  Future<void> _addMore() async {
    final s = AppStrings.of(context);
    final remaining = _maxPhotos - _images.length;
    if (remaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.maxPhotosAllowed(_maxPhotos))),
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
        SnackBar(content: Text(s.onlyMoreAllowed(remaining, _maxPhotos))),
      );
    }
    setState(() => _images.addAll(allowed.map((p) => File(p))));
  }

  String _intervalLabel(AppStrings s, int seconds) {
    return switch (seconds) {
      60 => s.oneMinute,
      120 => s.nMinutes(2),
      300 => s.nMinutes(5),
      600 => s.nMinutes(10),
      1800 => s.nMinutes(30),
      3600 => s.oneHour,
      _ => '$seconds sec',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          s.createPlaylistTitle,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _playlistNameController,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: s.myNewPlaylist,
                    hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.selectedPhotos(_images.length),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                  if (_images.length < _maxPhotos)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(s.addMore),
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
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 100,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _images[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!await FrameOnlineGuard.ensureOnlineForSend(context)) {
                      return;
                    }
                    if (!context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditColorGradeScreen(
                          selectedImages: _images,
                          initialIntervalSeconds: _selectedIntervalSeconds,
                          playlistName: _playlistNameController.text,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    s.sendPlaylistToFrame,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
