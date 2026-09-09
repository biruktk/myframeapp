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

  /// After Wi‑Fi + profile: land on the Registered Frames list (My Frames tab)
  /// so the freshly named frame is immediately visible.
  static void completePairingAndShowFrames() {
    void go() {
      goToTab(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        go();
      });
    });
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

  /// Requested sub-tab inside the Gallery screen: 0 = Personal, 1 = Playlists.
  /// [GalleryScreen] listens and applies it (then resets to null).
  static final ValueNotifier<int?> gallerySubTabRequest = ValueNotifier<int?>(null);

  /// Switch to the Send tab (tab index 2).
  static void switchToSend() {
    goToTab(2);
  }

  /// Switch to the Gallery tab (tab index 1) so the live [PushProgressBanner]
  /// mounted on [GalleryScreen] is immediately visible after an external share
  /// uploads + registers a tracked push. [subTab] selects the inner Gallery
  /// segment: 0 = Personal, 1 = Playlists (default keeps the current one).
  static void goToGallery({int? subTab}) {
    goToTab(1);
    if (subTab != null) {
      gallerySubTabRequest.value = subTab;
    }
  }

  /// Switch to the Gallery tab and force the inner segment to [subTab].
  static void goToGalleryTab(int subTab) {
    goToTab(1);
    gallerySubTabRequest.value = subTab;
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

  /// After a successful send, pop every sheet/picker back to the shell and
  /// route to the Gallery tab with the correct inner segment — single photo →
  /// Personal (0), album/playlist → Playlists (1). Never leave the user on the
  /// Send screen.
  static void routeToGalleryAfterCast(BuildContext context, {required bool isPlaylist}) {
    if (context.mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      goToGalleryTab(isPlaylist ? 1 : 0);
    });
  }

  /// Bottom inset for shell tab bodies while [Scaffold.extendBody] is true:
  /// system gesture inset + [BottomAppBar] + center-docked FAB clearance.
  static double contentBottomOverlap(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 100;
  }
}
