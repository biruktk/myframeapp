import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE discovery rules for MyFrame / InkJoy / companion hardware.
class BleFrameScanFilter {
  BleFrameScanFilter._();

  static const String _btBaseSuffix = '00001000800000805f9b34fb';

  /// GATT / advertisement service UUIDs used by frame firmware (16-bit or 128-bit).
  static const List<String> knownFrameServiceUuidStrings = [
    '0000ffff-0000-1000-8000-00805f9b34fb',
    '00002760-08c2-11e1-9073-0e8ac72e1001',
    'ffff',
    '2760',
  ];

  static String _normUuidStr(String uuidStr) {
    final u = uuidStr.toLowerCase().replaceAll('-', '');
    if (u.length == 32 && u.endsWith(_btBaseSuffix)) {
      return u.substring(4, 8);
    }
    if (u.length == 4) return u;
    return u;
  }

  static bool _uuidMatchesKnown(String uuidStr) {
    final n = _normUuidStr(uuidStr);
    for (final k in knownFrameServiceUuidStrings) {
      if (n == _normUuidStr(k)) return true;
    }
    return false;
  }

  static bool matchesServiceUuids(Iterable<Guid> uuids) {
    for (final g in uuids) {
      if (_uuidMatchesKnown(g.str)) return true;
    }
    return false;
  }

  /// True if [rawName] matches any allowed frame BLE name pattern.
  static bool matchesAdvertisedName(String rawName) {
    final t = rawName.trim();
    if (t.isEmpty) return false;
    final lower = t.toLowerCase();
    if (lower.startsWith('lj_')) return true;
    if (lower.startsWith('ij_')) return true;
    if (lower.startsWith('my_')) return true;
    if (lower.startsWith('mf_')) return true;
    if (lower.startsWith('inkjoy')) return true;
    if (lower.contains('myframe')) return true;
    if (lower.startsWith('3837')) return true;
    if (lower.contains('ink_joy')) return true;
    if (lower.contains('ink') && lower.contains('joy') && lower.contains('frame')) return true;
    return false;
  }

  /// Combined rule: allowed name, known service UUID (FlutterBluePlus + optional native parser),
  /// or companion-style numeric prefix.
  static bool isDiscoverableEntry({
    required String effectiveName,
    required Iterable<Guid> serviceUuids,
    List<String>? nativeServiceUuidStrings,
  }) {
    final name = effectiveName.trim();
    if (matchesAdvertisedName(name)) return true;
    if (matchesServiceUuids(serviceUuids)) return true;
    if (nativeServiceUuidStrings != null) {
      for (final s in nativeServiceUuidStrings) {
        if (_uuidMatchesKnown(s)) return true;
      }
    }
    // Unnamed (no GAP name): still list when the radio clearly advertises a frame service UUID.
    if (name.isEmpty) {
      return matchesServiceUuids(serviceUuids) ||
          (nativeServiceUuidStrings?.any(_uuidMatchesKnown) ?? false);
    }
    return false;
  }
}
