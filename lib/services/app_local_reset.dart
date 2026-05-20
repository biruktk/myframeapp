import 'package:shared_preferences/shared_preferences.dart';

import 'device_store.dart';
import 'usage_metrics_store.dart';

/// Wipes all local [SharedPreferences] and re-seeds first-run usage metrics.
class AppLocalReset {
  AppLocalReset._();

  static Future<void> wipeAllLocalData() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    await DeviceStore.instance.clear();
    await UsageMetricsStore.instance.ensureInitialized();
  }
}
