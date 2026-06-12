import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../config/api_config.dart';
import 'package:path/path.dart' as p;

import '../services/device_store.dart';
import '../services/gallery_image_cache.dart';
import '../services/personal_gallery_store.dart';
import '../services/frame_api_client.dart';
import '../services/frame_cast_progress.dart';
import '../services/app_diag_log.dart';
import '../services/app_release_guard.dart';
import '../services/cloud_photo_upload_service.dart';
import '../services/in_app_notification_store.dart';
import '../widgets/debug_slog_overlay.dart';
import '../services/frame_cloud_cast_service.dart';
import '../services/editor_settings_cache.dart';
import '../services/image_processor_service.dart';
import '../services/image_send_isolate_worker.dart';
import '../services/sd_card_export.dart';
import '../services/slideshow_style.dart';
import '../services/transport_kind.dart';
import '../services/usage_metrics_store.dart';
import '../settings/app_settings.dart';
import '../l10n/app_strings.dart';
import '../navigation/pairing_flow_nav.dart';
import '../models/pairing_nav_result.dart';
import '../models/send_overlay_options.dart';
import 'device_discovery_screen.dart';
import 'wifi_provision_screen.dart';

/// Step 1 from `ra/api`: color grade + filters before resize / E-ink (handled on Send).
class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({
    super.key,
    required this.imageBytes,
    this.deviceId = '',
    this.transport = TransportKind.wifi,
    this.slideshow = SlideshowStyle.fade,
    this.overlay = const SendOverlayOptions(),
    this.overlayLocationOverride,
    this.displaySeconds = 10,
    this.queueIndex = 1,
    this.queueTotal = 1,
    this.galleryPersistPath,
  });

  final Uint8List imageBytes;
  final String deviceId;
  final TransportKind transport;
  final SlideshowStyle slideshow;
  final SendOverlayOptions overlay;

  /// When location overlay is on, shown instead of frame name (e.g. city + weather).
  final String? overlayLocationOverride;

  /// Per-photo display duration from album settings sheet (seconds).
  final int displaySeconds;

  /// When sending multiple picks: 1-based index and total count.
  final int queueIndex;
  final int queueTotal;

  /// Durable gallery file from Send pick — updated in place after a successful send.
  final String? galleryPersistPath;

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final _processor = ImageProcessorService();
  final _api = FrameApiClient();

  img.Image? _decoded;
  Timer? _debounce;

  int _quarterTurns = 0;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  FrameImageFilter _filter = FrameImageFilter.none;

  Uint8List? _previewBytes;
  bool _uploading = false;
  String? _status;
  double? _castProgress;
  bool _castProgressIndeterminate = false;
  final List<String> _castLogLines = [];
  bool _sendSucceeded = false;
  bool _decodeFailed = false;
  ProcessedFrameResult? _cachedProcess;
  PairedFrame? _paired;

  late TransportKind _transport;
  late SlideshowStyle _slideshow;

  AppStrings? _strings;

  /// Photo caption / overlay: top→bottom on image is custom, greeting, location, date (send sheet + `ra/ui` mock).
  bool _oDate = false;
  bool _oLocation = false;
  bool _oGreeting = false;
  late final TextEditingController _overlayText;

  SendOverlayOptions get _currentOverlay => SendOverlayOptions(
    showDate: _oDate,
    showLocation: _oLocation,
    showGreeting: _oGreeting,
    customText: _overlayText.text,
    greetingCustom: widget.overlay.greetingCustom,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _strings = AppStrings.of(context);
  }

  String get _overlayLocationValue {
    final s = _strings ?? AppStrings(AppLocale.en);
    final ovr = widget.overlayLocationOverride?.trim();
    if (_oLocation && ovr != null && ovr.isNotEmpty) {
      return ovr;
    }
    final n = _paired?.frameName?.trim();
    if (n != null && n.isNotEmpty) return n;
    if (_paired != null) return _paired!.listDisplayTitle(s);
    return s.frameDefaultDisplayName;
  }

  Future<void> _copyCastDiagnostics() async {
    final buf = StringBuffer();
    final paired = _paired;
    if (paired != null) {
      buf.writeln('Paired deviceId: ${paired.deviceId}');
      buf.writeln('bleRemoteId: ${paired.bleRemoteId ?? '—'}');
      buf.writeln(
        'Upload device_id: ${FrameCloudCastService.instance.uploadDeviceId(paired)}',
      );
      buf.writeln('API base: ${paired.resolvedApiBaseUrl ?? '—'}');
    }
    if (_castLogLines.isNotEmpty) {
      buf.writeln('--- Cast activity ---');
      for (final line in _castLogLines) {
        buf.writeln(line);
      }
    }
    if (_status != null && _status!.trim().isNotEmpty) {
      buf.writeln('--- Status ---');
      buf.writeln(_status);
    }
    final text = buf.toString().trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Log copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _appendCastLog(CastProgress p) {
    if (!AppDiagLog.isDebugEnabled) return;
    final line = AppDiagLog.castUiLine(p.phase.name, p.message);
    if (line == null) return;
    _castLogLines.add(line);
    if (_castLogLines.length > 14) {
      _castLogLines.removeAt(0);
    }
  }

  String _userFacingCastStatus(CastProgress p) {
    return AppDiagLog.userFacingStatus(
      p.message,
      fallback: p.phase == CastPhase.failed
          ? 'Could not send the photo. Try again.'
          : 'Sending to frame…',
    );
  }

  Future<void> _finishSuccessfulSend(String status, {Uint8List? sentJpeg}) async {
    if (!mounted) return;
    setState(() {
      _status = status;
      _uploading = false;
      _sendSucceeded = true;
      _castProgress = 1;
      _castProgressIndeterminate = false;
    });
    unawaited(UsageMetricsStore.instance.markPhotoSentNow());
    unawaited(
      InAppNotificationStore.instance.photoSent(
        frameName: _paired?.frameName ?? _paired?.listDisplayTitle(_strings ?? AppStrings(AppLocale.en)),
      ),
    );
    if (sentJpeg != null && sentJpeg.isNotEmpty) {
      unawaited(_saveSentPhotoToGallery(sentJpeg, persistPath: widget.galleryPersistPath));
    }
  }

  Future<void> _saveSentPhotoToGallery(
    Uint8List jpeg, {
    String? persistPath,
  }) async {
    try {
      final trimmed = persistPath?.trim();
      late final String destPath;
      if (trimmed != null && trimmed.isNotEmpty) {
        destPath = trimmed;
      } else {
        final dir = await GalleryImageCache.galleryDirForSync();
        destPath = p.join(
          dir.path,
          'sent_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
      await File(destPath).writeAsBytes(jpeg, flush: true);
      await PersonalGalleryStore.instance.addPaths([destPath]);
    } catch (e) {
      AppDiagLog.verbose('[Editor] gallery save failed: $e');
    }
  }

  void _leaveEditorAfterSend() {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    final cached = EditorSettingsCache.instance.last;
    final sheetOverlay = widget.overlay.hasAnyOverlay ||
        widget.overlay.customText.trim().isNotEmpty ||
        (widget.overlayLocationOverride?.trim().isNotEmpty ?? false);
    _transport = TransportKind.wifi;
    _slideshow = cached?.slideshow ?? widget.slideshow;
    if (sheetOverlay) {
      _oDate = widget.overlay.showDate;
      _oLocation = widget.overlay.showLocation;
      _oGreeting = widget.overlay.showGreeting;
    } else if (cached != null) {
      _oDate = cached.showDate;
      _oLocation = cached.showLocation;
      _oGreeting = cached.showGreeting;
    } else {
      _oDate = widget.overlay.showDate;
      _oLocation = widget.overlay.showLocation;
      _oGreeting = widget.overlay.showGreeting;
    }
    if (cached != null) {
      _brightness = cached.brightness;
      _contrast = cached.contrast;
      _saturation = cached.saturation;
      _filter = cached.filter;
    }
    // Each new image starts upright; grade/filter prefs are sticky across sessions.
    _quarterTurns = 0;
    final overlayText = widget.overlay.customText.trim().isNotEmpty
        ? widget.overlay.customText
        : (cached?.customText ?? '');
    _overlayText = TextEditingController(text: overlayText);
    _overlayText.addListener(_onOverlayTextChanged);
    _decoded = _processor.decode(widget.imageBytes);
    if (_decoded != null) {
      _schedulePreview();
    } else {
      _decodeFailed = true;
    }
    _loadPairing();
  }

  void _onOverlayTextChanged() {
    if (!mounted) return;
    _schedulePreview();
  }

  Future<void> _loadPairing() async {
    await DeviceStore.instance.load();
    if (!mounted) return;
    setState(() {
      _paired = DeviceStore.instance.cached;
      _transport = TransportKind.wifi;
    });
  }

  void _invalidateProcessCache() {
    _cachedProcess = null;
    _previewGen++;
  }

  @override
  void dispose() {
    _overlayText.removeListener(_onOverlayTextChanged);
    EditorSettingsCache.instance.update(
      EditorSettingsSnapshot(
        transport: _transport,
        slideshow: _slideshow,
        showDate: _oDate,
        showLocation: _oLocation,
        showGreeting: _oGreeting,
        customText: _overlayText.text,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        filter: _filter,
      ),
    );
    _overlayText.dispose();
    _debounce?.cancel();
    _api.close();
    super.dispose();
  }

  int _previewGen = 0;

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _renderPreview);
  }

  /// 6‑color e‑ink preview — matches what the frame will display (not full RGB).
  void _renderPreview() {
    if (_decoded == null) return;
    final gen = ++_previewGen;
    final args = FrameProcessOnlyArgs(
      imageBytes: widget.imageBytes,
      quarterTurns: _quarterTurns,
      brightness: 1.0 + _brightness * 0.35,
      contrast: 1.0 + _contrast * 0.45,
      saturation: 1.0 + _saturation * 0.45,
      filterIndex: _filter.index,
      overlay: _currentOverlay,
      locationText: _overlayLocationValue,
    );
    compute(isolateFrameEinkPreviewJpeg, args).then((bytes) {
      if (!mounted || gen != _previewGen || bytes == null) return;
      setState(() => _previewBytes = bytes);
    });
  }

  Future<ProcessedFrameResult?> _ensureProcessed() async {
    if (_decoded == null) return null;
    if (_cachedProcess != null) return _cachedProcess;
    final result = await compute(
      isolateFrameProcessOnly,
      FrameProcessOnlyArgs(
        imageBytes: widget.imageBytes,
        quarterTurns: _quarterTurns,
        brightness: 1.0 + _brightness * 0.35,
        contrast: 1.0 + _contrast * 0.45,
        saturation: 1.0 + _saturation * 0.45,
        filterIndex: _filter.index,
        overlay: _currentOverlay,
        locationText: _overlayLocationValue,
      ),
    );
    _cachedProcess = result;
    return result;
  }

  Future<void> _send() async {
    if (_decoded == null) return;
    try {
      await _sendInner();
    } catch (e, st) {
      AppDiagLog.verbose('[Editor] send failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _status = AppDiagLog.userFacingStatus(
          e.toString(),
          fallback: 'Could not send the photo. Try again.',
        );
      });
    }
  }

  Future<void> _sendInner() async {
    if (_paired == null) {
      if (!mounted) return;
      setState(() => _status = 'Connect your frame to send this photo…');
      final result = await SafeNav.push<PairingNavResult>(
        context,
        MaterialPageRoute<PairingNavResult>(
          builder: (_) => const DeviceDiscoveryScreen(openSendAfterSetup: false),
        ),
      );
      await DeviceStore.instance.load();
      await _loadPairing();
      if (!mounted) return;
      if (result?.success != true && _paired == null) {
        setState(() => _status = 'Frame connection cancelled.');
        return;
      }
      if (_paired == null) {
        setState(() => _status = 'No frame paired yet. Scan a frame to continue.');
        return;
      }
    }
    final frame = _paired!;
    final sEarly = AppStrings.of(context);
    if (!frame.canUploadToServer) {
      if (!mounted) return;
      setState(() {
        _status = frame.resolvedFrameTargetCandidates.isEmpty
            ? 'This iPhone pairing has only an iOS Bluetooth UUID, not the frame display ID. Scan the frame pairing QR once, then try upload again.'
            : sEarly.pairingNeedsApiUrl;
      });
      return;
    }
    var activePaired = frame;
    if (!activePaired.isWifiProvisioned) {
      if (!mounted) return;
      setState(() => _status = 'Complete Wi‑Fi setup before sending photos…');
      final setup = await SafeNav.push<PairingNavResult>(
        context,
        MaterialPageRoute<PairingNavResult>(
          builder: (_) => const WifiProvisionScreen(firstTimeSetup: true),
        ),
      );
      await DeviceStore.instance.load();
      if (!mounted || setup?.success != true) return;
      final refreshed = DeviceStore.instance.cached;
      if (refreshed == null || !refreshed.isWifiProvisioned) return;
      activePaired = refreshed;
    }
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _uploading = true;
      _sendSucceeded = false;
      _castLogLines.clear();
      _status = 'Preparing image for frame…';
      _castProgress = null;
      _castProgressIndeterminate = true;
    });
    try {
      if (!mounted) return;
      final s = AppStrings.of(context);
      AppDiagLog.verbose(
        '[Editor] input bytes=${widget.imageBytes.length}',
      );
      final uploadBin = await compute(
        isolateComposeUploadBin,
        ComposeUploadIsolateArgs(
          imageBytes: widget.imageBytes,
          quarterTurns: _quarterTurns,
          brightness: 1.0 + _brightness * 0.35,
          contrast: 1.0 + _contrast * 0.45,
          saturation: 1.0 + _saturation * 0.45,
          filterIndex: _filter.index,
          overlay: _currentOverlay,
          locationText: _overlayLocationValue,
        ),
      );
      if (uploadBin == null) {
        if (!mounted) return;
        setState(() => _status = s.processingFailed);
        return;
      }
      AppDiagLog.verbose('[Editor] upload bin bytes=${uploadBin.length}');

      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final httpName = 'photo_$ts.bin';

      final app = AppSettingsScope.of(context);
      final cloud = await CloudPhotoUploadService.instance.uploadIfConfigured(
        app: app,
        bytes: uploadBin,
        filename: httpName,
      );
      if (cloud != null) {
        if (!cloud.ok) {
          if (!mounted) return;
          setState(() {
            _uploading = false;
            _status = cloud.error;
          });
          return;
        }
        await InAppNotificationStore.instance.cloudUpload(
          provider: cloud.provider,
          fileName: httpName,
        );
        AppDiagLog.log('[Editor] saved to ${cloud.provider} ${cloud.webUrl}');
      }

      final authToken = app.authToken;
      final cast = await FrameCloudCastService.instance.castPhoto(
        api: _api,
        paired: activePaired,
        jpegBytes: uploadBin,
        filename: httpName,
        slideshowStyle: _slideshow.apiValue,
        displaySeconds: widget.displaySeconds,
        strings: s,
        userAuthToken: authToken,
        syncSlideshowAfterSuccess: false,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _appendCastLog(p);
            _status = _userFacingCastStatus(p);
            if (p.phase == CastPhase.success) {
              _castProgress = 1;
              _castProgressIndeterminate = false;
            } else if (p.isTerminal) {
              _castProgress = null;
              _castProgressIndeterminate = false;
            } else {
              _castProgress = p.showIndeterminate ? null : p.progress;
              _castProgressIndeterminate =
                  p.showIndeterminate || p.progress == null;
            }
          });
        },
      );
      if (!mounted) return;
      if (cast.ok) {
        await _finishSuccessfulSend(cast.message, sentJpeg: _previewBytes);
        if (!mounted) return;
        if (widget.queueTotal > 1 && widget.queueIndex < widget.queueTotal) {
          Navigator.of(context).pop(true);
        }
        return;
      }
      setState(() {
        _status = cast.message;
        _sendSucceeded = false;
      });
    } on FrameApiException catch (e) {
      if (!mounted) return;
      var line = AppStrings.of(context).apiError(e);
      try {
        final j = jsonDecode(e.body);
        if (j is Map<String, dynamic> && j['error'] == 'myfm_encode_failed') {
          final hint = j['hint'] as String?;
          final msg = j['message'] as String?;
          if (hint != null && hint.isNotEmpty) {
            line = msg != null && msg.isNotEmpty ? '$hint\n($msg)' : hint;
          }
        }
      } catch (_) {
        /* ignore */
      }
      setState(() => _status = line);
    } on SocketException catch (e) {
      if (!mounted) return;
      final s = AppStrings.of(context);
      final msg = e.message.toLowerCase();
      if (msg.contains('failed host lookup') ||
          msg.contains('no address associated with hostname')) {
        final host = Uri.tryParse(ApiConfig.baseUrl)?.host ?? ApiConfig.baseUrl;
        setState(() {
          _status =
              'Cannot resolve $host. Check DNS/network, or set API_BASE to a reachable URL.';
        });
      } else {
        setState(() => _status = AppDiagLog.userFacingStatus(
              '${s.sendOfflineNoNetworkForWifi} ($e)',
              fallback: s.sendOfflineNoNetworkForWifi,
            ));
      }
    } on TimeoutException catch (e) {
      if (mounted) setState(() => _status = AppStrings.of(context).apiError(e));
    } catch (e) {
      if (mounted) {
        setState(() => _status = AppDiagLog.userFacingStatus(
              '$e',
              fallback: 'Could not send the photo. Try again.',
            ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _castProgress = null;
          _castProgressIndeterminate = false;
        });
      }
    }
  }

  Future<void> _exportForSdCard() async {
    if (_decoded == null) return;
    setState(() {
      _uploading = true;
      _status = null;
    });
    try {
      final s = AppStrings.of(context);
      final result = await _ensureProcessed();
      if (result == null) {
        if (!mounted) return;
        setState(() => _status = s.processingFailed);
        return;
      }
      final name = 'myframe_${DateTime.now().millisecondsSinceEpoch}.bin';
      final disposition = await shareBinForPhysicalSd(
        binBytes: result.binPayload,
        filename: name,
        saveDialogTitle: s.sdExportSaveDialogTitle,
      );
      if (!mounted) return;
      switch (disposition) {
        case SdBinExportDisposition.savedWithPicker:
          await UsageMetricsStore.instance.markSdDetectedNow();
          setState(() => _status = s.sdExportSavedHint);
          break;
        case SdBinExportDisposition.openedShareSheet:
          await UsageMetricsStore.instance.markSdDetectedNow();
          setState(() => _status = s.shareSheetSdHint);
          break;
        case SdBinExportDisposition.cancelled:
          setState(() => _status = s.sdExportCancelledHint);
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = AppDiagLog.userFacingStatus(
              '$e',
              fallback: 'Export failed. Try again.',
            ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final slideshowLabel = _slideshowLabel(s);
    final debugOn = AppSettingsScope.of(context).debugModeEnabled;
    if (_decodeFailed) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text(s.editTitle)),
        body: Center(child: Text(s.decodeError)),
      );
    }
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboardOpen = viewInsets.bottom > 0;
    final previewMaxHeight = keyboardOpen ? 160.0 : double.infinity;

    return DebugSlogOverlay(
      child: PopScope(
      canPop: !_uploading,
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.queueTotal > 1
              ? '${s.editTitle} (${widget.queueIndex}/${widget.queueTotal})'
              : s.editTitle,
        ),
        automaticallyImplyLeading: !_uploading,
        leading: _uploading
            ? null
            : BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        actions: [
          if (debugOn &&
              (_castLogLines.isNotEmpty || (_status?.trim().isNotEmpty ?? false)))
            IconButton(
              tooltip: 'Copy log',
              onPressed: _copyCastDiagnostics,
              icon: const Icon(Icons.copy_outlined),
            ),
          IconButton(
            tooltip: s.rotateTooltip,
            onPressed: _decoded == null
                ? null
                : () {
                    setState(() {
                      _quarterTurns = (_quarterTurns + 1) % 4;
                      _invalidateProcessCache();
                    });
                    _schedulePreview();
                  },
            icon: const Icon(Icons.rotate_right),
          ),
        ],
      ),
      body: _decoded == null
          ? Center(child: Text(_status ?? s.noImage))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + viewInsets.bottom),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (widget.queueTotal > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      s.sendQueueFrameShowsLatest(
                        widget.queueIndex,
                        widget.queueTotal,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: previewMaxHeight),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _previewBytes == null
                          ? const ColoredBox(color: Color(0xFFE5E7EB))
                          : InteractiveViewer(
                              minScale: 1,
                              maxScale: 4,
                              panEnabled: !keyboardOpen,
                              boundaryMargin: const EdgeInsets.all(24),
                              child: Center(
                                child: Image.memory(
                                  _previewBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    s.targetFrameHint(
                      ImageProcessorService.frameWidth,
                      ImageProcessorService.frameHeight,
                    ),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                      _editorSectionTitle(s.editorSectionLook, cs),
                      const SizedBox(height: 4),
                      _slider(
                        label: s.brightness,
                        value: _brightness,
                        onChanged: (v) {
                          setState(() {
                            _brightness = v;
                            _invalidateProcessCache();
                          });
                          _schedulePreview();
                        },
                      ),
                      _slider(
                        label: s.contrast,
                        value: _contrast,
                        onChanged: (v) {
                          setState(() {
                            _contrast = v;
                            _invalidateProcessCache();
                          });
                          _schedulePreview();
                        },
                      ),
                      _slider(
                        label: s.saturation,
                        value: _saturation,
                        onChanged: (v) {
                          setState(() {
                            _saturation = v;
                            _invalidateProcessCache();
                          });
                          _schedulePreview();
                        },
                      ),
                      Text(
                        s.filterLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FrameImageFilter.values.map((f) {
                          final sel = _filter == f;
                          return ChoiceChip(
                            label: Text(_filterLabel(f, s)),
                            selected: sel,
                            onSelected: (_) {
                              setState(() {
                                _filter = f;
                                _invalidateProcessCache();
                              });
                              _schedulePreview();
                            },
                            selectedColor: primary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: sel ? primary : cs.onSurface,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      _editorSectionTitle(s.editorSectionSend, cs),
                      const SizedBox(height: 6),
                      Text(
                        s.editorSendVpsOnlyHelp,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.slideshowStyle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SlideshowStyle.values.map((e) {
                          final on = _slideshow == e;
                          return ChoiceChip(
                            label: Text(_slideshowChoiceLabel(e, s)),
                            selected: on,
                            onSelected: (_) => setState(() => _slideshow = e),
                            selectedColor: primary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: on ? primary : cs.onSurface,
                              fontWeight: on
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.overlayOptions,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.overlayOnPhotoHelper,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in [
                            'Love',
                            'Family',
                            'Congrats',
                            'Happy Birthday',
                            'Best wishes',
                            'Holiday',
                          ])
                            ActionChip(
                              label: Text(w),
                              onPressed: () {
                                final t = _overlayText.text.trim();
                                final next = t.isEmpty ? w : '$t $w';
                                _overlayText.text = next;
                                _overlayText.selection =
                                    TextSelection.collapsed(
                                      offset: next.length,
                                    );
                                _schedulePreview();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _overlayText,
                        maxLength: 40,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: s.overlayCustomTextLabel,
                          hintText: s.overlayCustomTextHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        value: _oGreeting,
                        onChanged: (v) {
                          setState(() => _oGreeting = v);
                          _schedulePreview();
                        },
                        title: Text(s.overlayGreetingLabel),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile.adaptive(
                        value: _oLocation,
                        onChanged: (v) {
                          setState(() => _oLocation = v);
                          _schedulePreview();
                        },
                        title: Text(s.overlayLocationLabel),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile.adaptive(
                        value: _oDate,
                        onChanged: (v) {
                          setState(() => _oDate = v);
                          _schedulePreview();
                        },
                        title: Text(s.overlayDateLabel),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _paired == null
                            ? s.pairingLineUnpaired(
                                s.transportLabelVps,
                                slideshowLabel,
                              )
                            : s.pairingLinePaired(
                                _paired!.listDisplayTitle(s),
                                _paired!.resolvedApiBaseUrl ?? _paired!.apiUrl,
                                s.transportLabelVps,
                                slideshowLabel,
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (_paired != null && !_paired!.canUploadToServer) ...[
                        const SizedBox(height: 10),
                        Text(
                          s.pairingNeedsApiUrl,
                          style: TextStyle(fontSize: 12, color: cs.error),
                        ),
                      ],
                      if (debugOn &&
                          _paired != null &&
                          (_uploading || _castLogLines.isNotEmpty)) ...[
                        const SizedBox(height: 10),
                        _CastDebugTargetsPanel(paired: _paired!),
                        if (_castLogLines.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _CastActivityLog(
                            lines: List<String>.from(_castLogLines),
                            onCopy: _copyCastDiagnostics,
                          ),
                        ],
                      ],
                      if (_paired == null) ...[
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final result = await Navigator.of(context).push<PairingNavResult>(
                              MaterialPageRoute<PairingNavResult>(
                                builder: (_) => const DeviceDiscoveryScreen(),
                              ),
                            );
                            await _loadPairing();
                            PairingFlowNav.onComplete(result);
                          },
                          icon: const Icon(Icons.bluetooth_searching),
                          label: Text(s.scanDeviceTitle),
                        ),
                      ],
                      if (_uploading &&
                          (_castProgress != null ||
                              _castProgressIndeterminate)) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _castProgressIndeterminate
                              ? null
                              : _castProgress,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                      if (_status != null) ...[
                        const SizedBox(height: 12),
                        debugOn
                            ? SelectableText(
                                _status!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _uploading
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant,
                                ),
                              )
                            : Text(
                                _status!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _uploading
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                      ],
                      const SizedBox(height: 24),
                      if (_sendSucceeded) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _leaveEditorAfterSend,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Done — sent to frame'),
                        ),
                        const SizedBox(height: 10),
                      ] else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _uploading ? null : _send,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(_uploading ? s.working : s.processUpload),
                        ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _exportForSdCard,
                        icon: const Icon(Icons.sd_card),
                        label: Text(s.exportSdButton),
                      ),
                ],
              ),
            ),
      ),
    ),
    );
  }

  String _slideshowLabel(AppStrings s) {
    return _slideshowChoiceLabel(_slideshow, s);
  }

  String _slideshowChoiceLabel(SlideshowStyle e, AppStrings s) {
    return switch (e) {
      SlideshowStyle.fade => s.styleFade,
      SlideshowStyle.kenBurns => s.styleKenBurns,
      SlideshowStyle.grid => s.styleGrid,
      SlideshowStyle.random => s.styleRandom,
    };
  }

  String _filterLabel(FrameImageFilter f, AppStrings s) {
    return switch (f) {
      FrameImageFilter.none => s.filterOriginal,
      FrameImageFilter.grayscale => s.filterGrayscale,
      FrameImageFilter.sepia => s.filterSepia,
      FrameImageFilter.warm => s.filterWarm,
      FrameImageFilter.cool => s.filterCool,
    };
  }

  Widget _editorSectionTitle(String title, ColorScheme cs) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value.toStringAsFixed(2)),
          ],
        ),
        Slider(
          min: -1,
          max: 1,
          value: value.clamp(-1.0, 1.0),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CastActivityLog extends StatelessWidget {
  const _CastActivityLog({
    required this.lines,
    required this.onCopy,
  });

  final List<String> lines;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mono = TextStyle(
      fontSize: 10,
      fontFamily: 'monospace',
      color: cs.onSurface,
      height: 1.35,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cast activity',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy log',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onCopy,
                icon: Icon(Icons.copy_outlined, size: 18, color: cs.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            lines.join('\n'),
            style: mono,
          ),
        ],
      ),
    );
  }
}

/// Cast targets (device_id / API) — shown while uploading for troubleshooting.
class _CastDebugTargetsPanel extends StatelessWidget {
  const _CastDebugTargetsPanel({required this.paired});

  final PairedFrame paired;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uploadId = FrameCloudCastService.instance.uploadDeviceId(paired);
    final lines = <String>[
      'Paired deviceId (stored): ${paired.deviceId}',
      'bleRemoteId: ${paired.bleRemoteId ?? '—'}',
      'Upload device_id (same as Android): $uploadId',
      'API base URL: ${paired.resolvedApiBaseUrl ?? '—'}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frame cast',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Text(
              line,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: cs.onSurface,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
