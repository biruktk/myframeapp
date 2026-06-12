import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-app activity feed (Settings → Notifications). Tracks what the user did in MyFrame.
class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestampMs,
    this.iconName = 'info',
    this.kind,
    this.params = const {},
  });

  final String id;
  final String title;
  final String body;
  final int timestampMs;
  final String iconName;
  /// When set, UI localizes title/body via [AppStrings] (`photo`, `cloud`, …).
  final String? kind;
  final Map<String, String> params;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestampMs': timestampMs,
        'iconName': iconName,
        if (kind != null) 'kind': kind,
        if (params.isNotEmpty) 'params': params,
      };

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    final rawParams = json['params'];
    return InAppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timestampMs: json['timestampMs'] as int? ?? 0,
      iconName: json['iconName'] as String? ?? 'info',
      kind: json['kind'] as String?,
      params: rawParams is Map
          ? rawParams.map((k, v) => MapEntry('$k', '$v'))
          : const {},
    );
  }
}

class InAppNotificationStore extends ChangeNotifier {
  InAppNotificationStore._();

  static final InAppNotificationStore instance = InAppNotificationStore._();

  static const _kKey = 'in_app_notifications_v1';
  static const _maxItems = 100;

  final List<InAppNotification> _items = [];
  var _loaded = false;

  List<InAppNotification> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            _items.add(InAppNotification.fromJson(e));
          }
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await p.setString(_kKey, encoded);
  }

  Future<void> add({
    required String kind,
    required String iconName,
    Map<String, String> params = const {},
  }) async {
    await ensureLoaded();
    final n = InAppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
      title: '',
      body: '',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      iconName: iconName,
      kind: kind,
      params: params,
    );
    _items.insert(0, n);
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> photoSent({String? frameName}) async {
    await add(
      kind: 'photo',
      iconName: 'photo',
      params: {'frameName': frameName?.trim() ?? ''},
    );
  }

  Future<void> birthdayReminder({required String name, required int daysUntil}) async {
    await add(
      kind: 'birthday',
      iconName: 'cake',
      params: {'name': name, 'daysUntil': '$daysUntil'},
    );
  }

  Future<void> familyActivity({required String message}) async {
    await add(
      kind: 'family',
      iconName: 'family',
      params: {'message': message},
    );
  }

  Future<void> frameOffline({String? frameName}) async {
    await add(
      kind: 'offline',
      iconName: 'offline',
      params: {'frameName': frameName?.trim() ?? ''},
    );
  }

  Future<void> cloudUpload({required String provider, required String fileName}) async {
    await add(
      kind: 'cloud',
      iconName: 'cloud',
      params: {'provider': provider, 'fileName': fileName},
    );
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    if (_items.isEmpty) return;
    _items.clear();
    await _persist();
    notifyListeners();
  }
}
