import 'dart:convert';

class UserPlaylist {
  const UserPlaylist({
    required this.id,
    required this.name,
    required this.imageRelativePaths,
  });

  final String id;
  final String name;

  /// Paths relative to app support directory.
  final List<String> imageRelativePaths;

  int get photoCount => imageRelativePaths.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageRelativePaths': imageRelativePaths,
      };

  static UserPlaylist fromJson(Map<String, dynamic> m) {
    return UserPlaylist(
      id: m['id'] as String,
      name: m['name'] as String,
      imageRelativePaths: (m['imageRelativePaths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  static String encodeList(List<UserPlaylist> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<UserPlaylist> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => UserPlaylist.fromJson(e as Map<String, dynamic>)).toList();
  }
}
