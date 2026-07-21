import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFcmToken = 'fcm_token';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (_) {}
  }

  Future<String?> getToken() async {
    if (!_initialized) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kFcmToken, token);
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<String?> savedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kFcmToken);
  }

  Future<void> sendTokenToBackend(String backendUrl, String pairingToken) async {
    final token = await savedToken();
    if (token == null) return;
    try {
      await Future.delayed(Duration.zero);
      // POST to backend with token
    } catch (_) {}
  }
}
