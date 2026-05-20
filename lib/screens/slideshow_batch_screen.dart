import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../models/send_overlay_options.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/image_processor_service.dart';
import '../services/image_send_isolate_worker.dart';
import '../services/network_link.dart';
import '../services/slideshow_playlist_store.dart';
import '../services/slideshow_style.dart';
import '../services/slideshow_remote_api.dart';
import '../services/frame_ble_mac_slug.dart';
import '../services/transport_kind.dart';
import '../settings/app_settings.dart';

/// Multi-photo upload with progress + server slideshow playlist POST.
class SlideshowBatchScreen extends StatefulWidget {
  const SlideshowBatchScreen({super.key});

  @override
  State<SlideshowBatchScreen> createState() => _SlideshowBatchScreenState();
}

class _SlideshowBatchScreenState extends State<SlideshowBatchScreen> {
  static const _intervals = [60, 240, 480, 1440];
  int _intervalMinutes = 240;
  var _busy = false;
  final _api = FrameApiClient();

  String _intervalLabel(AppStrings s, int m) {
    return switch (m) {
      60 => '1 h',
      240 => '4 h',
      480 => '8 h',
      1440 => '24 h',
      _ => '$m min',
    };
  }

  Future<List<XFile>> _pickPhotos() async {
    if (Platform.isAndroid || Platform.isIOS) {
      var next = await Permission.photos.status;
      if (!next.isGranted && !next.isLimited) next = await Permission.photos.request();
      if (!next.isGranted && !next.isLimited) return [];
    }
    final picker = ImagePicker();
    var list = await picker.pickMultiImage();
    if (list.isEmpty) {
      final one = await picker.pickImage(source: ImageSource.gallery, maxWidth: 4096, maxHeight: 4096);
      if (one != null) list = [one];
    }
    return list;
  }

  Future<void> _runPipeline() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    await DeviceStore.instance.load();
    final pFrame = DeviceStore.instance.cached;
    if (pFrame == null || !pFrame.canUploadToServer) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pairingNeedsApiUrl)));
      }
      return;
    }

    final files = await _pickPhotos();
    if (files.isEmpty) return;
    if (!(await hasNetworkInterface())) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.authErrorNetwork)));
      return;
    }

    setState(() => _busy = true);
    final ids = <String>[];
    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle.apiValue;

    try {
      for (var i = 0; i < files.length; i++) {
        if (!mounted) break;
        final idx = i + 1;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(days: 1),
            content: Text(s.slideshowSendingProgress(idx, files.length)),
          ),
        );

        final bytes = await files[i].readAsBytes();
        final uploadJpeg = await compute(
          isolateComposeUploadJpeg,
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
        if (uploadJpeg == null) continue;

        final ts = DateTime.now().millisecondsSinceEpoch;
        final photo = await _api.uploadPhoto(
          fileBytes: uploadJpeg,
          filename: 'slideshow_$ts.jpg',
          deviceId: pFrame.deviceId,
          baseUrlOverride: pFrame.resolvedApiBaseUrl!,
          slideshowStyle: slideshow,
          transport: TransportKind.wifi.apiValue,
          pairingToken: pFrame.resolvedPairingToken,
        );
        final id = photo.checksumSha256?.trim().isNotEmpty == true
            ? photo.checksumSha256!
            : (photo.framePlayBasename ?? 'img_$ts');
        ids.add(id);
      }

      if (ids.isNotEmpty && mounted) {
        await SlideshowPlaylistStore.instance.save(
          paired: pFrame,
          imageIds: ids,
          intervalMinutes: _intervalMinutes,
        );
        final token = AppSettingsScope.of(context).authToken.trim();
        if (token.isNotEmpty) {
          try {
            await SlideshowRemoteApi(baseUrl: ApiConfig.baseUrl).publish(
              bearerToken: token,
              macSlug: frameBleMacSlug(pFrame),
              imageIds: ids,
              intervalMinutes: _intervalMinutes,
            );
          } catch (_) {
            /* server optional */
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.slideshowBatchDone(ids.length))),
        );
      }
    } catch (_) {
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
    return Scaffold(
      appBar: AppBar(title: Text(s.slideshowBatchTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
            label: Text(_busy ? s.working : s.slideshowRunBatch),
          ),
        ],
      ),
    );
  }
}
