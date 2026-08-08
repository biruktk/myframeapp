import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'family_remote_api.dart';
import 'local_storage_service.dart';

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

  factory JoinedFamilySnapshot.fromJson(Map<String, dynamic> j) =>
      JoinedFamilySnapshot(
        code: (j['code'] as String? ?? '').toUpperCase(),
        label: j['label'] as String? ?? '',
        joinedAtMs: j['t'] as int? ?? 0,
      );
}

enum JoinFamilyResult {
  ok,
  codeTooShort,
  ownInviteCode,
  alreadyMember,
  notFound,
  invalidInvite,
  unauthorized,
  networkError,
}

/// Local cache + optional cloud sync via [FamilyRemoteApi].
class FamilyGroupStore {
  FamilyGroupStore._();
  static final FamilyGroupStore instance = FamilyGroupStore._();

  var _loaded = false;

  String familyName = 'Our family';
  String inviteCode = '';
  String remoteFamilyId = '';

  /// When [true], [members]/[inviteCode] last came from `GET /api/family/members`.
  bool cloudSynced = false;
  List<FamilyMember> members = [];
  List<JoinedFamilySnapshot> joinedFamilies = [];

  /// Bumps when members / invite / cloud sync state changes (Family UI listens).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _bumpRevision() => revision.value++;

