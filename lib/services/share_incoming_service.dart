import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Queues images shared into MyFrame from the system gallery / photos app.
class ShareIncomingService {
  ShareIncomingService._();

  static final ShareIncomingService instance = ShareIncomingService._();

  final List<String> _pendingPaths = [];
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _listening = false;

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> bootstrap() async {
    if (_listening) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _listening = true;

    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _enqueue(initial);
    } catch (e) {
      debugPrint('ShareIncomingService initial: $e');
    }

    ReceiveSharingIntent.instance.getMediaStream().listen(
      _enqueue,
      onError: (Object e) => debugPrint('ShareIncomingService stream: $e'),
    );
  }

  void _enqueue(List<SharedMediaFile> files) {
    var added = false;
    for (final f in files) {
      if (f.type != SharedMediaType.image) continue;
      final path = f.path.trim();
      if (path.isEmpty) continue;
      if (!File(path).existsSync()) continue;
      if (_pendingPaths.contains(path)) continue;
      _pendingPaths.add(path);
      added = true;
    }
    if (added) revision.value++;
  }

  /// Returns queued image paths and clears the queue.
  List<String> takePendingPaths() {
    if (_pendingPaths.isEmpty) return const [];
    final out = List<String>.from(_pendingPaths);
    _pendingPaths.clear();
    return out;
  }

  bool get hasPending => _pendingPaths.isNotEmpty;

  void requeuePaths(Iterable<String> paths) {
    var added = false;
    for (final path in paths) {
      final p = path.trim();
      if (p.isEmpty || _pendingPaths.contains(p)) continue;
      if (!File(p).existsSync()) continue;
      _pendingPaths.add(p);
      added = true;
    }
    if (added) revision.value++;
  }
}
