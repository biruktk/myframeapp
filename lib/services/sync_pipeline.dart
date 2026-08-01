import 'dart:async';

import '../settings/app_settings.dart';
import 'account_sync_service.dart';
import 'album_cloud_sync.dart';
import 'app_diag_log.dart';
import 'device_store.dart';
import 'user_gallery_cloud_service.dart';

/// Smart sync pipeline for account frames + personal gallery + albums.
///
/// Design (devices ≠ settings):
/// - **Frames** are hardware: list comes from server bind/unbind; status
///   (online/battery/storage) is fetched live per MAC — never invent it.
/// - **Gallery** is account media: upload on cast/add, download on pull/tick.
/// - **Albums/playlists** are account folders of gallery media IDs.
/// - **Settings** stay LWW via [AccountSyncService] (language/theme).
///
/// Triggers:
/// 1. Periodic tick every 10s while signed in (foreground)
/// 2. Immediate: cast, gallery add/delete, album create/edit, frame changes
/// 3. Pull-to-refresh / app resume
class SyncPipeline {
  SyncPipeline._();
  static final instance = SyncPipeline._();

  static const tickInterval = Duration(seconds: 10);
  static const _pullTimeout = Duration(seconds: 35);

  Timer? _tick;
  AppSettings? _app;
  var _running = false;
  var _rerunPull = false;
  DateTime? _lastFullAt;
  DateTime? _lastGalleryAt;
  DateTime? _lastFramesAt;
  DateTime? _lastAlbumsAt;

  void start({required AppSettings appSettings}) {
    _app = appSettings;
    _tick?.cancel();
    if (!appSettings.hasAuthenticatedSession) {
      stop();
      return;
    }
    _tick = Timer.periodic(tickInterval, (_) {
      unawaited(tick());
    });
    unawaited(tick(forceFrames: true, forceGallery: true, forceAlbums: true));
  }

  void stop() {
    _tick?.cancel();
    _tick = null;
  }

  AppSettings? get _settings => _app;

  String? get _token {
    final t = _settings?.authToken.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Future<void> tick({
    bool forceFrames = false,
    bool forceGallery = false,
    bool forceAlbums = false,
  }) async {
    final token = _token;
    if (token == null) return;
    if (_running) return;
    _running = true;
    try {
      final now = DateTime.now();
      final framesDue = forceFrames ||
          _lastFramesAt == null ||
          now.difference(_lastFramesAt!) >= tickInterval;
      final galleryDue = forceGallery ||
          _lastGalleryAt == null ||
          now.difference(_lastGalleryAt!) >= tickInterval;
      final albumsDue = forceAlbums ||
          _lastAlbumsAt == null ||
          now.difference(_lastAlbumsAt!) >= tickInterval;

      if (framesDue) {
        // Soft sync on tick — never replaceFrames every 10s (re-imported ghosts).
        await AccountSyncService.instance
            .syncAccountState(
              force: false,
              replaceFrames: false,
              appSettings: _settings,
              authTokenOverride: token,
            )
            .timeout(const Duration(seconds: 15));
        await DeviceStore.instance.dedupeRelatedFrames();
        _lastFramesAt = now;
      }

      if (galleryDue) {
        // Download-first on tick so other-device uploads appear quickly.
        await UserGalleryCloudService.instance.syncFromServer(
          token,
          uploadLocalFirst: true,
          deviceId: DeviceStore.instance.cached?.deviceId,
        );
        _lastGalleryAt = now;
      }

      if (albumsDue) {
        await AlbumCloudSync.instance
            .syncAll(token)
            .timeout(const Duration(seconds: 25));
        _lastAlbumsAt = now;
      }
      _lastFullAt = now;
    } catch (e, st) {
      AppDiagLog.verbose('[SyncPipeline] tick failed: $e\n$st');
    } finally {
      _running = false;
      if (_rerunPull) {
        _rerunPull = false;
        unawaited(pullToRefresh());
      }
    }
  }

  Future<void> pullToRefresh() async {
    final token = _token;
    if (token == null) return;
    if (_running) {
      _rerunPull = true;
      return;
    }
    _running = true;
    try {
      // Frames + gallery first (parallel), then albums (needs gallery id→path map).
      await Future.wait<void>([
        AccountSyncService.instance
            .pullToRefresh(appSettings: _settings)
            .timeout(const Duration(seconds: 15)),
        UserGalleryCloudService.instance
            .syncFromServer(
              token,
              uploadLocalFirst: false,
              deviceId: DeviceStore.instance.cached?.deviceId,
            )
            .timeout(const Duration(seconds: 30)),
      ]).timeout(_pullTimeout);
      await AlbumCloudSync.instance
          .syncAll(token, pushLocal: false)
          .timeout(const Duration(seconds: 20));
      await DeviceStore.instance.dedupeRelatedFrames();
      // Background: push any local-only photos/albums after UI refresh.
      unawaited(
        UserGalleryCloudService.instance.syncFromServer(
          token,
          uploadLocalFirst: true,
          deviceId: DeviceStore.instance.cached?.deviceId,
        ),
      );
      unawaited(AlbumCloudSync.instance.syncAll(token, pushLocal: true));
      final now = DateTime.now();
      _lastFramesAt = now;
      _lastGalleryAt = now;
      _lastAlbumsAt = now;
      _lastFullAt = now;
    } catch (e, st) {
      AppDiagLog.verbose('[SyncPipeline] pullToRefresh failed: $e\n$st');
    } finally {
      _running = false;
      if (_rerunPull) {
        _rerunPull = false;
        unawaited(pullToRefresh());
      }
    }
  }

  Future<void> onPhotoCasted({
    required String localPath,
    String? deviceId,
  }) async {
    final token = _token;
    if (token == null) return;
    await UserGalleryCloudService.instance.uploadFile(
      authToken: token,
      localPath: localPath,
      deviceId: deviceId,
    );
    // Don't wait on a full sync here — upload is enough for the other phone.
    unawaited(
      UserGalleryCloudService.instance.syncFromServer(
        token,
        uploadLocalFirst: false,
        deviceId: deviceId,
      ),
    );
    _lastGalleryAt = DateTime.now();
  }

  Future<void> onGalleryLocalChanged() async {
    final token = _token;
    if (token == null) return;
    await UserGalleryCloudService.instance.syncFromServer(
      token,
      uploadLocalFirst: true,
    );
    _lastGalleryAt = DateTime.now();
  }

  /// After album/playlist create, rename, add photos, or delete.
  Future<void> onAlbumsChanged({String? albumId}) async {
    final token = _token;
    if (token == null) return;
    try {
      if (albumId != null && albumId.trim().isNotEmpty) {
        await AlbumCloudSync.instance
            .pushAlbum(albumId.trim(), token)
            .timeout(const Duration(seconds: 30));
      } else {
        await AlbumCloudSync.instance
            .syncAll(token)
            .timeout(const Duration(seconds: 30));
      }
    } catch (e, st) {
      AppDiagLog.verbose('[SyncPipeline] onAlbumsChanged failed: $e\n$st');
    }
    _lastAlbumsAt = DateTime.now();
  }

  Future<void> onFramesChanged({bool replace = true}) async {
    final token = _token;
    if (token == null) return;
    await AccountSyncService.instance.syncAccountState(
      force: true,
      replaceFrames: replace,
      appSettings: _settings,
      authTokenOverride: token,
    );
    await DeviceStore.instance.dedupeRelatedFrames();
    _lastFramesAt = DateTime.now();
  }

  DateTime? get lastFullSyncAt => _lastFullAt;
}
