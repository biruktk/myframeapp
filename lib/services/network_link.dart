import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a network interface that could reach a host (Wi‑Fi, mobile data, etc.).
/// Does **not** prove access to the public internet; only [ConnectivityResult.none] / empty means "no path at all."
Future<bool> hasNetworkInterface() async {
  final list = await Connectivity().checkConnectivity();
  if (list.isEmpty) return false;
  return list.any((e) => e != ConnectivityResult.none);
}
