import 'package:flutter/foundation.dart';

import '../l10n/app_strings.dart';
import '../models/pairing_payload.dart';

/// How [PairingPayload] failed the MyFrame product / run checks.
enum MyFramePairingRejection {
  /// Expected [MyFrameProductConfig.productCode] in QR, got something else.
  wrongProduct,

  /// [deviceId] could not be parsed to a unit serial in this run.
  badDeviceIdFormat,

  /// Parsed serial is not in 1..[MyFrameProductConfig.maxUnits] for this product run.
  unitOutOfRun,
}

/// Binds the app to **your** product line and a **capped** serial run (e.g. 100 units).
/// Override at build time: `flutter run --dart-define=MYFRAME_MAX_UNITS=100`
class MyFrameProductConfig {
  MyFrameProductConfig._();

  /// QR field `product` (if present) must match this, case-insensitive.
  static const String productCode = String.fromEnvironment(
    'MYFRAME_PRODUCT_CODE',
    defaultValue: 'myframe',
  );

  /// Only serial numbers 1..[maxUnits] (inclusive) are accepted for this product run.
  static const int maxUnits = int.fromEnvironment(
    'MYFRAME_MAX_UNITS',
    defaultValue: 100,
  );

  /// Dev only: accept any [PairingPayload] without unit / product checks.
  static const bool bypassDeviceChecks = kDebugMode &&
      bool.fromEnvironment('MYFRAME_BYPASS_DEVICE_CAP', defaultValue: false);

  /// `true` if [deviceId] is in this run and (when set) [product] matches.
  static bool isAcceptablePairingPayload(PairingPayload p) {
    return validatePairing(p) == null;
  }

  /// `true` for stored [deviceId] on every send (HTTP + BLE).
  static bool isAcceptableDeviceId(String deviceId) {
    return rejectionForDeviceId(deviceId) == null;
  }

  /// True when an id format looks like this app's own MyFrame serial pattern.
  static bool looksLikeMyFrameDeviceId(String deviceId) {
    return _serialFromDeviceId(deviceId.trim()) != null;
  }

  /// When [deviceId] is not allowed, the reason; otherwise `null`.
  static MyFramePairingRejection? rejectionForDeviceId(String deviceId) {
    if (bypassDeviceChecks) return null;
    final n = _serialFromDeviceId(deviceId.trim());
    if (n == null) {
      return MyFramePairingRejection.badDeviceIdFormat;
    }
    if (n < 1 || n > maxUnits) {
      return MyFramePairingRejection.unitOutOfRun;
    }
    return null;
  }

  /// `null` if ok; otherwise the reason the QR must be rejected.
  static MyFramePairingRejection? validatePairing(PairingPayload p) {
    if (bypassDeviceChecks) return null;
    final rawProduct = p.product?.trim();
    if (rawProduct != null && rawProduct.isNotEmpty) {
      if (rawProduct.toLowerCase() != productCode.toLowerCase()) {
        return MyFramePairingRejection.wrongProduct;
      }
    }
    final n = _serialFromDeviceId(p.deviceId.trim());
    if (n == null) {
      return MyFramePairingRejection.badDeviceIdFormat;
    }
    if (n < 1 || n > maxUnits) {
      return MyFramePairingRejection.unitOutOfRun;
    }
    return null;
  }

  /// Known formats:
  /// - `YX-133P-001` → **1** (factory style for this app)
  /// - `YX-133P-100` → **100**
  /// - `MF-42` or `mf-7` → **42** / **7**
  static int? _serialFromDeviceId(String id) {
    if (id.isEmpty) return null;
    // YX-133P-042 or YX-133P-1
    final pShort = RegExp(r'^YX-133P-(\d{1,3})$', caseSensitive: false).firstMatch(id);
    if (pShort != null) {
      return int.parse(pShort.group(1)!);
    }
    // MF-7, MF-042
    final mf = RegExp(r'^MF-(\d+)$', caseSensitive: false).firstMatch(id);
    if (mf != null) {
      return int.parse(mf.group(1)!);
    }
    return null;
  }
}

/// Localized line for a pairing / device-id check (scan flow + send guard).
String myFrameRejectionToMessage(AppStrings s, MyFramePairingRejection r) {
  return switch (r) {
    MyFramePairingRejection.wrongProduct => s.pairingWrongProduct,
    MyFramePairingRejection.badDeviceIdFormat => s.pairingBadIdFormat,
    MyFramePairingRejection.unitOutOfRun => s.pairingNotInThisRun(MyFrameProductConfig.maxUnits),
  };
}
