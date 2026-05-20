import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// How the user completed (or exited) the SD export flow.
enum SdBinExportDisposition {
  /// SAF / Files picker wrote [binBytes] to a URI the user chose (e.g. SD card).
  savedWithPicker,

  /// Share sheet was used (or shown as fallback after cancelling save).
  openedShareSheet,

  /// User finished without saving or sharing.
  cancelled,
}

/// Physical SD workflow from `ra/api`: user places `.bin` under `DCIM/MyFrame/` on the card.
///
/// On Android and iOS we open the system **Save** dialog first ([FilePicker.saveFile] with bytes)
/// so the user can pick removable storage or `Documents` without relying on the share sheet
/// (which can fail on some OEMs / Android 11+ visibility).
///
/// Falls back to [Share.shareXFiles] if the save dialog is cancelled or unavailable.
Future<SdBinExportDisposition> shareBinForPhysicalSd({
  required Uint8List binBytes,
  required String filename,
  String? message,
  String? saveDialogTitle,
}) async {
  final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final shareText = message ??
      'Save to SD card (recommended folder: DCIM/MyFrame/), then insert the card into the frame.';

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: saveDialogTitle,
        fileName: safeName,
        type: FileType.custom,
        allowedExtensions: const ['bin'],
        bytes: binBytes,
      );
      if (savedPath != null) {
        return SdBinExportDisposition.savedWithPicker;
      }
    } catch (_) {
      // Missing activity or unsupported device — fall through to share.
    }
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(binBytes);
  final shareResult = await Share.shareXFiles(
    [
      XFile(
        file.path,
        mimeType: 'application/octet-stream',
        name: safeName,
      ),
    ],
    text: shareText,
  );
  if (shareResult.status == ShareResultStatus.dismissed) {
    return SdBinExportDisposition.cancelled;
  }
  return SdBinExportDisposition.openedShareSheet;
}
