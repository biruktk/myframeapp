import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_diag_log.dart';
import 'slideshow_style.dart';
import 'transport_kind.dart';

// Wi‑Fi provisioning over BLE (ESP32): Espressif documents **BluFi** in ESP-IDF —
// a GATT-based protocol for app ↔ chip Wi‑Fi setup + control. A production
// “Bluetooth” path for MyFrame can wrap BluFi to push SSID/credentials, then
// use Wi‑Fi for bulk photo transfer. See:
// https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/ble/blufi.html
//
// This file only defines a Dart-side transport; firmware must implement the
// actual BLE GATT/BluFi session.

/// Abstraction for sending bytes to the frame. Replace [MockDeviceTransport]
/// with real Wi‑Fi / BLE implementations that talk to your firmware.
abstract class DeviceTransport {
  Future<SendResult> sendImage({
    required List<int> bytes,
    required String filename,
    required TransportKind transport,
    required SlideshowStyle slideshow,
    Duration? displayDuration,
  });

  Stream<FrameConnectionState> get connectionState;
}

enum FrameConnectionState { disconnected, connecting, connected }

class SendResult {
  SendResult({required this.ok, this.message});

  final bool ok;
  final String? message;
}

/// Simulates network/BLE latency and success. Logs transport for debugging.
class MockDeviceTransport implements DeviceTransport {
  MockDeviceTransport() {
    _controller.add(FrameConnectionState.disconnected);
  }

  final _controller = StreamController<FrameConnectionState>.broadcast();

  @override
  Stream<FrameConnectionState> get connectionState => _controller.stream;

  @override
  Future<SendResult> sendImage({
    required List<int> bytes,
    required String filename,
    required TransportKind transport,
    required SlideshowStyle slideshow,
    Duration? displayDuration,
  }) async {
    _controller.add(FrameConnectionState.connecting);
    await Future<void>.delayed(
      transport == TransportKind.bluetooth
          ? const Duration(milliseconds: 1200)
          : const Duration(milliseconds: 700),
    );
    _controller.add(FrameConnectionState.connected);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    AppDiagLog.verbose(
      '[MyFrame] send ${bytes.length}B via ${transport.label} '
      'slideshow=${slideshow.apiValue} file=$filename',
    );
    if (transport == TransportKind.bluetooth) {
      return SendResult(ok: true, message: 'BLE queued (${bytes.length} bytes)');
    }
    return SendResult(ok: true, message: 'Wi‑Fi queued (${bytes.length} bytes)');
  }
}
