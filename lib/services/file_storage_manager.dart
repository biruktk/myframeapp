import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_diag_log.dart';
import 'local_storage_service.dart';

/// User-isolated on-disk media under app documents.
///
/// Layout:
///   `{docs}/users/{userId}/images/`
///   `{docs}/users/{userId}/albums/`
///
/// Legacy flat `{docs}/personal_gallery/` is migrated once into the active
/// user's `images/` folder when that folder is empty.
class FileStorageManager {
  FileStorageManager._();
  static final FileStorageManager instance = FileStorageManager._();

  static const usersRootName = 'users';
  static const imagesDirName = 'images';
  static const albumsDirName = 'albums';
  static const legacyGalleryDirName = 'personal_gallery';

  Future<Directory> _docs() => getApplicationDocumentsDirectory();

  Future<String> _resolveUserId(String? userId) async {
    final uid = (userId ?? await LocalStorageService.instance.currentUserId())
        .trim();
    return uid.isEmpty ? LocalStorageService.guestId : uid;
  }

  Future<Directory> userRoot({String? userId}) async {
    final uid = await _resolveUserId(userId);
    final base = await _docs();
    final dir = Directory(p.join(base.path, usersRootName, uid));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> imagesDir({String? userId}) async {
    final root = await userRoot(userId: userId);
    final dir = Directory(p.join(root.path, imagesDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    await migrateLegacyPersonalGalleryIfNeeded(userId: userId);
    return dir;
  }

  Future<Directory> albumsDir({String? userId}) async {
    final root = await userRoot(userId: userId);
    final dir = Directory(p.join(root.path, albumsDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Legacy root used before user isolation.
  Future<Directory> legacyPersonalGalleryDir() async {
    final base = await _docs();
    return Directory(p.join(base.path, legacyGalleryDirName));
  }

  bool isUnderDir(String path, String rootPath) {
    final normalized = p.normalize(path);
    final root = p.normalize(rootPath);
    return normalized == root ||
        normalized.startsWith('$root${Platform.pathSeparator}');
  }

  /// Move leftover flat `personal_gallery/*` into `users/<uid>/images/` once.
  Future<void> migrateLegacyPersonalGalleryIfNeeded({String? userId}) async {
    try {
      final uid = await _resolveUserId(userId);
      if (uid == LocalStorageService.guestId) return;

      final legacy = await legacyPersonalGalleryDir();
      if (!await legacy.exists()) return;

      final images = Directory(
        p.join((await userRoot(userId: uid)).path, imagesDirName),
      );
      if (!await images.exists()) await images.create(recursive: true);

      final existing = await images
          .list()
          .where((e) => e is File)
          .length
          .catchError((_) => 0);
      // Only migrate when the user folder is still empty.
      if (existing > 0) return;

      var moved = 0;
      await for (final entity in legacy.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        final dest = File(p.join(images.path, name));
        if (await dest.exists()) continue;
        try {
          await entity.copy(dest.path);
          moved++;
        } catch (e) {
          AppDiagLog.verbose('[FileStorage] migrate copy failed $name: $e');
        }
      }
      if (moved > 0) {
        AppDiagLog.verbose(
          '[FileStorage] migrated $moved legacy gallery files → users/$uid/images',
        );
      }
    } catch (e, st) {
      AppDiagLog.verbose('[FileStorage] migrate failed: $e\n$st');
    }
  }

  /// Best-effort delete of this account's on-disk media (optional hard wipe).
  Future<void> deleteUserTree(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty || uid == LocalStorageService.guestId) return;
    try {
      final base = await _docs();
      final dir = Directory(p.join(base.path, usersRootName, uid));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      AppDiagLog.verbose('[FileStorage] deleteUserTree($userId): $e');
    }
  }
}
