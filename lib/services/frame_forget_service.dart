import 'ble_frame_device_transport.dart';
import 'device_store.dart';

/// Removes a paired frame from storage and drops any live BLE session.
class FrameForgetService {
  FrameForgetService._();

  static final FrameForgetService instance = FrameForgetService._();

  Future<void> forgetFrame(String deviceId) async {
    await DeviceStore.instance.forgetPairedFrame(deviceId);
    await BleFrameDeviceTransport.instance.releaseSession();
  }

  Future<void> forgetAllFrames() async {
    await DeviceStore.instance.clear();
    await BleFrameDeviceTransport.instance.releaseSession();
  }
}
