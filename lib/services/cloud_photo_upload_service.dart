import 'dart:typed_data';

import '../settings/app_settings.dart';
import 'app_diag_log.dart';
import 'google_drive_service.dart';
import 'google_photos_service.dart';
import 'icloud_photos_service.dart';

/// Where processed photos are stored before frame delivery.
enum PhotoStorageBackend { vps, googlePhotos, iCloudPhotos }

class CloudPhotoUploadService {
  CloudPhotoUploadService._();

  static final CloudPhotoUploadService instance = CloudPhotoUploadService._();

  PhotoStorageBackend backendFor(AppSettings app) {
    switch (app.photoStorageBackend) {
      case 'google_photos':
      case 'google_drive':
        return PhotoStorageBackend.googlePhotos;
      case 'icloud_photos':
      case 'dropbox':
        return PhotoStorageBackend.iCloudPhotos;
      default:
        return PhotoStorageBackend.vps;
    }
  }

  Future<CloudUploadResult?> uploadIfConfigured({
    required AppSettings app,
    required Uint8List bytes,
    required String filename,
  }) async {
    final backend = backendFor(app);
    switch (backend) {
      case PhotoStorageBackend.vps:
        return null;
      case PhotoStorageBackend.googlePhotos:
        if (!GooglePhotosService.instance.isConnected) {
          AppDiagLog.log('[Cloud] Google Photos selected but not connected');
          return const CloudUploadResult.failed(
            'Connect Google Photos in Settings -> Integrations.',
          );
        }
        return GooglePhotosService.instance.uploadBytes(
          bytes: bytes,
          filename: filename,
          mimeType: 'image/jpeg',
        );
      case PhotoStorageBackend.iCloudPhotos:
        if (!ICloudPhotosService.instance.isAvailable) {
          AppDiagLog.log('[Cloud] iCloud Photos selected on non-iOS; skipping');
          return null;
        }
        if (!ICloudPhotosService.instance.isConnected) {
          AppDiagLog.log('[Cloud] iCloud Photos selected but not connected');
          return const CloudUploadResult.failed(
            'Connect iCloud Photos in Settings -> Integrations.',
          );
        }
        return ICloudPhotosService.instance.uploadBytes(
          bytes: bytes,
          filename: filename,
        );
    }
  }
}
