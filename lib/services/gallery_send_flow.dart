import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/pairing_nav_result.dart';
import '../navigation/pairing_flow_nav.dart';
import '../screens/device_discovery_screen.dart';
import '../screens/image_editor_screen.dart';
import '../services/device_store.dart';
import '../services/frame_online_guard.dart';
import '../settings/app_settings.dart';
import '../widgets/frame_picker_sheet.dart';

/// Gallery / album photo → frame list → editor → automatic upload.
Future<bool> sendGalleryPhotoToFrame(
  BuildContext context, {
  required String path,
}) async {
  final s = AppStrings.of(context);
  final file = File(path);
  if (!await file.exists()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noImageSelected)),
      );
    }
    return false;
  }

  await DeviceStore.instance.load();
  var frames = DeviceStore.instance.pairedFrames;
  if (frames.isEmpty) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.shareIncomingConnectFrame),
        action: SnackBarAction(
          label: s.connectLabel,
          onPressed: () async {
            if (!context.mounted) return;
            final result = await Navigator.of(context).push<PairingNavResult>(
              MaterialPageRoute<PairingNavResult>(
                builder: (_) => const DeviceDiscoveryScreen(),
              ),
            );
            PairingFlowNav.onComplete(result);
          },
        ),
      ),
    );
    return false;
  }

  PairedFrame? picked;
  if (frames.length == 1) {
    picked = frames.first;
  } else if (context.mounted) {
    picked = await showFramePickerSheet(context, frames: frames);
  }
  if (picked == null || !context.mounted) return false;

  await DeviceStore.instance.setActiveFrameDeviceId(picked.deviceId);
  if (!await FrameOnlineGuard.ensureOnlineForSend(context, frame: picked)) {
    return false;
  }
  if (!context.mounted) return false;
  late final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noImageSelected)),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final slideshow = AppSettingsScope.of(context).defaultSlideshowStyle;
  final sent = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => ImageEditorScreen(
        imageBytes: bytes,
        galleryPersistPath: path,
        slideshow: slideshow,
        autoSendAfterLoad: true,
      ),
    ),
  );
  return sent == true;
}
