import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../settings/app_settings.dart';
import 'app_diag_log.dart';
import 'auth_api_service.dart';

/// Background isolate handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  AppDiagLog.verbose(
    '[fcm] background message id=${message.messageId} title=${message.notification?.title}',
  );
}

/// Firebase Cloud Messaging + local notification display for foreground.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _androidChannel = AndroidNotificationChannel(
    'myframe_uploads',
    'MyFrame uploads',
    description: 'Photo upload and frame activity alerts',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  final _auth = AuthApiService();

  var _initialized = false;
  String? _lastToken;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  /// Bumped when a family-related push arrives (owner should refresh members).
  final ValueNotifier<int> familyPushRevision = ValueNotifier<int>(0);

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Lightweight bootstrap — safe to call after first frame.
  Future<void> init() async {
    if (_initialized) return;
    try {
      // Native AppDelegate already calls FirebaseApp.configure(); Dart options
      // still needed for FlutterFire. Tolerate already-initialized default app.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initLocalNotifications();
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _foregroundSub ??= FirebaseMessaging.onMessage.listen(_showForeground);
      _tokenSub ??= _messaging.onTokenRefresh.listen((token) {
        _lastToken = token;
        unawaited(registerTokenWithBackend(token: token));
      });
      _initialized = true;
      // Permission + token happen after UI (see [syncTokenWithAuth]).
    } catch (e, st) {
      AppDiagLog.verbose('[fcm] init failed: $e\n$st');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_androidChannel);
    }
  }

  Future<NotificationSettings> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null) {
          AppDiagLog.verbose('[fcm] APNs token not ready yet');
          // Do not block startup with a long poll; caller can retry later.
          return _lastToken;
        }
      }
      _lastToken = await _messaging.getToken();
      return _lastToken;
    } catch (e, st) {
      AppDiagLog.verbose('[fcm] getToken failed: $e\n$st');
      return null;
    }
  }

  /// Registers the current device token with `/api/auth/fcm-token` when signed in.
  Future<void> syncTokenWithAuth(AppSettings settings) async {
    try {
      if (!_initialized) await init();
      final authToken = settings.authToken.trim();
      if (!settings.hasAuthenticatedSession || authToken.isEmpty) return;

      await requestPermission();

      // iOS: give APNs a moment after permission grant, then retry a few times.
      String? token;
      for (var i = 0; i < 8; i++) {
        token = await getToken();
        if (token != null && token.isNotEmpty) break;
        if (Platform.isIOS) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        } else {
          break;
        }
      }
      if (token == null || token.isEmpty) {
        AppDiagLog.verbose('[fcm] no token yet — will retry on refresh');
        return;
      }
      await registerTokenWithBackend(token: token, authToken: authToken);
    } catch (e, st) {
      AppDiagLog.verbose('[fcm] syncTokenWithAuth failed: $e\n$st');
    }
  }

  Future<void> registerTokenWithBackend({
    required String token,
    String? authToken,
  }) async {
    final clean = token.trim();
    if (clean.isEmpty) return;
    try {
      final bearer = (authToken ?? '').trim();
      if (bearer.isEmpty) {
        AppDiagLog.verbose('[fcm] skip register — no auth token');
        return;
      }
      final r = await _auth.registerFcmToken(token: clean, authToken: bearer);
      AppDiagLog.verbose('[fcm] register result ok=${r is AuthApiSuccess}');
    } catch (e, st) {
      AppDiagLog.verbose('[fcm] register failed: $e\n$st');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] ?? 'MyFrame';
    final body = n?.body ?? message.data['body'] ?? '';
    final combined = '${title.toString()} ${body.toString()}'.toLowerCase();
    if (combined.contains('family member joined') ||
        message.data['type'] == 'FAMILY_MEMBER_JOINED') {
      familyPushRevision.value++;
    }
    if (body.isEmpty && (n?.title == null)) return;

    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  /// Show a local (system) notification, used when a background dispatch task
  /// completes — e.g. "Image is now displaying on your frame".
  Future<void> showCompletionNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      AppDiagLog.verbose('[fcm] local completion notification failed: $e');
    }
  }

  void dispose() {
    unawaited(_tokenSub?.cancel());
    unawaited(_foregroundSub?.cancel());
  }
}