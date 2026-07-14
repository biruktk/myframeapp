import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'app_diag_log.dart';
import 'permission_gate.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.tempC,
    required this.label,
    required this.icon,
    this.city = '',
  });

  final int tempC;
  final String label;
  final String icon;
  final String city;

  String get line {
    final place = city.trim().isEmpty ? '' : ' · $city';
    return '$icon $tempC°C$place';
  }
}

/// Device location + Open-Meteo current weather (no API key).
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  WeatherSnapshot? _cache;
  DateTime? _cacheAt;

  Future<WeatherSnapshot?> fetchCurrent({bool force = false}) async {
    if (!force &&
        _cache != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < const Duration(minutes: 15)) {
      return _cache;
    }

    final permitted = await ensureLocationPermission();
    if (!permitted) return null;

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      AppDiagLog.log('[Weather] location services disabled');
      return null;
    }

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        AppDiagLog.log('[Weather] position failed: $e');
        return null;
      }
      pos = last;
    }

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${pos.latitude}&longitude=${pos.longitude}'
        '&current=temperature_2m,weather_code'
        '&timezone=auto',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        AppDiagLog.log('[Weather] open-meteo ${res.statusCode}');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return null;
      final temp = (current['temperature_2m'] as num?)?.round() ?? 0;
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final city = await _reverseCity(pos.latitude, pos.longitude);
      final snap = WeatherSnapshot(
        tempC: temp,
        label: _labelForCode(code),
        icon: _iconForCode(code),
        city: city,
      );
      _cache = snap;
      _cacheAt = DateTime.now();
      return snap;
    } catch (e) {
      AppDiagLog.log('[Weather] fetch failed: $e');
      return null;
    }
  }

  /// Returns true when location-when-in-use is granted (requests if needed).
  Future<bool> ensureLocationPermission() async {
    // Keep permission_handler in sync with the rest of the app.
    await PermissionGate.locationWhenInUse();

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<String> _reverseCity(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/reverse'
        '?latitude=$lat&longitude=$lon&language=en&format=json',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return '';
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'];
      if (results is! List || results.isEmpty) return '';
      final first = results.first as Map<String, dynamic>;
      return (first['name'] as String?)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _iconForCode(int code) {
    if (code == 0) return '☀';
    if (code <= 3) return '☁';
    if (code <= 48) return '≋';
    if (code <= 67) return '☔';
    if (code <= 77) return '✻';
    if (code <= 82) return '☔';
    if (code <= 86) return '✻';
    if (code >= 95) return '⚡';
    return '☀';
  }

  static String _labelForCode(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Cloudy';
    if (code <= 48) return 'Fog';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Showers';
    if (code >= 95) return 'Storm';
    return 'Weather';
  }
}
