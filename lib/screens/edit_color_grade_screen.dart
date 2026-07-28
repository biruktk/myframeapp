import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_ble_mac_slug.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/slideshow_playlist_store.dart';
import '../services/slideshow_remote_api.dart';
import '../settings/app_settings.dart';
import '../services/send_albums_store.dart';

class EditColorGradeScreen extends StatefulWidget {
  final List<File> selectedImages;
  final int initialIntervalSeconds;
  final String playlistName;

  const EditColorGradeScreen({
    super.key,
    required this.selectedImages,
    required this.initialIntervalSeconds,
    required this.playlistName,
  });

  @override
  State<EditColorGradeScreen> createState() => _EditColorGradeScreenState();
}

class _EditColorGradeScreenState extends State<EditColorGradeScreen> {
  int _currentIndex = 0;
  late int _selectedIntervalSeconds;
  bool _isSending = false;

  final List<Map<String, dynamic>> _intervalPills = [
    {'seconds': 60, 'label': '1m'},
    {'seconds': 120, 'label': '2m'},
    {'seconds': 300, 'label': '5m'},
    {'seconds': 600, 'label': '10m'},
    {'seconds': 1800, 'label': '30m'},
    {'seconds': 3600, 'label': '1h'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedIntervalSeconds = widget.initialIntervalSeconds;
  }

  int get _intervalMinutes => _selectedIntervalSeconds ~/ 60;

  Future<void> _handleSendPlaylist() async {
    setState(() => _isSending = true);

    try {
      if (!mounted) return;
      final s = AppStrings.of(context);
      final app = AppSettingsScope.of(context);
      final authToken = app.authToken;

      await DeviceStore.instance.load();
      final activePaired = DeviceStore.instance.cached;
      if (activePaired == null || !activePaired.canUploadToServer) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please connect a frame first.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final pairingToken = activePaired.resolvedPairingToken;
      final api = FrameApiClient();
      final total = widget.selectedImages.length;
      final allIds = <String>[];
      final allPaths = <String>[];

      for (var i = 0; i < total; i++) {
        if (!mounted) break;

        final file = widget.selectedImages[i];
        allPaths.add(file.path);
        if (!await file.exists()) {
          AppDiagLog.verbose('[EditColorGrade] file not found: ${file.path}');
          continue;
        }

        final bytes = await file.readAsBytes();
        final isFirstUpload = i == 0;
        final ts = DateTime.now().millisecondsSinceEpoch;
        final filename = 'slideshow_$ts.jpg';

        final cast = await FrameCloudCastService.instance.castPhoto(
          api: api,
          paired: activePaired,
          jpegBytes: bytes,
          filename: filename,
          slideshowStyle: 'classic',
          displaySeconds: _selectedIntervalSeconds,
          strings: s,
          userAuthToken: authToken,
          syncSlideshowAfterSuccess: false,
          skipPlay: !isFirstUpload,
          editsJson: null,
          onProgress: (_) {},
        );

        if (!cast.ok) {
          AppDiagLog.verbose('[EditColorGrade] upload ${i + 1} failed: ${cast.message}');
          continue;
        }

        final id = cast.slideshowImageId?.trim();
        if (id != null && id.isNotEmpty && !allIds.contains(id)) {
          allIds.add(id);
        }

        if (i + 1 < total) {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
      }

      if (allIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All uploads failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await SendAlbumsStore.instance.createAlbum(
        widget.playlistName.trim().isEmpty ? 'My New Playlist' : widget.playlistName.trim(),
        allPaths,
      );

      unawaited(SlideshowPlaylistStore.instance.save(
        paired: activePaired,
        imageIds: allIds,
        intervalMinutes: _intervalMinutes,
      ));
      unawaited(SlideshowRemoteApi(baseUrl: ApiConfig.baseUrl).publish(
        bearerToken: authToken,
        pairingToken: pairingToken,
        macSlug: frameBleMacSlug(activePaired),
        imageIds: allIds,
        intervalMinutes: _intervalMinutes,
        skipPlay: true,
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Playlist sent successfully to frame!'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      AppDiagLog.verbose('[EditColorGrade] send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit & color grade (${_currentIndex + 1}/${widget.selectedImages.length})',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: screenHeight * 0.42,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PageView.builder(
                  itemCount: widget.selectedImages.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, index) {
                    return Image.file(
                      widget.selectedImages[index],
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),
            if (widget.selectedImages.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.selectedImages.length, (i) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentIndex
                            ? const Color(0xFFE53935)
                            : const Color(0xFFD0D0D0),
                      ),
                    );
                  }),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interval:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _intervalPills.map((item) {
                      final seconds = item['seconds'] as int;
                      final label = item['label'] as String;
                      final isSelected = _selectedIntervalSeconds == seconds;
                      return ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE53935),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFE53935) : const Color(0xFFE0E0E0),
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedIntervalSeconds = seconds);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _handleSendPlaylist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    disabledBackgroundColor: const Color(0xFFE53935).withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Send Playlist (${widget.selectedImages.length})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
