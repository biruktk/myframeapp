import 'dart:async';

import 'package:fluwx/fluwx.dart';

class WeChatSignInService {
  WeChatSignInService._();

  static final WeChatSignInService instance = WeChatSignInService._();

  static const appId = 'wx452059b9ecaf1fc0';
  static const universalLink = 'https://myframe.ink/';

  final Fluwx _fluwx = Fluwx();
  var _registered = false;

  Future<void> _ensureRegistered() async {
    if (_registered) return;
    final ok = await _fluwx.registerApi(
      appId: appId,
      universalLink: universalLink,
    );
    if (!ok) {
      throw StateError('wechat_register_failed');
    }
    _registered = true;
  }

  Future<String> requestAuthCode() async {
    await _ensureRegistered();
    final installed = await _fluwx.isWeChatInstalled;
    if (!installed) {
      throw StateError('wechat_not_installed');
    }

    final completer = Completer<String>();
    late final FluwxCancelable sub;
    sub = _fluwx.addSubscriber((response) {
      if (response is! WeChatAuthResponse || completer.isCompleted) return;
      if (response.isSuccessful && response.code?.isNotEmpty == true) {
        completer.complete(response.code!);
      } else {
        completer.completeError(
          StateError(response.errStr?.isNotEmpty == true
              ? response.errStr!
              : 'wechat_auth_cancelled'),
        );
      }
    });

    try {
      final launched = await _fluwx.authBy(
        which: NormalAuth(
          scope: 'snsapi_userinfo',
          state: 'myframe_wechat_login',
        ),
      );
      if (!launched) {
        throw StateError('wechat_launch_failed');
      }
      return await completer.future.timeout(const Duration(seconds: 90));
    } finally {
      sub.cancel();
    }
  }
}
