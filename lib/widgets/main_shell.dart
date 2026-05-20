import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../screens/family_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/home_screen.dart';
import '../screens/send_screen.dart';
import '../screens/settings_screen.dart';
import '../services/share_incoming_service.dart';
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
    ShellNavigation.registerHost(_setIndex);
    ShareIncomingService.instance.revision.addListener(_onShareIncomingRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeSharedPaths());
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
    final primary = cs.primary;

    final body = switch (_index) {
      0 => const HomeScreen(),
      1 => const GalleryScreen(),
      2 => SendScreen(
          galleryPickNonce: sendGalleryPickNonce,
          sharedPathsNonce: sendSharedPathsNonce,
        ),
      3 => const FamilyScreen(),
      4 => const SettingsScreen(),
      _ => const HomeScreen(),
    };

    return Scaffold(
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(bottom: ShellNavigation.contentBottomOverlap(context)),
        child: body,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Tooltip(
        message: s.navSend,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Material(
            shape: CircleBorder(
              side: _index == 2
                  ? BorderSide(color: cs.onPrimary.withValues(alpha: 0.9), width: 3)
                  : BorderSide.none,
            ),
            elevation: _index == 2 ? 8 : 6,
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
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        height: 64,
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
              onTap: () => _setIndex(0),
            ),
            _DockItem(
              icon: Icons.arrow_circle_up_outlined,
              selIcon: Icons.arrow_circle_up_rounded,
              label: s.navGallery,
              selected: _index == 1,
              primary: primary,
              onTap: () => _setIndex(1),
            ),
            const SizedBox(width: 80),
            _DockItem(
              icon: Icons.groups_outlined,
              selIcon: Icons.groups_rounded,
              label: s.navFamily,
              selected: _index == 3,
              primary: primary,
              onTap: () => _setIndex(3),
            ),
            _DockItem(
              icon: Icons.settings_outlined,
              selIcon: Icons.settings_rounded,
              label: s.navSettings,
              selected: _index == 4,
              primary: primary,
              onTap: () => _setIndex(4),
            ),
          ],
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
  });

  final IconData icon;
  final IconData selIcon;
  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final col = selected ? primary : cs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selIcon : icon, color: col, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: col),
            ),
          ],
        ),
      ),
    );
  }
}
