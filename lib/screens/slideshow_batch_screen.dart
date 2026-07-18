import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/gallery_photo_picker.dart';
import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../models/send_overlay_options.dart';
import '../services/app_diag_log.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/image_processor_service.dart';
import '../services/image_send_isolate_worker.dart';
import '../services/network_link.dart';
import '../services/slideshow_playlist_store.dart';
import '../services/slideshow_style.dart';
import '../services/slideshow_remote_api.dart';
import '../services/frame_ble_mac_slug.dart';
import '../services/user_playlist_remote_api.dart';
import '../settings/app_settings.dart';

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
  static const _intervals = [5, 10, 30, 60];
  int _intervalMinutes = 10;
  var _busy = false;
  final _api = FrameApiClient();

  bool get _hasPresetPaths =>
      widget.imagePaths != null && widget.imagePaths!.isNotEmpty;

  String _intervalLabel(AppStrings s, int m) {
    return switch (m) {
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

    setState(() => _busy = true);
    final ids = <String>[];
    final sourcePaths = _hasPresetPaths
        ? presetPaths
        : picked.map((f) => f.path).toList();
    if (sourcePaths.toSet().length < sourcePaths.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist has duplicate photos — pick different images for each slot.'),
          ),
        );
      }
      setState(() => _busy = false);
      return;
    }
    final total = sourcePaths.length;
    final token = AppSettingsScope.of(context).authToken.trim();
    final pairingToken = pFrame.resolvedPairingToken;

    try {
      for (var i = 0; i < total; i++) {
        if (!mounted) break;
        final idx = i + 1;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(days: 1),
            content: Text(s.slideshowSendingProgress(idx, total)),
          ),
        );

        final bytes = await File(sourcePaths[i]).readAsBytes();
        final uploadBin = await compute(
          isolateComposeUploadBin,
          ComposeUploadIsolateArgs(
            imageBytes: bytes,
            quarterTurns: 0,
            brightness: 1,
            contrast: 1,
            saturation: 1,
            filterIndex: FrameImageFilter.none.index,
            overlay: const SendOverlayOptions(),
            locationText: pFrame.listDisplayTitle(s),
          ),
        );
        if (uploadBin == null) continue;

        final ts = DateTime.now().millisecondsSinceEpoch;
        // First upload triggers MQTT play so the frame shows the image immediately.
        // Subsequent uploads are stored only — the slideshow endpoint will manage timing.
        final isFirstUpload = i == 0;
        final cast = await FrameCloudCastService.instance.castPhoto(
          api: _api,
          paired: pFrame,
          jpegBytes: uploadBin,
          filename: 'slideshow_$ts.bin',
          slideshowStyle: SlideshowStyle.fade.apiValue,
          strings: s,
          userAuthToken: token.isNotEmpty ? token : null,
          syncSlideshowAfterSuccess: false,
          skipPlay: !isFirstUpload,
          onProgress: (_) {},
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
            const SnackBar(
              content: Text(
                'Could not send playlist photos to the frame. Try single Send first.',
              ),
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
          );
        } on SlideshowPublishException catch (e) {
          AppDiagLog.verbose(
            '[Slideshow] VPS publish failed ${e.statusCode}: ${e.body}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Playlist saved locally but server sync failed (${e.statusCode}). The frame may not auto-advance.',
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
                  ? 'Sent ${ids.length} of $total photos to the frame playlist.'
                  : s.slideshowBatchDone(ids.length),
            ),
          ),
        );
        if (_hasPresetPaths) Navigator.of(context).pop();
      }
    } catch (e, st) {
      AppDiagLog.verbose('[Slideshow] pipeline failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.processingFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
          FilledButton.icon(
            onPressed: _busy ? null : _runPipeline,
            icon: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.collections),
            label: Text(
              _busy
                  ? s.working
                  : (_hasPresetPaths ? s.sendToFrame : s.slideshowRunBatch),
            ),
          ),
        ],
      ),
    );
  }
}
