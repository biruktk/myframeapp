import 'package:shared_preferences/shared_preferences.dart';

/// User-scoped SharedPreferences key helper.
///
/// All account-owned cache keys must go through [scopedKey] / [keyFor] so
/// logout → login as another user never reads the previous account's data.
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const authUserIdKey = 'settings_auth_user_id';
  static const guestId = 'guest';

  /// Base keys that hold per-account data (always suffix with `_\$userId`).
  static const galleryPathsBase = 'personal_gallery_file_paths_v1';
  static const sendAlbumsBase = 'send_albums_v1';
  static const sendAlbumsDeletedBase = 'send_albums_deleted_ids_v1';
  static const galleryCloudIdsBase = 'personal_gallery_cloud_ids_v1';
  static const galleryDeletedIdsBase = 'personal_gallery_deleted_ids_v1';
  static const familyOwnBase = 'family_group_own_v1';
  static const familyJoinedBase = 'family_group_joined_v1';
  static const notificationsBase = 'in_app_notifications_v1';
  static const slideshowPlaylistBase = 'slideshow_playlist';

  Future<SharedPreferences> get prefs async => SharedPreferences.getInstance();

  /// Active account id from prefs (or [guestId] when signed out).
  Future<String> currentUserId() async {
    final p = await prefs;
    final uid = (p.getString(authUserIdKey) ?? '').trim();
    return uid.isEmpty ? guestId : uid;
  }

  /// `base_userId` — never store account data under the bare [base] key.
  static String keyFor(String base, String userId) {
    final uid = userId.trim().isEmpty ? guestId : userId.trim();
    return '${base}_$uid';
  }

  Future<String> scopedKey(String base, {String? userId}) async {
    final uid = (userId ?? await currentUserId()).trim();
    return keyFor(base, uid);
  }

  Future<String?> getString(String base, {String? userId}) async {
    final p = await prefs;
    return p.getString(await scopedKey(base, userId: userId));
  }

  Future<bool> setString(String base, String value, {String? userId}) async {
    final p = await prefs;
    return p.setString(await scopedKey(base, userId: userId), value);
  }

  Future<List<String>> getStringList(String base, {String? userId}) async {
    final p = await prefs;
    return List<String>.from(
      p.getStringList(await scopedKey(base, userId: userId)) ?? const [],
    );
  }

  Future<bool> setStringList(
    String base,
    List<String> value, {
    String? userId,
  }) async {
    final p = await prefs;
    return p.setStringList(await scopedKey(base, userId: userId), value);
  }

  Future<bool> remove(String base, {String? userId}) async {
    final p = await prefs;
    return p.remove(await scopedKey(base, userId: userId));
  }

  /// Slideshow playlist key: `slideshow_playlist_<userId>_<macSlug>`.
  static String slideshowKey(String userId, String macSlug) {
    final uid = userId.trim().isEmpty ? guestId : userId.trim();
    final mac = macSlug.trim().isEmpty ? 'unknown' : macSlug.trim();
    return '${slideshowPlaylistBase}_${uid}_$mac';
  }

  Future<String> slideshowScopedKey(String macSlug, {String? userId}) async {
    final uid = userId ?? await currentUserId();
    return slideshowKey(uid, macSlug);
  }

  /// Remove every prefs key that belongs to [userId] (account logout wipe).
  Future<void> clearAllKeysForUser(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty || uid == guestId) return;
    final p = await prefs;
    final suffix = '_$uid';
    final slideshowPrefix = '${slideshowPlaylistBase}_${uid}_';
    final toRemove = <String>[];
    for (final k in p.getKeys()) {
      if (k.endsWith(suffix) || k.startsWith(slideshowPrefix)) {
        toRemove.add(k);
      }
    }
    for (final k in toRemove) {
      await p.remove(k);
    }
  }
}
