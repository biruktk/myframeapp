import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_diag_log.dart';

/// Purpose-built local notification service for frame-activity events.
///
/// Owns the high-priority Android channel (heads-up on all OEM skins), the
/// iOS foreground presentation options (banner/badge/sound while the app is
/// open), and the Android 13+ runtime permission request. Used to surface the
/// "Frame updated" heads-up exactly when the upload queue reaches `completed`
/// (hardware `play_ack`), never before.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'myframe_push_channel';
  static const String channelName = 'Frame Updates';
  static const String channelDescription =
      'Notifications for photo delivery and display completion';

  /// High importance (max) so OEM skins (Xiaomi / Samsung / Oppo / Pixel)
  /// surface a heads-up banner instead of burying it in the shade.
  static const AndroidNotificationChannel highPriorityChannel =
      AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  var _initialized = false;

  /// Ensure channels + iOS presentation options are configured.
  Future<void> init() async {
    if (_initialized) return;
    try {
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
        await android?.createNotificationChannel(highPriorityChannel);
      }
      _initialized = true;
    } catch (e, st) {
      AppDiagLog.verbose('[NotificationService] init failed: $e\n$st');
    }
  }

  /// Request the Android 13+ (API 33) POST_NOTIFICATIONS runtime permission.
  /// No-op on iOS (APNs permission is requested separately / by [FcmService]).
  Future<bool> requestPermission() async {
    try {
      await init();
      if (Platform.isAndroid) {
        final android = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      AppDiagLog.verbose('[NotificationService] requestPermission failed: $e');
      return false;
    }
  }

  /// Show the "Frame updated" heads-up after the hardware confirms the image
  /// is displayed (`play_ack`). High-priority Android + foreground iOS banner.
  Future<void> showFrameUpdatedNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await init();
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
        payload: payload,
      );
    } catch (e, st) {
      AppDiagLog.verbose('[NotificationService] show failed: $e\n$st');
    }
  }
}
