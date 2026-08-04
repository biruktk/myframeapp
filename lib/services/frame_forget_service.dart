import 'account_sync_service.dart';
import 'ble_frame_device_transport.dart';
import 'device_store.dart';

/// Removes a paired frame from storage and drops any live BLE session.
class FrameForgetService {
  FrameForgetService._();

  static final FrameForgetService instance = FrameForgetService._();

  /// Removes the frame locally and unbinds it from the signed-in account so
  /// other devices / family members drop it on the next pull.
  Future<void> forgetFrame(String deviceId) async {
    final id = deviceId.trim();
    if (id.isEmpty) return;

    // Account unbind (owner / family-owner) + local wipe. Always ends with
    // local removal so Home does not keep a zombie row.
    await AccountSyncService.instance.deleteFrame(id);
    try {
      await DeviceStore.instance.forgetPairedFrame(id);
    } catch (_) {}
    await BleFrameDeviceTransport.instance.releaseSession();
  }

  Future<void> forgetAllFrames() async {
    await DeviceStore.instance.load();
    final ids = DeviceStore.instance.pairedFrames
        .map((e) => e.deviceId.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final id in ids) {
      await AccountSyncService.instance.deleteFrame(id);
    }
    await DeviceStore.instance.clear();
    await BleFrameDeviceTransport.instance.releaseSession();
  }
}
