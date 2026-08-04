import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../models/playback_config.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_ble_mac_slug.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/frame_online_guard.dart';
import '../services/slideshow_playlist_store.dart';
import '../services/slideshow_remote_api.dart';
import '../settings/app_settings.dart';
import '../services/send_albums_store.dart';
import '../widgets/playlist_controls_widget.dart';
import '../widgets/progress_action_button.dart';
import '../widgets/safe_render_boundary.dart';
import '../widgets/shell_navigation.dart';

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
  late List<File> _images;
  late final PageController _pageController;
  int _currentIndex = 0;
  late int _selectedIntervalSeconds;
  bool _isSending = false;
  int _sendCurrent = 0;
  int _sendTotal = 0;
  int _strategy = 1;
  int _durationHours = 0;
  int _listEpoch = 0;

  @override
  void initState() {
    super.initState();
    _images = List<File>.from(widget.selectedImages);
    _currentIndex = clampImageIndex(0, _images.length);
    _pageController = PageController(initialPage: _currentIndex);
    _selectedIntervalSeconds = widget.initialIntervalSeconds;
  }

  @override
  void didUpdateWidget(covariant EditColorGradeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePaths(oldWidget.selectedImages, widget.selectedImages)) {
      _adoptImages(List<File>.from(widget.selectedImages));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _samePaths(List<File> a, List<File> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].path != b[i].path) return false;
    }
    return true;
  }

  void _adoptImages(List<File> next) {
    final clamped = clampImageIndex(_currentIndex, next.length);
    setState(() {
      _images = next;
      _currentIndex = clamped;
      _listEpoch++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_images.isEmpty) return;
      _pageController.jumpToPage(_currentIndex);
    });
  }

  int get _intervalMinutes => _selectedIntervalSeconds ~/ 60;

  PlaybackConfig get _config => PlaybackConfig(
        intervalMinutes: _intervalMinutes,
        strategy: _strategy,
        durationHours: _durationHours,
      );

  Key get _previewKey => ValueKey(
        'playlist-preview-$_listEpoch-${_images.length}-${_images.map((f) => f.path).join('|').hashCode}',
      );

  Future<void> _handleSendPlaylist() async {
    if (_isSending) return;
    final total = _images.length;
    if (total == 0) return;

    setState(() {
      _isSending = true;
      _sendCurrent = 0;
      _sendTotal = total;
    });

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
      if (!mounted) return;
      if (!await FrameOnlineGuard.ensureOnlineForSend(context, frame: activePaired)) {
        return;
      }
      if (!mounted) return;

      final pairingToken = activePaired.resolvedPairingToken;
      final api = FrameApiClient();
      final allIds = <String>[];
      final allPaths = <String>[];

      // Snapshot so UI cannot mutate the send set mid-flight.
      final sendFiles = List<File>.from(_images);

      for (var i = 0; i < sendFiles.length; i++) {
        if (!mounted) break;
        setState(() => _sendCurrent = i + 1);

        final file = sendFiles[i];
        allPaths.add(file.path);
        if (!await file.exists()) {
          AppDiagLog.verbose('[EditColorGrade] file not found: ${file.path}');
          continue;
        }

        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final isFirstUpload = allIds.isEmpty;
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

        if (i + 1 < sendFiles.length) {
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

      final name = widget.playlistName.trim().isEmpty
          ? s.myNewPlaylist
          : widget.playlistName.trim();
      final albumId = widget.albumId?.trim();
      if (albumId != null && albumId.isNotEmpty) {
        // Re-send updated playlist: keep the same album id (do NOT delete+recreate —
        // that tombstones the old id and black-screens open detail routes).
        // Resolve aliases in case cloud sync rebound the local timestamp id.
        final ok = await SendAlbumsStore.instance.replaceAlbumPaths(albumId, allPaths);
        if (!ok) {
          await SendAlbumsStore.instance.createAlbum(name, allPaths);
        } else if (name.isNotEmpty) {
          await SendAlbumsStore.instance.renameAlbum(albumId, name);
        }
      } else {
        await SendAlbumsStore.instance.createAlbum(name, allPaths);
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
        strategy: _strategy == 2 ? 2 : 1,
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

      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      // Always fall back to the Send Photo tab after a successful playlist send.
      ShellNavigation.returnToSendAfterCast(context);
    } catch (e, st) {
      AppDiagLog.verbose('[EditColorGrade] send error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.uploadFailed(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendCurrent = 0;
          _sendTotal = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final count = _images.length;
    final safeIndex = clampImageIndex(_currentIndex, count);

    return PopScope(
      canPop: !_isSending,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.chevron_left, color: cs.onSurface, size: 28),
            onPressed: _isSending ? null : () => Navigator.pop(context),
          ),
          title: Text(
            count == 0
                ? s.multiImageCasting(0, 0)
                : s.multiImageCasting(safeIndex + 1, count),
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: _isSending,
            child: Column(
              children: [
                Expanded(
                  child: count == 0
                      ? SafeRenderFallback(
                          message: s.playlistAddPhotosBeforeSend,
                          onRetry: () => Navigator.pop(context),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                height: screenHeight * 0.35,
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: Theme.of(context).brightness == Brightness.dark
                                            ? 0.35
                                            : 0.04,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SafeRenderBoundary(
                                    child: PageView.builder(
                                      key: _previewKey,
                                      controller: _pageController,
                                      itemCount: count,
                                      onPageChanged: (idx) {
                                        setState(() {
                                          _currentIndex = clampImageIndex(idx, _images.length);
                                        });
                                      },
                                      itemBuilder: (context, index) {
                                        if (index < 0 || index >= _images.length) {
                                          return SafeRenderFallback(onRetry: () {
                                            setState(() {
                                              _currentIndex = clampImageIndex(0, _images.length);
                                              _listEpoch++;
                                            });
                                          });
                                        }
                                        final file = _images[index];
                                        return SafeFileImage(
                                          key: ValueKey('img-${file.path}'),
                                          path: file.path,
                                          fit: BoxFit.contain,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              if (count > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(count, (i) {
                                      return Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: i == safeIndex
                                              ? cs.primary
                                              : cs.outlineVariant,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              PlaylistControlsWidget(
                                selectedIntervalSeconds: _selectedIntervalSeconds,
                                onIntervalChanged: (seconds) =>
                                    setState(() => _selectedIntervalSeconds = seconds),
                                selectedStrategy: _strategy,
                                onStrategyChanged: (v) => setState(() => _strategy = v),
                                selectedDurationHours: _durationHours,
                                onDurationChanged: (v) => setState(() => _durationHours = v),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Text(
                                      s.totalLoopTime(_config.estimatedLoopTime(count)),
                                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                ),
                Material(
                  color: cs.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: ProgressActionButton(
                      label: s.sendPlaylistN(count),
                      isLoading: _isSending,
                      statusMessage: s.progressSendingPhotos,
                      currentStep: _sendCurrent > 0 ? _sendCurrent : null,
                      totalSteps: _sendTotal > 1 ? _sendTotal : null,
                      progress: (_isSending && _sendTotal > 0 && _sendCurrent > 0)
                          ? (_sendCurrent / _sendTotal).clamp(0.05, 1.0)
                          : null,
                      onPressed: (_isSending || count == 0) ? null : _handleSendPlaylist,
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
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
