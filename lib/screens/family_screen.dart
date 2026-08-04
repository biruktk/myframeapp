import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/platform_share.dart';

import '../config/api_config.dart';
import '../config/vps_defaults.dart';
import '../l10n/app_strings.dart';
import '../services/account_sync_service.dart';
import '../services/device_store.dart';
import '../services/family_group_store.dart';
import '../services/family_invite_deep_link.dart';
import '../services/fcm_service.dart';
import '../services/share_service.dart';
import '../settings/app_settings.dart';
import '../widgets/app_status_toast.dart';
import '../widgets/shell_navigation.dart';


class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> with WidgetsBindingObserver {
  var _busy = false;
  var _storeLoadStarted = false;
  var _joinSheetOpen = false;
  /// True while resolving invite when there is no usable cached code yet.
  var _inviteLoading = false;
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FamilyInviteDeepLink.revision.addListener(_onInviteDeepLink);
    FamilyGroupStore.instance.revision.addListener(_onFamilyStoreRevision);
    ShellNavigation.activeTab.addListener(_onShellTabChanged);
    FcmService.instance.familyPushRevision.addListener(_onFamilyPush);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openJoinIfPending();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FamilyInviteDeepLink.revision.removeListener(_onInviteDeepLink);
    FamilyGroupStore.instance.revision.removeListener(_onFamilyStoreRevision);
    ShellNavigation.activeTab.removeListener(_onShellTabChanged);
    FcmService.instance.familyPushRevision.removeListener(_onFamilyPush);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ShellNavigation.activeTab.value == 3) {
      unawaited(_refreshVisible());
    }
  }

  void _onShellTabChanged() {
    if (!mounted) return;
    if (ShellNavigation.activeTab.value == 3) {
      unawaited(_refreshVisible());
    }
  }

  void _onFamilyPush() {
    if (!mounted) return;
    unawaited(_refreshVisible());
  }

  void _onFamilyStoreRevision() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshVisible() async {
    if (!mounted || _refreshing) return;
    final app = AppSettingsScope.of(context);
    await _loadStore(app, quiet: true);
  }

  void _onInviteDeepLink() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openJoinIfPending();
    });
  }

  void _openJoinIfPending() {
    final pre = FamilyInviteDeepLink.takePendingCode();
    if (pre == null || pre.length < 8) return;
    if (_joinSheetOpen) return;
    _showJoinSheet(context, AppStrings.of(context), prefill: pre);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storeLoadStarted) return;
    _storeLoadStarted = true;
    final app = AppSettingsScope.of(context);
    unawaited(_loadStore(app));
  }

  Future<void> _loadStore(AppSettings app, {bool quiet = false}) async {
    if (!mounted) return;
    if (_refreshing) return;
    _refreshing = true;
    final owner = () {
      final fromName = app.profileName.trim();
      if (fromName.isNotEmpty) return fromName;
      final mail = app.accountEmail.trim();
      if (mail.isNotEmpty) return mail.split('@').first;
      return 'You';
    };
    try {
      await FamilyGroupStore.instance.ensureLoaded(ownerDisplayName: owner);
      final g = FamilyGroupStore.instance;
      final tok = app.authToken.trim();

      // Show cached invite immediately when we already have a cloud-backed code.
      final hasCachedServerCode =
          g.cloudSynced && FamilyGroupStore.normalizeCode(g.inviteCode).length >= 8;
      if (mounted && !quiet) {
        setState(() {
          // Signed-in without a known server code → shimmer instead of ghost local "…".
          _inviteLoading = tok.isNotEmpty && !hasCachedServerCode;
        });
      }

      if (tok.isNotEmpty) {
        try {
          await DeviceStore.instance.load();
          // Only auto-create for owners who already have a local frame.
          // Bare invitees must NOT get a new empty family (that races with Join).
          final mayCreate =
              DeviceStore.instance.pairedFrames.isNotEmpty && !g.cloudSynced;
          await FamilyGroupStore.instance.refreshInviteFromServer(
            ApiConfig.baseUrl,
            tok,
            name: g.familyName,
            createIfMissing: mayCreate && !quiet,
          );
          // Always re-pull members so the owner sees newly joined people.
          await FamilyGroupStore.instance.pullFromRemote(ApiConfig.baseUrl, tok);
          // Pull shared family frames onto Home (pairedFrames), not just a side cache.
          await DeviceStore.instance.syncServerFrames(bearerToken: tok);
          await AccountSyncService.instance.syncAccountState(
            force: true,
            authTokenOverride: tok,
            replaceFrames: false,
            pruneMissingFrames: false,
          );
        } catch (_) {
          // Keep whatever cache we already painted.
        }
      }

      if (mounted) {
        setState(() => _inviteLoading = false);
      }
    } finally {
      _refreshing = false;
    }
  }

  String _inviteWebUrl(FamilyGroupStore g) {
    final s = AppStrings.of(context);
    return ShareService.withShareLang(
      'https://${VpsDefaults.hostnameInk}/join?code=${Uri.encodeComponent(g.inviteCode)}',
      s,
    );
  }

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
    try {
      await FamilyGroupStore.instance
          .rotateInviteOnServer(ApiConfig.baseUrl, tok);
      if (context.mounted) {
        AppStatusToast.show(
          context,
          title: s.familyCodeRegeneratedTitle,
          message: s.familyCodeRegenerated,
          tone: AppStatusTone.success,
          icon: Icons.refresh_rounded,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppStatusToast.show(
          context,
          title: s.familyCodeRegenerateFailedTitle,
          message: s.familyCodeRegenerateFailed,
          tone: AppStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showJoinSheet(BuildContext context, AppStrings s,
      {String? prefill}) async {
    if (_joinSheetOpen) return;
    _joinSheetOpen = true;
    final appTok = AppSettingsScope.of(context).authToken.trim();
    final birthdayPrefill = AppSettingsScope.of(context).birthday;
    try {
      final joined = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => _JoinFamilySheet(
          strings: s,
          prefill: prefill,
          birthdayPrefill: birthdayPrefill,
          authToken: appTok,
        ),
      );
      if (joined != true || !mounted) return;
      final tok = AppSettingsScope.of(this.context).authToken.trim();
      if (tok.isNotEmpty) {
        FamilyGroupStore.instance.invalidatePendingFamilyEnsure();
        // Family frames first (GET /api/frames), then profile merge without pruning
        // so a partial profile cannot wipe the just-synced shared devices.
        await DeviceStore.instance.syncServerFrames(bearerToken: tok);
        await AccountSyncService.instance.syncAccountState(
          force: true,
          authTokenOverride: tok,
          replaceFrames: false,
          pruneMissingFrames: false,
        );
        // Second pass in case membership/frame pool lagged on the first read.
        await DeviceStore.instance.syncServerFrames(bearerToken: tok);
      }
      if (!mounted) return;
      setState(() {});
      // Invitees should land on Home where the shared frame appears for send/playlist.
      ShellNavigation.goToTab(0);
      AppStatusToast.show(
        this.context,
        title: s.joinFamilySuccessTitle,
        message: s.joinFamilySuccess,
        tone: AppStatusTone.success,
        icon: Icons.family_restroom_rounded,
        duration: const Duration(seconds: 4),
      );
    } finally {
      _joinSheetOpen = false;
    }
  }

  Future<void> _inviteShare(BuildContext context, AppStrings s) async {
    final g = FamilyGroupStore.instance;
    final inviteUrl = _inviteWebUrl(g);
    await platformShareText(
      context,
      text: ShareService.familyInviteShareBody(
        strings: s,
        familyName: g.familyName,
        inviteCode: g.inviteCode,
        webUrl: inviteUrl,
      ),
      subject: ShareService.familyInviteSubject(s, g.familyName),
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
    if (!g.cloudSynced) return null;
    final me = app.authUserId.trim();
    final isCurrentUserOwner = me.isNotEmpty &&
        g.members.any((x) => x.role == FamilyRoles.owner && x.id == me);
    if (!isCurrentUserOwner) return null;

    return IconButton(
      icon: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
      tooltip: s.familyRemoveMemberConfirm,
      onPressed: () async {
        final cs = Theme.of(context).colorScheme;
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(s.familyRemoveMemberTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(s.familyRemoveMemberBody(m.displayName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(
                  s.familyRemoveMemberConfirm,
                  style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        if (go != true || !context.mounted) return;

        final tok = app.authToken.trim();
        final ok = await FamilyGroupStore.instance.removeMember(
          m.id,
          apiOrigin: tok.isNotEmpty ? ApiConfig.baseUrl : null,
          token: tok.isNotEmpty ? tok : null,
        );
        if (!context.mounted) return;
        if (!ok) {
          AppStatusToast.show(
            context,
            title: s.familyRemoveMemberTitle,
            message: s.familyMemberRemoveFailed,
            tone: AppStatusTone.error,
          );
          return;
        }
        if (tok.isNotEmpty) {
          await DeviceStore.instance.syncServerFrames(bearerToken: tok);
        }
        if (!mounted) return;
        setState(() {});
        AppStatusToast.show(
          context,
          title: s.familyMemberRemoved(m.displayName),
          message: s.familyMemberUnlinkedSub,
          tone: AppStatusTone.success,
          icon: Icons.person_remove_outlined,
        );
      },
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
        if (!context.mounted) return;
        AppStatusToast.show(
          context,
          title: s.familyCloudCreateSuccessTitle,
          message: s.familyCloudCreateSuccess,
          tone: AppStatusTone.success,
          icon: Icons.cloud_done_rounded,
        );
      } catch (_) {
        if (!context.mounted) return;
        AppStatusToast.show(
          context,
          title: s.familyCloudCreateFailedTitle,
          message: s.familyCloudCreateFailed,
          tone: AppStatusTone.error,
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
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
            if (app.authToken.isNotEmpty &&
                !g.cloudSynced &&
                !_inviteLoading) ...[
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
                    if (_inviteLoading &&
                        (!g.cloudSynced || g.inviteCode.isEmpty))
                      const _InviteCodeShimmer()
                    else
                      GestureDetector(
                        onTap: () {
                          if (g.inviteCode.isEmpty) return;
                          Clipboard.setData(ClipboardData(text: g.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.familyCodeCopied)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SelectableText(
                                g.inviteCode.isEmpty ? '—' : g.inviteCode,
                                style: TextStyle(
                                    fontSize: 22,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface),
                              ),
                              if (g.inviteCode.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.copy_rounded,
                                    size: 20, color: cs.primary),
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
                          child: (_inviteLoading &&
                                  (!g.cloudSynced || g.inviteCode.isEmpty))
                              ? const _InviteQrShimmer()
                              : QrImageView(
                                  data: g.inviteCode.isEmpty
                                      ? 'https://${VpsDefaults.hostnameInk}/join'
                                      : _inviteWebUrl(g),
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
                            onPressed: g.inviteCode.isEmpty
                                ? null
                                : () => _inviteShare(context, s),
                            icon: const Icon(Icons.ios_share_outlined),
                            label: Text(s.inviteFamily),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: (_busy || _inviteLoading)
                            ? null
                            : () => _confirmRegenerateInvite(context, s),
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
            if (!g.cloudSynced)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  s.familyMembersNeedCloudHint,
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                ),
              )
            else if (g.members.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  s.familyMembersEmptyHint,
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                ),
              )
            else ...[
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
              if (g.members.every((m) => m.role == FamilyRoles.owner))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s.familyMembersEmptyHint,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.35, fontSize: 13),
                  ),
                ),
            ],
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
  });

  final AppStrings strings;
  final String? prefill;
  final String birthdayPrefill;
  final String authToken;

  @override
  State<_JoinFamilySheet> createState() => _JoinFamilySheetState();
}

class _JoinFamilySheetState extends State<_JoinFamilySheet> {
  late final TextEditingController _ctrl;
  DateTime? _birthdayPick;
  var _joining = false;
  _JoinFeedback? _feedback;

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

  void _showFeedback(_JoinFeedback feedback) {
    if (!mounted) return;
    setState(() => _feedback = feedback);
    AppStatusToast.show(
      context,
      title: feedback.title,
      message: feedback.message,
      tone: feedback.tone,
      icon: feedback.icon,
    );
  }

  _JoinFeedback _feedbackFor(JoinFamilyResult r, AppStrings s) {
    return switch (r) {
      JoinFamilyResult.ok => _JoinFeedback(
          title: s.joinFamilySuccessTitle,
          message: s.joinFamilySuccess,
          tone: AppStatusTone.success,
          icon: Icons.family_restroom_rounded,
        ),
      JoinFamilyResult.codeTooShort => _JoinFeedback(
          title: s.joinFamilyCodeTooShortTitle,
          message: s.joinFamilyCodeTooShort,
          tone: AppStatusTone.warning,
          icon: Icons.pin_outlined,
        ),
      JoinFamilyResult.ownInviteCode => _JoinFeedback(
          title: s.joinFamilyOwnCodeTitle,
          message: s.joinFamilyOwnCodeHint,
          tone: AppStatusTone.info,
          icon: Icons.share_rounded,
        ),
      JoinFamilyResult.alreadyMember => _JoinFeedback(
          title: s.joinFamilyAlreadyMemberTitle,
          message: s.joinFamilyAlreadyMember,
          tone: AppStatusTone.info,
          icon: Icons.how_to_reg_rounded,
        ),
      JoinFamilyResult.notFound => _JoinFeedback(
          title: s.joinFamilyNotFoundTitle,
          message: s.joinFamilyNotFound,
          tone: AppStatusTone.error,
          icon: Icons.search_off_rounded,
        ),
      JoinFamilyResult.invalidInvite => _JoinFeedback(
          title: s.joinFamilyInvalidCodeTitle,
          message: s.joinFamilyInvalidCode,
          tone: AppStatusTone.error,
          icon: Icons.link_off_rounded,
        ),
      JoinFamilyResult.unauthorized => _JoinFeedback(
          title: s.joinFamilyNeedLoginTitle,
          message: s.joinFamilyNeedLogin,
          tone: AppStatusTone.warning,
          icon: Icons.lock_outline_rounded,
        ),
      JoinFamilyResult.networkError => _JoinFeedback(
          title: s.joinFamilyNetworkErrorTitle,
          message: s.joinFamilyNetworkError,
          tone: AppStatusTone.error,
          icon: Icons.wifi_off_rounded,
        ),
    };
  }

  Future<void> _confirm() async {
    if (_joining) return;
    final s = widget.strings;
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      _showFeedback(
        _JoinFeedback(
          title: s.joinFamilyCodeRequiredTitle,
          message: s.joinFamilyCodeRequired,
          tone: AppStatusTone.warning,
          icon: Icons.edit_outlined,
        ),
      );
      return;
    }
    final norm = FamilyGroupStore.normalizeCode(raw);
    if (norm.length != 8) {
      _showFeedback(_feedbackFor(JoinFamilyResult.codeTooShort, s));
      return;
    }
    if (_birthdayPick == null) {
      _showFeedback(
        _JoinFeedback(
          title: s.joinFamilyBirthdayRequiredTitle,
          message: s.joinFamilyBirthdayRequired,
          tone: AppStatusTone.warning,
          icon: Icons.cake_outlined,
        ),
      );
      return;
    }
    if (widget.authToken.trim().isEmpty) {
      _showFeedback(_feedbackFor(JoinFamilyResult.unauthorized, s));
      return;
    }

    setState(() {
      _joining = true;
      _feedback = null;
    });
    final bIso = _isoBirthday(_birthdayPick!);
    try {
      final r = await FamilyGroupStore.instance.joinWithCode(
        raw,
        labelIfNew: s.joinFamilyDefaultLabel(norm),
        bearerToken: widget.authToken,
        apiOrigin: ApiConfig.baseUrl,
        birthdayIso: bIso,
      );
      if (!mounted) return;

      if (r == JoinFamilyResult.ok || r == JoinFamilyResult.alreadyMember) {
        final scope = AppSettingsScope.of(context);
        try {
          await scope.setAccountProfile(
            name: scope.profileName,
            email: scope.accountEmail,
            birthdayValue: bIso,
          );
        } catch (_) {
          // Birthday save is best-effort; join already succeeded.
        }
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      _showFeedback(_feedbackFor(r, s));
    } catch (_) {
      _showFeedback(_feedbackFor(JoinFamilyResult.networkError, s));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final cs = Theme.of(context).colorScheme;
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
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            enabled: !_joining,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: s.joinFamilyHint,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
            maxLength: 12,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_feedback != null) setState(() => _feedback = null);
            },
            onSubmitted: (_) {
              if (!_joining) unawaited(_confirm());
            },
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: AppStatusBanner(
                key: ValueKey(_feedback!.title + _feedback!.message),
                title: _feedback!.title,
                message: _feedback!.message,
                tone: _feedback!.tone,
                icon: _feedback!.icon,
                onDismiss: () => setState(() => _feedback = null),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Divider(color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(
            s.joinFamilyProfileSection,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            s.joinFamilyBirthdayHint,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              enabled: !_joining,
              title: Text(s.joinFamilyBirthdayLabel),
              subtitle: Text(
                _birthdayPick == null ? '—' : _isoBirthday(_birthdayPick!),
              ),
              trailing: const Icon(Icons.cake_outlined),
              onTap: _joining
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _birthdayPick ?? DateTime(1990, 6, 15),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null && mounted) {
                        setState(() {
                          _birthdayPick = d;
                          _feedback = null;
                        });
                      }
                    },
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _joining ? null : () => unawaited(_confirm()),
            child: _joining
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(s.joinFamilyConfirm),
          ),
        ],
      ),
    );
  }
}

class _JoinFeedback {
  const _JoinFeedback({
    required this.title,
    required this.message,
    required this.tone,
    this.icon,
  });

  final String title;
  final String message;
  final AppStatusTone tone;
  final IconData? icon;
}

/// Subtle placeholder while the invite code is fetched / cloud family is created.
class _InviteCodeShimmer extends StatefulWidget {
  const _InviteCodeShimmer();

  @override
  State<_InviteCodeShimmer> createState() => _InviteCodeShimmerState();
}

class _InviteCodeShimmerState extends State<_InviteCodeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = 0.35 + (_c.value * 0.35);
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: t),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 148,
            height: 16,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      },
    );
  }
}

class _InviteQrShimmer extends StatefulWidget {
  const _InviteQrShimmer();

  @override
  State<_InviteQrShimmer> createState() => _InviteQrShimmerState();
}

class _InviteQrShimmerState extends State<_InviteQrShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = 0.2 + (_c.value * 0.25);
        return Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: t),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
