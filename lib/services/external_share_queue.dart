import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_diag_log.dart';
import '../l10n/app_strings.dart';
import 'frame_api_client.dart';
import 'slideshow_remote_api.dart';
import 'transport_kind.dart';
import 'gallery_image_normalizer.dart';
import 'upload_queue_controller.dart';

/// A persisted batch of photos shared from an external app (gallery / share
/// sheet) that could not be uploaded immediately because the device was
/// offline or the frame unreachable.
class QueuedExternalShare {
  const QueuedExternalShare({
    required this.id,
    this.uploadedIds = const [],
    this.dispatchAttempted = false,
    required this.paths,
    required this.uploadTargets,
    required this.baseUrl,
    required this.pairingToken,
    required this.authToken,
    required this.macSlug,
    required this.displaySeconds,
    required this.intervalMinutes,
    required this.strategy,
    required this.durationHours,
    required this.createdAtMs,
  });

  final String id;
  final List<String> uploadedIds;
  final bool dispatchAttempted;
  final List<String> paths;

  /// Upload targets (Wi-Fi/MQTT station MAC first), mirroring castPhoto.
  final List<String> uploadTargets;
  final String? baseUrl;
  final String? pairingToken;
  final String authToken;
  final String macSlug;

  /// External-sharing defaults: 10 min / sequential / 6 h.
  final int displaySeconds;
  final int intervalMinutes;
  final int strategy;
  final int durationHours;
  final int createdAtMs;

  Map<String, dynamic> toMap() => {
    'id': id,
    'uploadedIds': uploadedIds,
    'dispatchAttempted': dispatchAttempted,
    'paths': paths,
    'uploadTargets': uploadTargets,
    'baseUrl': baseUrl,
    'pairingToken': pairingToken,
    'authToken': authToken,
    'macSlug': macSlug,
    'displaySeconds': displaySeconds,
    'intervalMinutes': intervalMinutes,
    'strategy': strategy,
    'durationHours': durationHours,
    'createdAtMs': createdAtMs,
  };

  factory QueuedExternalShare.fromMap(Map<dynamic, dynamic> map) {
    List<String> strs(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const <String>[];
    final baseUrl = map['baseUrl'];
    final pairing = map['pairingToken'];
    return QueuedExternalShare(
      id: '${map['id'] ?? ''}',
      uploadedIds: strs(map['uploadedIds']),
      dispatchAttempted: map['dispatchAttempted'] == true,
      paths: strs(map['paths']),
      uploadTargets: strs(map['uploadTargets']),
      baseUrl: baseUrl is String && baseUrl.isNotEmpty ? baseUrl : null,
      pairingToken: pairing is String && pairing.isNotEmpty ? pairing : null,
      authToken: '${map['authToken'] ?? ''}',
      macSlug: '${map['macSlug'] ?? ''}',
      displaySeconds: map['displaySeconds'] is num
          ? (map['displaySeconds'] as num).toInt()
          : 600,
      intervalMinutes: map['intervalMinutes'] is num
          ? (map['intervalMinutes'] as num).toInt()
          : 10,
      strategy: map['strategy'] is num ? (map['strategy'] as num).toInt() : 1,
      durationHours: map['durationHours'] is num
          ? (map['durationHours'] as num).toInt()
          : 6,
      createdAtMs: map['createdAtMs'] is num
          ? (map['createdAtMs'] as num).toInt()
          : 0,
    );
  }
}

/// Durable, automatically-retried queue for external-share uploads.
///
/// Payloads are saved when the device is offline or a frame is unreachable,
/// then flushed in the background as soon as connectivity returns.
/// Backed by Hive (persistent local device storage) so nothing is lost across
/// app restarts.
class ExternalShareQueue {
  ExternalShareQueue._();
  static final ExternalShareQueue instance = ExternalShareQueue._();

  static const _boxName = 'external_share_queue_v1';

  Box<dynamic>? _box;
  Future<Box<dynamic>>? _opening;
  bool _initialized = false;
  bool _watcherStarted = false;
  bool _flushing = false;

  /// Initializes the box and (if a network path exists) flushes leftovers.
  /// Safe to call multiple times.
  Future<void> bootstrap() async {
    if (!_initialized) {
      await _ensureBox();
      _initialized = true;
    }
    _startRetryWatcher();
    // Catch anything enqueued while the app was closed.
    unawaited(flush());
  }

