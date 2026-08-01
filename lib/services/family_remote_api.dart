import 'dart:convert';

import 'package:http/http.dart' as http;

/// REST client for `/api/family/*` (Bearer JWT from `/api/auth/*`).
class FamilyRemoteApi {
  FamilyRemoteApi({required this.baseUrl, required this.token})
      : _origin = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _tok = token.trim();

  final String baseUrl;
  final String token;
  final String _origin;
  final String _tok;

  Map<String, String> get _hdr => {
        'Authorization': 'Bearer $_tok',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Uri _u(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_origin$p');
  }

  /// `null` = 404 **no_family** — user must call [create].
  Future<FamilyMembersBundle?> fetchMembers() async {
    final res = await http.get(_u('/api/family/members'), headers: _hdr);
    if (res.statusCode == 401) throw FamilyRemoteAuthException(res.body);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw FamilyRemoteHttpException(res.statusCode, res.body);
    }
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) return null;
    return FamilyMembersBundle.fromJson(map);
  }

  Future<({String familyId, String inviteCode})> create({String name = 'Our family'}) async {
    final res = await http.post(
      _u('/api/family/create'),
      headers: _hdr,
      body: jsonEncode({'name': name}),
    );
    _throwUnlessOk(res);
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) throw StateError('invalid create body');
    return (familyId: map['familyId'] as String, inviteCode: map['inviteCode'] as String);
  }

  Future<void> join(String inviteCode, {String? birthdayIso}) async {
    final body = <String, dynamic>{'inviteCode': inviteCode};
    if (birthdayIso != null && birthdayIso.trim().isNotEmpty) {
      body['birthday'] = birthdayIso.trim();
    }
    final res = await http.post(
      _u('/api/family/join'),
      headers: _hdr,
      body: jsonEncode(body),
    );
    _throwUnlessOk(res);
  }

  Future<void> leave() async {
    final res = await http.delete(_u('/api/family/leave'), headers: _hdr);
    _throwUnlessOk(res);
  }

  Future<void> removeMember(String userId) async {
    final res = await http.delete(_u('/api/family/members/$userId'), headers: _hdr);
    _throwUnlessOk(res);
  }

  Future<String> rotateInviteCode() async {
    final res = await http.post(_u('/api/family/invite/rotate'), headers: _hdr);
    _throwUnlessOk(res);
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) throw StateError('invalid rotate body');
    return map['inviteCode'] as String;
  }

  void _throwUnlessOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    if (res.statusCode == 401) throw FamilyRemoteAuthException(res.body);
    throw FamilyRemoteHttpException(res.statusCode, res.body);
  }
}

class FamilyRemoteAuthException implements Exception {
  FamilyRemoteAuthException(this.body);
  final String body;
}

class FamilyRemoteHttpException implements Exception {
  FamilyRemoteHttpException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  /// Best-effort parse of `{ "error": "..." }` from the API body.
  String? get errorCode {
    try {
      final map = jsonDecode(body);
      if (map is Map && map['error'] != null) {
        return map['error'].toString();
      }
    } catch (_) {}
    return null;
  }

  String? get message {
    try {
      final map = jsonDecode(body);
      if (map is Map && map['message'] != null) {
        return map['message'].toString();
      }
    } catch (_) {}
    return null;
  }
}

class FamilyMembersBundle {
  FamilyMembersBundle({
    required this.familyId,
    required this.familyName,
    required this.inviteCode,
    required this.members,
  });

  final String familyId;
  final String familyName;
  final String inviteCode;
  final List<Map<String, dynamic>> members;

  factory FamilyMembersBundle.fromJson(Map<String, dynamic> j) {
    final rawList = j['members'];
    final list = <Map<String, dynamic>>[];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map<String, dynamic>) {
          list.add(e);
        } else if (e is Map) {
          list.add(Map<String, dynamic>.from(e.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }
    return FamilyMembersBundle(
      familyId: j['familyId'] as String? ?? '',
      familyName: j['familyName'] as String? ?? 'Our family',
      inviteCode: j['inviteCode'] as String? ?? '',
      members: list,
    );
  }
}
