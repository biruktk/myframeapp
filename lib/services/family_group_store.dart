import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'family_remote_api.dart';

/// Role for [FamilyMember.role]; use string for JSON portability.
abstract class FamilyRoles {
  static const owner = 'owner';
  static const member = 'member';
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.displayName,
    required this.role,
    this.pending = false,
  });

  final String id;
  final String displayName;
  final String role;
  final bool pending;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': displayName,
        'role': role,
        'pending': pending,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> j) {
    return FamilyMember(
      id: j['id'] as String? ?? '',
      displayName: j['name'] as String? ?? '',
      role: j['role'] as String? ?? FamilyRoles.member,
      pending: j['pending'] as bool? ?? false,
    );
  }
}

/// Local-only record when entering a code while **signed out** (no JWT).
class JoinedFamilySnapshot {
  const JoinedFamilySnapshot({
    required this.code,
    required this.label,
    required this.joinedAtMs,
  });

  final String code;
  final String label;
  final int joinedAtMs;

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        't': joinedAtMs,
      };

  factory JoinedFamilySnapshot.fromJson(Map<String, dynamic> j) => JoinedFamilySnapshot(
        code: (j['code'] as String? ?? '').toUpperCase(),
        label: j['label'] as String? ?? '',
        joinedAtMs: j['t'] as int? ?? 0,
      );
}

enum JoinFamilyResult { ok, codeTooShort, ownInviteCode, networkError }

/// Local cache + optional cloud sync via [FamilyRemoteApi].
class FamilyGroupStore {
  FamilyGroupStore._();
  static final FamilyGroupStore instance = FamilyGroupStore._();

  static const _kOwn = 'family_group_own_v1';
  static const _kJoined = 'family_group_joined_v1';

  var _loaded = false;

  String familyName = 'Our family';
  String inviteCode = '';
  String remoteFamilyId = '';
  /// When [true], [members]/[inviteCode] last came from `GET /api/family/members`.
  bool cloudSynced = false;
  List<FamilyMember> members = [];
  List<JoinedFamilySnapshot> joinedFamilies = [];

  static String generateInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  static String normalizeCode(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  Future<void> ensureLoaded({required String Function() ownerDisplayName}) async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();

    final rawOwn = p.getString(_kOwn);
    if (rawOwn != null && rawOwn.isNotEmpty) {
      try {
        final map = jsonDecode(rawOwn) as Map<String, dynamic>;
        familyName = map['name'] as String? ?? 'Our family';
        final rawCode = map['code'] as String?;
        inviteCode = (rawCode == null || rawCode.trim().isEmpty) ? generateInviteCode() : rawCode.trim();
        remoteFamilyId = map['remoteFamilyId'] as String? ?? '';
        cloudSynced = map['cloudSynced'] as bool? ?? false;
        final list = map['members'] as List<dynamic>?;
        members = list
                ?.map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
                .where((m) => m.id.isNotEmpty)
                .toList() ??
            [];
        if (members.where((m) => m.role == FamilyRoles.owner).isEmpty) {
          members.insert(
            0,
            FamilyMember(
              id: 'owner',
              displayName: ownerDisplayName(),
              role: FamilyRoles.owner,
            ),
          );
        }
      } catch (_) {
        _seedNewGroup(ownerDisplayName());
      }
    } else {
      _seedNewGroup(ownerDisplayName());
    }

    final rawJ = p.getString(_kJoined);
    if (rawJ != null && rawJ.isNotEmpty) {
      try {
        final list = jsonDecode(rawJ) as List<dynamic>;
        joinedFamilies = list
            .map((e) => JoinedFamilySnapshot.fromJson(e as Map<String, dynamic>))
            .where((j) => j.code.isNotEmpty)
            .toList();
      } catch (_) {
        joinedFamilies = [];
      }
    }

    _loaded = true;
    await _persistOwn();
    await _persistJoined();
  }

  void _seedNewGroup(String ownerName) {
    inviteCode = generateInviteCode();
    familyName = 'Our family';
    remoteFamilyId = '';
    cloudSynced = false;
    members = [
      FamilyMember(
        id: 'owner',
        displayName: ownerName.trim().isEmpty ? 'You' : ownerName.trim(),
        role: FamilyRoles.owner,
      ),
    ];
  }

  Future<void> _persistOwn() async {
    final p = await SharedPreferences.getInstance();
    final map = {
      'name': familyName,
      'code': inviteCode,
      'remoteFamilyId': remoteFamilyId,
      'cloudSynced': cloudSynced,
      'members': members.map((m) => m.toJson()).toList(),
    };
    await p.setString(_kOwn, jsonEncode(map));
  }

