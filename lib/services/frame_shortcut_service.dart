import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'app_diag_log.dart';

/// Donates iOS `INSendMessageIntent` shortcuts (Siri Suggestions) so paired
/// MyFrame frame targets surface in the top circular row of the native Share
/// Sheet (next to AirDrop / recent contacts). See the native
/// `FrameShortcutPlugin` (ios/Runner/FrameShortcutPlugin.swift).
///
/// Call [donateFrame] whenever a frame is paired, selected as the active frame,
/// or used for a send — that is what teaches Siri to rank it as a 1-tap target.
class FrameShortcutService {
  FrameShortcutService._();
  static final FrameShortcutService instance = FrameShortcutService._();

  static const _methodChannel = MethodChannel('myframe/frame_shortcuts');

  /// True on iOS where Siri/Shortcuts donation is available.
  bool get isSupported => Platform.isIOS;

  /// Donate a frame target. best-effort — iOS may silently ignore donations or
  /// delay re-ranking until Siri re-learns, so failures are only logged.
  Future<void> donateFrame({
    required String frameName,
    required String frameMac,
    bool withAppIcon = true,
  }) async {
    if (!isSupported) return;
    final name = frameName.trim();
    final mac = frameMac.trim();
    if (name.isEmpty && mac.isEmpty) return;
    try {
      await _methodChannel.invokeMethod<void>(
        withAppIcon ? 'donateFrameSelected' : 'donateFrame',
        {'frameName': name, 'frameMac': mac},
      );
    } catch (e) {
      AppDiagLog.verbose('[FrameShortcut] donate failed: $e');
    }
  }

  /// Assist iOS to re-rank donated interactions (best-effort).
  Future<void> deleteAllDonations() async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('deleteAllDonations');
    } catch (e) {
      AppDiagLog.verbose('[FrameShortcut] clear failed: $e');
    }
  }
}
