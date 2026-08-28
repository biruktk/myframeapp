import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/task_queue_service.dart';

/// Non-intrusive top banner showing active background dispatch tasks.
///
/// Place at the top of a Scaffold body (e.g. in a Column, or as a
/// `SafeArea`-wrapped sliver) — it collapses to nothing when there are no
/// active/incomplete tasks.
class TaskProgressOverlay extends StatelessWidget {
  const TaskProgressOverlay({super.key, this.strings});

  final AppStrings? strings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrackedTask>>(
      valueListenable: TaskQueueService.instance.activeTasks,
      builder: (context, tasks, _) {
        final visible = tasks
            .where((t) => !t.isCompleted && !t.isFailed)
            .toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        final task = visible.last;
        final s = strings ?? AppStrings.of(context);
        final anyFailed = visible.any((t) => t.isFailed);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: anyFailed
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (!anyFailed)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anyFailed
                          ? s.taskPushedFailed
                          : s.pushingToFrameBackground,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.pushingToFrameBackground,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: _aggregateProgress(visible),
                minHeight: 4,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
            ],
          ),
        );
      },
    );
  }

  double _aggregateProgress(List<TrackedTask> tasks) {
    if (tasks.isEmpty) return 0;
    final sum =
        tasks.fold<double>(0, (acc, t) => acc + t.progress);
    return (sum / tasks.length).clamp(0.0, 1.0);
  }
}
