import 'dart:async';

import 'package:flutter/foundation.dart';

import 'frame_api_client.dart';
import 'fcm_service.dart';

/// A single dispatch task tracked by the client (mirrors backend task states).
class TrackedTask {
  TrackedTask({
    required this.taskId,
    required this.deviceId,
    required this.displayName,
    required this.totalItems,
    this.status = 'uploaded',
    this.msgid,
  });

  final String taskId;
  final String deviceId;
  final String displayName;
  final int totalItems;
  String status;
  String? msgid;

  double get progress => status == 'completed' ? 1 : 0;
  bool get isCompleted => status == 'completed';
  bool get isFailed =>
      status == 'failed' ||
      status == 'timeout_no_ack' ||
      status == 'publish_failed';

  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'deviceId': deviceId,
        'displayName': displayName,
        'totalItems': totalItems,
        'status': status,
        'msgid': msgid,
      };
}

/// Global, app-wide background task tracker.
///
/// When a photo/strategy is sent, the backend returns a `taskId`. This service
/// registers it, polls `GET /api/v1/tasks/:taskId/status` every ~2.5s, and
/// surfaces a completion/failure via:
///   * [activeTasks] ValueNotifier (drives [TaskProgressOverlay])
///   * a local/system notification on completion
class TaskQueueService {
  TaskQueueService._();
  static final TaskQueueService instance = TaskQueueService._();

  /// Ordered active tasks (most recent last).
  final ValueNotifier<List<TrackedTask>> activeTasks =
      ValueNotifier<List<TrackedTask>>(const []);

  /// Single running task per frame at a time — enforced by backend FIFO; this
  /// map tracks the client-side pollers so we don't double-poll.
  final Map<String, TrackedTask> _runningByFrame = {};
  final Map<String, Timer> _timersByTask = {};
  bool _notifyInitialized = false;

  /// How many complete/failed tasks are retained in [activeTasks].
  static const int _maxRetained = 12;

  /// Whether [trackTask] should also fire a system notification on completion.
  bool notifyOnComplete = true;

  /// Register a dispatch task and begin polling its backend status.
  Future<void> trackTask({
    required String taskId,
    required String deviceId,
    required String displayName,
    int totalItems = 1,
    bool notifyOnComplete = true,
    Duration pollInterval = const Duration(milliseconds: 2500),
  }) async {
    if (taskId.trim().isEmpty) return;
    final existing =
        activeTasks.value.any((t) => t.taskId == taskId);
    if (existing) return;

    final task = TrackedTask(
      taskId: taskId,
      deviceId: deviceId,
      displayName: displayName,
      totalItems: totalItems,
    );
    _runningByFrame[deviceId] = task;
    _append(task);
    _startPolling(task, pollInterval);
  }

  void _startPolling(TrackedTask task, Duration interval) {
    _cancelPoll(task.taskId);
    final timer = Timer.periodic(interval, (timer) async {
      try {
        final status = await fetchTaskStatus(task.taskId);
        if (status == null) {
          // Not found yet — transient; keep polling.
          return;
        }
        _applyServerStatus(task, status);
        if (task.isCompleted || task.isFailed) {
          timer.cancel();
          _timersByTask.remove(task.taskId);
          _runningByFrame.remove(task.deviceId);
          if (task.isCompleted && notifyOnComplete) {
            await FcmService.instance.showCompletionNotification(
              title: 'Display Complete',
              body: 'Your photo is now displaying on the frame.',
              payload: task.toMap().toString(),
            );
          }
          _refreshNotifier();
        }
      } catch (_) {
        // Network hiccup — keep polling on next tick.
      }
    });
    _timersByTask[task.taskId] = timer;
  }

  Future<String?> fetchTaskStatus(String taskId) async {
    try {
      final api = FrameApiClient();
      try {
        final res = await api.fetchTaskStatus(taskId);
        if (res == null) return null;
        return res['status'] as String?;
      } finally {
        api.close();
      }
    } catch (_) {
      return null;
    }
  }

  void _applyServerStatus(TrackedTask task, String status) {
    task.status = status;
    _refreshNotifier();
  }

  void _append(TrackedTask task) {
    final list = List<TrackedTask>.from(activeTasks.value)
      ..add(task);
    if (list.length > _maxRetained) {
      list.removeRange(0, list.length - _maxRetained);
    }
    activeTasks.value = list;
  }

  void _refreshNotifier() {
    activeTasks.value = List<TrackedTask>.from(activeTasks.value);
  }

  void _cancelPoll(String taskId) {
    final timer = _timersByTask.remove(taskId);
    timer?.cancel();
  }

  /// Manually mark a task failed/done from UI (e.g. retry cancelled).
  void markDone(String taskId) {
    final task = _find(taskId);
    if (task != null) {
      task.status = 'completed';
      _cancelPoll(taskId);
      _runningByFrame.remove(task.deviceId);
      _refreshNotifier();
    }
  }

  void markFailed(String taskId) {
    final task = _find(taskId);
    if (task != null) {
      task.status = 'failed';
      _cancelPoll(taskId);
      _runningByFrame.remove(task.deviceId);
      _refreshNotifier();
    }
  }

  TrackedTask? _find(String taskId) {
    for (final t in activeTasks.value) {
      if (t.taskId == taskId) return t;
    }
    return null;
  }

  void dispose() {
    for (final t in _timersByTask.values) {
      t.cancel();
    }
    _timersByTask.clear();
    _runningByFrame.clear();
    activeTasks.dispose();
  }
}
