import 'dart:async';

import 'package:flutter/material.dart';
import '../services/google_sign_in_bridge.dart';
import '../services/mobile_auth_deep_link.dart';

/// Opens Google sign-in in a Custom Tab / SFSafariView (not embedded WebView).
/// GIS does not work inside WebView; Custom Tab is required for the web fallback.
class GoogleSignInHostedScreen extends StatefulWidget {
  const GoogleSignInHostedScreen({super.key});

  static Future<MobileGoogleAuthResult?> open(BuildContext context) {
    return Navigator.of(context).push<MobileGoogleAuthResult>(
      MaterialPageRoute(builder: (_) => const GoogleSignInHostedScreen()),
    );
  }

  @override
  State<GoogleSignInHostedScreen> createState() =>
      _GoogleSignInHostedScreenState();
}

class _GoogleSignInHostedScreenState extends State<GoogleSignInHostedScreen>
    with WidgetsBindingObserver {
  var _opened = false;
  var _waiting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSignIn());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_waiting) MobileAuthDeepLink.cancelPendingGoogle();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(MobileAuthDeepLink.pumpLatestLink());
    }
  }

  Future<void> _openSignIn() async {
    if (_opened || !mounted) return;
    _opened = true;
    try {
      final result = await GoogleSignInBridge.signIn(useCustomTab: true);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Sign-in timed out. Close the browser tab and try again.';
        _waiting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open Google sign-in.';
        _waiting = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _waiting = true;
      _opened = false;
    });
    await _openSignIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sign-In'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_waiting) ...[
              const SizedBox(height: 48),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
              Text(
                'Opening Google sign-in…\n\nChoose your Gmail account on the Google screen, then you will return to MyFrame automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 24),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _retry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
