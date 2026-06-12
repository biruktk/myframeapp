import '../models/pairing_nav_result.dart';
import '../widgets/shell_navigation.dart';

/// After first-time Wi‑Fi + profile setup, open the Send photo page (iOS + Android).
abstract final class PairingFlowNav {
  static void onComplete(PairingNavResult? result, {bool openGalleryPicker = true}) {
    if (result?.success != true || result!.openSendGallery != true) return;
    ShellNavigation.completePairingAndOpenSend(openGalleryPicker: openGalleryPicker);
  }
}
