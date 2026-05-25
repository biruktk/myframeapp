import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
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
    final ctrl = TextEditingController(text: prefill ?? '');
    final appTok = AppSettingsScope.of(context).authToken.trim();
    DateTime? birthdayPick;
    String isoBirthday(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.joinFamilyTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(s.joinFamilyBody,
                      style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          height: 1.4)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: s.joinFamilyHint,
                      border: const OutlineInputBorder(),
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.joinFamilyBirthdayLabel),
                    subtitle: Text(
                      birthdayPick == null ? '—' : isoBirthday(birthdayPick!),
                    ),
                    trailing: const Icon(Icons.cake_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: birthdayPick ?? DateTime(1990, 6, 15),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setModal(() => birthdayPick = d);
                    },
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final raw = ctrl.text.trim();
                            if (raw.isEmpty) return;
                            if (birthdayPick == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content:
                                        Text(s.joinFamilyBirthdayRequired)),
                              );
                              return;
                            }
                            setState(() => _busy = true);
                            try {
                              final norm = FamilyGroupStore.normalizeCode(raw);
                              final bIso = isoBirthday(birthdayPick!);
                              final r =
                                  await FamilyGroupStore.instance.joinWithCode(
                                raw,
                                labelIfNew: s.joinFamilyDefaultLabel(norm),
                                bearerToken: appTok.isNotEmpty ? appTok : null,
                                apiOrigin: appTok.isNotEmpty
                                    ? ApiConfig.baseUrl
                                    : null,
                                birthdayIso: bIso,
                              );
                              if (!ctx.mounted) return;
                              switch (r) {
                                case JoinFamilyResult.ok:
                                  final scope = AppSettingsScope.of(context);
                                  await scope.setAccountProfile(
                                    name: scope.profileName,
                                    email: scope.accountEmail,
                                    birthdayValue: bIso,
                                  );
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(s.joinFamilySuccess)));
                                  setState(() {});
                                case JoinFamilyResult.codeTooShort:
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(s.joinFamilyCodeTooShort)));
                                case JoinFamilyResult.ownInviteCode:
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(s.joinFamilyOwnCodeHint)));
                                case JoinFamilyResult.networkError:
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(s.joinFamilyNetworkError)));
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(s.joinFamilyConfirm),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    ctrl.dispose();
  }

  Future<void> _openInviteUrlInBrowser(
      BuildContext context, AppStrings s, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !mounted) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.familyCouldNotOpenLink)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.familyCouldNotOpenLink)));
      }
    }
  }

  Future<void> _inviteShare(BuildContext context, AppStrings s) async {
    final g = FamilyGroupStore.instance;
    final inviteUrl = _inviteWebUrl(g);
    final subject = '${s.inviteFamily} · ${g.familyName}';
    await Share.share(
      s.familyInviteShareBody(g.familyName, g.inviteCode, inviteUrl),
      subject: subject,
    );
  }

  Future<void> _addMemberDialog(BuildContext context, AppStrings s) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.familyAddMemberTitle),
        content: SingleChildScrollView(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: s.familyAddMemberHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.familyAddMemberSave),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await FamilyGroupStore.instance.addMemberByName(ctrl.text.trim());
      setState(() {});
    }
    ctrl.dispose();
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
            if (app.authToken.isNotEmpty && g.cloudSynced)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: Icon(Icons.cloud_done_rounded,
                        size: 18, color: cs.primary),
                    label: Text(s.familyCloudSynced),
                  ),
                ),
              ),
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
                    SelectableText(
                      g.inviteCode.isEmpty ? '…' : g.inviteCode,
                      style: TextStyle(
                          fontSize: 22,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface),
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
                    SelectionArea(
                      child: Text(
                        _inviteWebUrl(g),
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: cs.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openInviteUrlInBrowser(
                              context, s, _inviteWebUrl(g)),
                          icon: Icon(Icons.open_in_browser_rounded,
                              color: cs.primary, size: 18),
                          label: Text(s.familyOpenInviteLink),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: _inviteWebUrl(g)));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(s.familyInviteLinkCopied)),
                              );
                            }
                          },
                          icon: Icon(Icons.link_rounded,
                              color: cs.primary, size: 18),
                          label: Text(s.familyCopyInviteLink),
                        ),
                      ],
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
                    trailing: m.role == FamilyRoles.owner
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () async {
                              await FamilyGroupStore.instance
                                  .removeMember(m.id);
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addMemberDialog(context, s),
                icon: const Icon(Icons.person_add_alt_1, size: 20),
                label: Text(s.familyAddMemberTitle),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s.sharedFrames),
                    content: Text(s.sharedFramesBody),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(s.cancel)),
                    ],
                  ),
                );
              },
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
