import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
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
import '../services/weather_service.dart';
import '../settings/app_settings.dart';
import '../l10n/app_strings.dart';
import '../navigation/pairing_flow_nav.dart';
import '../models/pairing_nav_result.dart';
import '../models/send_overlay_options.dart';
import '../theme/app_theme.dart';
import 'device_discovery_screen.dart';
import 'wifi_provision_screen.dart';

const Color _kEditorRed = AppTheme.primaryRed;

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
    this.isAiGenerated = false,
    this.autoSendAfterLoad = false,
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

  final bool isAiGenerated;

  /// When true (gallery share flow), upload starts once pairing is loaded.
  final bool autoSendAfterLoad;

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

  SendOverlayOptions get _currentOverlay {
    const palette = [
      0xFF000000,
      0xFFFFFFFF,
      0xFFFFFF00,
      0xFFFF0000,
      0xFF0000FF,
      0xFF00FF00,
    ];
    final color = (_textColor >= 0 && _textColor < palette.length)
        ? palette[_textColor]
        : 0xFFFFFFFF;
    return SendOverlayOptions(
      showDate: _oDate,
      showLocation: _oLocation && !_oWeather,
      showGreeting: _oGreeting,
      showWeather: _oWeather,
      customText: '',
      greetingCustom: widget.overlay.greetingCustom,
      centerText: _overlayText.text.trim(),
      centerTextColor: color,
      centerTextSize: _textSize,
      centerSticker: _selectedSticker ?? '',
      stickerAlignX: (_stickerAlignX + 1) / 2, // -1..1 → 0..1
      stickerAlignY: (_stickerAlignY + 1) / 2,
      stickerSize: _stickerSize,
      weatherText: _weatherLine,
    );
  }

  String _weatherLine = '';
  bool _weatherLoading = false;
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

  Future<void> _finishSuccessfulSend(
    String status, {
    Uint8List? sentJpeg,
  }) async {
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
        frameName:
            _paired?.frameName ??
            _paired?.listDisplayTitle(_strings ?? AppStrings(AppLocale.en)),
      ),
    );
    if (sentJpeg != null && sentJpeg.isNotEmpty) {
      unawaited(
        _saveSentPhotoToGallery(
          sentJpeg,
          persistPath: widget.galleryPersistPath,
        ),
      );
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

  Future<void> _saveCloudCopyIfConfigured({
    required AppSettings app,
    required ComposeUploadIsolateArgs composeArgs,
    required String filename,
  }) async {
    if (CloudPhotoUploadService.instance.backendFor(app) ==
        PhotoStorageBackend.vps) {
      return;
    }
    try {
      final jpeg = await compute(isolateComposeCloudJpeg, composeArgs);
      if (jpeg == null || jpeg.isEmpty) {
        AppDiagLog.log('[Editor] cloud copy skipped: JPEG render failed');
        return;
      }
      final cloud = await CloudPhotoUploadService.instance.uploadIfConfigured(
        app: app,
        bytes: jpeg,
        filename: filename,
      );
      if (cloud == null) return;
      if (!cloud.ok) {
        AppDiagLog.log('[Editor] cloud copy failed: ${cloud.error}');
        return;
      }
      await InAppNotificationStore.instance.cloudUpload(
        provider: cloud.provider,
        fileName: filename,
      );
      AppDiagLog.log('[Editor] saved to ${cloud.provider} ${cloud.webUrl}');
    } catch (e, st) {
      AppDiagLog.log('[Editor] cloud copy failed: $e\n$st');
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
    _transport = TransportKind.wifi;
    _slideshow = cached?.slideshow ?? widget.slideshow;
    // Fresh pick: plain image only — no sticky overlays / filters / grade.
    _oDate = false;
    _oLocation = false;
    _oGreeting = false;
    _oWeather = false;
    _weatherLine = '';
    _brightness = 0;
    _contrast = 0;
    _saturation = 0;
    _filter = FrameImageFilter.none;
    _quarterTurns = 0;
    _overlayText = TextEditingController();
    _overlayText.addListener(_onOverlayTextChanged);
    _decoded = _processor.decode(widget.imageBytes);
    if (_decoded != null) {
      _previewBytes = widget.imageBytes; // instant first frame
      _warmFastPreviewCache();
    } else {
      _decodeFailed = true;
    }
    _loadPairing().then((_) {
      if (!mounted || !widget.autoSendAfterLoad || _decoded == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _uploading || _sendSucceeded) return;
        unawaited(_send());
      });
    });
  }

  void _onOverlayTextChanged() {
    if (!mounted) return;
    setState(() {});
    _invalidateProcessCache();
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
    // Warm the E-ink Preview JPEG in the background so the button opens instantly.
    _warmFastPreviewCache();
  }

  int _previewGen = 0;
  Timer? _previewWarmTimer;

  void _warmFastPreviewCache() {
    _previewWarmTimer?.cancel();
    _previewWarmTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _decoded == null) return;
      final gen = ++_previewGen;
      final args = _previewArgs();
      compute(isolateFastPreviewJpeg, args).then((bytes) {
        if (!mounted || gen != _previewGen || bytes == null) return;
        _previewBytes = bytes;
      });
    });
  }

  void _schedulePreview({int delayMs = 80}) {
    // Live preview is Flutter-widget based (instant). Isolate only for send cache.
    _cachedProcess = null;
  }

  /// Kept for six-color / export paths that still need a baked JPEG.
  void _renderPreview() {
    if (_decoded == null) return;
    final gen = ++_previewGen;
    final args = _previewArgs();
    compute(isolateFastPreviewJpeg, args).then((bytes) {
      if (!mounted || gen != _previewGen || bytes == null) return;
      setState(() => _previewBytes = bytes);
    });
  }

  @override
  void dispose() {
    _overlayText.removeListener(_onOverlayTextChanged);
    EditorSettingsCache.instance.update(
      EditorSettingsSnapshot(
        transport: _transport,
        slideshow: _slideshow,
        showDate: false,
        showLocation: false,
        showGreeting: false,
        customText: '',
        brightness: 0,
        contrast: 0,
        saturation: 0,
        filter: FrameImageFilter.none,
      ),
    );
    _overlayText.dispose();
    _textController.dispose();
    _weatherTempController.dispose();
    _previewTransform.dispose();
    _debounce?.cancel();
    _previewWarmTimer?.cancel();
    _api.close();
    super.dispose();
  }

  Future<ProcessedFrameResult?> _ensureProcessed() async {
    if (_decoded == null) return null;
    if (_cachedProcess != null) return _cachedProcess;
    final result = await compute(isolateFrameProcessOnly, _previewArgs());
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
          builder: (_) =>
              const DeviceDiscoveryScreen(openSendAfterSetup: false),
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
        setState(
          () => _status = 'No frame paired yet. Scan a frame to continue.',
        );
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
      final app = AppSettingsScope.of(context);
      AppDiagLog.verbose('[Editor] input bytes=${widget.imageBytes.length}');
      final composeArgs = _composeArgs();
      final uploadBin = await compute(isolateComposeUploadBin, composeArgs);
      if (uploadBin == null) {
        if (!mounted) return;
        setState(() => _status = s.processingFailed);
        return;
      }
      AppDiagLog.verbose('[Editor] upload bin bytes=${uploadBin.length}');

      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final httpName = 'photo_$ts.bin';

      final authToken = app.authToken;
      unawaited(
        _saveCloudCopyIfConfigured(
          app: app,
          composeArgs: composeArgs,
          filename: 'photo_$ts.jpg',
        ),
      );
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
        setState(
          () => _status = AppDiagLog.userFacingStatus(
            '${s.sendOfflineNoNetworkForWifi} ($e)',
            fallback: s.sendOfflineNoNetworkForWifi,
          ),
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) setState(() => _status = AppStrings.of(context).apiError(e));
    } catch (e) {
      if (mounted) {
        setState(
          () => _status = AppDiagLog.userFacingStatus(
            '$e',
            fallback: 'Could not send the photo. Try again.',
          ),
        );
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
        setState(
          () => _status = AppDiagLog.userFacingStatus(
            '$e',
            fallback: 'Export failed. Try again.',
          ),
        );
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
    final debugOn = AppSettingsScope.of(context).debugModeEnabled;
    if (_decodeFailed) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(s.editTitle),
          leadingWidth: 44,
          leading: IconButton(
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Theme.of(context).platform == TargetPlatform.iOS ||
                      Theme.of(context).platform == TargetPlatform.macOS
                  ? CupertinoIcons.back
                  : Icons.arrow_back,
              size: 22,
            ),
          ),
        ),
        body: Center(child: Text(s.decodeError)),
      );
    }
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboardOpen = viewInsets.bottom > 0;

    return DebugSlogOverlay(
      child: PopScope(
        canPop: !_uploading,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              widget.queueTotal > 1
                  ? '${s.editTitle} (${widget.queueIndex}/${widget.queueTotal})'
                  : s.editTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A0A0A),
              ),
            ),
            automaticallyImplyLeading: false,
            leadingWidth: 44,
            leading: _uploading
                ? null
                : IconButton(
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Theme.of(context).platform == TargetPlatform.iOS ||
                              Theme.of(context).platform == TargetPlatform.macOS
                          ? CupertinoIcons.back
                          : Icons.arrow_back,
                      size: 22,
                      color: const Color(0xFF0A0A0A),
                    ),
                  ),
            actions: [
              if (debugOn &&
                  (_castLogLines.isNotEmpty ||
                      (_status?.trim().isNotEmpty ?? false)))
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  onPressed: _copyCastDiagnostics,
                  child: const Icon(CupertinoIcons.doc_on_doc, size: 22, color: Color(0xFF0A0A0A)),
                ),
              CupertinoButton(
                padding: const EdgeInsets.only(right: 12),
                onPressed: _decoded == null
                    ? null
                    : () {
                        setState(() {
                          _quarterTurns = (_quarterTurns + 1) % 4;
                          _invalidateProcessCache();
                        });
                      },
                child: const Icon(CupertinoIcons.refresh, size: 22, color: Color(0xFF0A0A0A)),
              ),
            ],
          ),
          body: _decoded == null
              ? Center(child: Text(_status ?? s.noImage))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: _einkPreviewOn ? _kEditorRed.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () {
                              setState(() => _einkPreviewOn = true);
                              _showFastRealPreview();
                            },
                            child: Text(
                              'E-ink Preview',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _einkPreviewOn ? _kEditorRed : const Color(0xFF374151),
                              ),
                            ),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            onPressed: _clearEditorOverlays,
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                color: _kEditorRed,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final screenH = MediaQuery.sizeOf(context).height;
                          final maxH = keyboardOpen
                              ? math.min(120.0, screenH * 0.16)
                              : screenH * 0.30;
                          final height = maxH.clamp(100.0, 280.0);
                          return Center(
                            child: SizedBox(
                              width: height * 3 / 4,
                              height: height,
                              child: _buildPreviewStage(cs, keyboardOpen),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildToolSection(context, s, cs, primary, keyboardOpen),
                    ),
                    if (!keyboardOpen) _buildBottomBar(context, s, cs, primary, debugOn),
                  ],
                ),
        ),
      ),
    );
  }

  String _slideshowChoiceLabel(SlideshowStyle e, AppStrings s) {
    return switch (e) {
      SlideshowStyle.fade => s.styleFade,
      SlideshowStyle.kenBurns => s.styleKenBurns,
      SlideshowStyle.grid => s.styleGrid,
      SlideshowStyle.random => s.styleRandom,
    };
  }

  // ─── Tool tab state ──────────────────────────────────────────────
  String _activeTool = 'filters';
  bool _einkPreviewOn = true;
  final TransformationController _previewTransform = TransformationController();

  // ─── Crop state ───────────────────────────────────────────────────
  String _cropAspect = '3:4';
  double _cropZoom = 100;
  bool _flipH = false;
  bool _flipV = false;
  double _cropPanX = 0;
  double _cropPanY = 0;

  double get _cropAspectRatioValue {
    switch (_cropAspect) {
      case 'free':
      case '3:4':
        return 3 / 4;
      case '1:1':
        return 1;
      case '4:3':
        return 4 / 3;
      case '16:9':
        return 16 / 9;
      case '9:16':
        return 9 / 16;
      case 'original':
        final img = _decoded;
        if (img == null || img.height == 0) return 3 / 4;
        return img.width / img.height;
      default:
        return 3 / 4;
    }
  }

  FrameProcessOnlyArgs _previewArgs() {
    return FrameProcessOnlyArgs(
      imageBytes: widget.imageBytes,
      quarterTurns: _quarterTurns,
      brightness: 1.0 + _brightness * 0.35,
      contrast: 1.0 + _contrast * 0.45,
      saturation: 1.0 + _saturation * 0.45,
      filterIndex: _filter.index,
      overlay: _currentOverlay,
      locationText: _overlayLocationValue,
      flipH: _flipH,
      flipV: _flipV,
      cropAspect: _cropAspectRatioValue,
      cropZoom: (_cropZoom / 100).clamp(1.0, 3.0),
      cropPanX: _cropPanX,
      cropPanY: _cropPanY,
    );
  }

  ComposeUploadIsolateArgs _composeArgs() {
    return ComposeUploadIsolateArgs(
      imageBytes: widget.imageBytes,
      quarterTurns: _quarterTurns,
      brightness: 1.0 + _brightness * 0.35,
      contrast: 1.0 + _contrast * 0.45,
      saturation: 1.0 + _saturation * 0.45,
      filterIndex: _filter.index,
      overlay: _currentOverlay,
      locationText: _overlayLocationValue,
      flipH: _flipH,
      flipV: _flipV,
      cropAspect: _cropAspectRatioValue,
      cropZoom: (_cropZoom / 100).clamp(1.0, 3.0),
      cropPanX: _cropPanX,
      cropPanY: _cropPanY,
    );
  }

  // ─── Text state ───────────────────────────────────────────────────
  final _textController = TextEditingController();
  double _textSize = 38;
  int _textColor = 1; // white
  bool _textBold = false;
  double _textRotation = 0;

  // ─── Weather state ────────────────────────────────────────────────
  bool _oWeather = false;
  final _weatherTempController = TextEditingController();

  // ─── Sticker state ────────────────────────────────────────────────
  String? _selectedSticker;
  double _stickerRotation = 0;
  double _stickerAlignX = 0.35; // slightly right of center (-1..1)
  double _stickerAlignY = -0.15;
  double _stickerSize = 28;

  // ─── Border state ─────────────────────────────────────────────────
  String _borderStyle = 'none';

  String _filterLabel(FrameImageFilter f, AppStrings s) {
    return switch (f) {
      FrameImageFilter.none => s.filterOriginal,
      FrameImageFilter.grayscale => s.filterGrayscale,
      FrameImageFilter.sepia => s.filterSepia,
      FrameImageFilter.warm => s.filterWarm,
      FrameImageFilter.cool => s.filterCool,
      FrameImageFilter.contrast => 'Contrast',
      FrameImageFilter.vivid => 'Vivid',
      FrameImageFilter.vintage => 'Vintage',
    };
  }

  List<ColorFilter?> get _filterPreviewMatrices => [
        null, // none
        const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        const ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        const ColorFilter.matrix(<double>[
          1.1, 0.05, 0, 0, 8,
          0.05, 1.05, 0, 0, 4,
          0, 0, 0.9, 0, -6,
          0, 0, 0, 1, 0,
        ]),
        const ColorFilter.matrix(<double>[
          0.9, 0, 0.05, 0, -6,
          0, 1.02, 0.05, 0, 2,
          0.05, 0.05, 1.15, 0, 10,
          0, 0, 0, 1, 0,
        ]),
        const ColorFilter.matrix(<double>[
          1.25, 0, 0, 0, -20,
          0, 1.25, 0, 0, -20,
          0, 0, 1.25, 0, -20,
          0, 0, 0, 1, 0,
        ]),
        const ColorFilter.matrix(<double>[
          1.15, -0.05, -0.05, 0, 0,
          -0.05, 1.2, -0.05, 0, 0,
          -0.05, -0.05, 1.25, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        const ColorFilter.matrix(<double>[
          0.5, 0.4, 0.1, 0, 10,
          0.3, 0.5, 0.1, 0, 5,
          0.2, 0.3, 0.3, 0, 0,
          0, 0, 0, 1, 0,
        ]),
      ];

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

  void _clearEditorOverlays() {
    setState(() {
      _oDate = false;
      _oLocation = false;
      _oGreeting = false;
      _oWeather = false;
      _overlayText.clear();
      _textController.clear();
      _selectedSticker = null;
      _borderStyle = 'none';
      _invalidateProcessCache();
    });
  }

  BoxDecoration _previewDecoration(ColorScheme cs) {
    switch (_borderStyle) {
      case 'thinBlack':
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 2),
        );
      case 'thickWhite':
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        );
      case 'polaroid':
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: const Border(
            top: BorderSide(color: Colors.white, width: 10),
            left: BorderSide(color: Colors.white, width: 10),
            right: BorderSide(color: Colors.white, width: 10),
            bottom: BorderSide(color: Colors.white, width: 28),
          ),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        );
      case 'film':
        return BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black, width: 12),
        );
      case 'rounded':
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.outlineVariant),
        );
      case 'double':
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black87, width: 4),
          boxShadow: const [
            BoxShadow(color: Colors.white, spreadRadius: 3),
            BoxShadow(color: Colors.black26, blurRadius: 6),
          ],
        );
      default:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        );
    }
  }

  Widget _filteredImage() {
    final idx = _filter.index.clamp(0, _filterPreviewMatrices.length - 1);
    final matrix = _filterPreviewMatrices[idx];
    final b = 1.0 + _brightness * 0.35;
    final c = 1.0 + _contrast * 0.45;
    final t = (1.0 - c) * 128.0;
    final grade = ColorFilter.matrix(<double>[
      c, 0, 0, 0, t + (b - 1) * 40,
      0, c, 0, 0, t + (b - 1) * 40,
      0, 0, c, 0, t + (b - 1) * 40,
      0, 0, 0, 1, 0,
    ]);
    Widget img = Image.memory(
      widget.imageBytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
    );
    img = ColorFiltered(colorFilter: grade, child: img);
    if (matrix != null) {
      img = ColorFiltered(colorFilter: matrix, child: img);
    }
    return img;
  }

  Widget _buildLiveOverlayStack() {
    const palette = [
      Colors.black,
      Colors.white,
      Colors.yellow,
      Colors.red,
      Colors.blue,
      Colors.green,
    ];
    final textColor = (_textColor >= 0 && _textColor < palette.length)
        ? palette[_textColor]
        : Colors.white;
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Match baked arial24 on ~800px frame work image (~3% of width).
        final barFont = (w * 0.032).clamp(9.0, 13.0);
        final stickerPx = (w * 0.085 * (_stickerSize / 28)).clamp(14.0, 48.0);
        final barLines = <Widget>[];
        if (_oWeather && _weatherLine.trim().isNotEmpty) {
          barLines.add(
            Text(
              _weatherLine,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: barFont,
                height: 1.15,
              ),
            ),
          );
        }
        if (_oDate) {
          barLines.add(
            Text(
              dateStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: barFont,
                height: 1.15,
              ),
            ),
          );
        }
        final draft = _overlayText.text.trim();
        if (draft.isNotEmpty) {
          // Bar text matches E-ink bake (fixed arial24) — ignore large UI size slider.
          barLines.add(
            Text(
              draft,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: _textBold ? FontWeight.w800 : FontWeight.w600,
                fontSize: barFont,
                height: 1.15,
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (_selectedSticker != null)
              Align(
                alignment: Alignment(_stickerAlignX, _stickerAlignY),
                child: Transform.rotate(
                  angle: _stickerRotation * math.pi / 180,
                  child: _selectedSticker == '♥'
                      ? Icon(
                          Icons.favorite,
                          color: const Color(0xFFE5252A),
                          size: stickerPx,
                        )
                      : Text(
                          _selectedSticker!,
                          style: TextStyle(fontSize: stickerPx, height: 1),
                        ),
                ),
              ),
            if (barLines.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 120 / 255),
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: (w * 0.025).clamp(6.0, 12.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < barLines.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
                          child: barLines[i],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewStage(ColorScheme cs, bool keyboardOpen) {
    final zoom = (_cropZoom / 100).clamp(1.0, 3.0);
    final aspect = _cropAspectRatioValue;
    return Container(
      decoration: _previewDecoration(cs),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),
          Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onPanUpdate: keyboardOpen
                          ? null
                          : (d) {
                              if (_activeTool == 'crop') {
                                setState(() {
                                  _cropPanX = (_cropPanX + d.delta.dx / 90).clamp(-1.0, 1.0);
                                  _cropPanY = (_cropPanY + d.delta.dy / 90).clamp(-1.0, 1.0);
                                });
                                _invalidateProcessCache();
                              } else if (_activeTool == 'stickers' && _selectedSticker != null) {
                                setState(() {
                                  _stickerAlignX = (_stickerAlignX + d.delta.dx / 120).clamp(-0.85, 0.85);
                                  _stickerAlignY = (_stickerAlignY + d.delta.dy / 120).clamp(-0.85, 0.85);
                                });
                                _invalidateProcessCache();
                              }
                            },
                      child: Transform(
                        alignment: Alignment.center,
                        transform: () {
                          final m = Matrix4.identity();
                          m.translateByDouble(_cropPanX * 40.0, _cropPanY * 40.0, 0, 1);
                          m.rotateZ(_quarterTurns * math.pi / 2);
                          m.scaleByDouble(
                            _flipH ? -zoom : zoom,
                            _flipV ? -zoom : zoom,
                            1,
                            1,
                          );
                          return m;
                        }(),
                        child: _filteredImage(),
                      ),
                    ),
                    // On the photo bounds so weather/date/text match E-ink Preview.
                    IgnorePointer(child: _buildLiveOverlayStack()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildToolSection(
    BuildContext context,
    AppStrings s,
    ColorScheme cs,
    Color primary,
    bool keyboardOpen,
  ) {
    return Column(
      children: [
        // Horizontal tool tabs
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _toolTab(s.filterLabel, 'filters', Icons.tune, cs),
              _toolTab('Crop', 'crop', Icons.crop, cs),
              _toolTab('Weather', 'weather', Icons.wb_sunny_outlined, cs),
              _toolTab('Date', 'date', Icons.date_range, cs),
              _toolTab('Text', 'text', Icons.text_fields, cs),
              _toolTab('Sticker', 'stickers', Icons.emoji_emotions_outlined, cs),
              _toolTab('Border', 'border', Icons.border_style, cs),
            ],
          ),
        ),
        const Divider(height: 1),
        // Active tool panel
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildActiveToolPanel(s, cs, primary),
          ),
        ),
      ],
    );
  }

  Widget _toolTab(String label, String tool, IconData icon, ColorScheme cs) {
    final active = _activeTool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => setState(() => _activeTool = tool),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? _kEditorRed : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? Colors.white : const Color(0xFF4B5563)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveToolPanel(AppStrings s, ColorScheme cs, Color primary) {
    switch (_activeTool) {
      case 'crop':
        return _buildCropPanel(s, cs, primary);
      case 'weather':
        return _buildWeatherPanel(s, cs);
      case 'date':
        return _buildDatePanel(s, cs);
      case 'text':
        return _buildTextPanel(s, cs, primary);
      case 'stickers':
        return _buildStickerPanel(s, cs);
      case 'border':
        return _buildBorderPanel(s, cs);
      default:
        return _buildFilterPanel(s, cs, primary);
    }
  }

  Widget _buildFilterPanel(AppStrings s, ColorScheme cs, Color primary) {
    final matrices = _filterPreviewMatrices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: FrameImageFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final f = FrameImageFilter.values[index];
              final sel = _filter == f;
              final matrix = matrices[index];
              Widget thumb = Image.memory(
                widget.imageBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              );
              if (matrix != null) {
                thumb = ColorFiltered(colorFilter: matrix, child: thumb);
              }
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _filter = f;
                    _invalidateProcessCache();
                  });
                },
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? _kEditorRed : cs.outlineVariant,
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: thumb,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _filterLabel(f, s),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sel ? _kEditorRed : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _slider(
          label: s.brightness,
          value: _brightness,
          onChanged: (v) {
            setState(() {
              _brightness = v;
              _invalidateProcessCache();
            });
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
          },
        ),
      ],
    );
  }

  Widget _buildCropPanel(AppStrings s, ColorScheme cs, Color primary) {
    final aspects = ['Free', 'Original', '1:1', '3:4', '4:3', '16:9', '9:16'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: aspects.map((a) {
              final key = a.toLowerCase();
              final sel = _cropAspect == key;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: sel ? _kEditorRed : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _cropAspect = key;
                        _cropPanX = 0;
                        _cropPanY = 0;
                        _invalidateProcessCache();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        a,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _iconAction(Icons.rotate_left, 'Left 90', () {
                setState(() {
                  _quarterTurns = (_quarterTurns + 3) % 4;
                  _invalidateProcessCache();
                });
              }),
              _iconAction(Icons.rotate_right, 'Right 90', () {
                setState(() {
                  _quarterTurns = (_quarterTurns + 1) % 4;
                  _invalidateProcessCache();
                });
              }),
              _iconAction(Icons.flip, 'Flip H', () {
                setState(() {
                  _flipH = !_flipH;
                  _invalidateProcessCache();
                });
              }),
              _iconAction(Icons.swap_vert, 'Flip V', () {
                setState(() {
                  _flipV = !_flipV;
                  _invalidateProcessCache();
                });
              }),
              _iconAction(Icons.restart_alt, 'Reset', _resetCropState),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Text('Zoom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Expanded(
              child: Slider(
                value: _cropZoom,
                min: 100,
                max: 300,
                activeColor: _kEditorRed,
                onChanged: (v) {
                  setState(() => _cropZoom = v);
                  _invalidateProcessCache();
                },
                onChangeEnd: (_) => _invalidateProcessCache(),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${_cropZoom.toInt()}%',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        Text(
          'Drag the photo to reposition. Frame stays 3:4.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildWeatherPanel(AppStrings s, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          value: _oWeather,
          onChanged: (v) => _onWeatherToggled(v),
          title: const Text('Show weather'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeTrackColor: _kEditorRed,
        ),
        if (_weatherLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2, color: _kEditorRed),
          ),
        if (_weatherLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _weatherLine,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        TextFormField(
          controller: _weatherTempController,
          decoration: const InputDecoration(
            labelText: 'Override temperature (optional)',
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            if (!_oWeather) return;
            final t = v.trim();
            if (t.isNotEmpty) {
              setState(() {
                _weatherLine = '☀ $t°C';
                _invalidateProcessCache();
              });
            } else {
              unawaited(_loadRealWeather());
            }
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Turns on location permission to load live weather for your device.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _onWeatherToggled(bool enabled) async {
    if (!enabled) {
      setState(() {
        _oWeather = false;
        _weatherLoading = false;
        _invalidateProcessCache();
      });
      return;
    }

    setState(() {
      _oWeather = true;
      _weatherLoading = true;
    });

    final ok = await WeatherService.instance.ensureLocationPermission();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _oWeather = false;
        _weatherLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Location permission is needed for live weather.'),
        ),
      );
      return;
    }

    await _loadRealWeather();
  }

  Future<void> _loadRealWeather() async {
    setState(() => _weatherLoading = true);
    final snap = await WeatherService.instance.fetchCurrent(force: true);
    if (!mounted) return;
    if (snap == null) {
      setState(() {
        _weatherLoading = false;
        _weatherLine = _weatherTempController.text.trim().isEmpty
            ? '☀ --°C'
            : '☀ ${_weatherTempController.text.trim()}°C';
        _invalidateProcessCache();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not load weather. Check location and try again.'),
        ),
      );
      return;
    }
    setState(() {
      _weatherLoading = false;
      _weatherLine = snap.line;
      _weatherTempController.text = '${snap.tempC}';
      _invalidateProcessCache();
    });
  }

  Widget _buildDatePanel(AppStrings s, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          value: _oDate,
          onChanged: (v) {
            setState(() {
              _oDate = v;
              _invalidateProcessCache();
            });
          },
          title: const Text('Show date/time'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeTrackColor: _kEditorRed,
        ),
        Text(
          'When on, the current date and time are added at the bottom of the frame.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildTextPanel(AppStrings s, ColorScheme cs, Color primary) {
    const palette = [
      Colors.black,
      Colors.white,
      Colors.yellow,
      Colors.red,
      Colors.blue,
      Colors.green,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLength: 240,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Happy BirthDay',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kEditorRed,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: () {
                final draft = _textController.text.trim();
                if (draft.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Type something first'),
                    ),
                  );
                  return;
                }
                setState(() {
                  _overlayText.text = draft;
                  _textController.text = draft;
                  _invalidateProcessCache();
                });
              },
              child: const Text('Add Text', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        Row(
          children: [
            Text('Size ${_textSize.toInt()}px', style: const TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: _textSize,
                min: 12,
                max: 120,
                activeColor: _kEditorRed,
                onChanged: (v) {
                  setState(() => _textSize = v);
                  _invalidateProcessCache();
                },
                onChangeEnd: (_) => _invalidateProcessCache(),
              ),
            ),
          ],
        ),
        Row(
          children: [
            ...List.generate(6, (i) {
              return GestureDetector(
                onTap: () {
                  setState(() => _textColor = i);
                  _invalidateProcessCache();
                },
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: palette[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _textColor == i ? _kEditorRed : const Color(0xFFDADDE5),
                      width: _textColor == i ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Bold'),
              selected: _textBold,
              onSelected: (v) => setState(() => _textBold = v),
              selectedColor: _kEditorRed,
              labelStyle: TextStyle(color: _textBold ? Colors.white : cs.onSurface),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
            _iconAction(Icons.rotate_left, '', () => setState(() => _textRotation -= 15)),
            _iconAction(Icons.rotate_right, '', () => setState(() => _textRotation += 15)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Drag text on the photo to move it.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildStickerPanel(AppStrings s, ColorScheme cs) {
    const stickers = ['♥', '★', '→', '◖', '●', '▲', '✚', '☀'];
    const labels = ['Heart', 'Star', 'Arrow', 'Bubble', 'Circle', 'Triangle', 'Holiday', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(8, (i) {
            final selected = _selectedSticker == stickers[i];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSticker = stickers[i];
                  // Default slightly right of center.
                  if (_stickerAlignX.abs() < 0.05 && _stickerAlignY.abs() < 0.05) {
                    _stickerAlignX = 0.35;
                    _stickerAlignY = -0.15;
                  }
                  _invalidateProcessCache();
                });
              },
              child: Container(
                width: 72,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: selected ? Border.all(color: _kEditorRed, width: 2) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    stickers[i] == '♥'
                        ? const Icon(Icons.favorite, color: Color(0xFFE5252A), size: 22)
                        : Text(stickers[i], style: const TextStyle(fontSize: 20)),
                    Text(labels[i], style: const TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Expanded(
              child: Slider(
                value: _stickerSize,
                min: 16,
                max: 64,
                activeColor: _kEditorRed,
                onChanged: (v) {
                  setState(() => _stickerSize = v);
                  _invalidateProcessCache();
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            _iconAction(Icons.rotate_left, '', () {
              setState(() => _stickerRotation -= 15);
              _invalidateProcessCache();
            }),
            _iconAction(Icons.rotate_right, '', () {
              setState(() => _stickerRotation += 15);
              _invalidateProcessCache();
            }),
            _iconAction(Icons.restart_alt, 'Reset', () {
              setState(() {
                _stickerAlignX = 0.35;
                _stickerAlignY = -0.15;
                _stickerRotation = 0;
                _stickerSize = 28;
                _invalidateProcessCache();
              });
            }),
          ],
        ),
        Text(
          'Drag on the photo to move the sticker.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildBorderPanel(AppStrings s, ColorScheme cs) {
    const borders = ['None', 'Thin black', 'Thick white', 'Polaroid', 'Film strip', 'Rounded', 'Double'];
    const keys = ['none', 'thinBlack', 'thickWhite', 'polaroid', 'film', 'rounded', 'double'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        final selected = _borderStyle == keys[i];
        return GestureDetector(
          onTap: () => setState(() => _borderStyle = keys[i]),
          child: Container(
            width: 88,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? _kEditorRed : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                borders[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : cs.onSurface,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _iconAction(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show six-color e-ink preview in a fullscreen dialog.
  Future<void> _preview() async {
    if (_decoded == null) return;
    final bytes = await compute(isolateFrameEinkPreviewJpeg, _previewArgs());
    if (!mounted || bytes == null) return;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: Text(
                'Preview uses black, white, yellow, red, blue, and green only.',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _resetCropState() {
    setState(() {
      _cropAspect = '3:4';
      _cropZoom = 100;
      _flipH = false;
      _flipV = false;
      _cropPanX = 0;
      _cropPanY = 0;
      _quarterTurns = 0;
      _previewTransform.value = Matrix4.identity();
      _invalidateProcessCache();
    });
  }

  Widget _buildBottomBar(
    BuildContext context,
    AppStrings s,
    ColorScheme cs,
    Color primary,
    bool debugOn,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_uploading) ...[
                if (_castProgressIndeterminate || _castProgress != null)
                  LinearProgressIndicator(
                    value: _castProgressIndeterminate ? null : _castProgress,
                    minHeight: 3,
                    color: _kEditorRed,
                  ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: Text(
                      _status!,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ] else if (_paired != null && !_paired!.canUploadToServer)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s.pairingNeedsApiUrl,
                    style: TextStyle(fontSize: 11, color: cs.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kEditorRed,
                          side: const BorderSide(color: _kEditorRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _uploading ? null : _showFastRealPreview,
                        child: const Text(
                          'E-ink Preview',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kEditorRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _uploading ? null : _send,
                        child: _uploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Send',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens immediately (uses warm cache when ready); refreshes bake in background.
  void _showFastRealPreview() {
    final args = _previewArgs();
    final cached = _previewBytes;
    showDialog<void>(
      context: context,
      builder: (ctx) => _FastEinkPreviewDialog(
        initialBytes: cached,
        fallbackBytes: widget.imageBytes,
        load: () => compute(isolateFastPreviewJpeg, args),
      ),
    );
  }
}

class _FastEinkPreviewDialog extends StatefulWidget {
  const _FastEinkPreviewDialog({
    required this.initialBytes,
    required this.fallbackBytes,
    required this.load,
  });

  final Uint8List? initialBytes;
  final Uint8List fallbackBytes;
  final Future<Uint8List?> Function() load;

  @override
  State<_FastEinkPreviewDialog> createState() => _FastEinkPreviewDialogState();
}

class _FastEinkPreviewDialogState extends State<_FastEinkPreviewDialog> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
    if (_bytes == null) {
      _loading = true;
    }
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final next = await widget.load();
    if (!mounted) return;
    if (next == null) {
      setState(() {
        _bytes ??= widget.fallbackBytes;
        _loading = false;
      });
      return;
    }
    setState(() {
      _bytes = next;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _bytes != null
                  ? Image.memory(_bytes!, fit: BoxFit.contain)
                  : const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                    ),
            ),
          ),
          if (_loading && _bytes != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'Preview of your edited photo.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CastActivityLog extends StatelessWidget {
  const _CastActivityLog({required this.lines, required this.onCopy});

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
          SelectableText(lines.join('\n'), style: mono),
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
