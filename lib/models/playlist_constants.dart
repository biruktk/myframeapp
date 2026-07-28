class PlaylistInterval {
  final int seconds;
  final String label;
  final String shortLabel;

  const PlaylistInterval({
    required this.seconds,
    required this.label,
    required this.shortLabel,
  });
}

const List<PlaylistInterval> kPlaylistIntervals = [
  PlaylistInterval(seconds: 60, label: "1 Minute", shortLabel: "1m"),
  PlaylistInterval(seconds: 120, label: "2 Minutes", shortLabel: "2m"),
  PlaylistInterval(seconds: 300, label: "5 Minutes", shortLabel: "5m"),
  PlaylistInterval(seconds: 600, label: "10 Minutes", shortLabel: "10m"),
  PlaylistInterval(seconds: 1800, label: "30 Minutes", shortLabel: "30m"),
  PlaylistInterval(seconds: 3600, label: "1 Hour", shortLabel: "1h"),
];
