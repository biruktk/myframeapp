import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imgLib;
import 'package:image_picker/image_picker.dart';

import '../services/gallery_photo_picker.dart';
import '../services/gallery_image_normalizer.dart';
import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/frame_online_guard.dart';
import '../services/network_link.dart';
import '../services/slideshow_playlist_store.dart';
import '../services/slideshow_style.dart';
import '../services/slideshow_remote_api.dart';
import '../services/frame_ble_mac_slug.dart';
import '../widgets/shell_navigation.dart';
import '../services/user_playlist_remote_api.dart';
import '../settings/app_settings.dart';
import '../widgets/progress_action_button.dart';

/// Multi-photo upload with progress + server slideshow playlist POST.
class SlideshowBatchScreen extends StatefulWidget {
  const SlideshowBatchScreen({
    super.key,
    this.imagePaths,
    this.playlistTitle,
    this.albumId,
  });

  /// When set, skip the gallery picker and upload these local files.
  final List<String>? imagePaths;
  final String? playlistTitle;
  final String? albumId;

  @override
  State<SlideshowBatchScreen> createState() => _SlideshowBatchScreenState();
}

class _SlideshowBatchScreenState extends State<SlideshowBatchScreen> {
  static const _intervals = [2, 5, 10, 30, 60];
  int _intervalMinutes = 10;
  var _busy = false;
  var _sendCurrent = 0;
  var _sendTotal = 0;
  final _api = FrameApiClient();

  bool get _hasPresetPaths =>
      widget.imagePaths != null && widget.imagePaths!.isNotEmpty;

  String _intervalLabel(AppStrings s, int m) {
    return switch (m) {
      2 => '2 min',
      5 => '5 min',
      10 => '10 min',
      30 => '30 min',
      60 => '1 h',
      _ => '$m min',
    };
  }

  Future<List<XFile>> _pickPhotos() => GalleryPhotoPicker.pickMulti(context);

