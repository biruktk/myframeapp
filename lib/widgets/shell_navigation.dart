import 'package:flutter/material.dart';

/// Tab switching for [MainShell] without an [InheritedWidget] (avoids framework
/// teardown assertions such as `_dependents.isEmpty` when overlays/tooltips
/// interact with the shell).
class ShellNavigation {
  ShellNavigation._();

  static void Function(int index)? _setTab;
  static VoidCallback? _openSendGalleryPick;
  static bool _skipAlbumSheetOnNextGalleryPick = false;

  static void registerHost(
    void Function(int index) setTab, {
    VoidCallback? openSendGalleryPick,
  }) {
    _setTab = setTab;
    _openSendGalleryPick = openSendGalleryPick;
  }

  static void unregisterHost() {
    _setTab = null;
    _openSendGalleryPick = null;
  }

  /// True once after pairing: skip album sheet so picker goes straight to the editor.
  static bool consumeSkipAlbumSheetOnNextGalleryPick() {
    if (!_skipAlbumSheetOnNextGalleryPick) return false;
    _skipAlbumSheetOnNextGalleryPick = false;
    return true;
  }

  /// After Wi‑Fi + profile: open Send tab; optionally launch the photo picker.
  static void completePairingAndOpenSend({bool openGalleryPicker = true}) {
    if (openGalleryPicker) {
      _skipAlbumSheetOnNextGalleryPick = true;
    }
    void go() {
      goToTab(2);
      if (!openGalleryPicker) return;
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        _openSendGalleryPick?.call();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        go();
      });
    });
  }

  /// After Wi‑Fi + profile: open Send, request Photos if needed, show picker — user still edits before upload.
  static void scheduleOpenSendGalleryAfterPairing() {
    completePairingAndOpenSend(openGalleryPicker: true);
  }

  /// Switch the main shell tab: 0 My Frames, 1 Gallery, 2 Send, 3 Family, 4 Settings.
  static void goToTab(int index) {
    if (index < 0 || index >= 5) return;
    _setTab?.call(index);
    if (activeTab.value != index) activeTab.value = index;
  }

  /// Current shell tab index (updated by [MainShell] and [goToTab]).
  static final ValueNotifier<int> activeTab = ValueNotifier<int>(0);

  /// Switch to the Send tab (tab index 2).
  static void switchToSend() {
    goToTab(2);
  }

  /// After a successful cast: clear pushed routes (editor / playlist send),
  /// then land on the Send Photo tab.
  static void returnToSendAfterCast(BuildContext context) {
    if (context.mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switchToSend();
    });
  }

  /// Bottom inset for shell tab bodies while [Scaffold.extendBody] is true:
  /// system gesture inset + [BottomAppBar] + center-docked FAB clearance.
  static double contentBottomOverlap(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 100;
  }
}
