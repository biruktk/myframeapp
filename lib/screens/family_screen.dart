import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/platform_share.dart';

import '../config/api_config.dart';
import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../services/device_store.dart';
import '../services/family_group_store.dart';
import '../services/family_invite_deep_link.dart';
import '../settings/app_settings.dart';


class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  var _busy = false;
  var _storeLoadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pre = FamilyInviteDeepLink.takePendingCode();
      if (pre != null && pre.length >= 8) {
        _showJoinSheet(context, AppStrings.of(context), prefill: pre);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storeLoadStarted) return;
    _storeLoadStarted = true;
    final app = AppSettingsScope.of(context);
    unawaited(_loadStore(app));
  }

  Future<void> _loadStore(AppSettings app) async {
    if (!mounted) return;
    final owner = () {
      final fromName = app.profileName.trim();
      if (fromName.isNotEmpty) return fromName;
      final mail = app.accountEmail.trim();
      if (mail.isNotEmpty) return mail.split('@').first;
      return 'You';
    };
    await FamilyGroupStore.instance.ensureLoaded(ownerDisplayName: owner);
    final tok = app.authToken.trim();
    if (tok.isNotEmpty) {
      await FamilyGroupStore.instance.pullFromRemote(ApiConfig.baseUrl, tok);
      await DeviceStore.instance.syncServerFrames(bearerToken: tok);
    }
    if (mounted) setState(() {});
  }

  String _inviteWebUrl(FamilyGroupStore g) =>
      'https://${VpsDefaults.hostnameInk}/join?code=${Uri.encodeComponent(g.inviteCode)}';

  Future<void> _confirmRegenerateInvite(
      BuildContext context, AppStrings s) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.familyRegenerateCodeTitle),
        content: Text(s.familyRegenerateCodeBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(s.familyRegenerateCodeConfirm)),
        ],
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    final tok = AppSettingsScope.of(context).authToken.trim();
    await FamilyGroupStore.instance
        .rotateInviteOnServer(ApiConfig.baseUrl, tok);
    setState(() => _busy = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.familyCodeRegenerated)));
    }
  }

  Future<void> _showJoinSheet(BuildContext context, AppStrings s,
      {String? prefill}) async {
    final appTok = AppSettingsScope.of(context).authToken.trim();
    final birthdayPrefill = AppSettingsScope.of(context).birthday;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _JoinFamilySheet(
        strings: s,
        prefill: prefill,
        birthdayPrefill: birthdayPrefill,
        authToken: appTok,
        onJoined: () async {
          final tok = AppSettingsScope.of(context).authToken.trim();
          if (tok.isNotEmpty) {
            await DeviceStore.instance.syncServerFrames(bearerToken: tok);
          }
          if (mounted) setState(() {});
        },
        onBusyChanged: (busy) {
          if (mounted) setState(() => _busy = busy);
        },
        isBusy: _busy,
      ),
    );
  }

  Future<void> _inviteShare(BuildContext context, AppStrings s) async {
    final g = FamilyGroupStore.instance;
    final inviteUrl = _inviteWebUrl(g);
    final subject = '${s.inviteFamily} · ${g.familyName}';
    await platformShareText(
      context,
      text: s.familyInviteShareBody(g.familyName, g.inviteCode, inviteUrl),
      subject: subject,
    );
  }

  Future<void> _showSharedFramesSheet(BuildContext context, AppStrings s) async {
    await DeviceStore.instance.load();
    final paired = DeviceStore.instance.cached;
    final g = FamilyGroupStore.instance;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.sharedFrames,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(s.sharedFramesBody, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 16),
              if (paired != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.photo_outlined, color: cs.primary),
                  title: Text(paired.listDisplayTitle(s)),
                  subtitle: Text(paired.deviceId),
                )
              else
                Text(s.notPaired, style: TextStyle(color: cs.onSurfaceVariant)),
              if (g.cloudSynced && g.members.length > 1) ...[
                const SizedBox(height: 8),
                Text(s.familyMembersTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...g.members.map(
                  (m) => Text('• ${m.displayName}', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _removeButton(BuildContext context, AppStrings s, FamilyGroupStore g, FamilyMember m, AppSettings app) {
    if (m.role == FamilyRoles.owner) return null;
    final ownerId = g.members.where((x) => x.role == FamilyRoles.owner).map((x) => x.id).firstOrNull;
    final isCurrentUserOwner = ownerId != null && ownerId == app.authUserId;
    if (!isCurrentUserOwner) return null;

    return IconButton(
      icon: const Icon(Icons.remove_circle_outline),
      onPressed: () async {
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('移除成员', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('确定要从家庭圈中移除「${m.displayName}」吗？移除后对方将无法继续访问共享相框。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('确定移除', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (go != true) return;

        final tok = app.authToken.trim();
        await FamilyGroupStore.instance.removeMember(
          m.id,
          apiOrigin: tok.isNotEmpty ? ApiConfig.baseUrl : null,
          token: tok.isNotEmpty ? tok : null,
        );
        setState(() {});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已从家庭圈移除 ${m.displayName}')),
        );
      },
      tooltip: '移除成员',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    final g = FamilyGroupStore.instance;

    Future<void> createCloudTap() async {
      final tok = app.authToken.trim();
      if (tok.isEmpty) return;
      setState(() => _busy = true);
      try {
        await FamilyGroupStore.instance
            .createCloudFamily(ApiConfig.baseUrl, tok);
        if (mounted) setState(() {});
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.joinFamilySuccess)));
    }

    Future<void> leaveCloudTap() async {
      final tok = app.authToken.trim();
      if (tok.isEmpty) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(s.familyLeaveCloud),
          content: Text(s.familyLeaveCloudBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(s.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(s.familyLeaveCloud)),
          ],
        ),
      );
      if (go != true || !mounted) return;
      setState(() => _busy = true);
      final owner = () {
        final fromName = app.profileName.trim();
        if (fromName.isNotEmpty) return fromName;
        final mail = app.accountEmail.trim();
        if (mail.isNotEmpty) return mail.split('@').first;
        return 'You';
      };
      await FamilyGroupStore.instance
          .leaveServerFamily(ApiConfig.baseUrl, tok, ownerDisplayName: owner);
      if (mounted) setState(() => _busy = false);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(s.familyTitle)),
      body: RefreshIndicator(
        onRefresh: () => _loadStore(app),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text(
              s.familySubtitle,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (app.authToken.isNotEmpty && !g.cloudSynced) ...[
              Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s.familyCloudCreateHint,
                            style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                                height: 1.35)),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _busy ? null : createCloudTap,
                          child: Text(
                              _busy ? s.authBusyLabel : s.familyCloudCreateLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(s.familyYourCircle,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.familyInviteCodeLabel,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        if (g.inviteCode.isEmpty) return;
                        Clipboard.setData(ClipboardData(text: g.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.familyCodeCopied)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(
                              g.inviteCode.isEmpty ? '…' : g.inviteCode,
                              style: TextStyle(
                                  fontSize: 22,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface),
                            ),
                            if (g.inviteCode.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.copy_rounded, size: 20, color: cs.primary),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: QrImageView(
                            data: _inviteWebUrl(g),
                            size: 168,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: g.inviteCode.isEmpty
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: g.inviteCode));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(s.familyCodeCopied)),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.copy_rounded),
                            label: Text(s.familyCopyInviteCode),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _inviteShare(context, s),
                            icon: const Icon(Icons.ios_share_outlined),
                            label: Text(s.inviteFamily),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _confirmRegenerateInvite(context, s),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(s.familyRegenerateCodeShort),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showJoinSheet(context, s, prefill: null),
              icon: const Icon(Icons.login_rounded),
              label: Text(s.joinFamilyTitle),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            if (app.authToken.isNotEmpty && g.cloudSynced) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : leaveCloudTap,
                icon: const Icon(Icons.logout_rounded),
                label: Text(s.familyLeaveCloud),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
            if (g.joinedFamilies.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(s.familyJoinedListTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...g.joinedFamilies.map(
                (j) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      title: Text(j.label),
                      subtitle: Text('${s.familyInviteCodeLabel}: ${j.code}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: s.familyLeaveJoined,
                        onPressed: () async {
                          await FamilyGroupStore.instance
                              .leaveJoinedFamilyOffline(j.code);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(s.familyMembersTitle,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...g.members.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: primary.withValues(alpha: 0.15),
                      child: Icon(
                        m.role == FamilyRoles.owner
                            ? Icons.star_rounded
                            : Icons.person_outline_rounded,
                        color: primary,
                      ),
                    ),
                    title: Text(m.displayName),
                    subtitle: Text(
                      m.role == FamilyRoles.owner
                          ? s.familyRoleOwner
                          : s.familyRoleMember,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    trailing: _removeButton(context, s, g, m, app),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showSharedFramesSheet(context, s),
              icon: const Icon(Icons.devices),
              label: Text(s.sharedFrames),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinFamilySheet extends StatefulWidget {
  const _JoinFamilySheet({
    required this.strings,
    required this.prefill,
    required this.birthdayPrefill,
    required this.authToken,
    required this.onJoined,
    required this.onBusyChanged,
    required this.isBusy,
  });

  final AppStrings strings;
  final String? prefill;
  final String birthdayPrefill;
  final String authToken;
  final VoidCallback onJoined;
  final void Function(bool busy) onBusyChanged;
  final bool isBusy;

  @override
  State<_JoinFamilySheet> createState() => _JoinFamilySheetState();
}

class _JoinFamilySheetState extends State<_JoinFamilySheet> {
  late final TextEditingController _ctrl;
  DateTime? _birthdayPick;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.prefill ?? '');
    _birthdayPick = _parseBirthday(widget.birthdayPrefill);
  }

  DateTime? _parseBirthday(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final p = s.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _isoBirthday(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _confirm() async {
    final s = widget.strings;
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    if (_birthdayPick == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.joinFamilyBirthdayRequired)),
      );
      return;
    }
    widget.onBusyChanged(true);
    try {
      final norm = FamilyGroupStore.normalizeCode(raw);
      final bIso = _isoBirthday(_birthdayPick!);
      final r = await FamilyGroupStore.instance.joinWithCode(
        raw,
        labelIfNew: s.joinFamilyDefaultLabel(norm),
        bearerToken: widget.authToken.isNotEmpty ? widget.authToken : null,
        apiOrigin: widget.authToken.isNotEmpty ? ApiConfig.baseUrl : null,
        birthdayIso: bIso,
      );
      if (!mounted) return;
      switch (r) {
        case JoinFamilyResult.ok:
          final scope = AppSettingsScope.of(context);
          await scope.setAccountProfile(
            name: scope.profileName,
            email: scope.accountEmail,
            birthdayValue: bIso,
          );
          if (!mounted) return;
          Navigator.pop(context);
          widget.onJoined();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.joinFamilySuccess)),
          );
        case JoinFamilyResult.codeTooShort:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.joinFamilyCodeTooShort)),
          );
        case JoinFamilyResult.ownInviteCode:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.joinFamilyOwnCodeHint)),
          );
        case JoinFamilyResult.networkError:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.joinFamilyNetworkError)),
          );
      }
    } finally {
      widget.onBusyChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.joinFamilyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(s.joinFamilyBody,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: s.joinFamilyHint,
              border: const OutlineInputBorder(),
            ),
            autocorrect: false,
          ),
          const SizedBox(height: 20),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            s.joinFamilyProfileSection,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            s.joinFamilyBirthdayHint,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ListTile(
              title: Text(s.joinFamilyBirthdayLabel),
              subtitle: Text(
                _birthdayPick == null ? '—' : _isoBirthday(_birthdayPick!),
              ),
              trailing: const Icon(Icons.cake_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _birthdayPick ?? DateTime(1990, 6, 15),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (d != null && mounted) setState(() => _birthdayPick = d);
              },
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: widget.isBusy ? null : _confirm,
            child: Text(s.joinFamilyConfirm),
          ),
        ],
      ),
    );
  }
}
