import 'dart:io';

import 'package:flutter/foundation.dart';
import 'permission_gate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_diag_log.dart';

/// Outcome of BLE scan-related permission requests.
class BleScanPermissionOutcome {
  const BleScanPermissionOutcome({
    required this.allGranted,
    required this.bluetoothScanDenied,
    required this.bluetoothConnectDenied,
    required this.locationDenied,
    required this.bluetoothDenied,
    required this.anyPermanentlyDenied,
  });

  final bool allGranted;
  final bool bluetoothScanDenied;
  final bool bluetoothConnectDenied;
  final bool locationDenied;

  /// iOS / legacy Bluetooth prompt.
  final bool bluetoothDenied;
  final bool anyPermanentlyDenied;

  bool get needsBluetoothSettings =>
      bluetoothDenied || bluetoothScanDenied || bluetoothConnectDenied;

  bool get needsLocationSettings => locationDenied;
}

bool _ok(PermissionStatus s) => s.isGranted || s.isLimited;

/// Detailed BLE scan permission request.
Future<BleScanPermissionOutcome> requestBleScanPermissions() async {
  if (Platform.isIOS) {
    final beforeBt = await Permission.bluetooth.status;
    final beforeLoc = await Permission.locationWhenInUse.status;
    
      AppDiagLog.verbose(
        '[BLE] iOS permission before: bluetooth=$beforeBt location=$beforeLoc',
      );
    
    final bt = await PermissionGate.bluetooth();
    final loc = await PermissionGate.locationWhenInUse();
    final btBlocked = bt.isPermanentlyDenied || bt.isRestricted;
    final locOk = _ok(loc);
    
      AppDiagLog.verbose('[BLE] iOS permission after: bluetooth=$bt location=$loc');
    
    return BleScanPermissionOutcome(
      allGranted: _ok(bt) || !btBlocked,
      bluetoothScanDenied: false,
      bluetoothConnectDenied: false,
      locationDenied: !locOk,
      bluetoothDenied: btBlocked,
      anyPermanentlyDenied: bt.isPermanentlyDenied || loc.isPermanentlyDenied,
    );
  }

  if (!Platform.isAndroid) {
    return const BleScanPermissionOutcome(
      allGranted: true,
      bluetoothScanDenied: false,
      bluetoothConnectDenied: false,
      locationDenied: false,
      bluetoothDenied: false,
      anyPermanentlyDenied: false,
    );
  }

  // Location first — Android 12+ may skip the location dialog if BLE is requested first.
  var loc = await PermissionGate.locationWhenInUse();
  if (!_ok(loc)) {
    loc = await PermissionGate.enqueueLocationCoarse();
  }
  final locOk = _ok(loc);

  await Permission.bluetooth.request();
  final scan = await Permission.bluetoothScan.request();
  final connect = await Permission.bluetoothConnect.request();

  final scanOk = _ok(scan);
  final connOk = _ok(connect);

  final deniedScan = !scanOk;
  final deniedConn = !connOk;
  final deniedLoc = !locOk;
  final permDenied =
      scan.isPermanentlyDenied ||
      connect.isPermanentlyDenied ||
      loc.isPermanentlyDenied;

  return BleScanPermissionOutcome(
    allGranted: scanOk && connOk && locOk,
    bluetoothScanDenied: deniedScan,
    bluetoothConnectDenied: deniedConn,
    locationDenied: deniedLoc,
    bluetoothDenied: false,
    anyPermanentlyDenied: permDenied,
  );
}

/// Request BLE-related permissions before starting a BLE scan / connect pipeline.
Future<bool> ensureBlePermissionsBeforeScan() async {
  final o = await requestBleScanPermissions();
  return o.allGranted;
}
