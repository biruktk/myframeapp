import 'package:flutter/material.dart';

import 'services/device_transport.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.transport,
    required super.child,
  });

  final DeviceTransport transport;

  static DeviceTransport transportOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.transport;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.transport != transport;
}
