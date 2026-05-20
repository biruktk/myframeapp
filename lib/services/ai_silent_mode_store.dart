import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SilentPersonEntry {
  SilentPersonEntry({
    required this.id,
    required this.nickname,
    required this.birthdayIso,
    this.photoPath,
  });

  final String id;
  final String nickname;
  final String birthdayIso;
  final String? photoPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'birthdayIso': birthdayIso,
        'photoPath': photoPath,
      };

  static SilentPersonEntry fromJson(Map<String, dynamic> j) => SilentPersonEntry(
        id: '${j['id']}',
        nickname: '${j['nickname']}',
        birthdayIso: '${j['birthdayIso']}',
        photoPath: j['photoPath'] as String?,
      );
}

/// Persists AI Silent Mode UI state (background logic hooks to server later).
class AiSilentModeStore {
  AiSilentModeStore._();
  static final AiSilentModeStore instance = AiSilentModeStore._();

  static const _k = 'ai_silent_mode_bundle_v1';

  bool silentModeEnabled = false;
  bool backgroundScreening = false;
  bool emotionFiltering = false;
  bool qualityCheck = false;
  bool eventBasedPushing = false;
  bool quietHoursInSilent = false;
  String silentApiKeys = '';
  List<SilentPersonEntry> people = [];
  int statsProcessed = 1248;
  int statsPushed = 632;
  double statsPositivePct = 50.8;
  double statsQualityPct = 92.3;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      silentModeEnabled = m['silent'] == true;
      backgroundScreening = m['bg'] == true;
      emotionFiltering = m['emo'] == true;
      qualityCheck = m['qual'] == true;
      eventBasedPushing = m['evt'] == true;
      quietHoursInSilent = m['quiet'] == true;
      silentApiKeys = '${m['keys'] ?? ''}';
      statsProcessed = (m['sp'] as num?)?.toInt() ?? statsProcessed;
      statsPushed = (m['su'] as num?)?.toInt() ?? statsPushed;
      statsPositivePct = (m['pp'] as num?)?.toDouble() ?? statsPositivePct;
      statsQualityPct = (m['qp'] as num?)?.toDouble() ?? statsQualityPct;
      final pl = m['people'] as List?;
      if (pl != null) {
        people = pl.map((e) => SilentPersonEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode({
        'silent': silentModeEnabled,
        'bg': backgroundScreening,
        'emo': emotionFiltering,
        'qual': qualityCheck,
        'evt': eventBasedPushing,
        'quiet': quietHoursInSilent,
        'keys': silentApiKeys,
        'sp': statsProcessed,
        'su': statsPushed,
        'pp': statsPositivePct,
        'qp': statsQualityPct,
        'people': people.map((e) => e.toJson()).toList(),
      }),
    );
  }
}
