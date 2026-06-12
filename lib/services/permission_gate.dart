import 'package:permission_handler/permission_handler.dart';

/// Serializes permission_handler requests (avoids "already running" popups).
class PermissionGate {
  PermissionGate._();

  static Future<void>? _chain;

  static Future<PermissionStatus> _enqueue(
    Future<PermissionStatus> Function() action,
  ) async {
    while (_chain != null) {
      await _chain;
    }
    final done = action();
    _chain = done.whenComplete(() => _chain = null);
    return done;
  }

  static Future<PermissionStatus> photos() async {
    final current = await Permission.photos.status;
    if (current.isGranted || current.isLimited) return current;
    if (current.isPermanentlyDenied) return current;
    return _enqueue(() => Permission.photos.request());
  }

  static Future<PermissionStatus> camera() async {
    final current = await Permission.camera.status;
    if (current.isGranted || current.isLimited) return current;
    if (current.isPermanentlyDenied) return current;
    return _enqueue(() => Permission.camera.request());
  }

  static Future<PermissionStatus> bluetooth() async {
    final current = await Permission.bluetooth.status;
    if (current.isGranted || current.isLimited) return current;
    if (current.isPermanentlyDenied || current.isRestricted) return current;
    return _enqueue(() => Permission.bluetooth.request());
  }

  static Future<PermissionStatus> locationWhenInUse() async {
    final current = await Permission.locationWhenInUse.status;
    if (current.isGranted || current.isLimited) return current;
    if (current.isPermanentlyDenied || current.isRestricted) return current;
    return _enqueue(() => Permission.locationWhenInUse.request());
  }

  /// Coarse location fallback when fine location was not granted (some OEMs).
  static Future<PermissionStatus> enqueueLocationCoarse() async {
    final current = await Permission.location.status;
    if (current.isGranted || current.isLimited) return current;
    if (current.isPermanentlyDenied || current.isRestricted) return current;
    return _enqueue(() => Permission.location.request());
  }
}
