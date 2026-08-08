import 'dart:convert';

import '../config/api_config.dart';
import 'api_client.dart';

/// Cloud playlists + frame slideshow status via `/api/user/*`.
class UserPlaylistRemoteApi {
  UserPlaylistRemoteApi({String? baseUrl, required String bearerToken})
      : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _api = ApiClient(bearerToken: bearerToken.trim());

  final String _origin;
  final ApiClient _api;

  Uri _u(String path) => Uri.parse('$_origin${path.startsWith('/') ? path : '/$path'}');

  Future<UserDashboardSnapshot?> fetchDashboard() async {
    if (!_api.hasToken) return null;
    final res = await _api.get(_u('/api/user/dashboard'));
    if (res.statusCode == 401) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) return null;
    return UserDashboardSnapshot.fromJson(map);
  }

  Future<CloudPlaylist?> createPlaylist({required String title, String? assignedFrameId}) async {
    if (!_api.hasToken) return null;
    final body = <String, dynamic>{'title': title};
    if (assignedFrameId != null && assignedFrameId.trim().isNotEmpty) {
      body['assignedFrameId'] = assignedFrameId.trim();
    }
    final res = await _api.post(_u('/api/user/playlists'), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) return null;
    final pl = map['playlist'];
    if (pl is! Map<String, dynamic>) return null;
    return CloudPlaylist.fromJson(pl);
  }

  Future<CloudPlaylist?> updatePlaylistPhotos({
    required String playlistId,
    required List<String> photoIds,
    String? assignedFrameId,
  }) async {
    if (!_api.hasToken) return null;
    final body = <String, dynamic>{'photoIds': photoIds};
    final af = assignedFrameId?.trim() ?? '';
    if (af.isNotEmpty) body['assignedFrameId'] = af;
    final res = await _api.patch(
      _u('/api/user/playlists/$playlistId'),
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) return null;
    final pl = map['playlist'];
    if (pl is! Map<String, dynamic>) return null;
    return CloudPlaylist.fromJson(pl);
  }
}

class UserDashboardSnapshot {
  const UserDashboardSnapshot({
    required this.devices,
    required this.playlists,
  });

  final List<DashboardDevice> devices;
  final List<CloudPlaylist> playlists;

  factory UserDashboardSnapshot.fromJson(Map<String, dynamic> j) {
    final devRaw = j['devices'];
    final plRaw = j['playlists'];
    return UserDashboardSnapshot(
      devices: devRaw is List
          ? devRaw
              .whereType<Map>()
              .map((e) => DashboardDevice.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      playlists: plRaw is List
          ? plRaw
              .whereType<Map>()
              .map((e) => CloudPlaylist.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
    );
  }
}

class DashboardDevice {
  const DashboardDevice({
    required this.id,
    required this.name,
    required this.bleMac,
    required this.online,
    required this.slideshowImageCount,
    required this.slideshowIntervalMinutes,
  });

  final String id;
  final String name;
  final String bleMac;
  final bool online;
  final int slideshowImageCount;
  final int slideshowIntervalMinutes;

  factory DashboardDevice.fromJson(Map<String, dynamic> j) => DashboardDevice(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        bleMac: j['bleMac'] as String? ?? '',
        online: j['online'] as bool? ?? false,
        slideshowImageCount: j['slideshowImageCount'] as int? ?? 0,
        slideshowIntervalMinutes: j['slideshowIntervalMinutes'] as int? ?? 60,
      );
}

class CloudPlaylist {
  const CloudPlaylist({
    required this.id,
    required this.title,
    required this.photoIds,
    required this.assignedFrameIds,
  });

  final String id;
  final String title;
  final List<String> photoIds;
  final List<String> assignedFrameIds;

  factory CloudPlaylist.fromJson(Map<String, dynamic> j) => CloudPlaylist(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? 'Playlist',
        photoIds: (j['photoIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        assignedFrameIds:
            (j['assignedFrameIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );
}
