import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../screens/create_playlist_screen.dart';
import '../screens/image_editor_screen.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/frame_online_guard.dart';
import '../services/gallery_image_cache.dart';
import '../services/gallery_image_normalizer.dart';
import '../services/share_receiver_service.dart';
import '../services/slideshow_style.dart';
import '../settings/app_settings.dart';

/// Result of [showShareTargetBottomSheet].
class ShareTargetSheetResult {
  const ShareTargetSheetResult({
    required this.paths,
    required this.frames,
    this.navigatedAway = false,
  });

  final List<String> paths;
  final List<PairedFrame> frames;
  final bool navigatedAway;
}

/// Aura-style “Sharing to MyFrame” destination picker + send progress.
Future<ShareTargetSheetResult?> showShareTargetBottomSheet(
  BuildContext context, {
  required List<SharedMediaItem> items,
}) {
  if (items.isEmpty) return Future.value(null);
  return showModalBottomSheet<ShareTargetSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ShareTargetBottomSheetWidget(items: items),
  );
}

class ShareTargetBottomSheetWidget extends StatefulWidget {
  const ShareTargetBottomSheetWidget({super.key, required this.items});

  final List<SharedMediaItem> items;

  @override
  State<ShareTargetBottomSheetWidget> createState() =>
      _ShareTargetBottomSheetWidgetState();
}

enum _ShareSheetPhase { pick, sending, done, failed }

