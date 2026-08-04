import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app_diag_log.dart';

/// One image handed off from the OS share sheet / share extension.
class SharedMediaItem {
  const SharedMediaItem({
    required this.path,
    this.thumbnail,
    this.mimeType,
  });

  final String path;
  final String? thumbnail;
  final String? mimeType;

  File get file => File(path);

  bool get exists => file.existsSync();
}

/// Receives OS-level shared images (Android SEND / iOS Share Extension).
class ShareReceiverService {
  ShareReceiverService._();

  static final ShareReceiverService instance = ShareReceiverService._();

  final List<SharedMediaItem> _pending = [];
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _listening = false;

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> bootstrap() async {
    if (_listening) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _listening = true;

    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _enqueueShared(initial);
      await ReceiveSharingIntent.instance.reset();
    } catch (e) {
      AppDiagLog.verbose('ShareReceiverService initial: $e');
    }

    ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        _enqueueShared(files);
        unawaitedReset();
      },
      onError: (Object e) =>
          AppDiagLog.verbose('ShareReceiverService stream: $e'),
    );
  }

  void unawaitedReset() {
    ReceiveSharingIntent.instance.reset().catchError((Object e) {
      AppDiagLog.verbose('ShareReceiverService reset: $e');
    });
  }

  void _enqueueShared(List<SharedMediaFile> files) {
    var added = false;
    for (final f in files) {
      if (f.type != SharedMediaType.image) continue;
      var path = f.path.trim();
      if (path.isEmpty) continue;
      if (path.startsWith('file://')) {
        path = Uri.parse(path).toFilePath();
      }
      if (_pending.any((e) => e.path == path)) continue;
      _pending.add(SharedMediaItem(
        path: path,
        thumbnail: f.thumbnail,
        mimeType: f.mimeType,
      ));
      added = true;
    }
    if (added) revision.value++;
  }

  /// Snapshot + clear pending shared images.
  List<SharedMediaItem> takePendingItems() {
    if (_pending.isEmpty) return const [];
    final out = List<SharedMediaItem>.from(_pending);
    _pending.clear();
    return out;
  }

  /// Snapshot + clear as bare paths (legacy).
  List<String> takePendingPaths() =>
      takePendingItems().map((e) => e.path).toList(growable: false);

  bool get hasPending => _pending.isNotEmpty;

  void requeuePaths(Iterable<String> paths) {
    var added = false;
    for (final path in paths) {
      final p = path.trim();
      if (p.isEmpty || _pending.any((e) => e.path == p)) continue;
      _pending.add(SharedMediaItem(path: p));
      added = true;
    }
    if (added) revision.value++;
  }

  void requeueItems(Iterable<SharedMediaItem> items) {
    requeuePaths(items.map((e) => e.path));
  }
}
