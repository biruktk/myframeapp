import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../config/api_config.dart';
import '../services/ble_frame_device_transport.dart';
import '../services/device_store.dart';
import '../services/frame_api_client.dart';
import '../services/editor_settings_cache.dart';
import '../services/image_processor_service.dart';
import '../services/image_send_isolate_worker.dart';
import '../services/send_overlay_paint.dart';
import '../services/network_link.dart';
import '../services/sd_card_export.dart';
import '../services/slideshow_style.dart';
import '../services/transport_kind.dart';
import '../services/usage_metrics_store.dart';
import '../l10n/app_strings.dart';
import '../models/send_overlay_options.dart';
import 'device_discovery_screen.dart';

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
  });

  final Uint8List imageBytes;
  final String deviceId;
  final TransportKind transport;
  final SlideshowStyle slideshow;
  final SendOverlayOptions overlay;
  /// When [SendOverlayOptions.showLocation] is true, shown instead of frame name (e.g. city + weather).
  final String? overlayLocationOverride;

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
    if (widget.overlay.showLocation && ovr != null && ovr.isNotEmpty) return ovr;
    final n = _paired?.frameName?.trim();
    if (n != null && n.isNotEmpty) return n;
    if (_paired != null) return _paired!.listDisplayTitle(s);
    return s.frameDefaultDisplayName;
  }

  Future<void> _finishSuccessfulSend(String status) async {
    if (!mounted) return;
    setState(() => _status = status);
    unawaited(UsageMetricsStore.instance.markPhotoSentNow());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    final cached = EditorSettingsCache.instance.last;
    if (cached != null) {
      _transport = TransportKind.wifi;
      _slideshow = cached.slideshow;
      _oDate = cached.showDate;
      _oLocation = cached.showLocation;
      _oGreeting = cached.showGreeting;
      _brightness = cached.brightness;
      _contrast = cached.contrast;
      _saturation = cached.saturation;
      _filter = cached.filter;
    } else {
      _transport = TransportKind.wifi;
      _slideshow = widget.slideshow;
      _oDate = widget.overlay.showDate;
      _oLocation = widget.overlay.showLocation;
      _oGreeting = widget.overlay.showGreeting;
    }
    // Each new image starts upright; only grade / overlay / send prefs are sticky.
    _quarterTurns = 0;
    _overlayText = TextEditingController(
      text: cached != null ? cached.customText : widget.overlay.customText,
    );
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

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _renderPreview);
  }

  void _renderPreview() {
    final src = _decoded;
    if (src == null) return;
    final preview = _processor.buildPreview(
      source: src,
      quarterTurns: _quarterTurns,
      brightness: 1.0 + _brightness * 0.35,
      contrast: 1.0 + _contrast * 0.45,
      saturation: 1.0 + _saturation * 0.45,
      filter: _filter,
    );
    final overlaid = _drawOverlay(preview, _currentOverlay, locationText: _overlayLocationValue);
    final bytes = _processor.encodeJpg(overlaid, quality: 88);
    setState(() => _previewBytes = bytes);
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
      ),
    );
    _cachedProcess = result;
    return result;
  }

  Future<void> _send() async {
    if (_decoded == null) return;
    final paired = _paired;
    final sEarly = AppStrings.of(context);
    if (paired == null) {
      if (!mounted) return;
      setState(() {
        _status = '${sEarly.notPaired}. ${sEarly.scanDeviceTitle}';
      });
      return;
    }
    if (!paired.canUploadToServer) {
      if (!mounted) return;
      setState(() {
        _status = sEarly.pairingNeedsApiUrl;
      });
      return;
    }
    setState(() {
      _uploading = true;
      _status = 'Preparing image for frame...';
    });
    try {
      if (!mounted) return;
      final s = AppStrings.of(context);
      final uploadJpeg = await compute(
        isolateComposeUploadJpeg,
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
      if (uploadJpeg == null) {
        if (!mounted) return;
        setState(() => _status = s.processingFailed);
        return;
      }

      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final httpName = 'photo_$ts.jpg';
      final targetIds = _paired != null
          ? _paired!.resolvedFrameTargetCandidates
          : <String>[widget.deviceId];

      Future<bool> applyHttpOk(
        PhotoUploadResponse res, {
        required String targetId,
        required bool hasFallback,
      }) async {
        final hash = res.checksumSha256 != null && res.checksumSha256!.length >= 8
            ? res.checksumSha256!.substring(0, 8)
            : '…';
        String statusExtras(PhotoUploadResponse r) {
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
            parts.add(looksBin ? s.uploadFrameMyfmBinUrl(playUrl) : s.uploadFrameMqttJpegUrl(playUrl));
          }

          final preview = r.previewStoredPath?.trim();
          if (preview != null && preview.isNotEmpty) {
            parts.add(s.uploadServerJpegBackupOnly(preview));
          }
          return parts.isEmpty ? '' : '\n${parts.join('\n')}';
        }

        if (res.deliveredToFrame == true) {
          await _finishSuccessfulSend(
            '${s.uploadSuccessLine(res.receivedBytes ?? 0, hash)}${statusExtras(res)}',
          );
          return true;
        }
        setState(
          () => _status =
              'Uploaded to server. Waiting for frame confirmation…${statusExtras(res)}',
        );
        final checksum = res.checksumSha256;
        if (checksum == null || checksum.isEmpty) {
          if (hasFallback) {
            setState(() {
              _status =
                  'Uploaded to server, but frame confirmation is missing for $targetId. Retrying alternate frame MAC…${statusExtras(res)}';
            });
            return false;
          }
          setState(() {
            _status =
                'Uploaded to server only. Frame display not confirmed yet. Make sure frame is online and linked.${statusExtras(res)}';
          });
          return true;
        }
        final started = DateTime.now();
        while (DateTime.now().difference(started) < const Duration(seconds: 25)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          final delivery = await _api.getDeliveryStatus(
            checksumSha256: checksum,
            deviceId: targetId,
            baseUrlOverride: paired.resolvedApiBaseUrl,
            pairingToken: paired.resolvedPairingToken,
          );
          if (delivery.deliveredToFrame) {
            if (!mounted) return true;
            await _finishSuccessfulSend(
              '${s.uploadSuccessLine(res.receivedBytes ?? 0, hash)}${statusExtras(res)}',
            );
            return true;
          }
          if (delivery.deliveryMode == 'frame_push_failed' ||
              delivery.deliveryMode == 'mqtt_publish_failed' ||
              delivery.deliveryMode == 'mqtt_disconnected') {
            if (hasFallback) {
              if (!mounted) return false;
              setState(() {
                _status =
                    'Uploaded, but MQTT did not reach the frame on $targetId. Retrying alternate MAC…${statusExtras(res)}';
              });
              return false;
            }
            if (!mounted) return true;
            setState(() {
              _status =
                  'Uploaded, but MQTT did not reach the frame. Check broker, API MQTT_URL, and device_id/MAC.${statusExtras(res)}';
            });
            return true;
          }
        }
        if (!mounted) return true;
        if (hasFallback) {
          setState(() {
            _status =
                'Frame confirmation timed out on $targetId. Retrying alternate frame MAC…${statusExtras(res)}';
          });
          return false;
        }
        setState(() {
          _status =
              'Uploaded to server only. Frame confirmation timed out.${statusExtras(res)}';
        });
        return true;
      }

      final onLink = await hasNetworkInterface();
      if (!onLink) {
        if (!mounted) return;
        setState(() {
          _status = s.sendOfflineNoNetworkForWifi;
        });
        return;
      }

      if (mounted) {
        setState(() => _status = 'Connecting to your server…');
      }
      await BleFrameDeviceTransport.instance.releaseSession();

      for (var i = 0; i < targetIds.length; i++) {
        final targetId = targetIds[i];
        final hasFallback = i < targetIds.length - 1;
        if (mounted) {
          setState(() {
            _status = i == 0
                ? 'Uploading to server…'
                : 'Retrying frame with alternate MAC…';
          });
        }
        try {
          final res = await _api.uploadPhoto(
            fileBytes: uploadJpeg,
            filename: httpName,
            deviceId: targetId,
            baseUrlOverride: paired.resolvedApiBaseUrl!,
            slideshowStyle: _slideshow.apiValue,
            transport: TransportKind.wifi.apiValue,
            pairingToken: paired.resolvedPairingToken,
          );
          if (!mounted) return;
          final done = await applyHttpOk(
            res,
            targetId: targetId,
            hasFallback: hasFallback,
          );
          if (done) {
            return;
          }
        } on SocketException catch (e) {
          if (!mounted) return;
          final msgLower = e.message.toLowerCase();
          if (msgLower.contains('failed host lookup') ||
              msgLower.contains('no address associated with hostname')) {
            final hostHint = paired.apiUrl != null ? Uri.tryParse(paired.apiUrl!)?.host ?? '' : '';
            setState(() {
              _status = hostHint.isNotEmpty
                  ? 'Cannot resolve $hostHint — check DNS and that the phone has internet.'
                  : '${s.sendOfflineNoNetworkForWifi} ($e)';
            });
            return;
          }
          setState(() => _status = '${s.sendOfflineNoNetworkForWifi} ($e)');
          return;
        }
      }
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
      if (msg.contains('failed host lookup') || msg.contains('no address associated with hostname')) {
        final host = Uri.tryParse(ApiConfig.baseUrl)?.host ?? ApiConfig.baseUrl;
        setState(() {
          _status = 'Cannot resolve $host. Check DNS/network, or set API_BASE to a reachable URL.';
        });
      } else {
        setState(() => _status = '${s.sendOfflineNoNetworkForWifi} ($e)');
      }
    } on TimeoutException catch (e) {
      if (mounted) setState(() => _status = AppStrings.of(context).apiError(e));
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
      if (mounted) setState(() => _status = '$e');
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
    if (_decodeFailed) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text(s.editTitle)),
        body: Center(child: Text(s.decodeError)),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.editTitle),
        actions: [
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                              panEnabled: true,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    s.targetFrameHint(ImageProcessorService.frameWidth, ImageProcessorService.frameHeight),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    children: [
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
                Text(s.filterLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _editorSectionTitle(s.editorSectionSend, cs),
                const SizedBox(height: 6),
                Text(
                  s.editorSendVpsOnlyHelp,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 16),
                Text(s.slideshowStyle, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(s.overlayOptions, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  s.overlayOnPhotoHelper,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.3),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in ['Love', 'Family', 'Congrats', 'Happy Birthday', 'Best wishes', 'Holiday'])
                      ActionChip(
                        label: Text(w),
                        onPressed: () {
                          final t = _overlayText.text.trim();
                          final next = t.isEmpty ? w : '$t $w';
                          _overlayText.text = next;
                          _overlayText.selection = TextSelection.collapsed(offset: next.length);
                          _schedulePreview();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _overlayText,
                  maxLength: 40,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                      ? s.pairingLineUnpaired(s.transportLabelVps, slideshowLabel)
                      : s.pairingLinePaired(
                          _paired!.listDisplayTitle(s),
                          _paired!.resolvedApiBaseUrl ?? _paired!.apiUrl,
                          s.transportLabelVps,
                          slideshowLabel,
                        ),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
                ),
                if (_paired != null && !_paired!.canUploadToServer) ...[
                  const SizedBox(height: 10),
                  Text(
                    s.pairingNeedsApiUrl,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ],
                if (_paired == null) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DeviceDiscoveryScreen(),
                        ),
                      );
                      await _loadPairing();
                    },
                    icon: const Icon(Icons.bluetooth_searching),
                    label: Text(s.scanDeviceTitle),
                  ),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(_status!, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _uploading || _paired == null || !_paired!.canUploadToServer ? null : _send,
                  icon: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
              ],
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

  img.Image _drawOverlay(
    img.Image source,
    SendOverlayOptions overlay, {
    required String locationText,
  }) {
    return drawSendOverlayOnImage(source, overlay, locationText: locationText);
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
