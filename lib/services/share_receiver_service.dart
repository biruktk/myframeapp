import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app_diag_log.dart';

/// One image handed off from the OS share sheet / share extension.
class SharedMediaItem {
  const SharedMediaItem({
    required this.path,
    this.thumbnail,
    this.mimeType,
    this.sessionId = '',
  });

  final String path;
  final String sessionId;
  final String? thumbnail;
  final String? mimeType;

  File get file => File(path);

  bool get exists => file.existsSync();
}

/// Receives OS-level shared images (Android SEND / iOS Share Extension).
class ShareReceiverService {
  ShareReceiverService._();

  static final ShareReceiverService instance = ShareReceiverService._();

  final List<List<SharedMediaItem>> _pending = [];
  final Map<String, DateTime> _received = {};
  final Map<String, String> _active = {};
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _listening = false;

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> bootstrap() async {
    if (_listening) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _listening = true;

    _subscription ??= ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        enqueueShared(files);
        unawaitedReset();
      },
      onError: (Object e) =>
          AppDiagLog.verbose('ShareReceiverService stream: $e'),
    );
    try {
      enqueueShared(await ReceiveSharingIntent.instance.getInitialMedia());
      await ReceiveSharingIntent.instance.reset();
    } catch (e) {
      AppDiagLog.verbose('ShareReceiverService initial: $e');
    }
  }

  void unawaitedReset() {
    ReceiveSharingIntent.instance.reset().catchError((Object e) {
      AppDiagLog.verbose('ShareReceiverService reset: $e');
    });
  }

  @visibleForTesting
  void enqueueShared(List<SharedMediaFile> files) {
    final images = files.where((f) => f.type == SharedMediaType.image).toList();
    final paths = images
        .map(
          (f) => f.path.startsWith('file://')
              ? Uri.parse(f.path).toFilePath()
              : f.path.trim(),
        )
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    if (paths.isEmpty) return;
    final sorted = [...paths]..sort();
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(sorted)))
        .toString();
    final now = DateTime.now();
    _received.removeWhere(
      (_, at) => now.difference(at) > const Duration(seconds: 30),
    );
    if (_received.containsKey(fingerprint) ||
        _active.containsKey(fingerprint)) {
      return;
    }
    _received[fingerprint] = now;
    final session = '${now.microsecondsSinceEpoch}_$fingerprint';
    _active[fingerprint] = session;
    _pending.add(
      paths.map((p) => SharedMediaItem(path: p, sessionId: session)).toList(),
    );
    revision.value++;
  }

  void completeBatch(String sessionId) {
    final keys = _active.entries
        .where((e) => e.value == sessionId)
        .map((e) => e.key)
        .toList();
    for (final key in keys) {
      _active.remove(key);
      _received[key] = DateTime.now();
    }
  }

  /// Take ONE OS share batch; independent shares must never be merged.
  List<SharedMediaItem> takePendingItems() =>
      _pending.isEmpty ? const [] : _pending.removeAt(0);

  /// Snapshot + clear as bare paths (legacy).
  List<String> takePendingPaths() =>
      takePendingItems().map((e) => e.path).toList(growable: false);

  bool get hasPending => _pending.isNotEmpty;

  void requeuePaths(Iterable<String> paths) {
    requeueItems(paths.map((p) => SharedMediaItem(path: p)));
  }

  void requeueItems(Iterable<SharedMediaItem> items) {
    final batch = items.toList();
    if (batch.isEmpty) return;
    _pending.insert(0, batch);
    revision.value++;
  }
}
