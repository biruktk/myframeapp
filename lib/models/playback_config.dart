class PlaybackConfig {
  final int intervalMinutes;
  final int strategy;
  final int durationHours;
  final int idle;

  const PlaybackConfig({
    required this.intervalMinutes,
    this.strategy = 1,
    this.durationHours = 0,
    this.idle = 1,
  });

  Map<String, dynamic> toJson() => {
        'intervalMinutes': intervalMinutes,
        'strategy': strategy,
        'durationHours': durationHours,
        'idle': idle,
      };

  factory PlaybackConfig.fromJson(Map<String, dynamic> json) => PlaybackConfig(
        intervalMinutes: json['intervalMinutes'] ?? 1,
        strategy: json['strategy'] ?? 1,
        durationHours: json['durationHours'] ?? 0,
        idle: json['idle'] ?? 1,
      );

  static const List<int> kDurationOptions = [0, 6, 12, 24, 48, 72];

  String get durationLabel {
    if (durationHours == 0) return 'Unlimited';
    if (durationHours < 24) return '${durationHours}h';
    final days = durationHours ~/ 24;
    return '$days day${days > 1 ? 's' : ''}';
  }

  String get strategyLabel => strategy == 1 ? 'Sequential' : 'Random';

  int get totalLoopSeconds => intervalMinutes * 60;

  String estimatedLoopTime(int photoCount) {
    final totalSec = totalLoopSeconds * photoCount;
    if (totalSec < 60) return '$totalSec sec';
    if (totalSec < 3600) return '${totalSec ~/ 60} min';
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}
