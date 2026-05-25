import 'dart:async';
import 'dart:io';
import 'package:app_settings/app_settings.dart' as app_os;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../services/family_group_store.dart';
import '../settings/app_settings.dart';
import 'image_editor_screen.dart';
import 'slideshow_batch_screen.dart';
import '../services/ble_frame_device_transport.dart';
import '../services/device_store.dart';
import '../services/device_transport.dart' show FrameConnectionState;
import '../services/personal_gallery_store.dart';
import '../services/send_albums_store.dart';
import '../services/share_incoming_service.dart';
import '../widgets/send_album_settings_sheet.dart';
import '../widgets/shell_navigation.dart';
import 'device_discovery_screen.dart';

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

class _SendScreenState extends State<SendScreen> {
  int _lastGalleryNonce = 0;
  List<String> _lastSharedPaths = const [];

  @override
  void initState() {
    super.initState();
    widget.galleryPickNonce?.addListener(_onGalleryNonce);
    widget.sharedPathsNonce?.addListener(_onSharedPathsNonce);
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
    widget.galleryPickNonce?.removeListener(_onGalleryNonce);
    widget.sharedPathsNonce?.removeListener(_onSharedPathsNonce);
    super.dispose();
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

  Future<bool> _ensureConnectedFrame(BuildContext context) async {
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    if (paired != null) return true;
    if (!context.mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const DeviceDiscoveryScreen()),
    );
    await DeviceStore.instance.load();
    return ok == true || DeviceStore.instance.cached != null;
  }

  Future<void> _openCameraPermissionSettings() =>
      app_os.AppSettings.openAppSettings(type: app_os.AppSettingsType.settings);

  Future<void> _shareInviteFromSend(BuildContext context) async {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    await FamilyGroupStore.instance.ensureLoaded(ownerDisplayName: () {
      final name = app.profileName.trim();
      if (name.isNotEmpty) return name;
      final mail = app.accountEmail.trim();
      if (mail.isNotEmpty) return mail.split('@').first;
      return 'You';
    });
    if (!context.mounted) return;
    final g = FamilyGroupStore.instance;
    final inviteUrl =
        'https://${VpsDefaults.hostnameInk}/join?code=${Uri.encodeComponent(g.inviteCode)}';
    await Share.share(
      s.familyInviteShareBody(g.familyName, g.inviteCode, inviteUrl),
      subject: '${s.inviteFamily} · ${g.familyName}',
    );
  }