  Future<void> _runPipeline() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    await DeviceStore.instance.load();
    final pFrame = DeviceStore.instance.cached;
    if (pFrame == null || !pFrame.canUploadToServer) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.connectFrameFirst)));
      }
      return;
    }
    if (!await FrameOnlineGuard.ensureOnlineForSend(context, frame: pFrame)) {
      return;
    }

    final presetPaths = _hasPresetPaths
        ? widget.imagePaths!
            .where((p) {
              try {
                return File(p).existsSync();
              } catch (_) {
                return false;
              }
            })
            .toList()
        : <String>[];
    final picked = _hasPresetPaths ? <XFile>[] : await _pickPhotos();
    if (_hasPresetPaths) {
      if (presetPaths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.playlistNeedPhotos)),
          );
        }
        return;
      }
    } else if (picked.isEmpty) {
      return;
    }
    if (!(await hasNetworkInterface())) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.authErrorNetwork)));
      return;
    }

    final ids = <String>[];
    final sourcePaths = _hasPresetPaths
        ? presetPaths
        : picked.map((f) => f.path).toList();
    if (sourcePaths.toSet().length < sourcePaths.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.duplicatePhotosError),
          ),
        );
      }
      return;
    }
    final total = sourcePaths.length;
    final token = AppSettingsScope.of(context).authToken.trim();
    final pairingToken = pFrame.resolvedPairingToken;

    setState(() {
      _busy = true;
      _sendCurrent = 0;
      _sendTotal = total;
    });

    try {
      for (var i = 0; i < total; i++) {
        if (!mounted) break;
        final idx = i + 1;
        setState(() => _sendCurrent = idx);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(days: 1),
            content: Text(s.slideshowSendingProgress(idx, total)),
          ),
        );

        final raw = await File(sourcePaths[i]).readAsBytes();
        final jpeg = await GalleryImageNormalizer.toJpegBytes(
          raw,
          pathHint: sourcePaths[i],
        );
        if (jpeg == null || jpeg.isEmpty) {
          AppDiagLog.verbose('[Slideshow] normalize failed photo $idx');
          continue;
        }
        final img = imgLib.decodeImage(jpeg);
        if (img == null) {
          AppDiagLog.verbose('[Slideshow] decode failed photo $idx');
          continue;
        }
        final resized = imgLib.copyResize(img, width: 1200);
        final compressed = Uint8List.fromList(imgLib.encodeJpg(resized, quality: 85));

        final ts = DateTime.now().millisecondsSinceEpoch;
        final isFirstUpload = i == 0;
        final cast = await FrameCloudCastService.instance.castPhoto(
          api: _api,
          paired: pFrame,
          jpegBytes: compressed,
          filename: 'slideshow_$ts.bin',
          slideshowStyle: SlideshowStyle.fade.apiValue,
          strings: s,
          userAuthToken: token.isNotEmpty ? token : null,
          syncSlideshowAfterSuccess: false,
          skipPlay: true,
          onProgress: (_) {},
          // Source isolation: playlist uploads must NOT bleed into the
          // user's Personal Album grid. The backend uses source=playlist
          // to exclude these from GET /api/user/gallery.
          source: UploadSource.playlist,
          playlistId: widget.albumId,
        );
        if (!cast.ok) {
          AppDiagLog.verbose('[Slideshow] cast failed photo $idx: ${cast.message}');
          continue;
        }
        final id = cast.slideshowImageId?.trim();
        if (id != null && id.isNotEmpty && !ids.contains(id)) {
          ids.add(id);
        }
        if (i + 1 < total) {
          // Increased delay to ensure frame has time to process and display each photo
          // E-ink refresh can take up to 60 seconds, wait 5s between uploads
          await Future<void>.delayed(const Duration(seconds: 5));
        }
      }

      if (ids.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.slideshowSendFailedHint),
            ),
          );
        }
        return;
      }

      if (mounted) {
        await SlideshowPlaylistStore.instance.save(
          paired: pFrame,
          imageIds: ids,
          intervalMinutes: _intervalMinutes,
        );
        try {
          await SlideshowRemoteApi(baseUrl: ApiConfig.baseUrl).publish(
            bearerToken: token.isNotEmpty ? token : null,
            pairingToken: pairingToken,
            macSlug: frameBleMacSlug(pFrame),
            imageIds: ids,
            intervalMinutes: _intervalMinutes,
            skipPlay: true,
            source: 'playlist',
          );
        } on SlideshowPublishException catch (e) {
          AppDiagLog.verbose(
            '[Slideshow] VPS publish failed ${e.statusCode}: ${e.body}',
          );
          if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.slideshowServerSyncFailed(e.statusCode),
              ),
            ),
          );
          }
        } catch (e) {
          AppDiagLog.verbose('[Slideshow] VPS publish: $e');
        }
        final albumId = widget.albumId?.trim();
        if (albumId != null && albumId.isNotEmpty) {
          try {
            await UserPlaylistRemoteApi(bearerToken: token).updatePlaylistPhotos(
              playlistId: albumId,
              photoIds: ids,
            );
          } catch (e) {
            AppDiagLog.verbose('[Slideshow] playlist sync: $e');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final partial = ids.length < total;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              partial
                  ? s.slideshowSentXOfY(ids.length, total)
                  : s.slideshowBatchDone(ids.length),
            ),
          ),
        );
        ShellNavigation.returnToSendAfterCast(context);
      }
    } catch (e, st) {
      AppDiagLog.verbose('[Slideshow] pipeline failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.processingFailed)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _sendCurrent = 0;
          _sendTotal = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final title = widget.playlistTitle?.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(title?.isNotEmpty == true ? title! : s.slideshowBatchTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_hasPresetPaths) ...[
            Text(
              s.slideshowBatchExplain,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.imagePaths!.length} photos',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
            ),
            const SizedBox(height: 16),
          ],
          Text(s.slideshowPickInterval, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _intervals)
                ChoiceChip(
                  label: Text(_intervalLabel(s, m)),
                  selected: _intervalMinutes == m,
                  onSelected: _busy ? null : (v) => setState(() => _intervalMinutes = m),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ProgressActionButton(
            label: _hasPresetPaths ? s.sendToFrame : s.slideshowRunBatch,
            icon: Icons.collections,
            isLoading: _busy,
            statusMessage: s.progressSendingPhotos,
            currentStep: _sendCurrent > 0 ? _sendCurrent : null,
            totalSteps: _sendTotal > 1 ? _sendTotal : null,
            progress: (_busy && _sendTotal > 0 && _sendCurrent > 0)
                ? (_sendCurrent / _sendTotal).clamp(0.05, 1.0)
                : null,
            onPressed: _busy ? null : _runPipeline,
            height: 52,
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
    );
  }
}
