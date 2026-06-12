import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import 'ble_frame_device_transport.dart';
import 'device_store.dart';
import 'frame_api_client.dart';
import 'frame_ble_mac_slug.dart';
import 'frame_cast_progress.dart';
import 'frame_recovery_service.dart';
import 'network_link.dart';
import 'slideshow_playlist_store.dart';
import 'slideshow_remote_api.dart';
import 'transport_kind.dart';
import 'app_diag_log.dart';

/// VPS upload + wait until the frame actually confirms display (production flow).
class FrameCloudCastService {
  FrameCloudCastService._();

  static final FrameCloudCastService instance = FrameCloudCastService._();

  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _primaryWait = Duration(seconds: 60);
  static const Duration _extendedWait = Duration(seconds: 45);

  /// Wi‑Fi/MQTT station MAC for uploads (not BLE +2).
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

  /// After BluFi, wait until the frame is on MQTT so the first cast is faster.
  Future<bool> waitUntilFrameReady({
    required PairedFrame paired,
    Duration timeout = const Duration(seconds: 45),
    void Function(String message)? onStatus,
  }) async {
    final api = FrameApiClient();
    final deviceId = uploadDeviceId(paired);
    if (deviceId.isEmpty) return false;

    final deadline = DateTime.now().add(timeout);
    onStatus?.call('Waiting for frame to come online…');
    while (DateTime.now().isBefore(deadline)) {
      try {
        await FrameRecoveryService.instance.sendLoginAck(paired);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 800));
      try {
        final st = await _frameStatus(api, paired, deviceId);
        if (st.isFrameMqttReady()) {
          onStatus?.call('Frame connected to MQTT — ready to send photos.');
          return true;
        }
        if (st.online == true) {
          onStatus?.call('Frame is online — waking MQTT…');
        }
        onStatus?.call('Connecting frame to server…');
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
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
    /// When false (playlist batch), caller publishes slideshow after all casts complete.
    bool syncSlideshowAfterSuccess = false,
    int? displaySeconds,
  }) async {
    void report(CastProgress p) => onProgress?.call(p);

    final deviceId = uploadDeviceId(paired);
    if (deviceId.trim().isEmpty) {
      report(
        const CastProgress(
          phase: CastPhase.failed,
          message:
              'No frame display ID saved. Scan the pairing QR on the frame once, then try again.',
        ),
      );
      return FrameCloudCastResult.failed(
        'No frame display ID saved. Scan the pairing QR on the frame once, then try again.',
      );
    }
    if (!paired.canUploadToServer) {
      final msg = paired.resolvedFrameTargetCandidates.isEmpty
          ? 'Pairing is missing the frame display ID. Scan the frame QR once, then try again.'
          : strings.pairingNeedsApiUrl;
      report(CastProgress(phase: CastPhase.failed, message: msg));
      return FrameCloudCastResult.failed(msg);
    }

    report(
      const CastProgress(
        phase: CastPhase.preparing,
        message: 'Preparing photo…',
        progress: 0.05,
        showIndeterminate: true,
      ),
    );

    if (!await hasNetworkInterface()) {
      final msg = strings.sendOfflineNoNetworkForWifi;
      report(CastProgress(phase: CastPhase.failed, message: msg));
      return FrameCloudCastResult.failed(msg);
    }

    report(
      const CastProgress(
        phase: CastPhase.connectingFrame,
        message: 'Connecting to your frame…',
        progress: 0.12,
        showIndeterminate: true,
      ),
    );
    await BleFrameDeviceTransport.instance.releaseSession();

    report(
      const CastProgress(
        phase: CastPhase.wakingFrame,
        message: 'Waking frame MQTT session…',
        progress: 0.15,
        showIndeterminate: true,
      ),
    );
    try {
      await FrameRecoveryService.instance.prepareForCloudUpload(paired);
    } catch (e) {
      AppDiagLog.verbose('[Cast] prepareForCloudUpload: $e');
    }

    try {
      if (paired.bleRemoteId?.trim().isNotEmpty == true) {
        final preflight = await _frameStatus(api, paired, deviceId);
        if (preflight.mqttConnected != true) {
          report(
            const CastProgress(
              phase: CastPhase.connectingFrame,
              message:
                  'Frame not on MQTT yet — refreshing Wi‑Fi and server settings over Bluetooth…',
              progress: 0.18,
              showIndeterminate: true,
            ),
          );
          try {
            await FrameRecoveryService.instance.reconfigureServer(paired);
          } catch (e) {
            AppDiagLog.verbose('[Cast] preflight reconfigure: $e');
          }
          await waitUntilFrameReady(
            paired: paired,
            timeout: const Duration(seconds: 45),
            onStatus: (line) => report(
              CastProgress(
                phase: CastPhase.connectingFrame,
                message: line,
                progress: 0.2,
                showIndeterminate: true,
              ),
            ),
          );
        }
        await _sendLoginAckBrief(paired);
      }
    } catch (e) {
      AppDiagLog.verbose('[Cast] preflight status: $e');
    }

    AppDiagLog.verbose(
      '[Cast] upload file len=${jpegBytes.length} name=$filename',
    );

    final targets = _uploadTargets(paired);
    PhotoUploadResponse? lastRes;
    var lastDeviceId = deviceId;

    for (var ti = 0; ti < targets.length; ti++) {
      final tryId = targets[ti];
      lastDeviceId = tryId;

      int? baselineMs;
      var frameOnline = false;
      try {
        final st = await _frameStatus(api, paired, tryId);
        baselineMs = st.lastUploadMs;
        frameOnline = st.mqttConnected == true || st.online == true;
      } catch (e) {
        AppDiagLog.verbose('[Cast] pre-upload status ($tryId): $e');
      }

      if (!frameOnline) {
        report(
          const CastProgress(
            phase: CastPhase.wakingFrame,
            message: 'Waking frame connection…',
            progress: 0.18,
            showIndeterminate: true,
          ),
        );
        await _sendLoginAckBrief(paired);
        try {
          final st = await _frameStatus(api, paired, tryId);
          frameOnline = st.mqttConnected == true || st.online == true;
        } catch (_) {}
      }

      report(
        CastProgress(
          phase: CastPhase.uploading,
          message: targets.length > 1 && ti > 0
              ? 'Retrying upload (alternate frame ID)…'
              : frameOnline
                  ? 'Uploading photo (frame is online)…'
                  : 'Uploading photo to server…',
          progress: 0.32,
          showIndeterminate: true,
        ),
      );

      try {
        final uploadStartedMs = DateTime.now().millisecondsSinceEpoch;
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
        );
        lastRes = res;

        AppDiagLog.verbose(
          '[Cast] device_id=$tryId delivered=${res.deliveredToFrame} '
          'mode=${res.deliveryMode}',
        );

        final outcome = await _waitUntilFrameShows(
          api: api,
          paired: paired,
          deviceId: tryId,
          res: res,
          strings: strings,
          uploadStartedMs: uploadStartedMs,
          baselineLastUploadMs: baselineMs,
          report: report,
          primaryWait: _primaryWait,
          extendedWait: frameOnline ? _extendedWait : Duration.zero,
        );

        if (outcome != null) {
          final hash = _shortHash(res);
          final successMsg = strings.uploadSuccessLine(
            res.receivedBytes ?? 0,
            hash,
          );
          final userMsg = AppDiagLog.isDebugEnabled
              ? '$successMsg${_verboseExtras(strings, res)}'
              : 'Photo sent — updating frame (e‑ink may take up to a minute).';
          report(
            CastProgress(
              phase: CastPhase.success,
              message: userMsg,
              progress: 1,
            ),
          );
          if (syncSlideshowAfterSuccess) {
            unawaited(
              _syncSlideshowAfterSingleCast(
                paired: paired,
                res: res,
                userAuthToken: userAuthToken,
              ),
            );
          }
          return FrameCloudCastResult.success(
            userMsg,
            slideshowImageId: res.vpsSlideshowImageId,
          );
        }
      } on SocketException catch (e) {
        if (ti == targets.length - 1) {
          final msg = _socketMessage(strings, paired, e);
          report(CastProgress(phase: CastPhase.failed, message: msg));
          return FrameCloudCastResult.failed(msg);
        }
      }
    }

