import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../models/frame_playback_profile.dart';
import 'app_diag_log.dart';
import 'device_store.dart';
import 'external_share_queue.dart';
import 'frame_ble_mac_slug.dart';
import 'frame_cloud_cast_service.dart';
import 'frame_api_client.dart';
import 'frame_settings_store.dart';
import 'gallery_image_normalizer.dart';
import 'network_link.dart';
import 'slideshow_playlist_store.dart';
import 'slideshow_remote_api.dart';

/// External sharing → app (gallery / share sheet) upload orchestrator.
///
/// External payloads bypass the internal playlist/album configuration UI and
/// are uploaded immediately, **inheriting the target frame's active Frame
/// Profile** (interval / playback order / duration) instead of hardcoding a
/// fixed interval. When the device is offline or a frame is unreachable, the
/// normalized payload is persisted to the [ExternalShareQueue] and retried
/// automatically once connectivity returns.
class ExternalShareCastService {
  ExternalShareCastService._();
  static final ExternalShareCastService instance = ExternalShareCastService._();

  Future<ExternalShareCastSummary> castToFrames({
    required List<String> paths,
    required List<PairedFrame> frames,
    required String authToken,
    required AppStrings strings,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (frames.isEmpty || paths.isEmpty) {
      return const ExternalShareCastSummary(sent: 0, queued: false);
    }

    // Normalize HEIC / Display P3 / alpha into durable sRGB JPEG once, so the
    // offline queue can re-read the same files on retry.
    final items = await _normalizeDurable(paths);
    if (items.isEmpty) {
      return const ExternalShareCastSummary(sent: 0, queued: false);
    }

    var sent = 0;
    var queued = false;

    for (var fi = 0; fi < frames.length; fi++) {
      final frame = frames[fi];
      await DeviceStore.instance.setActiveFrameDeviceId(frame.deviceId);
      final profile = await FrameSettingsStore.instance.load(frame);
      if (!await hasNetworkInterface()) {
        await _enqueueForFrame(
          frame,
          items.map((e) => e.path).toList(growable: false),
          authToken,
          profile,
        );
        queued = true;
        continue;
      }

      final r = await _uploadToFrame(
        frame: frame,
        items: items,
        authToken: authToken,
        strings: strings,
        profile: profile,
        onProgress: (frac, status) {
          onProgress?.call((fi + frac) / frames.length, status);
        },
      );
      sent += r.sent;
      if (r.queued) queued = true;
    }

    return ExternalShareCastSummary(sent: sent, queued: queued);
  }

  Future<List<({String path, Uint8List bytes})>> _normalizeDurable(
    List<String> paths,
  ) async {
    final out = <({String path, Uint8List bytes})>[];
    for (final p in paths) {
      final r = await GalleryImageNormalizer.normalizeFileForUpload(p);
      if (r == null) continue;
      out.add((path: r.path, bytes: r.bytes));
    }
    return out;
  }

  Future<({int sent, bool queued})> _uploadToFrame({
    required PairedFrame frame,
    required List<({String path, Uint8List bytes})> items,
    required String authToken,
    required AppStrings strings,
    required FramePlaybackProfile profile,
    void Function(double progress, String status)? onProgress,
  }) async {
    final api = FrameApiClient();
    final label = _frameLabel(frame, strings);
    final ids = <String>[];
    final pendingPaths = <String>[];
    var sentCount = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      onProgress?.call(
        (i + 0.35) / items.length,
        strings.shareSheetSendingTo(label),
      );

      final cast = await FrameCloudCastService.instance.castPhoto(
        api: api,
        paired: frame,
        jpegBytes: item.bytes,
        filename: 'share_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        slideshowStyle: 'classic',
        displaySeconds: profile.intervalSeconds,
        strings: strings,
        userAuthToken: authToken.trim().isEmpty ? null : authToken.trim(),
        syncSlideshowAfterSuccess: false,
        skipPlay: ids.isNotEmpty,
        editsJson: null,
        onProgress: (p) {
          onProgress?.call(
            (i + (p.progress ?? 0.5)) / items.length,
            p.message,
          );
        },
      );

      if (cast.ok) {
        sentCount++;
        final id = cast.slideshowImageId?.trim();
        if (id != null && id.isNotEmpty && !ids.contains(id)) ids.add(id);
        continue;
      }

      // Offline / frame unreachable → keep the failed + remaining photos for
      // the persistent background queue instead of dropping them.
      for (var j = i; j < items.length; j++) {
        pendingPaths.add(items[j].path);
      }
      AppDiagLog.verbose('[ExternalShare] upload stopped at $i: ${cast.message}');
      break;
    }

    if (ids.isNotEmpty) {
      await _publishExternal(frame, ids, authToken, profile);
      unawaited(
        SlideshowPlaylistStore.instance.save(
          paired: frame,
          imageIds: ids,
          intervalMinutes: profile.intervalMinutes,
        ),
      );
    }

    var queued = false;
    if (pendingPaths.isNotEmpty) {
      await _enqueueForFrame(frame, pendingPaths, authToken, profile);
      queued = true;
    }
    return (sent: sentCount, queued: queued);
  }

  Future<void> _publishExternal(
    PairedFrame frame,
    List<String> imageIds,
    String authToken,
    FramePlaybackProfile profile,
  ) async {
    try {
      await SlideshowRemoteApi(baseUrl: ApiConfig.baseUrl).publish(
        bearerToken: authToken.trim().isEmpty ? null : authToken.trim(),
        pairingToken: frame.resolvedPairingToken,
        macSlug: frameBleMacSlug(frame),
        imageIds: imageIds,
        intervalMinutes: profile.intervalMinutes,
        strategy: profile.strategy,
        durationHours: profile.durationHours,
        skipPlay: true,
      );
    } catch (e) {
      AppDiagLog.verbose('[ExternalShare] slideshow publish failed: $e');
    }
  }

  Future<void> _enqueueForFrame(
    PairedFrame frame,
    List<String> durablePaths,
    String authToken,
    FramePlaybackProfile profile,
  ) async {
    if (durablePaths.isEmpty) return;
    final targets = frame.resolvedFrameUploadTargets;
    if (targets.isEmpty) return;
    await ExternalShareQueue.instance.enqueue(
      QueuedExternalShare(
        id:
            'share_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}',
        paths: durablePaths,
        uploadTargets: targets,
        baseUrl: frame.resolvedApiBaseUrl,
        pairingToken: frame.resolvedPairingToken,
        authToken: authToken,
        macSlug: frameBleMacSlug(frame),
        displaySeconds: profile.intervalSeconds,
        intervalMinutes: profile.intervalMinutes,
        strategy: profile.strategy,
        durationHours: profile.durationHours,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String _frameLabel(PairedFrame f, AppStrings s) {
    final name = f.frameName?.trim() ?? '';
    return name.isNotEmpty ? name : f.listDisplayTitle(s);
  }
}

class ExternalShareCastSummary {
  const ExternalShareCastSummary({required this.sent, required this.queued});

  final int sent;

  /// True when some payloads were persisted for background retry.
  final bool queued;
}
