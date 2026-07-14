import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// iPad/iPhone require a non-zero [sharePositionOrigin] for the share sheet.
Rect sharePositionOriginFor(BuildContext context, {Rect? anchor}) {
  if (anchor != null && anchor.width > 0 && anchor.height > 0) return anchor;
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
    final origin = box.localToGlobal(Offset.zero) & box.size;
    if (origin.width > 0 && origin.height > 0) return origin;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromLTWH(size.width * 0.5, size.height * 0.5, 1, 1);
}

Future<ShareResult> platformShareText(
  BuildContext context, {
  required String text,
  String? subject,
  Rect? sharePositionOrigin,
}) {
  return Share.share(
    text,
    subject: subject,
    sharePositionOrigin: Platform.isIOS || Platform.isMacOS
        ? (sharePositionOrigin ?? sharePositionOriginFor(context))
        : null,
  );
}

Future<ShareResult> platformShareFiles(
  BuildContext context, {
  required List<XFile> files,
  String? text,
  String? subject,
  Rect? sharePositionOrigin,
}) {
  return Share.shareXFiles(
    files,
    text: text,
    subject: subject,
    sharePositionOrigin: Platform.isIOS || Platform.isMacOS
        ? (sharePositionOrigin ?? sharePositionOriginFor(context))
        : null,
  );
}
