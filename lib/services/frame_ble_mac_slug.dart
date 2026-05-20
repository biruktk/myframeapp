import 'device_store.dart';

/// Stable key for slideshow APIs — prefers stripped BLE peripheral id hex, else sanitized [PairedFrame.deviceId].
String frameBleMacSlug(PairedFrame? p) {
  final raw = p?.bleRemoteId?.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  if (raw != null && raw.length >= 8) {
    return raw;
  }
  return p?.deviceId.replaceAll(RegExp(r'[^\w\-]'), '') ?? 'FRAME';
}
