/// Live cast progress for upload UI (accurate phases, no premature failure).
enum CastPhase {
  preparing,
  connectingFrame,
  uploading,
  waitingOnFrame,
  wakingFrame,
  retrying,
  success,
  failed,
}

class CastProgress {
  const CastProgress({
    required this.phase,
    required this.message,
    this.progress,
    this.waitSeconds,
    this.showIndeterminate = false,
  });

  final CastPhase phase;
  final String message;

  /// 0.0–1.0 for determinate progress bar; null = indeterminate.
  final double? progress;
  final int? waitSeconds;
  final bool showIndeterminate;

  bool get isTerminal =>
      phase == CastPhase.success || phase == CastPhase.failed;
}
