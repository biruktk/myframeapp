import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_diag_log.dart';
import 'google_drive_service.dart';

/// Saves processed photos into Apple Photos. When iCloud Photos is enabled on
/// the device, iOS syncs the saved asset to the user's iCloud Photos library.
class ICloudPhotosService {
  ICloudPhotosService._();

  static final ICloudPhotosService instance = ICloudPhotosService._();

  static const _channel = MethodChannel('myframe/icloud_photos');
  static const _kConnected = 'icloud_photos_connected';

  bool _connected = false;

  bool get isAvailable => Platform.isIOS;
  bool get isConnected => isAvailable && _connected;

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _connected = p.getBool(_kConnected) ?? false;
  }

  Future<bool> connect() async {
    if (!isAvailable) {
      throw StateError('iCloud Photos upload is only available on iOS.');
    }
    final ok =
        await _channel.invokeMethod<bool>('requestAddPermission') ?? false;
    _connected = ok;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kConnected, ok);
    AppDiagLog.log('[iCloudPhotos] ${ok ? 'connected' : 'permission denied'}');
    return ok;
  }

  Future<void> disconnect() async {
    _connected = false;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kConnected, false);
    AppDiagLog.log('[iCloudPhotos] disconnected');
  }

  Future<CloudUploadResult> uploadBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!isAvailable) {
      return const CloudUploadResult.failed(
        'iCloud Photos upload is only available on iOS.',
      );
    }
    if (!_connected) {
      return const CloudUploadResult.failed(
        'Connect iCloud Photos in Settings -> Integrations.',
      );
    }
    try {
      final id = await _channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
        'filename': filename,
      });
      if (id == null || id.isEmpty) {
        return const CloudUploadResult.failed('iCloud Photos save failed.');
      }
      AppDiagLog.log('[iCloudPhotos] saved $filename id=$id');
      return CloudUploadResult.ok(
        fileId: id,
        webUrl: '',
        provider: 'iCloud Photos',
      );
    } on PlatformException catch (e) {
      AppDiagLog.log('[iCloudPhotos] save failed ${e.code}: ${e.message}');
      return CloudUploadResult.failed(
        e.message ?? 'iCloud Photos save failed.',
      );
    }
  }
}