    final res = lastRes;
    if (res == null) {
      return FrameCloudCastResult.failed(
        'Upload failed — could not reach the server.',
      );
    }

    final mqttUnconfirmed = (res.deliveryMode == 'mqtt_published_unconfirmed' ||
            res.deliveredToFrame != true) &&
        res.deliveryMode != 'mqtt_published';
    if (mqttUnconfirmed && paired.bleRemoteId?.trim().isNotEmpty == true) {
      report(
        const CastProgress(
          phase: CastPhase.retrying,
          message:
              'Frame did not confirm MQTT — re-sending server config over Bluetooth…',
          progress: 0.42,
          showIndeterminate: true,
        ),
      );
      try {
        await FrameRecoveryService.instance.reconfigureServer(paired);
      } catch (e) {
        AppDiagLog.verbose('[Cast] BLE reconfigure (unconfirmed): $e');
      }
      await _sendLoginAckBrief(paired);
      try {
        final retryMs = DateTime.now().millisecondsSinceEpoch;
        int? retryBaseline;
        try {
          retryBaseline =
              (await _frameStatus(api, paired, lastDeviceId)).lastUploadMs;
        } catch (_) {}
        final res3 = await api.uploadPhoto(
          fileBytes: jpegBytes,
          filename: filename,
          deviceId: lastDeviceId,
          baseUrlOverride: paired.resolvedApiBaseUrl!,
          slideshowStyle: slideshowStyle,
          displaySeconds: displaySeconds,
          transport: TransportKind.wifi.apiValue,
          pairingToken: paired.resolvedPairingToken,
          userAuthToken: userAuthToken,
        );
        final outcome3 = await _waitUntilFrameShows(
          api: api,
          paired: paired,
          deviceId: lastDeviceId,
          res: res3,
          strings: strings,
          uploadStartedMs: retryMs,
          baselineLastUploadMs: retryBaseline,
          report: report,
          primaryWait: _primaryWait,
          extendedWait: _extendedWait,
        );
        if (outcome3 != null) {
          final userMsg = AppDiagLog.isDebugEnabled
              ? '${strings.uploadSuccessLine(res3.receivedBytes ?? 0, _shortHash(res3))}${_verboseExtras(strings, res3)}'
              : 'Photo sent — updating frame (e‑ink may take up to a minute).';
          report(
            CastProgress(phase: CastPhase.success, message: userMsg, progress: 1),
          );
          if (syncSlideshowAfterSuccess) {
            unawaited(
              _syncSlideshowAfterSingleCast(
                paired: paired,
                res: res3,
                userAuthToken: userAuthToken,
              ),
            );
          }
          return FrameCloudCastResult.success(
            userMsg,
            slideshowImageId: res3.vpsSlideshowImageId,
          );
        }
        lastRes = res3;
      } catch (e) {
        AppDiagLog.verbose('[Cast] retry after reconfigure: $e');
      }
    }

