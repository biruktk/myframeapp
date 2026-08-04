import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_settings/app_settings.dart' as app_os;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/platform_share.dart';

import '../config/feature_flags.dart';
import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';
import 'image_editor_screen.dart';
import 'playlist_screen.dart';
import '../services/ai_image_generate_service.dart';
import '../widgets/ai_content_notice.dart';
import '../widgets/text_input_bottom_sheet.dart';
import '../services/ble_frame_device_transport.dart';
import '../services/device_store.dart';
import '../services/frame_ble_mac_slug.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/frame_forget_service.dart';
import '../services/frame_guest_invite_service.dart';
import '../services/share_service.dart';
import '../services/frame_recovery_service.dart';
import '../services/gallery_image_cache.dart';
import '../services/gallery_image_normalizer.dart';
import '../services/gallery_photo_picker.dart';
import '../services/personal_gallery_store.dart';
import '../services/playlist_send_nav.dart';
import '../services/send_albums_store.dart';
import '../services/sync_pipeline.dart';
import '../services/device_transport.dart';
import '../services/permission_gate.dart';
import '../widgets/send_album_settings_sheet.dart';
import '../widgets/shell_navigation.dart';
import '../widgets/frame_picker_sheet.dart';
import '../models/pairing_nav_result.dart';
import '../navigation/pairing_flow_nav.dart';
import '../models/send_overlay_options.dart';
import '../services/app_diag_log.dart';
import '../services/frame_online_guard.dart';
import 'device_discovery_screen.dart';
import 'settings_ai_generate_screen.dart';

enum _SendSource { gallery, camera, sharelink, ai }

class SendScreen extends StatefulWidget {
  const SendScreen({super.key, this.galleryPickNonce, this.sharedPathsNonce});

  /// Incremented from [MainShellState.openSendGalleryPicker] to open the gallery + album sheet flow.
  final ValueNotifier<int>? galleryPickNonce;

