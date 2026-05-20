import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Runtime usage stats captured from real app actions (no hardcoded home values).
class UsageMetricsStore {
  UsageMetricsStore._();
  static final UsageMetricsStore instance = UsageMetricsStore._();

  static const _kFirstSeenMs = 'usage_first_seen_ms';
  static const _kLastPhotoMs = 'usage_last_photo_ms';
  static const _kPhotosSent = 'usage_photos_sent_count';
  static const _kLastSdDetectedMs = 'usage_last_sd_detected_ms';
  static const _kShareCount = 'usage_share_count';
  static const _kDeleteCount = 'usage_delete_count';
  static const _kLogJson = 'usage_activity_log_json';

  Future<void> ensureInitialized() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(_kFirstSeenMs)) {
      await p.setInt(_kFirstSeenMs, DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<void> markPhotoSentNow() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await p.setInt(_kLastPhotoMs, now);
    final nextCount = (p.getInt(_kPhotosSent) ?? 0) + 1;
    await p.setInt(_kPhotosSent, nextCount);
    await _appendLog(p, 'photo', null);
  }

  Future<void> markSdDetectedNow() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastSdDetectedMs, DateTime.now().millisecondsSinceEpoch);
    await _appendLog(p, 'sd', null);
  }

  /// Invite link or other in-app share actions.
  Future<void> markShareEvent() async {
    final p = await SharedPreferences.getInstance();
    final next = (p.getInt(_kShareCount) ?? 0) + 1;
    await p.setInt(_kShareCount, next);
    await _appendLog(p, 'share', null);
  }

  Future<void> markDeleteEvent() async {
    final p = await SharedPreferences.getInstance();
    final next = (p.getInt(_kDeleteCount) ?? 0) + 1;
    await p.setInt(_kDeleteCount, next);
    await _appendLog(p, 'delete', null);
  }

  Future<UsageMetrics> load() async {
    final p = await SharedPreferences.getInstance();
    final firstSeenMs = p.getInt(_kFirstSeenMs);
    final lastPhotoMs = p.getInt(_kLastPhotoMs);
    final lastSdMs = p.getInt(_kLastSdDetectedMs);
    return UsageMetrics(
      firstSeenAt: firstSeenMs == null ? null : DateTime.fromMillisecondsSinceEpoch(firstSeenMs),
      lastPhotoAt: lastPhotoMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastPhotoMs),
      photosSentCount: p.getInt(_kPhotosSent) ?? 0,
      lastSdDetectedAt: lastSdMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastSdMs),
      shareCount: p.getInt(_kShareCount) ?? 0,
      deleteCount: p.getInt(_kDeleteCount) ?? 0,
      recentLog: _readLog(p),
    );
  }

  Future<void> _appendLog(SharedPreferences p, String kind, String? detail) async {
    final list = _readLog(p);
    const max = 40;
    list.insert(
      0,
      ActivityLogItem(atMs: DateTime.now().millisecondsSinceEpoch, kind: kind, detail: detail),
    );
    if (list.length > max) {
      list.removeRange(max, list.length);
    }
    final enc = <Map<String, Object?>>[];
    for (final e in list) {
      enc.add(e.toJson());
    }
    await p.setString(_kLogJson, jsonEncode(enc));
  }

  List<ActivityLogItem> _readLog(SharedPreferences p) {
    final raw = p.getString(_kLogJson);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => ActivityLogItem.fromJson(e as Map<dynamic, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }
}

class UsageMetrics {
  const UsageMetrics({
    required this.firstSeenAt,
    required this.lastPhotoAt,
    required this.photosSentCount,
    required this.lastSdDetectedAt,
    required this.shareCount,
    required this.deleteCount,
    required this.recentLog,
  });

  final DateTime? firstSeenAt;
  final DateTime? lastPhotoAt;
  final int photosSentCount;
  final DateTime? lastSdDetectedAt;
  final int shareCount;
  final int deleteCount;
  final List<ActivityLogItem> recentLog;
}

class ActivityLogItem {
  const ActivityLogItem({required this.atMs, required this.kind, this.detail});

  final int atMs;
  final String kind;
  final String? detail;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  Map<String, Object?> toJson() => {
        'at': atMs,
        'k': kind,
        'd': detail,
      };

  factory ActivityLogItem.fromJson(Map<dynamic, dynamic> j) {
    return ActivityLogItem(
      atMs: j['at'] is int ? j['at'] as int : int.parse('${j['at'] ?? 0}'),
      kind: '${j['k'] ?? 'other'}',
      detail: j['d'] as String?,
    );
  }
}