  void _startRetryWatcher() {
    if (_watcherStarted) return;
    _watcherStarted = true;
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(flush());
    });
  }

  Future<int> enqueue(QueuedExternalShare entry) async {
    try {
      final box = await _ensureBox();
      if (!box.containsKey(entry.id)) await box.put(entry.id, entry.toMap());
      AppDiagLog.verbose(
        '[ExternalShareQueue] enqueued ${entry.paths.length} photo(s) to '
        '${entry.uploadTargets}',
      );
      return 1;
    } catch (e, st) {
      AppDiagLog.verbose('[ExternalShareQueue] enqueue failed: $e\n$st');
      return 0;
    }
  }

  Future<int> pendingCount() async {
    try {
      final box = await _ensureBox();
      return box.length;
    } catch (_) {
      return 0;
    }
  }

  Future<Box<dynamic>> _ensureBox() async {
    if (_box?.isOpen == true) return _box!;
    return _opening ??= (() async {
      try {
        await Hive.initFlutter();
        _box = await Hive.openBox<dynamic>(_boxName);
        _initialized = true;
        return _box!;
      } finally {
        _opening = null;
      }
    })();
  }

  /// Attempts to upload every queued batch. Returns the number of batches
  /// successfully delivered (and removed from the queue).
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    try {
      final box = await _ensureBox();
      final entries = box.toMap().entries.toList();
      if (entries.isEmpty) return 0;
      var delivered = 0;
      for (final entry in entries) {
        final map = entry.value;
        if (map is! Map) continue;
        final queued = QueuedExternalShare.fromMap(map);
        final ok = await _uploadBatch(queued, (value) async {
          await box.put(entry.key, value);
        });
        if (ok) {
          try {
            await box.delete(entry.key);
            delivered++;
          } catch (_) {}
        }
      }
      if (delivered > 0) {
        AppDiagLog.verbose(
          '[ExternalShareQueue] delivered $delivered batch(es)',
        );
      }
      return delivered;
    } catch (e, st) {
      AppDiagLog.verbose('[ExternalShareQueue] flush error: $e\n$st');
      return 0;
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _uploadBatch(
    QueuedExternalShare queued,
    Future<void> Function(Map<String, dynamic>) save,
  ) async {
    if (queued.dispatchAttempted) {
      // A lost response may follow an accepted POST; do not redispatch.
      return false;
    }
    if (queued.uploadTargets.isEmpty) return false;
    final api = FrameApiClient();
    final ids = [...queued.uploadedIds];
    var delivered = false;
    var attempted = false;

    final progress = UploadQueueController.instance;
    progress.beginShare(
      queued.id,
      AppStrings.current.sharedUploadLabel(queued.paths.length),
    );
    try {
      for (var i = ids.length; i < queued.paths.length; i++) {
        final path = queued.paths[i];
        final file = File(path);
        if (!await file.exists()) {
          return false;
        }
        final normalized = await GalleryImageNormalizer.normalizeFileForUpload(
          path,
        );
        if (normalized == null) return false;
        final bytes = normalized.bytes;

        var ok = false;
        for (final target in queued.uploadTargets) {
          try {
            final res = await api.uploadPhoto(
              fileBytes: bytes,
              filename: 'share_retry_${queued.createdAtMs}_$i.jpg',
              deviceId: target,
              baseUrlOverride: queued.baseUrl,
              slideshowStyle: 'classic',
              displaySeconds: queued.displaySeconds,
              transport: TransportKind.wifi.apiValue,
              pairingToken: queued.pairingToken,
              userAuthToken: queued.authToken.isEmpty ? null : queued.authToken,
              skipPlay: queued.paths.length > 1,
              editsJson: null,
              // Source isolation: multi-photo queued retries preserve the
              // original playlist tag; single-photo retries stay direct_cast.
              source: queued.paths.length > 1
                  ? UploadSource.playlist
                  : UploadSource.directCast,
            );
            final id = res.vpsSlideshowImageId?.trim();
            if (queued.paths.length > 1 && (id == null || id.isEmpty)) {
              return false;
            }
            ids.add(id ?? 'single');
            await save({...queued.toMap(), 'uploadedIds': ids});
            progress.updateShare(
              queued.id,
              ids.length / queued.paths.length,
              AppStrings.current.sharedUploadLabel(queued.paths.length),
            );
            ok = true;
            break;
          } catch (e) {
            AppDiagLog.verbose(
              '[ExternalShareQueue] upload failed to $target: $e',
            );
          }
        }
        if (!ok) return false; // keep the whole batch for the next retry.
      }

      if (queued.paths.length > 1 && ids.length == queued.paths.length) {
        await save({
          ...queued.toMap(),
          'uploadedIds': ids,
          'dispatchAttempted': true,
        });
        attempted = true;
        try {
          final msgid = await SlideshowRemoteApi().publish(
            bearerToken: queued.authToken.isEmpty ? null : queued.authToken,
            pairingToken: queued.pairingToken,
            macSlug: queued.macSlug,
            imageIds: ids,
            intervalMinutes: queued.intervalMinutes,
            strategy: queued.strategy,
            durationHours: queued.durationHours,
            skipPlay: false,
            source: 'playlist',
          );
          if (msgid != null && msgid.isNotEmpty) {
            progress.trackPush(
              mac: queued.macSlug,
              msgid: msgid,
              userAuthToken: queued.authToken,
              pairingToken: queued.pairingToken,
              notifyOnCompletion: false,
            );
          }
        } catch (e) {
          return false;
        }
      }
      delivered = true;
      progress.finishShare(queued.id);
      return true;
    } finally {
      if (!delivered) {
        progress.finishShare(
          queued.id,
          failed: attempted,
          queued: !attempted,
          label: attempted ? null : AppStrings.current.shareSheetQueuedOffline,
        );
      }
      api.close();
    }
  }
}