  /// Set from [MainShellState.openSendWithSharedPaths] when user shares into MyFrame.
  final ValueNotifier<List<String>>? sharedPathsNonce;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> with WidgetsBindingObserver {
  int _lastGalleryNonce = 0;
  List<String> _lastSharedPaths = const [];
  bool _sendFlowBusy = false;
  bool _pickerOpen = false;

  /// `true` when the active frame is online; `false` when offline; `null` when unknown / no frame.
  bool? _frameOnline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.galleryPickNonce?.addListener(_onGalleryNonce);
    widget.sharedPathsNonce?.addListener(_onSharedPathsNonce);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshFrameOnlineStatus());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshFrameOnlineStatus());
    }
  }

  Future<void> _refreshFrameOnlineStatus() async {
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    if (paired == null) {
      if (mounted) setState(() => _frameOnline = null);
      return;
    }
    final online = await FrameOnlineGuard.isFrameEffectivelyOnline(paired);
    if (mounted) setState(() => _frameOnline = online);
  }

  @override
  void didUpdateWidget(covariant SendScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.galleryPickNonce != widget.galleryPickNonce) {
      oldWidget.galleryPickNonce?.removeListener(_onGalleryNonce);
      widget.galleryPickNonce?.addListener(_onGalleryNonce);
    }
    if (oldWidget.sharedPathsNonce != widget.sharedPathsNonce) {
      oldWidget.sharedPathsNonce?.removeListener(_onSharedPathsNonce);
      widget.sharedPathsNonce?.addListener(_onSharedPathsNonce);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.galleryPickNonce?.removeListener(_onGalleryNonce);
    widget.sharedPathsNonce?.removeListener(_onSharedPathsNonce);
    super.dispose();
  }

  Future<void> _onSendEntryTap(BuildContext context, VoidCallback action) async {
    if (_frameOnline == false) {
      // Fast path: warn immediately; live check still runs if status flipped online.
      final ok = await FrameOnlineGuard.ensureCanStartSendFlow(context);
      if (mounted) unawaited(_refreshFrameOnlineStatus());
      if (!ok) return;
    }
    action();
  }

  void _onGalleryNonce() {
    final n = widget.galleryPickNonce?.value ?? 0;
    if (n == 0 || n == _lastGalleryNonce) return;
    _lastGalleryNonce = n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startFlow(context, _SendSource.gallery));
    });
  }

  void _onSharedPathsNonce() {
    final paths = widget.sharedPathsNonce?.value ?? const <String>[];
    if (paths.isEmpty || listEquals(paths, _lastSharedPaths)) return;
    _lastSharedPaths = List<String>.from(paths);
    widget.sharedPathsNonce?.value = const [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startFromSharedPaths(context, paths));
    });
  }

  Future<void> _openCameraPermissionSettings() =>
      app_os.AppSettings.openAppSettings(type: app_os.AppSettingsType.settings);

  void _showCameraDeniedSnackBar(BuildContext context) {
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(s.cameraPermissionDenied),
        action: SnackBarAction(label: s.settingsLabel, onPressed: _openCameraPermissionSettings),
      ),
    );
  }

  Future<void> _shareGuestUploadLink(BuildContext context) async {
    final s = AppStrings.of(context);
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    if (paired == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(s.frameNotConnected),
          action: SnackBarAction(
            label: s.connectLabel,
            onPressed: () async {
              final result = await Navigator.of(context).push<PairingNavResult>(
                MaterialPageRoute<PairingNavResult>(
                  builder: (_) => const DeviceDiscoveryScreen(),
                ),
              );
              PairingFlowNav.onComplete(result);
            },
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.preparingUploadLink),
        duration: const Duration(seconds: 20),
      ),
    );

    final app = AppSettingsScope.of(context);
    final invite = await FrameGuestInviteService.instance.createOrFetchInvite(
      frame: paired,
      userAuthToken: app.authToken,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (invite == null) {
      final s = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(s.couldNotCreateLink),
        ),
      );
      return;
    }

    final frameName = paired.frameName?.trim();
    final label = frameName != null && frameName.isNotEmpty ? frameName : AppStrings.of(context).myNewPlaylist;

    // Share sheet + hosted invite page follow the user's app language.
    final shareUrl = ShareService.withShareLang(invite.inviteUrl, s);

    await platformShareText(
      context,
      text: ShareService.photoInviteShareBody(
        strings: s,
        shareUrl: shareUrl,
        frameName: label,
      ),
      subject: ShareService.photoInviteSubject(s, label),
    );
    AppDiagLog.log('[ShareLink] shared $shareUrl');
  }

  Future<void> _startFlow(BuildContext context, _SendSource source) async {
    if (_sendFlowBusy) return;
    _sendFlowBusy = true;
    try {
      await _startFlowImpl(context, source);
    } finally {
      _sendFlowBusy = false;
    }
  }

  Future<void> _startFlowImpl(BuildContext context, _SendSource source) async {
    if (source == _SendSource.sharelink) {
      await _shareGuestUploadLink(context);
      return;
    }
    if (!await FrameOnlineGuard.ensureCanStartSendFlow(context)) {
      if (mounted) unawaited(_refreshFrameOnlineStatus());
      return;
    }
    if (source == _SendSource.gallery) {
      await _startFromGalleryWithQueue(context);
      return;
    }
    if (source == _SendSource.ai) {
      if (!FeatureFlags.enableAIFeatures) return;
      await _startAiGenerate(context);
      return;
    }
    // Camera flow — uses the same ImageEditorScreen as gallery picks.
    Uint8List? bytes;
    String? cameraPath;
    try {
      if (!context.mounted) return;
      final cam = await PermissionGate.camera();
      if (!cam.isGranted) {
        if (context.mounted) _showCameraDeniedSnackBar(context);
        return;
      }
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (x == null) return; // user cancelled
      cameraPath = x.path;
      bytes = await _ensureJpeg(await x.readAsBytes(), pathHint: x.path);
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final msg = e.code == 'camera_access_denied' || e.code == 'camera_access_denied_android'
          ? AppStrings.of(context).cameraPermissionHelp
          : (e.message ?? e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg),
          action: SnackBarAction(label: AppStrings.of(context).settingsLabel, onPressed: _openCameraPermissionSettings),
        ),
      );
      return;
    }
    if (bytes == null) {
      if (context.mounted) _showCameraDeniedSnackBar(context);
      return;
    }
    if (!context.mounted) return;
    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;

    // Persist the camera file so the editor can use a stable path for SD export etc.
    final persistPaths = cameraPath != null
        ? await GalleryImageCache.persistPaths([cameraPath])
        : <String>[];

    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ImageEditorScreen(
          imageBytes: bytes!,
          galleryPersistPath: persistPaths.isNotEmpty ? persistPaths.first : null,
          slideshow: slideshow,
        ),
      ),
    );
    if (sent == true && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShellNavigation.switchToSend();
      });
    }
  }

  /// Photo library: [pickMultiImage] with single-image fallback, then the editor for each selection in order.
  /// Images shared from another app (Gallery share sheet → MyFrame).
  Future<void> _startFromSharedPaths(BuildContext context, List<String> paths) async {
    final s = AppStrings.of(context);
    if (!context.mounted) return;
    if (!await FrameOnlineGuard.ensureCanStartSendFlow(context)) {
      if (mounted) unawaited(_refreshFrameOnlineStatus());
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(s.shareIncomingHint(paths.length)),
        duration: const Duration(seconds: 3),
      ),
    );

    final files = <XFile>[];
    for (final p in paths) {
      final f = File(p);
      if (await f.exists()) files.add(XFile(p));
    }
    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(s.noImageSelected),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final shareBytes = <Uint8List>[];
    for (final f in files) {
      try {
        final raw = await f.readAsBytes();
        final jpeg = await GalleryImageNormalizer.toJpegBytes(raw, pathHint: f.path);
        if (jpeg != null && jpeg.isNotEmpty) {
          shareBytes.add(jpeg);
        }
      } catch (e) {
        AppDiagLog.verbose('[Send] share read failed ${f.path}: $e');
      }
    }
    if (shareBytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(s.noImageSelected),
          ),
        );
      }
      return;
    }

    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;
    final pathList = await GalleryImageCache.persistPaths(files.map((e) => e.path));
    if (pathList.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(s.noImageSelected),
          ),
        );
      }
      return;
    }
    final sheet = await showSendAlbumSettingsSheet(context, photoPaths: pathList);
    if (!context.mounted || sheet == null) return;

    if (sheet.addToAlbumId != null) {
      await SendAlbumsStore.instance.addPathsToAlbum(sheet.addToAlbumId!, pathList);
      unawaited(SyncPipeline.instance.onAlbumsChanged(albumId: sheet.addToAlbumId));
    } else if (sheet.newAlbumName != null && sheet.newAlbumName!.trim().isNotEmpty) {
      await SendAlbumsStore.instance.createAlbum(sheet.newAlbumName!.trim(), pathList);
      await SendAlbumsStore.instance.load();
      final id = SendAlbumsStore.instance.albums.isNotEmpty
          ? SendAlbumsStore.instance.albums.first.id
          : null;
      if (id != null) {
        unawaited(SyncPipeline.instance.onAlbumsChanged(albumId: id));
      }
    }
    for (var i = 0; i < shareBytes.length; i++) {
      if (!context.mounted) return;
      final sent = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ImageEditorScreen(
            imageBytes: shareBytes[i],
            galleryPersistPath: pathList.length > i ? pathList[i] : null,
            slideshow: slideshow,
            overlay: sheet.overlay,
            overlayLocationOverride: sheet.locationLine,
            displaySeconds: sheet.displaySeconds,
          ),
        ),
      );
      if (sent == true) {
        if (!context.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ShellNavigation.switchToSend();
        });
        return;
      }
    }
  }

  Future<void> _startFromGalleryWithQueue(BuildContext context) async {
    List<XFile> files;
    try {
      files = await _pickFromGallery(context);
    } on PlatformException catch (e) {
    if (!context.mounted) return;
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(s.cameraPermissionDenied),
        action: SnackBarAction(label: s.settingsLabel, onPressed: _openCameraPermissionSettings),
      ),
    );
      return;
    }
    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(AppStrings.of(context).noImageSelected),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    if (frames.length > 1) {
      final picked = await showFramePickerSheet(context, frames: frames);
      if (picked == null || !context.mounted) return;
      await DeviceStore.instance.setActiveFrameDeviceId(picked.deviceId);
      if (!await FrameOnlineGuard.ensureOnlineForSend(context, frame: picked)) {
        if (mounted) unawaited(_refreshFrameOnlineStatus());
        return;
      }
    }

    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;
    // Fast durable copies — do not block on JPEG re-encode before opening send UI.
    final paths = await GalleryImageCache.persistPaths(
      files.map((e) => e.path),
      normalizeJpeg: false,
    );
    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(AppStrings.of(context).noImageSelected),
          ),
        );
      }
      return;
    }

    if (paths.length > 1) {
      // Mini-app: multi-pick → playlist send page immediately.
      unawaited(PlaylistSendNav.openPlaylistSend(context, paths: paths));
      return;
    }

    final fileBytes = <Uint8List>[];
    for (final path in paths) {
      try {
        final raw = await File(path).readAsBytes();
        final jpeg = await GalleryImageNormalizer.toJpegBytes(raw, pathHint: path);
        if (jpeg == null || jpeg.isEmpty) continue;
        fileBytes.add(jpeg);
        AppDiagLog.verbose('[Send] gallery pick $path bytes=${jpeg.length}');
      } catch (e) {
        AppDiagLog.verbose('[Send] gallery read failed $path: $e');
      }
    }
    if (fileBytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(AppStrings.of(context).noImageSelected),
          ),
        );
      }
      return;
    }

    final skipAlbumSheet = ShellNavigation.consumeSkipAlbumSheetOnNextGalleryPick();
    SendAlbumSheetResult? sheet;
    if (!skipAlbumSheet) {
      sheet = await showSendAlbumSettingsSheet(context, photoPaths: paths);
      if (!context.mounted || sheet == null) return;

      if (sheet.addToAlbumId != null) {
        await SendAlbumsStore.instance.addPathsToAlbum(sheet.addToAlbumId!, paths);
        unawaited(SyncPipeline.instance.onAlbumsChanged(albumId: sheet.addToAlbumId));
      } else if (sheet.newAlbumName != null && sheet.newAlbumName!.trim().isNotEmpty) {
        await SendAlbumsStore.instance.createAlbum(sheet.newAlbumName!.trim(), paths);
        await SendAlbumsStore.instance.load();
        final id = SendAlbumsStore.instance.albums.isNotEmpty
            ? SendAlbumsStore.instance.albums.first.id
            : null;
        if (id != null) {
          unawaited(SyncPipeline.instance.onAlbumsChanged(albumId: id));
        }
      }
    }

    final overlay = sheet?.overlay ?? const SendOverlayOptions();
    final locationLine = sheet?.locationLine;
    final displaySeconds = sheet?.displaySeconds ?? 10;

    for (var i = 0; i < fileBytes.length; i++) {
      if (!context.mounted) return;
      final sent = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ImageEditorScreen(
            imageBytes: fileBytes[i],
            galleryPersistPath: paths[i],
            slideshow: slideshow,
            overlay: overlay,
            overlayLocationOverride: locationLine,
            displaySeconds: displaySeconds,
            queueIndex: i + 1,
          ),
        ),
      );
      if (sent == true) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              duration: const Duration(seconds: 5),
              content: Text(
                AppStrings.of(context).sendQueueWaitForFrame(i + 1, fileBytes.length),
              ),
            ),
          );
          await DeviceStore.instance.load();
          final paired = DeviceStore.instance.cached;
          if (paired != null) {
            try {
              await FrameRecoveryService.instance.sendLoginAck(paired);
            } catch (_) {}
          }
          await Future<void>.delayed(const Duration(seconds: 120));
        } else {
          // User backed out of the editor — stay on Send Photo.
          if (!context.mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ShellNavigation.switchToSend();
          });
          return;
        }
    }
  }

  /// Multi-select when available; on iOS cancel does not reopen single picker.
  Future<List<XFile>> _pickFromGallery(BuildContext context) async {
    if (_pickerOpen) return [];
    _pickerOpen = true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final next = await PermissionGate.photos();
        if (!next.isGranted && !next.isLimited && next.isPermanentlyDenied && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(AppStrings.of(context).allowPhotosPermission),
              action: SnackBarAction(label: AppStrings.of(context).settingsLabel, onPressed: openAppSettings),
            ),
          );
          return [];
        }
        if (!next.isGranted && !next.isLimited) return [];
      }
      return GalleryPhotoPicker.pickMulti(context);
    } finally {
      _pickerOpen = false;
    }
  }

  /// Picks and returns camera bytes as JPEG. Returns `null` if user cancels.
  Future<({Uint8List bytes, String? path})?> _resolveCameraCapture() async {
    final cam = await PermissionGate.camera();
    if (!cam.isGranted) return null;
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (x == null) return null;
    final path = x.path;
    final raw = await x.readAsBytes();
    final bytes = await _ensureJpeg(raw, pathHint: path);
    return (bytes: bytes, path: path);
  }

  /// Re-encodes as JPEG if needed (HEIC / odd PNG from iOS).
  Future<Uint8List> _ensureJpeg(Uint8List raw, {String? pathHint}) async {
    final normalized = await GalleryImageNormalizer.toJpegBytes(
      raw,
      pathHint: pathHint,
    );
    if (normalized != null && normalized.isNotEmpty) return normalized;
    return raw;
  }

  Future<Uint8List?> _resolveImageBytes(_SendSource source) async {
    final picker = ImagePicker();
    switch (source) {
      case _SendSource.sharelink:
        throw StateError('sharelink uses _shareInviteFromSend');
      case _SendSource.gallery:
        throw StateError('Gallery uses _startFromGalleryWithQueue / _pickFromGallery');
      case _SendSource.camera:
        final r = await _resolveCameraCapture();
        return r?.bytes;
      case _SendSource.ai:
        throw StateError('AI uses _startAiGenerate');
    }
  }

  Future<void> _startAiGenerate(BuildContext context) async {
    final s = AppStrings.of(context);
    var app = AppSettingsScope.of(context);
    var provider = app.aiImageProvider;
    var apiKey = app.activeAiImageApiKey;
    if (apiKey.isEmpty) {
      if (!context.mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => const SettingsAiGenerateScreen(autoReturnAfterSave: true),
        ),
      );
      if (!context.mounted || saved != true) return;
      app = AppSettingsScope.of(context);
      provider = app.aiImageProvider;
      apiKey = app.activeAiImageApiKey;
      if (apiKey.isEmpty) return;
    }

    final prompt = await TextInputBottomSheet.show(
      context,
      title: s.aiGeneratePromptTitle,
      label: s.aiGeneratePromptLabel,
      confirmLabel: s.aiGeneratePromptConfirm,
      textCapitalization: TextCapitalization.sentences,
    );
    if (prompt == null || prompt.trim().isEmpty || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.aiGenerateWorking),
        duration: const Duration(seconds: 90),
      ),
    );

    Uint8List? bytes;
    try {
      bytes = await AiImageGenerateService.instance.generate(
        provider: provider,
        apiKey: apiKey,
        prompt: prompt.trim(),
      );
    } on AiImageGenerateException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiGenerateFailed(e.detail ?? e.code))),
      );
      return;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiGenerateFailed('$e'))),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final slideshow = app.defaultSlideshowStyle;
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ImageEditorScreen(
          imageBytes: bytes!,
          slideshow: slideshow,
          isAiGenerated: true,
        ),
      ),
    );
    if (sent == true && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShellNavigation.switchToSend();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(s.sendPhotoTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ListenableBuilder(
            listenable: BleFrameDeviceTransport.instance.connectionUi,
            builder: (context, _) {
              if (BleFrameDeviceTransport.instance.connectionUi.value != FrameConnectionState.connected) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: Icon(
                      Icons.bluetooth_connected,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(s.bleSessionBannerTitle),
                    subtitle: Text(
                      s.bleSessionBannerSub,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        unawaited(BleFrameDeviceTransport.instance.releaseSession());
                      },
                      child: Text(s.bleDisconnect),
                    ),
                  ),
                ),
              );
            },
          ),
          _SendHeroCard(
            s: s,
            primary: primary,
            colorScheme: cs,
            enabled: _frameOnline != false,
            onPickGallery: () => _onSendEntryTap(
              context,
              () => _startFlow(context, _SendSource.gallery),
            ),
          ),
          _SendRow(
            icon: Icons.view_carousel_outlined,
            title: s.navPlaylist,
            subtitle: s.sendSlideshowOpensPlaylist,
            enabled: _frameOnline != false,
            onTap: () => _onSendEntryTap(context, () async {
              if (!context.mounted) return;
              if (!await FrameOnlineGuard.ensureCanStartSendFlow(context)) {
                if (mounted) unawaited(_refreshFrameOnlineStatus());
                return;
              }
              if (!context.mounted) return;
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const PlaylistScreen()),
              );
              if (mounted) unawaited(_refreshFrameOnlineStatus());
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
            child: Text(
              s.sendTabMoreWays,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          _SendRow(
            icon: Icons.photo_camera_outlined,
            title: s.takePhoto,
            subtitle: s.takePhotoSub,
            enabled: _frameOnline != false,
            onTap: () => _onSendEntryTap(
              context,
              () => _startFlow(context, _SendSource.camera),
            ),
          ),
          _SendRow(
            icon: Icons.share_outlined,
            title: s.shareLink,
            subtitle: s.shareLinkSub,
            onTap: () => _startFlow(context, _SendSource.sharelink),
          ),
          if (FeatureFlags.enableAIFeatures) ...[
            _SendRow(
              icon: Icons.auto_awesome,
              title: s.aiGenerate,
              subtitle: s.aiGenerateSub,
              highlighted: true,
              enabled: _frameOnline != false,
              onTap: () => _onSendEntryTap(
                context,
                () => _startFlow(context, _SendSource.ai),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: AiContentNotice(compact: true),
            ),
          ],
        ],
      ),
    );
  }
}

/// Top card: one-tap path most people want (library).
class _SendHeroCard extends StatelessWidget {
  const _SendHeroCard({
    required this.s,
    required this.primary,
    required this.colorScheme,
    required this.onPickGallery,
    this.enabled = true,
  });

  final AppStrings s;
  final Color primary;
  final ColorScheme colorScheme;
  final VoidCallback onPickGallery;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? primary : colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      label: s.gallery,
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.11),
                colorScheme.surface,
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.photo_library_rounded, color: accent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        enabled ? s.sendTabSubhead : s.frameOfflineLabel,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 22),
                  label: Text(
                    s.gallery,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: enabled ? primary : colorScheme.surfaceContainerHighest,
                    foregroundColor: enabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
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

class _SendRow extends StatelessWidget {
  const _SendRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.highlighted = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool highlighted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final accent = enabled ? primary : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: highlighted && enabled ? primary : cs.outlineVariant,
                  width: highlighted && enabled ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                          if (trailing != null) ...[
                            const SizedBox(width: 8),
                            trailing!,
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.25),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.outline, size: 22),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
