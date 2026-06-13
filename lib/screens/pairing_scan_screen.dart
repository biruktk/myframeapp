import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/myframe_product_config.dart';
import '../l10n/app_strings.dart';
import '../models/pairing_payload.dart';
import '../models/pairing_nav_result.dart';
import '../services/app_release_guard.dart';
import '../services/device_store.dart';
import '../navigation/pairing_flow_nav.dart';
import 'wifi_provision_screen.dart';

/// Scan the QR shown on the frame display to capture [deviceId] + optional LAN [apiUrl].
class PairingScanScreen extends StatefulWidget {
  const PairingScanScreen({super.key});

  @override
  State<PairingScanScreen> createState() => _PairingScanScreenState();
}

class _PairingScanScreenState extends State<PairingScanScreen> {
  final _store = DeviceStore.instance;
  String? _error;
  bool _busy = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final code = codes.first.rawValue;
    if (code == null || code.isEmpty) return;

    final payload = PairingPayload.tryParse(code);
    if (payload == null) {
      setState(() => _error = AppStrings.of(context).notMyFrameQr);
      return;
    }

    final s = AppStrings.of(context);
    final product = payload.product?.toLowerCase().trim();
    final shouldValidateMyFrame = (product != null && product == MyFrameProductConfig.productCode.toLowerCase()) ||
        MyFrameProductConfig.looksLikeMyFrameDeviceId(payload.deviceId);
    if (shouldValidateMyFrame) {
      final reject = MyFrameProductConfig.validatePairing(payload);
      if (reject != null) {
        setState(() => _error = myFrameRejectionToMessage(s, reject));
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _pairFromPayload(payload);
    } catch (e, st) {
      AppReleaseGuard.onUncaughtError(e, st);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Pairing failed. Try again.';
      });
    }
  }

  Future<void> _pairFromPayload(PairingPayload payload) async {
    await _store.saveFromPayload(payload);
    if (!mounted) return;
    final wifiResult = await SafeNav.push<PairingNavResult>(
      context,
      MaterialPageRoute<PairingNavResult>(
        builder: (_) => const WifiProvisionScreen(
          firstTimeSetup: true,
          serverConfigAlreadySent: false,
        ),
      ),
    );
    if (!mounted) return;
    final result = wifiResult ?? const PairingNavResult(success: false);
    await SafeNav.popPairingResult(context, result: result);
    PairingFlowNav.onComplete(result);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.pairFrameTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, exception) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.cameraError(exception),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.paddingOf(context).bottom),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.pointAtQr,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.pairingQrHint,
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                  ],
                  if (_busy) const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
