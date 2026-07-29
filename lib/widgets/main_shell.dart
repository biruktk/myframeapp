import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../screens/family_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/home_screen.dart';
import '../screens/send_screen.dart';
import '../screens/settings_screen.dart';
import '../services/fcm_service.dart';
import '../services/share_incoming_service.dart';
import '../services/user_gallery_cloud_service.dart';
import '../settings/app_settings.dart';
import 'shell_navigation.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _index = 0;
  final ValueNotifier<int> sendGalleryPickNonce = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> sendSharedPathsNonce = ValueNotifier<List<String>>(const []);

  @override
  void initState() {
    super.initState();
    ShellNavigation.registerHost(
      _setIndex,
      openSendGalleryPick: openSendGalleryPicker,
    );
    ShareIncomingService.instance.revision.addListener(_onShareIncomingRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeSharedPaths();
      _syncCloudGalleryIfSignedIn();
      _syncFcmTokenIfSignedIn();
    });
  }

  void _syncCloudGalleryIfSignedIn() {
    if (!mounted) return;
    final app = AppSettingsScope.of(context);
    if (!app.hasAuthenticatedSession) return;
    unawaited(UserGalleryCloudService.instance.syncFromServer(app.authToken));
  }

  void _syncFcmTokenIfSignedIn() {
    if (!mounted) return;
    final app = AppSettingsScope.of(context);
    if (!app.hasAuthenticatedSession) return;
    unawaited(FcmService.instance.syncTokenWithAuth(app));
  }

  @override
  void dispose() {
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

  void _consumeSharedPaths() {
    final paths = ShareIncomingService.instance.takePendingPaths();
    if (paths.isEmpty) return;
    openSendWithSharedPaths(paths);
  }

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
