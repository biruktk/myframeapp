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
  }

  /// Switch to the Send tab (tab index 2).
  static void switchToSend() {
    goToTab(2);
  }

  /// Bottom inset for shell tab bodies while [Scaffold.extendBody] is true:
  /// system gesture inset + [BottomAppBar] + center-docked FAB clearance.
  static double contentBottomOverlap(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 100;
  }
}
