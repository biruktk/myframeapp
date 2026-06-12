import 'dart:typed_data';

import '../settings/app_settings.dart';
import 'app_diag_log.dart';
import 'dropbox_service.dart';
import 'google_drive_service.dart';

/// Where processed photos are stored before frame delivery.
enum PhotoStorageBackend { vps, googleDrive, dropbox }

class CloudPhotoUploadService {
  CloudPhotoUploadService._();

  static final CloudPhotoUploadService instance = CloudPhotoUploadService._();

  PhotoStorageBackend backendFor(AppSettings app) {
    switch (app.photoStorageBackend) {
      case 'google_drive':
        return PhotoStorageBackend.googleDrive;
      case 'dropbox':
        return PhotoStorageBackend.dropbox;
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
      case PhotoStorageBackend.googleDrive:
        if (!GoogleDriveService.instance.isConnected) {
          AppDiagLog.log('[Cloud] Google Drive selected but not connected');
          return const CloudUploadResult.failed('Connect Google Drive in Settings → Integrations.');
        }
        return GoogleDriveService.instance.uploadBytes(
          bytes: bytes,
          filename: filename,
        );
      case PhotoStorageBackend.dropbox:
        if (!DropboxService.instance.isConnected) {
          AppDiagLog.log('[Cloud] Dropbox selected but not connected');
          return const CloudUploadResult.failed('Connect Dropbox in Settings → Integrations.');
        }
        return DropboxService.instance.uploadBytes(
          bytes: bytes,
          filename: filename,
        );
    }
  }
}