class _ShareTargetBottomSheetWidgetState
    extends State<ShareTargetBottomSheetWidget> {
  final Set<String> _selectedIds = {};
  List<String> _paths = const [];
  _ShareSheetPhase _phase = _ShareSheetPhase.pick;
  double _progress = 0;
  String _status = '';
  bool _loadingPaths = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await DeviceStore.instance.load();
    final frames = DeviceStore.instance.pairedFrames;
    final active = DeviceStore.instance.cached?.deviceId;
    if (frames.isNotEmpty) {
      final prefer = frames.any((f) => f.deviceId == active)
          ? active!
          : frames.first.deviceId;
      _selectedIds.add(prefer);
    }

    final raw = widget.items.map((e) => e.path).toList();
    // Strip file:// if the Share Extension stored absoluteString.
    final cleaned = raw.map((p) {
      if (p.startsWith('file://')) {
        return Uri.parse(p).toFilePath();
      }
      return p;
    }).toList();
    final persisted = await GalleryImageCache.persistPaths(cleaned);
    if (!mounted) return;
    setState(() {
      _paths = persisted.isNotEmpty ? persisted : cleaned;
      _loadingPaths = false;
    });
  }

  List<PairedFrame> get _frames => DeviceStore.instance.pairedFrames;

  List<PairedFrame> get _selectedFrames =>
      _frames.where((f) => _selectedIds.contains(f.deviceId)).toList();

  Future<void> _onSend() async {
    final s = AppStrings.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    if (_paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noImageSelected)),
      );
      return;
    }
    if (_selectedFrames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.shareIncomingConnectFrame)),
      );
      return;
    }

    // Multi-photo → playlist UI (user configures interval / name).
    if (_paths.length > 1) {
      final target = _selectedFrames.first;
      await DeviceStore.instance.setActiveFrameDeviceId(target.deviceId);
      if (!mounted) return;
      final paths = List<String>.from(_paths);
      Navigator.pop(
        context,
        ShareTargetSheetResult(
          paths: paths,
          frames: _selectedFrames,
          navigatedAway: true,
        ),
      );
      unawaited(navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CreatePlaylistScreen(imagePaths: paths),
        ),
      ));
      return;
    }

    // Single photo → cast to each selected frame with in-sheet progress.
    setState(() {
      _phase = _ShareSheetPhase.sending;
      _progress = 0.05;
      _status = s.shareSheetSending;
    });

    final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;
    final api = FrameApiClient();
    final auth = AppSettingsScope.of(context).authToken;
    final file = File(_paths.first);
    Uint8List? jpeg;
    try {
      final raw = await file.readAsBytes();
      jpeg = await GalleryImageNormalizer.toJpegBytes(raw, pathHint: _paths.first);
      jpeg ??= raw;
    } catch (_) {
      jpeg = null;
    }
    if (jpeg == null || jpeg.isEmpty) {
      if (!mounted) return;
      setState(() {
        _phase = _ShareSheetPhase.failed;
        _status = s.decodeError;
      });
      return;
    }

    var okAny = false;
    final targets = _selectedFrames;
    for (var i = 0; i < targets.length; i++) {
      final frame = targets[i];
      if (!mounted) return;
      setState(() {
        _progress = (i + 0.2) / targets.length;
        _status = s.shareSheetSendingTo(
          frame.frameName?.trim().isNotEmpty == true
              ? frame.frameName!.trim()
              : frame.listDisplayTitle(s),
        );
      });

      await DeviceStore.instance.setActiveFrameDeviceId(frame.deviceId);
      if (!mounted) return;
      final online = await FrameOnlineGuard.ensureOnlineForSend(
        context,
        frame: frame,
      );
      if (!online) continue;

      final filename =
          'share_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final result = await FrameCloudCastService.instance.castPhoto(
        api: api,
        paired: frame,
        jpegBytes: jpeg,
        filename: filename,
        slideshowStyle: slideshow.apiValue,
        strings: s,
        userAuthToken: auth.isEmpty ? null : auth,
        syncSlideshowAfterSuccess: true,
        onProgress: (p) {
          if (!mounted) return;
          final frac = p.progress ?? 0.5;
          setState(() {
            _progress = ((i + frac.clamp(0, 1)) / targets.length)
                .clamp(0.0, 0.99);
            if (p.message.trim().isNotEmpty) _status = p.message;
          });
        },
      );
      if (result.ok) okAny = true;
    }

    if (!mounted) return;
    if (okAny) {
      setState(() {
        _phase = _ShareSheetPhase.done;
        _progress = 1;
        _status = s.shareSheetPhotoSent;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.pop(
          context,
          ShareTargetSheetResult(paths: _paths, frames: _selectedFrames),
        );
      }
    } else {
      setState(() {
        _phase = _ShareSheetPhase.pick;
        _status = '';
        _progress = 0;
      });
      final frame = _selectedFrames.first;
      await DeviceStore.instance.setActiveFrameDeviceId(frame.deviceId);
      if (!mounted) return;
      final jpegBytes = jpeg;
      final path = _paths.first;
      Navigator.pop(
        context,
        ShareTargetSheetResult(
          paths: _paths,
          frames: _selectedFrames,
          navigatedAway: true,
        ),
      );
      unawaited(navigator.push(
        MaterialPageRoute<bool>(
          builder: (_) => ImageEditorScreen(
            imageBytes: jpegBytes,
            galleryPersistPath: path,
            slideshow: slideshow,
            autoSendAfterLoad: true,
          ),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final photoCount = _paths.isNotEmpty ? _paths.length : widget.items.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: cs.surface,
          elevation: 10,
          shadowColor: Colors.black26,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.shareSheetTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _phase == _ShareSheetPhase.sending
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(s.cancel),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PhotoPreviewRow(
                  paths: _paths.isNotEmpty
                      ? _paths
                      : widget.items.map((e) {
                          final p = e.path;
                          return p.startsWith('file://')
                              ? Uri.parse(p).toFilePath()
                              : p;
                        }).toList(),
                  loading: _loadingPaths,
                  label: photoCount == 1
                      ? s.shareSheetOnePhoto
                      : s.shareSheetNPhotos(photoCount),
                ),
                const SizedBox(height: 18),
                Text(
                  s.shareSheetDestination,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (_frames.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      s.shareIncomingConnectFrame,
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.32,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _frames.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final f = _frames[i];
                        final selected = _selectedIds.contains(f.deviceId);
                        final title = f.frameName?.trim().isNotEmpty == true
                            ? f.frameName!.trim()
                            : f.listDisplayTitle(s);
                        return Material(
                          color: selected
                              ? cs.primary.withValues(alpha: 0.10)
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                          child: CheckboxListTile(
                            value: selected,
                            onChanged: _phase == _ShareSheetPhase.sending
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedIds.add(f.deviceId);
                                      } else {
                                        _selectedIds.remove(f.deviceId);
                                      }
                                    });
                                  },
                            controlAffinity: ListTileControlAffinity.trailing,
                            secondary: Icon(
                              Icons.photo_size_select_actual_outlined,
                              color: cs.primary,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              f.deviceId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_phase == _ShareSheetPhase.sending ||
                    _phase == _ShareSheetPhase.done ||
                    _phase == _ShareSheetPhase.failed) ...[
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _phase == _ShareSheetPhase.failed
                          ? cs.error
                          : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _phase == _ShareSheetPhase.sending
                          ? _progress.clamp(0.05, 1.0)
                          : (_phase == _ShareSheetPhase.done ? 1 : null),
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: (_phase == _ShareSheetPhase.sending ||
                          _loadingPaths ||
                          _frames.isEmpty ||
                          _selectedIds.isEmpty)
                      ? null
                      : _onSend,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _phase == _ShareSheetPhase.sending
                        ? s.shareSheetSending
                        : s.shareSheetSend,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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

class _PhotoPreviewRow extends StatelessWidget {
  const _PhotoPreviewRow({
    required this.paths,
    required this.label,
    required this.loading,
  });

  final List<String> paths;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final show = paths.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 56,
            width: 56.0 + (show.length > 1 ? (show.length - 1) * 18.0 : 0),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Stack(
                    children: [
                      for (var i = 0; i < show.length; i++)
                        Positioned(
                          left: i * 18.0,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.surface, width: 2),
                              image: DecorationImage(
                                image: FileImage(File(show[i])),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