  static String generateInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  /// Canonical invite form: trim → upper → strip ASCII spaces/hyphens + common
  /// zero-width / BOM characters. Mirrors the server's `normalizeInviteCode`.
  static String normalizeCode(String raw) => raw
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-\u200B\u200C\u200D\uFEFF]'), '');

  /// Drop in-memory family state (logout / account switch). Disk stays user-scoped.
  void resetMemory() {
    _loaded = false;
    familyName = 'Our family';
    inviteCode = '';
    remoteFamilyId = '';
    cloudSynced = false;
    members = [];
    joinedFamilies = [];
    _bumpRevision();
  }

  Future<void> ensureLoaded({
    required String Function() ownerDisplayName,
  }) async {
    if (_loaded) return;

    final rawOwn = await LocalStorageService.instance.getString(
      LocalStorageService.familyOwnBase,
    );
    if (rawOwn != null && rawOwn.isNotEmpty) {
      try {
        final map = jsonDecode(rawOwn) as Map<String, dynamic>;
        familyName = map['name'] as String? ?? 'Our family';
        final rawCode = map['code'] as String?;
        inviteCode = (rawCode == null || rawCode.trim().isEmpty)
            ? generateInviteCode()
            : rawCode.trim();
        remoteFamilyId = map['remoteFamilyId'] as String? ?? '';
        cloudSynced = map['cloudSynced'] as bool? ?? false;
        final list = map['members'] as List<dynamic>?;
        members =
            list
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

    final rawJ = await LocalStorageService.instance.getString(
      LocalStorageService.familyJoinedBase,
    );
    if (rawJ != null && rawJ.isNotEmpty) {
      try {
        final list = jsonDecode(rawJ) as List<dynamic>;
        joinedFamilies = list
            .map(
              (e) => JoinedFamilySnapshot.fromJson(e as Map<String, dynamic>),
            )
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
    final map = {
      'name': familyName,
      'code': inviteCode,
      'remoteFamilyId': remoteFamilyId,
      'cloudSynced': cloudSynced,
      'members': members.map((m) => m.toJson()).toList(),
    };
    await LocalStorageService.instance.setString(
      LocalStorageService.familyOwnBase,
      jsonEncode(map),
    );
  }

  /// A locally generated code has no server-side family record and must never
  /// be offered to another signed-in user. It cannot be redeemed remotely.
  Future<void> discardUnpublishedInviteCode() async {
    if (cloudSynced || inviteCode.isEmpty) return;
    inviteCode = '';
    await _persistOwn();
    _bumpRevision();
  }

  Future<void> _persistJoined() async {
    await LocalStorageService.instance.setString(
      LocalStorageService.familyJoinedBase,
      jsonEncode(joinedFamilies.map((j) => j.toJson()).toList()),
    );
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
    final api = FamilyRemoteApi(baseUrl: origin, token: t);
    try {
      final code = await api.rotateInviteCode();
      inviteCode = code;
      cloudSynced = true;
      await _persistOwn();
      return;
    } on FamilyRemoteHttpException catch (e) {
      // No cloud family yet — create one (gets a server code), then rotate
      // so "New code" always lands in the DB and never invents a ghost local code.
      if (e.statusCode == 404 || e.errorCode == 'no_family') {
        await createCloudFamily(origin, t);
        try {
          final code = await api.rotateInviteCode();
          inviteCode = code;
          cloudSynced = true;
          await _persistOwn();
        } catch (_) {
          // createCloudFamily already pulled a valid server inviteCode.
        }
        return;
      }
      rethrow;
    } catch (_) {
      // Signed-in rotate must not fall back to a local-only code — that code
      // never exists on the server and joiners get "No family matches…".
      rethrow;
    }
  }

  Future<void> createCloudFamily(
    String origin,
    String token, {
    String name = 'Our family',
  }) async {
    final api = FamilyRemoteApi(baseUrl: origin, token: token);
    await api.create(name: name);
    await pullFromRemote(origin, token);
  }

  /// Epoch bumped on join / leave so an in-flight "ensure invite" never creates a
  /// brand-new family after the user has already joined someone else's.
  int _ensureEpoch = 0;

  void invalidatePendingFamilyEnsure() => _ensureEpoch++;

  /// Refresh invite + members from the server. Optionally create a cloud family
  /// when [createIfMissing] is true (owners with a local frame only).
  ///
  /// Never auto-create for bare accounts — that races with Join and detaches the
  /// new member from the family they just joined (frames disappear).
  Future<void> refreshInviteFromServer(
    String origin,
    String token, {
    String name = 'Our family',
    bool createIfMissing = false,
  }) async {
    final t = token.trim();
    if (t.isEmpty) return;
    final epoch = _ensureEpoch;
    final api = FamilyRemoteApi(baseUrl: origin, token: t);

    try {
      final fast = await api.fetchInviteCode();
      if (epoch != _ensureEpoch) return;
      if (fast != null && fast.inviteCode.trim().isNotEmpty) {
        inviteCode = normalizeCode(fast.inviteCode);
        remoteFamilyId = fast.familyId;
        cloudSynced = true;
        await _persistOwn();
        await pullFromRemote(origin, t);
        return;
      }
    } on FamilyRemoteAuthException {
      rethrow;
    } on FamilyRemoteHttpException catch (e) {
      if (e.statusCode != 404 && e.errorCode != 'no_family') {
        return;
      }
    } catch (_) {
      return;
    }

    if (epoch != _ensureEpoch) return;
    if (!createIfMissing) {
      // Keep UI honest: no ghost local invite when there is no cloud family.
      await pullFromRemote(origin, t);
      return;
    }

    await createCloudFamily(origin, t, name: name);
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
        // Never keep advertising a device-only invite code — joiners hit 404.
        inviteCode = '';
        // Drop local-only name stubs from the old "Add household name" flow.
        members = members
            .where((m) => m.role == FamilyRoles.owner && !m.id.startsWith('m_'))
            .toList();
        if (members.isEmpty) {
          members = [
            const FamilyMember(
              id: 'owner',
              displayName: 'You',
              role: FamilyRoles.owner,
            ),
          ];
        }
        await _persistOwn();
        _bumpRevision();
        return;
      }
      cloudSynced = true;
      remoteFamilyId = bundle.familyId;
      familyName = bundle.familyName;
      inviteCode = bundle.inviteCode;
      members = bundle.members
          .map((m) {
            final id = m['userId'] as String? ?? '';
            final roleRaw = m['role'] as String? ?? 'member';
            final role = roleRaw == 'owner'
                ? FamilyRoles.owner
                : FamilyRoles.member;
            final display = (m['name'] as String?)?.trim();
            final email = (m['email'] as String?)?.trim() ?? '';
            final name =
                (display != null &&
                    display.isNotEmpty &&
                    display != '(unknown)')
                ? display
                : (email.isNotEmpty ? email.split('@').first : id);
            return FamilyMember(id: id, displayName: name, role: role);
          })
          .where((m) => m.id.isNotEmpty)
          .toList();
      joinedFamilies = [];
      await _persistOwn();
      await _persistJoined();
      _bumpRevision();
    } on FamilyRemoteAuthException {
      cloudSynced = false;
      _bumpRevision();
    } catch (_) {
      /* keep local cache */
    }
  }

  /// Unlink a non-owner member from the cloud family (and local cache).
  /// Returns `true` when the member was removed.
  Future<bool> removeMember(
    String id, {
    String? apiOrigin,
    String? token,
  }) async {
    final idx = members.indexWhere((e) => e.id == id);
    if (idx < 0) return false;
    if (members[idx].role == FamilyRoles.owner) return false;

    final origin = apiOrigin?.trim() ?? '';
    final tok = token?.trim() ?? '';
    if (cloudSynced) {
      if (origin.isEmpty || tok.isEmpty) return false;
      try {
        await FamilyRemoteApi(baseUrl: origin, token: tok).removeMember(id);
      } catch (_) {
        return false;
      }
      await pullFromRemote(origin, tok);
      return !members.any((m) => m.id == id);
    }

    // Offline / local-only stubs (legacy name-only entries).
    members.removeAt(idx);
    await _persistOwn();
    return true;
  }

  Future<JoinFamilyResult> joinWithCode(
    String rawCode, {
    required String labelIfNew,
    String? bearerToken,
    String? apiOrigin,
    String? birthdayIso,
  }) async {
    final c = normalizeCode(rawCode);
    if (c.length != 8) return JoinFamilyResult.codeTooShort;
    // Only treat as "own code" when this device is already on that cloud family.
    if (cloudSynced && inviteCode.isNotEmpty && c == inviteCode.toUpperCase()) {
      return JoinFamilyResult.ownInviteCode;
    }

    final tok = bearerToken?.trim() ?? '';
    final origin = apiOrigin ?? '';
    if (tok.isNotEmpty && origin.isNotEmpty) {
      // Cancel any in-flight Family-tab auto-create before we join.
      invalidatePendingFamilyEnsure();
      try {
        await FamilyRemoteApi(
          baseUrl: origin,
          token: tok,
        ).join(c, birthdayIso: birthdayIso);
        invalidatePendingFamilyEnsure();
        await pullFromRemote(origin, tok);
        return JoinFamilyResult.ok;
      } on FamilyRemoteAuthException {
        return JoinFamilyResult.unauthorized;
      } on FamilyRemoteHttpException catch (e) {
        final err = e.errorCode;
        if (e.statusCode == 409 || err == 'already_member') {
          // Already in this family — still refresh so frames/members land.
          await pullFromRemote(origin, tok);
          return JoinFamilyResult.alreadyMember;
        }
        if (e.statusCode == 404 || err == 'not_found') {
          return JoinFamilyResult.notFound;
        }
        if (e.statusCode == 400 || err == 'invalid_invite') {
          return JoinFamilyResult.invalidInvite;
        }
        return JoinFamilyResult.networkError;
      } catch (_) {
        return JoinFamilyResult.networkError;
      }
    }

    // Offline / signed-out: keep a local joined snapshot so UX still completes.
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

  Future<void> leaveServerFamily(
    String origin,
    String token, {
    required String Function() ownerDisplayName,
  }) async {
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