    try {
      var mqttUp = false;
      try {
        final st = await _frameStatus(api, paired, lastDeviceId);
        mqttUp = st.mqttConnected == true || st.online == true;
      } catch (_) {}

      if (!mqttUp &&
          Platform.isIOS &&
          paired.bleRemoteId?.trim().isNotEmpty == true) {
        report(
          const CastProgress(
            phase: CastPhase.retrying,
            message:
                'Frame offline on MQTT. Sending Wi‑Fi settings over Bluetooth — stay near the frame…',
            progress: 0.4,
            showIndeterminate: true,
          ),
        );
        try {
          await FrameRecoveryService.instance.reconfigureServer(paired);
        } catch (e) {
          AppDiagLog.verbose('[Cast] BLE reconfigure: $e');
        }
        await _sendLoginAckBrief(paired);

        report(
          const CastProgress(
            phase: CastPhase.uploading,
            message: 'Sending photo again…',
            progress: 0.5,
            showIndeterminate: true,
          ),
        );
        int? retryBaseline;
        try {
          retryBaseline = (await _frameStatus(api, paired, lastDeviceId)).lastUploadMs;
        } catch (_) {}
        final retryMs = DateTime.now().millisecondsSinceEpoch;
        final res2 = await api.uploadPhoto(
          fileBytes: jpegBytes,
          filename: filename,
          deviceId: lastDeviceId,
          baseUrlOverride: paired.resolvedApiBaseUrl!,
          slideshowStyle: slideshowStyle,
          displaySeconds: displaySeconds,
          transport: TransportKind.wifi.apiValue,
          pairingToken: paired.resolvedPairingToken,
          userAuthToken: userAuthToken,
        );
        final outcome2 = await _waitUntilFrameShows(
          api: api,
          paired: paired,
          deviceId: lastDeviceId,
          res: res2,
          strings: strings,
          uploadStartedMs: retryMs,
          baselineLastUploadMs: retryBaseline,
          report: report,
          primaryWait: _primaryWait,
          extendedWait: _extendedWait,
        );
        if (outcome2 != null) {
          final userMsg = AppDiagLog.isDebugEnabled
              ? '${strings.uploadSuccessLine(res2.receivedBytes ?? 0, _shortHash(res2))}${_verboseExtras(strings, res2)}'
              : 'Photo sent — updating frame (e‑ink may take up to a minute).';
          report(
            CastProgress(phase: CastPhase.success, message: userMsg, progress: 1),
          );
          if (syncSlideshowAfterSuccess) {
            unawaited(
              _syncSlideshowAfterSingleCast(
                paired: paired,
                res: res2,
                userAuthToken: userAuthToken,
              ),
            );
          }
          return FrameCloudCastResult.success(
            userMsg,
            slideshowImageId: res2.vpsSlideshowImageId,
          );
        }
        lastRes = res2;
      }

      final failMsg = await _buildFailureMessage(
        api,
        paired,
        lastDeviceId,
        lastRes ?? res,
        strings,
      );
      report(CastProgress(phase: CastPhase.failed, message: failMsg));
      return FrameCloudCastResult.failed(failMsg);
    } on SocketException catch (e) {
      final msg = _socketMessage(strings, paired, e);
      report(CastProgress(phase: CastPhase.failed, message: msg));
      return FrameCloudCastResult.failed(msg);
    }
  }

  Future<void> _sendLoginAckBrief(PairedFrame paired) async {
    try {
      await FrameRecoveryService.instance.sendLoginAck(paired);
    } catch (e) {
      AppDiagLog.verbose('[Cast] login_ack: $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<FrameCastStatusResponse> _frameStatus(
    FrameApiClient api,
    PairedFrame paired,
    String deviceId,
  ) {
    return api.getFrameCastStatus(
      mac: deviceId,
      baseUrlOverride: paired.resolvedApiBaseUrl,
    );
  }

  /// Returns non-null when the frame confirmed this upload.
  Future<Object?> _waitUntilFrameShows({
    required FrameApiClient api,
    required PairedFrame paired,
    required String deviceId,
    required PhotoUploadResponse res,
    required AppStrings strings,
    required int uploadStartedMs,
    required int? baselineLastUploadMs,
    required void Function(CastProgress report) report,
    required Duration primaryWait,
    required Duration extendedWait,
  }) async {
    final checksum = res.checksumSha256;

    if (res.deliveryMode == 'frame_push_failed' ||
        res.deliveryMode == 'mqtt_publish_failed' ||
        res.deliveryMode == 'mqtt_disconnected') {
      return null;
    }

    final mqttUnconfirmed = (res.deliveryMode == 'mqtt_published_unconfirmed' ||
            res.deliveredToFrame != true) &&
        res.deliveryMode != 'mqtt_published';

    if (res.deliveredToFrame == true) {
      final ok = await _confirmOnFrame(
        api,
        paired,
        deviceId,
        uploadStartedMs,
        baselineLastUploadMs,
      );
      if (ok) return Object();
    }

    if (checksum == null || checksum.isEmpty) {
      return null;
    }

    var extraWait = extendedWait;
    final started = DateTime.now();
    var lastLoginAck = DateTime.now();
    var extendedStarted = false;

    while (true) {
      if (mqttUnconfirmed &&
          DateTime.now().difference(lastLoginAck) >= const Duration(seconds: 10)) {
        lastLoginAck = DateTime.now();
        await _sendLoginAckBrief(paired);
      }
      final elapsed = DateTime.now().difference(started);
      if (extraWait == Duration.zero &&
          elapsed >= primaryWait &&
          !extendedStarted) {
        try {
          final st = await _frameStatus(api, paired, deviceId);
          if (st.mqttConnected == true) {
            extraWait = _extendedWait;
          }
        } catch (_) {}
      }
      if (elapsed >= primaryWait + extraWait) break;

      if (!extendedStarted && elapsed >= primaryWait && extraWait > Duration.zero) {
        extendedStarted = true;
        report(
          CastProgress(
            phase: CastPhase.waitingOnFrame,
            message:
                'Still updating the frame (e‑ink can take up to a minute)…',
            progress: 0.55,
            waitSeconds: elapsed.inSeconds,
            showIndeterminate: true,
          ),
        );
      }

      final waitSec = elapsed.inSeconds;
      final maxSec = (primaryWait + extraWait).inSeconds;
      final progress = 0.4 + (0.55 * (waitSec / maxSec)).clamp(0.0, 0.95);

      report(
        CastProgress(
          phase: CastPhase.waitingOnFrame,
          message: _waitMessage(waitSec, extendedStarted),
          progress: progress,
          waitSeconds: waitSec,
        ),
      );

      if (!mqttUnconfirmed &&
          DateTime.now().difference(lastLoginAck) >= const Duration(seconds: 18)) {
        lastLoginAck = DateTime.now();
        await _sendLoginAckBrief(paired);
      }

      final delivery = await api.getDeliveryStatus(
        checksumSha256: checksum,
        deviceId: deviceId,
        baseUrlOverride: paired.resolvedApiBaseUrl,
        pairingToken: paired.resolvedPairingToken,
      );
      if (delivery.deliveredToFrame) {
        if (await _confirmOnFrame(
          api,
          paired,
          deviceId,
          uploadStartedMs,
          baselineLastUploadMs,
        )) {
          return Object();
        }
      }
      if (delivery.deliveryMode == 'frame_push_failed' ||
          delivery.deliveryMode == 'mqtt_publish_failed' ||
          delivery.deliveryMode == 'mqtt_disconnected') {
        return null;
      }

      if (await _confirmOnFrame(
        api,
        paired,
        deviceId,
        uploadStartedMs,
        baselineLastUploadMs,
      )) {
        return Object();
      }

      await Future<void>.delayed(_pollInterval);
    }

    if (await _confirmOnFrame(
      api,
      paired,
      deviceId,
      uploadStartedMs,
      baselineLastUploadMs,
    )) {
      return Object();
    }

    return null;
  }

  Future<bool> _confirmOnFrame(
    FrameApiClient api,
    PairedFrame paired,
    String deviceId,
    int uploadStartedMs,
    int? baselineLastUploadMs,
  ) async {
    try {
      final cast = await _frameStatus(api, paired, deviceId);
      return cast.confirmsCastSince(
        uploadStartedMs,
        baselineLastUploadMs: baselineLastUploadMs,
      );
    } catch (_) {
      return false;
    }
  }

  static String _waitMessage(int seconds, bool extended) {
    if (seconds < 8) {
      return 'Photo sent · waiting for frame to display…';
    }
    if (seconds < 25) {
      return 'Frame is receiving your photo… (${seconds}s)';
    }
    if (!extended) {
      return 'Updating frame display… (${seconds}s)';
    }
    return 'E‑ink is still refreshing — please wait… (${seconds}s)';
  }

  static String _shortHash(PhotoUploadResponse res) {
    final full = res.checksumSha256;
    if (full != null && full.length >= 8) return full.substring(0, 8);
    return '…';
  }

  static String _verboseExtras(AppStrings s, PhotoUploadResponse r) {
    final parts = <String>[];
    final playUrl = () {
      final u = r.imageUrl?.trim();
      if (u != null && u.isNotEmpty) return u;
      final b = r.framePlayBasename?.trim();
      if (b != null && b.isNotEmpty) return '/frame-media/$b';
      return null;
    }();
    if (playUrl != null) {
      final looksBin =
          r.myfmSidecar == true ||
          playUrl.toLowerCase().endsWith('.bin') ||
          (r.framePlayBasename?.toLowerCase().endsWith('.bin') ?? false);
      parts.add(
        looksBin ? s.uploadFrameMyfmBinUrl(playUrl) : s.uploadFrameMqttJpegUrl(playUrl),
      );
    }
    final preview = r.previewStoredPath?.trim();
    if (preview != null && preview.isNotEmpty) {
      parts.add(s.uploadServerJpegBackupOnly(preview));
    }
    return parts.isEmpty ? '' : '\n${parts.join('\n')}';
  }

  Future<String> _buildFailureMessage(
    FrameApiClient api,
    PairedFrame paired,
    String deviceId,
    PhotoUploadResponse res,
    AppStrings strings,
  ) async {
    final extras = AppDiagLog.isDebugEnabled ? _verboseExtras(strings, res) : '';
    try {
      final st = await _frameStatus(api, paired, deviceId);
      if (st.mqttConnected != true) {
        return 'Photo is on the server, but the frame is not connected to MQTT yet. '
            'Stay near the frame → Settings → Reconfigure Server (sends mqtt_config again), '
            'wait 30s, then retry. Pairing must finish Wi‑Fi setup first.$extras';
      }
      if (st.lastAction?.toLowerCase() == 'play' && st.lastUploadMs != null) {
        return 'Photo was sent to the frame. E‑ink can take up to a minute to refresh — '
            'if nothing appears, tap Reconfigure in Settings while near the frame.$extras';
      }
      if (res.deliveryMode == 'mqtt_published_unconfirmed' ||
          (res.deliveredToFrame != true &&
              res.deliveryMode != 'mqtt_published')) {
        return 'Photo reached the server, but MQTT play was not confirmed. '
            'Stay near the frame, open Settings → Reconfigure Server, then try again.$extras';
      }
      return 'Photo reached the server, but the frame did not confirm display in time. '
          'E‑ink can take up to a minute — if nothing appears, reconfigure the frame server and retry.$extras';
    } catch (_) {
      return 'Photo reached the server, but the frame did not confirm in time. '
          'Check that the frame is on Wi‑Fi, then try again.$extras';
    }
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

  /// Single-photo sends reset a broken multi-image slideshow on the VPS (checksum lookup).
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

  /// Upload checksum for VPS slideshow / playlist (`resolvePlaybackUrl` on server).
  final String? slideshowImageId;
}
