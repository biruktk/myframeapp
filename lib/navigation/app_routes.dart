import 'package:flutter/material.dart';

import '../screens/frame_config_screen.dart';

/// Named routes for deep links and cross-screen navigation.
class AppRoutes {
  AppRoutes._();

  static const frameConfig = '/frame-config';

  static Map<String, WidgetBuilder> get routes => const {};

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == frameConfig) {
      final args = settings.arguments;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => FrameConfigScreen(
          initialDeviceName: args is FrameConfigArgs ? args.deviceName : null,
          initialMac: args is FrameConfigArgs ? args.mac : null,
          preconnectedRemoteId:
              args is FrameConfigArgs ? args.bleRemoteId : null,
        ),
      );
    }
    return null;
  }

  static Future<void> openFrameConfig(
    BuildContext context, {
    String? deviceName,
    String? mac,
    String? bleRemoteId,
  }) {
    return Navigator.of(context).pushNamed(
      frameConfig,
      arguments: FrameConfigArgs(
        deviceName: deviceName,
        mac: mac,
        bleRemoteId: bleRemoteId,
      ),
    );
  }
}

class FrameConfigArgs {
  const FrameConfigArgs({this.deviceName, this.mac, this.bleRemoteId});
  final String? deviceName;
  final String? mac;
  final String? bleRemoteId;
}
