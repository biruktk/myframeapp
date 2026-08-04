/// Legacy name — prefer [ShareReceiverService].
library;

export 'share_receiver_service.dart';

import 'share_receiver_service.dart';

/// Back-compat wrapper used by older call sites.
class ShareIncomingService {
  ShareIncomingService._();
  static ShareReceiverService get instance => ShareReceiverService.instance;
}
