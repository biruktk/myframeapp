import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'protocol_logger_service.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import 'device_store.dart';
import 'frame_api_client.dart';
import 'frame_cast_progress.dart';
import 'network_link.dart';
import 'slideshow_playlist_store.dart';
import 'slideshow_remote_api.dart';
import 'transport_kind.dart';
import 'app_diag_log.dart';
import 'frame_ble_mac_slug.dart';

class FrameCloudCastService {
  FrameCloudCastService._();

  static final FrameCloudCastService instance = FrameCloudCastService._();

  String uploadDeviceId(PairedFrame paired) {
    final targets = paired.resolvedFrameUploadTargets;
    if (targets.isNotEmpty) return targets.first;
    return paired.resolvedFrameTargetId;
  }

  List<String> _uploadTargets(PairedFrame paired) {
    final t = paired.resolvedFrameUploadTargets;
    if (t.isNotEmpty) return t;
    final id = uploadDeviceId(paired);
    return id.isEmpty ? const [] : [id];
  }

  Future<FrameCloudCastResult> castPhoto({
    required FrameApiClient api,
    required PairedFrame paired,
    required Uint8List jpegBytes,
    required String filename,
    required String slideshowStyle,
    required AppStrings strings,
    String? userAuthToken,
    void Function(CastProgress progress)? onProgress,
    bool syncSlideshowAfterSuccess = false,
    int? displaySeconds,
    bool skipPlay = false,
    String? editsJson,
    UploadSource source = UploadSource.directCast,
    String? playlistId,
    String? albumId,
  }) async {
    void report(CastProgress p) => onProgress?.call(p);

    final deviceId = uploadDeviceId(paired);
    if (deviceId.trim().isEmpty) {
      report(CastProgress(phase: CastPhase.failed, message: strings.uploadErrorNoFrameId));
      return FrameCloudCastResult.failed(strings.uploadErrorNoFrameId);
    }
    if (!paired.canUploadToServer) {
      final msg = paired.resolvedFrameTargetCandidates.isEmpty
          ? strings.uploadErrorMissingFrameId
          : strings.pairingNeedsApiUrl;
      report(CastProgress(phase: CastPhase.failed, message: msg));
      return FrameCloudCastResult.failed(msg);
    }

    report(CastProgress(
      phase: CastPhase.preparing,
      message: strings.uploadPreparingPhoto,
      progress: 0.05,
      showIndeterminate: true,
    ));

    if (!await hasNetworkInterface()) {
      final msg = strings.sendOfflineNoNetworkForWifi;
      report(CastProgress(phase: CastPhase.failed, message: msg));
      return FrameCloudCastResult.failed(msg);
    }

    report(CastProgress(
      phase: CastPhase.uploading,
      message: 'Uploading photo…',
      progress: 0.3,
      showIndeterminate: true,
    ));

    final targets = _uploadTargets(paired);
    PhotoUploadResponse? lastRes;

    for (var ti = 0; ti < targets.length; ti++) {
      final tryId = targets[ti];

      try {

        ProtocolLoggerService.instance.logMqttOut(
          skipPlay ? 'upload_photo (skip_play)' : 'play',
          {'deviceId': tryId, 'filename': filename},
        );
final res = await api.uploadPhoto(
          fileBytes: jpegBytes,
          filename: filename,
          deviceId: tryId,
          baseUrlOverride: paired.resolvedApiBaseUrl!,
          slideshowStyle: slideshowStyle,
          displaySeconds: displaySeconds,
          transport: TransportKind.wifi.apiValue,
          pairingToken: paired.resolvedPairingToken,
          userAuthToken: userAuthToken,
          skipPlay: skipPlay,
          source: source,
          playlistId: playlistId,
          albumId: albumId,
          displayName: filename,
        );
        lastRes = res;

        // Strict 1037346b backend: no task_id in the upload response, no
        // background polling — the device fetches the manifest + .bin files
        // autonomously per the strategy interval.
        report(CastProgress(
          phase: CastPhase.success,
          message: 'Photo uploaded — frame will update shortly.',
          progress: 1,
        ));

        if (syncSlideshowAfterSuccess) {
          unawaited(_syncSlideshowAfterSingleCast(
            paired: paired,
            res: res,
            userAuthToken: userAuthToken,
          ));
        }

        return FrameCloudCastResult.success(
          'Photo uploaded — frame will update shortly.',
          slideshowImageId: res.vpsSlideshowImageId,
        );
      } on SocketException catch (e) {
        if (ti == targets.length - 1) {
          final msg = _socketMessage(strings, paired, e);
          report(CastProgress(phase: CastPhase.failed, message: msg));
          return FrameCloudCastResult.failed(msg);
        }
      }
    }

    return FrameCloudCastResult.failed(
      lastRes != null ? 'Upload completed but confirmation pending.' : 'Upload failed.',
    );
  }

  String _socketMessage(AppStrings strings, PairedFrame paired, SocketException e) {
    final msgLower = e.message.toLowerCase();
    if (msgLower.contains('failed host lookup') ||
        msgLower.contains('no address associated with hostname')) {
      final hostHint = paired.apiUrl != null
          ? Uri.tryParse(paired.apiUrl!)?.host ?? ''
          : '';
      if (hostHint.isNotEmpty) {
        return 'Cannot reach $hostHint — check internet connection.';
      }
    }
    return strings.sendOfflineNoNetworkForWifi;
  }

  Future<void> _syncSlideshowAfterSingleCast({
    required PairedFrame paired,
    required PhotoUploadResponse res,
    String? userAuthToken,
  }) async {
    final token = userAuthToken?.trim() ?? '';
    final imageId = res.vpsSlideshowImageId;
    if (token.isEmpty || imageId == null) return;
    try {
      final macSlug = frameBleMacSlug(paired);
      await SlideshowRemoteApi(baseUrl: ApiConfig.baseUrl).publish(
        bearerToken: token,
        macSlug: macSlug,
        imageIds: [imageId],
        intervalMinutes: 1440,
      );
      await SlideshowPlaylistStore.instance.save(
        paired: paired,
        imageIds: [imageId],
        intervalMinutes: 1440,
      );
    } catch (e) {
      AppDiagLog.verbose('[Cast] sync single-image slideshow: $e');
    }
  }
}

class FrameCloudCastResult {
  const FrameCloudCastResult._({
    required this.ok,
    required this.message,
    this.slideshowImageId,
  });

  factory FrameCloudCastResult.success(
    String message, {
    String? slideshowImageId,
  }) =>
      FrameCloudCastResult._(
        ok: true,
        message: message,
        slideshowImageId: slideshowImageId,
      );

  factory FrameCloudCastResult.failed(String message) =>
      FrameCloudCastResult._(ok: false, message: message);

  final bool ok;
  final String message;
  final String? slideshowImageId;
}
