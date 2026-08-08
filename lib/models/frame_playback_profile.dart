import 'playback_config.dart';

/// Global frame-level playback profile.
///
/// Replaces per-album playback defaults: a single unified set of rules owned
/// by the frame (Frame Profile) that uploaded photos inherit unless the user
/// overrides them at send time.
///
/// Persisted/transmitted using the frame-settings API keys:
///  * `global_interval`        — minutes between photos (default 10)
///  * `global_playback_mode`    — `'sequential'` | `'random'` (default sequential)
///  * `global_duration`         — hours the slideshow stays active (default 6)
class FramePlaybackProfile {
  final int intervalMinutes;
  final String playbackMode;
  final int durationHours;

  const FramePlaybackProfile({
    this.intervalMinutes = 10,
    this.playbackMode = 'sequential',
    this.durationHours = 6,
  });

  /// Defaults applied to EXTERNAL SHARING payloads (gallery → app): 10 min /
  /// sequential / unlimited. These stay separate from internal playlist/album edits.
  static const FramePlaybackProfile externalShareDefaults = FramePlaybackProfile(
    intervalMinutes: 10,
    playbackMode: 'sequential',
    durationHours: 0,
  );

  static const String modeSequential = 'sequential';
  static const String modeRandom = 'random';

  bool get isRandom => playbackMode == modeRandom;
  int get strategy => isRandom ? 2 : 1;
  int get intervalSeconds => intervalMinutes * 60;
  int get durationSeconds => durationHours * 3600;

  FramePlaybackProfile copyWith({
    int? intervalMinutes,
    String? playbackMode,
    int? durationHours,
  }) =>
      FramePlaybackProfile(
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        playbackMode: playbackMode ?? this.playbackMode,
        durationHours: durationHours ?? this.durationHours,
      );

  /// Frame settings API payload — the global defaults stored on the frame's
  /// server profile and applied to all linked devices.
  Map<String, dynamic> toFrameSettingsPayload() => {
        'global_interval': intervalMinutes,
        'global_playback_mode': playbackMode,
        'global_duration': durationHours,
      };

  Map<String, dynamic> toJson() => toFrameSettingsPayload();

  factory FramePlaybackProfile.fromJson(Map<String, dynamic> json) {
    final interval = json['global_interval'] ?? json['intervalMinutes'];
    final duration = json['global_duration'] ?? json['durationHours'];
    final rawMode = json['global_playback_mode'];
    final strategy = json['strategy'];
    final String mode;
    if (rawMode is String &&
        (rawMode == modeSequential || rawMode == modeRandom)) {
      mode = rawMode;
    } else if (strategy is num && strategy.toInt() == 2) {
      mode = modeRandom;
    } else {
      mode = modeSequential;
    }
    return FramePlaybackProfile(
      intervalMinutes: interval is num ? interval.toInt() : 10,
      playbackMode: mode,
      durationHours: duration is num ? duration.toInt() : 6,
    );
  }

  PlaybackConfig toPlaybackConfig() => PlaybackConfig(
        intervalMinutes: intervalMinutes,
        strategy: strategy,
        durationHours: durationHours,
      );
}