  Future<void> _startFlow(BuildContext context, _SendSource source) async {
    final connected = await _ensureConnectedFrame(context);
    if (!connected) return;
    if (source == _SendSource.gallery) {
      await _startFromGalleryWithQueue(context);
      return;
    }
    if (source == _SendSource.sharelink) {
      await _shareInviteFromSend(context);
      return;
    }
    Uint8List? bytes;
    try {
      bytes = await _resolveImageBytes(source);
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final msg = e.code == 'camera_access_denied' || e.code == 'camera_access_denied_android'
          ? 'Allow Camera permission (Settings ▸ Apps ▸ MyFrame ▸ Permissions). Or use Gallery instead.'
          : (e.message ?? e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg),
          action: SnackBarAction(label: 'Settings', onPressed: _openCameraPermissionSettings),
        ),
      );
      return;
    }
    if (bytes == null) {
      if (context.mounted) {
        final msgNoCam = source == _SendSource.camera
            ? 'Camera permission denied. Use Gallery below or enable Camera in Settings.'
            : AppStrings.of(context).noImageSelected;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(msgNoCam),
            action:
                source == _SendSource.camera
                    ? SnackBarAction(label: 'Settings', onPressed: _openCameraPermissionSettings)
                    : null,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final Uint8List imageBytes = bytes;
    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;

    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ImageEditorScreen(
          imageBytes: imageBytes,
          slideshow: slideshow,
        ),
      ),
    );
    if (sent == true) {
      ShellNavigation.goToTab(0);
    }
  }

  /// Photo library: [pickMultiImage] with single-image fallback, then the editor for each selection in order.
  /// Images shared from another app (Gallery share sheet → MyFrame).
  Future<void> _startFromSharedPaths(BuildContext context, List<String> paths) async {
    final s = AppStrings.of(context);
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

    final connected = await _ensureConnectedFrame(context);
    if (!connected) {
      ShareIncomingService.instance.requeuePaths(paths);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(s.shareIncomingConnectFrame),
          ),
        );
      }
      return;
    }

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
    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;
    final pathList = files.map((e) => e.path).toList();
    final sheet = await showSendAlbumSettingsSheet(context, photoPaths: pathList);
    if (!context.mounted || sheet == null) return;

    if (sheet.addToAlbumId != null) {
      await SendAlbumsStore.instance.addPathsToAlbum(sheet.addToAlbumId!, pathList);
    } else if (sheet.newAlbumName != null && sheet.newAlbumName!.trim().isNotEmpty) {
      await SendAlbumsStore.instance.createAlbum(sheet.newAlbumName!.trim(), pathList);
    }
    await PersonalGalleryStore.instance.addPaths(pathList);

    for (var i = 0; i < files.length; i++) {
      if (!context.mounted) return;
      final bytes = await files[i].readAsBytes();
      if (!context.mounted) return;
      final sent = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ImageEditorScreen(
            imageBytes: bytes,
            slideshow: slideshow,
            overlay: sheet.overlay,
            overlayLocationOverride: sheet.locationLine,
          ),
        ),
      );
      if (sent == true) {
        ShellNavigation.goToTab(0);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(e.message ?? e.code),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
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

    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;
    final paths = files.map((e) => e.path).toList();
    final sheet = await showSendAlbumSettingsSheet(context, photoPaths: paths);
    if (!context.mounted || sheet == null) return;

    if (sheet.addToAlbumId != null) {
      await SendAlbumsStore.instance.addPathsToAlbum(sheet.addToAlbumId!, paths);
    } else if (sheet.newAlbumName != null && sheet.newAlbumName!.trim().isNotEmpty) {
      await SendAlbumsStore.instance.createAlbum(sheet.newAlbumName!.trim(), paths);
    }
    await PersonalGalleryStore.instance.addPaths(paths);

    for (var i = 0; i < files.length; i++) {
      if (!context.mounted) return;
      final bytes = await files[i].readAsBytes();
      if (!context.mounted) return;
      final sent = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ImageEditorScreen(
            imageBytes: bytes,
            slideshow: slideshow,
            overlay: sheet.overlay,
            overlayLocationOverride: sheet.locationLine,
          ),
        ),
      );
      if (sent == true) {
        ShellNavigation.goToTab(0);
        return;
      }
    }
  }

  /// Multi-select when available; otherwise a single [pickImage].
  Future<List<XFile>> _pickFromGallery(BuildContext context) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final st = await Permission.photos.status;
      var next = st;
      if (!st.isGranted && !st.isLimited) {
        next = await Permission.photos.request();
      }
      if (!next.isGranted && !next.isLimited && next.isPermanentlyDenied && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Allow Photos/Videos permission to pick images.'),
            action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          ),
        );
        return [];
      }
      if (!next.isGranted && !next.isLimited) return [];
    }
    final picker = ImagePicker();
    var list = await picker.pickMultiImage();
    if (list.isEmpty) {
      final one = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (one != null) list = [one];
    }
    return list;
  }

  Future<Uint8List?> _resolveImageBytes(_SendSource source) async {
    final picker = ImagePicker();
    switch (source) {
      case _SendSource.sharelink:
        throw StateError('sharelink uses _shareInviteFromSend');
      case _SendSource.gallery:
        throw StateError('Gallery uses _startFromGalleryWithQueue / _pickFromGallery');
      case _SendSource.camera:
        var cam = await Permission.camera.status;
        if (!cam.isGranted) cam = await Permission.camera.request();
        if (!cam.isGranted) return null;
        final x = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 4096,
          maxHeight: 4096,
        );
        return x == null ? null : x.readAsBytes();
      case _SendSource.ai:
        return _demoImageBytes();
    }
  }

  Uint8List _demoImageBytes() {
    final image = im.Image(width: 900, height: 1200);
    im.fill(image, color: im.ColorRgb8(130, 70, 180));
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final b = (x * 255 ~/ image.width);
        image.setPixelRgb(x, y, 200, 80 + b ~/ 3, 120);
      }
    }
    return Uint8List.fromList(im.encodeJpg(image, quality: 90));
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
            onPickGallery: () => _startFlow(context, _SendSource.gallery),
          ),
          _SendRow(
            icon: Icons.view_carousel_outlined,
            title: s.slideshowBatchTitle,
            subtitle: s.slideshowPickInterval,
            onTap: () async {
              final connected = await _ensureConnectedFrame(context);
              if (!connected) return;
              if (!context.mounted) return;
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SlideshowBatchScreen()),
              );
            },
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
            onTap: () => _startFlow(context, _SendSource.camera),
          ),
          _SendRow(
            icon: Icons.share_outlined,
            title: s.shareLink,
            subtitle: s.shareLinkSub,
            onTap: () => _startFlow(context, _SendSource.sharelink),
          ),
          _SendRow(
            icon: Icons.auto_awesome,
            title: s.aiGenerate,
            subtitle: s.aiGenerateSub,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(s.pro, style: TextStyle(color: Colors.purple.shade800, fontSize: 11)),
            ),
            highlighted: true,
            onTap: () => _startFlow(context, _SendSource.ai),
          ),
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
  });

  final AppStrings s;
  final Color primary;
  final ColorScheme colorScheme;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: s.gallery,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: 0.11),
              colorScheme.surface,
            ],
          ),
          border: Border.all(color: primary.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.08),
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
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.photo_library_rounded, color: primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.sendTabSubhead,
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
                  backgroundColor: primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
              ),
            ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                color: highlighted ? primary : cs.outlineVariant,
                width: highlighted ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: primary, size: 26),
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
    );
  }
}
