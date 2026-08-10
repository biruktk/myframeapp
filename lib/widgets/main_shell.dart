import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../screens/family_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/home_screen.dart';
import '../screens/send_screen.dart';
import '../screens/settings_screen.dart';
import '../services/account_sync_service.dart';
import '../services/device_store.dart';
import '../services/external_share_cast_service.dart';
import '../services/fcm_service.dart';
import '../services/gallery_image_cache.dart';
import '../services/share_extension_cache.dart';
import '../services/share_incoming_service.dart';
import '../services/sync_pipeline.dart';
import '../settings/app_settings.dart';
import 'share_auto_send_progress.dart';
import 'shell_navigation.dart';
import 'share_target_bottom_sheet.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  final ValueNotifier<int> sendGalleryPickNonce = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> sendSharedPathsNonce = ValueNotifier<List<String>>(const []);
  bool _shareSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShellNavigation.registerHost(
      _setIndex,
      openSendGalleryPick: openSendGalleryPicker,
    );
    ShareIncomingService.instance.revision.addListener(_onShareIncomingRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeSharedPaths();
      _startSyncPipeline();
      _syncFcmTokenIfSignedIn();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSyncPipeline();
      // Soft tick — not replaceFrames pull (that re-imported ghosts).
      unawaited(SyncPipeline.instance.tick(
        forceFrames: true,
        forceGallery: true,
        forceAlbums: true,
      ));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      SyncPipeline.instance.stop();
      AccountSyncService.instance.stopPeriodicSync();
    }
  }

  void _startSyncPipeline() {
    if (!mounted) return;
    final app = AppSettingsScope.of(context);
    if (!app.hasAuthenticatedSession) {
      SyncPipeline.instance.stop();
      AccountSyncService.instance.stopPeriodicSync();
      return;
    }
    // Single pipeline: 10s tick + event hooks. Stop legacy 2‑min-only poll.
    AccountSyncService.instance.stopPeriodicSync();
    SyncPipeline.instance.start(appSettings: app);
  }

  void _syncFcmTokenIfSignedIn() {
    if (!mounted) return;
    final app = AppSettingsScope.of(context);
    if (!app.hasAuthenticatedSession) return;
    unawaited(FcmService.instance.syncTokenWithAuth(app));
  }

  @override
  void dispose() {
    SyncPipeline.instance.stop();
    AccountSyncService.instance.stopPeriodicSync();
    WidgetsBinding.instance.removeObserver(this);
    ShareIncomingService.instance.revision.removeListener(_onShareIncomingRevision);
    ShellNavigation.unregisterHost();
    sendGalleryPickNonce.dispose();
    sendSharedPathsNonce.dispose();
    super.dispose();
  }

  void _onShareIncomingRevision() {
    if (!mounted) return;
    _consumeSharedPaths();
  }

  Future<void> _consumeSharedPaths() async {
    if (_shareSheetOpen) return;
    final items = ShareIncomingService.instance.takePendingItems();
    if (items.isEmpty) return;

    // Native iOS Share Extension hand-off: the user already picked the target
    // frame(s) in the sheet, so send straight to them (no destination picker).
    final autoFrameIds = await ShareExtensionCache.instance.consumeAutoSend();
    if (autoFrameIds.isNotEmpty) {
      final handled = await _autoSendToFrames(items, autoFrameIds);
      if (handled) return;
    }

    _shareSheetOpen = true;
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _shareSheetOpen = false;
          return;
        }
        try {
          await showShareTargetBottomSheet(context, items: items);
        } finally {
          _shareSheetOpen = false;
          // Drain any share that arrived while the sheet was open.
          if (mounted && ShareIncomingService.instance.hasPending) {
            _consumeSharedPaths();
          }
        }
      });
    } catch (_) {
      _shareSheetOpen = false;
      ShareIncomingService.instance.requeueItems(items);
    }
  }

  /// Sends shared items to the frames the native Share Extension pre-selected.
  /// Returns `true` when the send was handled here (no Flutter picker needed).
  Future<bool> _autoSendToFrames(
    List<SharedMediaItem> items,
    List<String> frameIds,
  ) async {
    final app = AppSettingsScope.of(context);
    final s = AppStrings.of(context);

    // Strip file:// prefixes the extension stores for non-container files.
    final raw = items.map((e) => e.path).map((p) {
      return p.startsWith('file://') ? Uri.parse(p).toFilePath() : p;
    }).toList();
    final persisted = await GalleryImageCache.persistPaths(raw);
    final paths = persisted.isNotEmpty ? persisted : raw;
    if (paths.isEmpty) return false;

    await DeviceStore.instance.load();
    final all = DeviceStore.instance.pairedFrames;
    final frames = all
        .where((f) => frameIds.contains(f.deviceId))
        .toList();
    if (frames.isEmpty) return false;

    if (!mounted) return false;
    final progress = ShareAutoSendProgress(context);
    // Fire-and-forget: the dialog closes when [progress.dismiss] is called
    // after the cast finishes (awaiting show() would deadlock the send).
    unawaited(progress.show());
    try {
      final summary = await ExternalShareCastService.instance.castToFrames(
        paths: paths,
        frames: frames,
        authToken: app.authToken,
        strings: s,
        onProgress: (frac, status) => progress.update(frac, status),
      );
      if (!mounted) {
        progress.dismiss();
        return true;
      }

      final messenger = ScaffoldMessenger.of(context);
      if (summary.queued) {
        messenger.showSnackBar(SnackBar(content: Text(s.shareSheetQueuedOffline)));
      } else if (summary.sent > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(frames.length == 1 ? s.shareSheetPhotoSent : s.shareSheetPlaylistSent)),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text(s.shareSheetErrorRetry)));
      }

      // Remember the chosen frame for the next native share.
      unawaited(
        ShareExtensionCache.instance
            .writeSelectedFrameIds(frames.map((f) => f.deviceId)),
      );
      // Multi-image external shares collect into the default "My Playlist".
      unawaited(routeSharedToMyPlaylist(paths, app.authToken, s));
      return true;
    } finally {
      progress.dismiss();
    }
  }

  /// Legacy path: jump to Send tab with shared paths (album / sequential editor).
  void openSendWithSharedPaths(List<String> paths) {
    if (paths.isEmpty) return;
    _setIndex(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sendSharedPathsNonce.value = List<String>.from(paths);
    });
  }

  void openSendGalleryPicker() {
    _setIndex(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sendGalleryPickNonce.value++;
    });
  }

  void _setIndex(int i) {
    if (i < 0 || i >= 5) return;
    final prev = _index;
    if (prev == 2 && i != 2) {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    }
    setState(() => _index = i);
    if (ShellNavigation.activeTab.value != i) {
      ShellNavigation.activeTab.value = i;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final app = AppSettingsScope.of(context);
    final primary = cs.primary;
    final barColor = cs.surface;
    final comfort = app.comfortMode;
    final barHeight = comfort ? 72.0 : 64.0;
    final iconSize = comfort ? 28.0 : 24.0;
    final labelSize = comfort ? 11.0 : 10.0;

    return Scaffold(
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(bottom: ShellNavigation.contentBottomOverlap(context)),
        child: IndexedStack(
          index: _index,
          children: [
            const HomeScreen(),
            const GalleryScreen(),
            SendScreen(
              galleryPickNonce: sendGalleryPickNonce,
              sharedPathsNonce: sendSharedPathsNonce,
            ),
            const FamilyScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Tooltip(
        message: s.navSend,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Material(
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: primary.withValues(alpha: 0.45),
            color: primary,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: openSendGalleryPicker,
              child: Icon(Icons.send_rounded, color: cs.onPrimary, size: 30),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: barColor,
        child: SafeArea(
          top: false,
          child: BottomAppBar(
            clipBehavior: Clip.antiAlias,
            color: barColor,
            surfaceTintColor: Colors.transparent,
            shadowColor: cs.brightness == Brightness.dark
                ? Colors.black54
                : Colors.black12,
            elevation: 8,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            height: barHeight,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: Row(
              children: [
                _DockItem(
                  icon: Icons.home_outlined,
                  selIcon: Icons.home_rounded,
                  label: s.navMyFrames,
                  selected: _index == 0,
                  primary: primary,
                  iconSize: iconSize,
                  labelSize: labelSize,
                  onTap: () => _setIndex(0),
                ),
                _DockItem(
                  icon: Icons.arrow_circle_up_outlined,
                  selIcon: Icons.arrow_circle_up_rounded,
                  label: s.navGallery,
                  selected: _index == 1,
                  primary: primary,
                  iconSize: iconSize,
                  labelSize: labelSize,
                  onTap: () => _setIndex(1),
                ),
                SizedBox(width: comfort ? 88 : 80),
                _DockItem(
                  icon: Icons.groups_outlined,
                  selIcon: Icons.groups_rounded,
                  label: s.navFamily,
                  selected: _index == 3,
                  primary: primary,
                  iconSize: iconSize,
                  labelSize: labelSize,
                  onTap: () => _setIndex(3),
                ),
                _DockItem(
                  icon: Icons.settings_outlined,
                  selIcon: Icons.settings_rounded,
                  label: s.navSettings,
                  selected: _index == 4,
                  primary: primary,
                  iconSize: iconSize,
                  labelSize: labelSize,
                  onTap: () => _setIndex(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.selIcon,
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
    this.iconSize = 24,
    this.labelSize = 10,
  });

  final IconData icon;
  final IconData selIcon;
  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;
  final double iconSize;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final col = selected ? primary : cs.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selIcon : icon, color: col, size: iconSize),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: labelSize,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: col,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