  Future<void> _persistJoined() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kJoined, jsonEncode(joinedFamilies.map((j) => j.toJson()).toList()));
  }

  Future<void> setFamilyName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    familyName = n;
    await _persistOwn();
  }

  /// Local-only rotation (signed out or offline).
  Future<void> regenerateInviteCodeLocal() async {
    inviteCode = generateInviteCode();
    await _persistOwn();
  }

  Future<void> rotateInviteOnServer(String origin, String token) async {
    final t = token.trim();
    if (t.isEmpty) {
      await regenerateInviteCodeLocal();
      return;
    }
    try {
      final code = await FamilyRemoteApi(baseUrl: origin, token: t).rotateInviteCode();
      inviteCode = code;
      await _persistOwn();
    } catch (_) {
      await regenerateInviteCodeLocal();
    }
  }

  Future<void> createCloudFamily(String origin, String token, {String name = 'Our family'}) async {
    final api = FamilyRemoteApi(baseUrl: origin, token: token);
    await api.create(name: name);
    await pullFromRemote(origin, token);
  }

  /// Overwrites local member list when the server has a family; clears [joinedFamilies].
  Future<void> pullFromRemote(String origin, String? token) async {
    final t = token?.trim() ?? '';
    if (t.isEmpty) return;
    try {
      final api = FamilyRemoteApi(baseUrl: origin, token: t);
      final bundle = await api.fetchMembers();
      if (bundle == null) {
        cloudSynced = false;
        remoteFamilyId = '';
        await _persistOwn();
        return;
      }
      cloudSynced = true;
      remoteFamilyId = bundle.familyId;
      familyName = bundle.familyName;
      inviteCode = bundle.inviteCode;
      members = bundle.members.map((m) {
        final id = m['userId'] as String? ?? '';
        final roleRaw = m['role'] as String? ?? 'member';
        final role = roleRaw == 'owner' ? FamilyRoles.owner : FamilyRoles.member;
        final display = m['name'] as String? ?? id;
        return FamilyMember(id: id, displayName: display, role: role);
      }).where((m) => m.id.isNotEmpty).toList();
      joinedFamilies = [];
      await _persistOwn();
      await _persistJoined();
    } on FamilyRemoteAuthException {
      cloudSynced = false;
    } catch (_) {
      /* keep local cache */
    }
  }

  Future<void> removeMember(String id, {String? apiOrigin, String? token}) async {
    final idx = members.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    if (members[idx].role == FamilyRoles.owner) return;

    if (cloudSynced && (apiOrigin?.isNotEmpty ?? false) && (token?.isNotEmpty ?? false)) {
      try {
        await FamilyRemoteApi(baseUrl: apiOrigin!, token: token!).removeMember(id);
      } catch (_) {
        // fall through — still remove locally
      }
    }

    members.removeAt(idx);
    await _persistOwn();
  }

  Future<JoinFamilyResult> joinWithCode(
    String rawCode, {
    required String labelIfNew,
    String? bearerToken,
    String? apiOrigin,
    String? birthdayIso,
  }) async {
    final c = normalizeCode(rawCode);
    if (c.length < 8) return JoinFamilyResult.codeTooShort;
    if (c == inviteCode.toUpperCase()) return JoinFamilyResult.ownInviteCode;

    final tok = bearerToken?.trim() ?? '';
    final origin = apiOrigin ?? '';
    if (tok.isNotEmpty && origin.isNotEmpty) {
      try {
        await FamilyRemoteApi(baseUrl: origin, token: tok).join(c, birthdayIso: birthdayIso);
        await pullFromRemote(origin, tok);
        return JoinFamilyResult.ok;
      } catch (_) {
        return JoinFamilyResult.networkError;
      }
    }

    joinedFamilies.removeWhere((j) => j.code == c);
    joinedFamilies.add(
      JoinedFamilySnapshot(
        code: c,
        label: labelIfNew.trim().isEmpty ? 'Family $c' : labelIfNew.trim(),
        joinedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _persistJoined();
    return JoinFamilyResult.ok;
  }

  Future<void> leaveJoinedFamilyOffline(String normalizedCode) async {
    joinedFamilies.removeWhere((j) => j.code == normalizedCode);
    await _persistJoined();
  }

  Future<void> leaveServerFamily(String origin, String token, {required String Function() ownerDisplayName}) async {
    try {
      await FamilyRemoteApi(baseUrl: origin, token: token).leave();
    } catch (_) {
      /* still reset local UX */
    }
    _seedNewGroup(ownerDisplayName());
    joinedFamilies.clear();
    cloudSynced = false;
    remoteFamilyId = '';
    await _persistOwn();
    await _persistJoined();
  }

  Future<void> reload({required String Function() ownerDisplayName}) async {
    _loaded = false;
    await ensureLoaded(ownerDisplayName: ownerDisplayName);
  }
}
