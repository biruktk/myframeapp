import '../models/pairing_nav_result.dart';
import '../widgets/shell_navigation.dart';

/// After first-time Wi‑Fi + profile setup, land on the Registered Frames list
/// (My Frames tab) so the freshly named frame is immediately visible.
abstract final class PairingFlowNav {
  static void onComplete(PairingNavResult? result) {
    if (result?.success != true || result!.openSendGallery != true) return;
    ShellNavigation.completePairingAndShowFrames();
  }
}
