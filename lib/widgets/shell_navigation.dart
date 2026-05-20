import 'package:flutter/material.dart';

/// Tab switching for [MainShell] without an [InheritedWidget] (avoids framework
/// teardown assertions such as `_dependents.isEmpty` when overlays/tooltips
/// interact with the shell).
class ShellNavigation {
  ShellNavigation._();

  static void Function(int index)? _setTab;

  static void registerHost(void Function(int index) setTab) {
    _setTab = setTab;
  }

  static void unregisterHost() {
    _setTab = null;
  }

  /// Switch the main shell tab: 0 My Frames, 1 Gallery, 2 Send, 3 Family, 4 Settings.
  static void goToTab(int index) {
    if (index < 0 || index >= 5) return;
    _setTab?.call(index);
  }

  /// Bottom inset for shell tab bodies while [Scaffold.extendBody] is true:
  /// system gesture inset + [BottomAppBar] + center-docked FAB clearance.
  static double contentBottomOverlap(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 100;
  }
}
