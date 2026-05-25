import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Outcome of BLE scan–related permission requests (Android + iOS).
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

  bool get needsLocationSettings => Platform.isAndroid && locationDenied;
}

bool _ok(PermissionStatus s) => s.isGranted || s.isLimited;

/// Detailed BLE scan permission request (Bluetooth + Android location for scans).
Future<BleScanPermissionOutcome> requestBleScanPermissions() async {
  if (Platform.isIOS) {
    final bt = await Permission.bluetooth.request();
    final blockedBySettings = bt.isPermanentlyDenied || bt.isRestricted;
    final ok = _ok(bt) || !blockedBySettings;
    return BleScanPermissionOutcome(
      allGranted: ok,
      bluetoothScanDenied: false,
      bluetoothConnectDenied: false,
      locationDenied: false,
      bluetoothDenied: blockedBySettings,
      anyPermanentlyDenied: bt.isPermanentlyDenied,
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

  await Permission.bluetooth.request();
  final scan = await Permission.bluetoothScan.request();
  final connect = await Permission.bluetoothConnect.request();
  final loc = await Permission.locationWhenInUse.request();

  final scanOk = _ok(scan);
  final connOk = _ok(connect);
  final locOk = _ok(loc);

  final deniedScan = !scanOk;
  final deniedConn = !connOk;
  final deniedLoc = !locOk;
  final permDenied = scan.isPermanentlyDenied ||
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
