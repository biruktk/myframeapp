import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../models/playback_config.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_ble_mac_slug.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/slideshow_playlist_store.dart';
import '../services/slideshow_remote_api.dart';
import '../settings/app_settings.dart';
import '../services/send_albums_store.dart';
import '../widgets/playlist_controls_widget.dart';

class EditColorGradeScreen extends StatefulWidget {
  final List<File> selectedImages;
  final int initialIntervalSeconds;
  final String playlistName;
  final String? albumId;

  const EditColorGradeScreen({
    super.key,
    required this.selectedImages,
    required this.initialIntervalSeconds,
    required this.playlistName,
    this.albumId,
  });

  @override
  State<EditColorGradeScreen> createState() => _EditColorGradeScreenState();
}

class _EditColorGradeScreenState extends State<EditColorGradeScreen> {
  int _currentIndex = 0;
  late int _selectedIntervalSeconds;
  bool _isSending = false;
  int _strategy = 1;
  int _durationHours = 0;

  @override
  void initState() {
    super.initState();
    _selectedIntervalSeconds = widget.initialIntervalSeconds;
  }

  int get _intervalMinutes => _selectedIntervalSeconds ~/ 60;

  PlaybackConfig get _config => PlaybackConfig(
        intervalMinutes: _intervalMinutes,
        strategy: _strategy,
        durationHours: _durationHours,
      );

  Future<void> _handleSendPlaylist() async {
    setState(() => _isSending = true);

    final s = AppStrings.of(context);
    try {
      if (!mounted) return;
      final app = AppSettingsScope.of(context);
      final authToken = app.authToken;

      await DeviceStore.instance.load();
      final activePaired = DeviceStore.instance.cached;
      if (activePaired == null || !activePaired.canUploadToServer) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.pleaseConnectFrame), backgroundColor: Colors.red),
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
            SnackBar(content: Text(s.allUploadsFailed), backgroundColor: Colors.red),
          );
        }
        return;
      }

      await SendAlbumsStore.instance.createAlbum(
        widget.playlistName.trim().isEmpty ? s.myNewPlaylist : widget.playlistName.trim(),
        allPaths,
      );

      if (widget.albumId != null) {
        await SendAlbumsStore.instance.deleteAlbum(widget.albumId!);
      }

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
        strategy: _strategy,
        durationHours: _durationHours,
        skipPlay: true,
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.playlistSent),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      AppDiagLog.verbose('[EditColorGrade] send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.uploadFailed(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          s.multiImageCasting(_currentIndex + 1, widget.selectedImages.length),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      height: screenHeight * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
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
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
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
                    const SizedBox(height: 12),
                    PlaylistControlsWidget(
                      selectedIntervalSeconds: _selectedIntervalSeconds,
                      onIntervalChanged: (seconds) => setState(() => _selectedIntervalSeconds = seconds),
                      selectedStrategy: _strategy,
                      onStrategyChanged: (v) => setState(() => _strategy = v),
                      selectedDurationHours: _durationHours,
                      onDurationChanged: (v) => setState(() => _durationHours = v),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            s.totalLoopTime(_config.estimatedLoopTime(widget.selectedImages.length)),
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _handleSendPlaylist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    disabledBackgroundColor: const Color(0xFFE53935).withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          s.sendPlaylistN(widget.selectedImages.length),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
