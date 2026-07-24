import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../l10n/app_strings.dart';
import '../services/auth_api_service.dart';
import '../utils/validators.dart';
import '../services/google_sign_in_factory.dart';
import '../services/google_sign_in_errors.dart';
import '../services/google_sign_in_bridge.dart';
import '../services/mobile_auth_deep_link.dart';
import '../services/wechat_sign_in_service.dart';
import '../settings/app_settings.dart';
import '../services/user_gallery_cloud_service.dart';
import '../services/fcm_service.dart';
import '../widgets/animated_splash_screen.dart';
import '../widgets/main_shell.dart';
import '../widgets/myframe_branding_lockup.dart';
import 'forgot_password_screen.dart';
import 'reset_password_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> with WidgetsBindingObserver {
  var _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForResetPasswordDeepLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _listenForResetPasswordDeepLink();
    }
  }

  void _listenForResetPasswordDeepLink() {
    unawaited(_checkResetPasswordDeepLink());
    unawaited(_checkVerifyEmailDeepLink());
  }

  Future<void> _checkResetPasswordDeepLink() async {
    try {
      final result = await MobileAuthDeepLink.waitForResetPassword(timeout: const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(token: result.token),
        ),
      );
    } on TimeoutException {
      // no pending reset-password deep link
    } catch (_) {
      // cancelled or error
    }
  }

  Future<void> _checkVerifyEmailDeepLink() async {
    try {
      final result = await MobileAuthDeepLink.waitForVerifyEmail(timeout: const Duration(seconds: 1));
      if (!mounted) return;
      final s = AppStrings.of(context);
      final auth = AuthApiService();
      setState(() {});
      final r = await auth.verifyEmail(token: result.token);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(r is AuthApiSuccess ? s.verifyEmailSuccess : s.verifyEmailFailed),
          content: Text(r is AuthApiSuccess ? s.verifyEmailSuccessBody : s.verifyEmailFailedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.coachGotIt),
            ),
          ],
        ),
      );
    } on TimeoutException {
      // no pending verify-email deep link
    } catch (_) {
      // cancelled or error
    }
  }

  void _onSplashComplete() {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppSettingsScope.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (_showSplash) {
          return AnimatedSplashScreen(onComplete: _onSplashComplete);
        }
        if (!app.onboardingDone) {
          return Localizations.override(
            context: context,
            locale: const Locale('en'),
            child: _OnboardingScreen(
              onDone: () async {
                await app.setOnboardingDone(true);
                await app.setSignedIn(value: false);
              },
            ),
          );
        }
        if (!app.hasAuthenticatedSession) {
          return _AuthScreen(onAuthenticated: () {});
        }
        return const MainShell();
      },
    );
  }
}

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({required this.onDone});

  final Future<void> Function() onDone;

  @override
  State<_OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<_OnboardingScreen> {
  Future<void> _finish() async {
    await widget.onDone();
    if (!mounted) return;
    setState(() {});
  }

  static const _cardRadius = 24.0;

  /// Light pink icon wells (matches product welcome mockup).
  static const _wellPink = Color(0xFFFFE4E8);

  Widget _heroIllustration(ColorScheme cs, {required double scale}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 14 * scale),
      decoration: BoxDecoration(
        color: _wellPink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline_rounded, size: 28 * scale, color: cs.primary),
          SizedBox(width: 8 * scale),
          Icon(Icons.wifi_rounded, size: 24 * scale, color: cs.primary),
          SizedBox(width: 6 * scale),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18 * scale,
            color: cs.primary.withValues(alpha: 0.65),
          ),
          SizedBox(width: 6 * scale),
          Icon(
            Icons.photo_size_select_actual_rounded,
            size: 26 * scale,
            color: cs.primary,
          ),
        ],
      ),
    );
  }

  Widget _shadowCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _stepRow(
    BuildContext context, {
    required int n,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showDivider,
    required double scale,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14 * scale, 10 * scale, 14 * scale, 10 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36 * scale,
                height: 36 * scale,
                decoration: BoxDecoration(
                  color: _wellPink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 18 * scale),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14 * scale,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: cs.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24 * scale,
                height: 24 * scale,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _wellPink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11 * scale,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxHeight / 740).clamp(0.82, 1.0);
            final hPad = 20.0 * scale;
            final btnH = 48.0 * scale;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: PopupMenuButton<String?>(
                      tooltip: s.onboardingLanguageHint,
                      icon: Icon(
                        Icons.language_rounded,
                        color: cs.onSurfaceVariant,
                        size: 22 * scale,
                      ),
                      onSelected: (code) async {
                        await app.setLanguageCode(code);
                        if (!context.mounted) return;
                        setState(() {});
                      },
                      itemBuilder: (c) => [
                        PopupMenuItem(value: null, child: Text(s.languageSystem)),
                        PopupMenuItem(value: 'en', child: Text(s.languageEnglish)),
                        PopupMenuItem(value: 'zh', child: Text(s.languageChinese)),
                        PopupMenuItem(value: 'ja', child: Text(s.languageJapanese)),
                        PopupMenuItem(value: 'es', child: Text(s.languageSpanish)),
                        PopupMenuItem(value: 'fr', child: Text(s.languageFrench)),
                        PopupMenuItem(value: 'de', child: Text(s.languageGerman)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(child: MyFrameBrandingLockup(width: 200 * scale)),
                        SizedBox(height: 12 * scale),
                        _shadowCard(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              16 * scale,
                              14 * scale,
                              16 * scale,
                              14 * scale,
                            ),
                            child: Column(
                              children: [
                                _heroIllustration(cs, scale: scale),
                                SizedBox(height: 12 * scale),
                                Text(
                                  s.welcomeInkTitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18 * scale,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 6 * scale),
                                Text(
                                  s.welcomeInkSubtitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13 * scale,
                                    color: cs.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 10 * scale),
                        _shadowCard(
                          child: Column(
                            children: [
                              _stepRow(
                                context,
                                n: 1,
                                icon: Icons.power_settings_new_rounded,
                                title: s.onboardStepPowerTitle,
                                subtitle: s.onboardStepPowerBody,
                                showDivider: true,
                                scale: scale,
                              ),
                              _stepRow(
                                context,
                                n: 2,
                                icon: Icons.add_rounded,
                                title: s.onboardStepPairTitle,
                                subtitle: s.onboardStepPairBody,
                                showDivider: true,
                                scale: scale,
                              ),
                              _stepRow(
                                context,
                                n: 3,
                                icon: Icons.send_rounded,
                                title: s.onboardStepSendTitle,
                                subtitle: s.onboardStepSendBody,
                                showDivider: false,
                                scale: scale,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(btnH),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      s.onboardingConnectNow,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15 * scale,
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  OutlinedButton(
                    onPressed: _finish,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(btnH),
                      backgroundColor: Colors.white,
                      foregroundColor: cs.onSurfaceVariant,
                      side: BorderSide(
                        color: cs.outline.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      s.onboardingLater,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15 * scale,
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen({required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> with WidgetsBindingObserver {
  var _authTab = 0;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  final _regName = TextEditingController();
  final _auth = AuthApiService();
  late final GoogleSignIn _googleSignIn = createGoogleSignIn();
  var _busy = false;
  var _waitingForGoogleBrowser = false;

  /// WeChat brand green for the social sign-in button.
  static const _weChatGreen = Color(0xFF07C160);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForGoogleBrowser) {
      unawaited(() async {
        await MobileAuthDeepLink.pumpLatestLink();
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted && _waitingForGoogleBrowser) {
          MobileAuthDeepLink.cancelPendingGoogle();
        }
      }());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    _password.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regName.dispose();
    super.dispose();
  }

  Future<void> _finishAuthSession(
    AuthApiSuccess data, {
    String provider = 'email',
  }) async {
    final app = AppSettingsScope.of(context);
    await app.setAccountProfile(name: data.user.name, email: data.user.email);
    await app.completeAuthenticatedSession(
      token: data.token,
      userId: data.user.id,
      provider: provider,
    );
    unawaited(UserGalleryCloudService.instance.syncFromServer(data.token));
    unawaited(_saveFcmTokenAfterLogin());
    if (!mounted) return;
    widget.onAuthenticated();
  }

  Future<void> _saveFcmTokenAfterLogin() async {
    try {
      final app = AppSettingsScope.of(context);
      final authToken = app.authToken;
      if (authToken == null || authToken.isEmpty) return;
      final fcmToken = await FcmService.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      unawaited(_auth.registerFcmToken(token: fcmToken, authToken: authToken));
    } catch (_) {}
  }

  void _showAuthMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _failureMessage(
    AuthApiFailure f,
    AppStrings s, {
    String? socialProvider,
  }) {
    if (f.errorKey == 'network_error') {
      return s.authErrorNetwork;
    }
    if (f.fieldErrors.isNotEmpty) {
      return f.fieldErrors.join('\n');
    }
    if (socialProvider != null) {
      return _socialFailureMessage(f, s, socialProvider);
    }
    final sc = f.statusCode;
    if (f.errorKey == 'email_not_verified') {
      return s.authErrorEmailNotVerified;
    }
    if (sc == 401 && f.errorKey == 'invalid_credentials') {
      return s.authErrorInvalidCredentials;
    }
    if (sc == 409 || f.errorKey == 'email_taken') {
      return s.authErrorEmailTaken;
    }
    if (sc >= 500 || f.errorKey == 'server_error') {
      return s.authErrorServer;
    }
    if (f.errorKey == 'google_auth_not_configured') {
      return s.authGoogleNotConfigured;
    }
    if (f.errorKey == 'unauthorized_admin_token') {
      return s.authErrorMobileAdminToken;
    }
    if (sc == 422 || f.errorKey == 'validation_error') {
      final m = f.message;
      if (m != null && m.trim().isNotEmpty) return m.trim();
      return s.authErrorInvalidFields;
    }
    if (sc == 400) {
      switch (f.errorKey) {
        case 'password_length':
          return s.authErrorPasswordLength;
        case 'invalid_email':
          return (f.message != null && f.message!.trim().isNotEmpty)
              ? f.message!.trim()
              : s.authErrorInvalidCredentials;
        case 'invalid_name':
          return (f.message != null && f.message!.trim().isNotEmpty)
              ? f.message!.trim()
              : s.authErrorInvalidFields;
        case 'invalid_credentials':
          return (f.message != null && f.message!.trim().isNotEmpty)
              ? f.message!.trim()
              : s.authErrorInvalidFields;
        default:
          final m400 = f.message;
          return (m400 != null && m400.trim().isNotEmpty)
              ? m400.trim()
              : s.authErrorInvalidFields;
      }
    }
    switch (f.errorKey) {
      case 'email_taken':
        return s.authErrorEmailTaken;
      case 'password_length':
        return s.authErrorPasswordLength;
      case 'invalid_email':
        return s.authErrorInvalidCredentials;
      case 'invalid_name':
      case 'account_suspended':
        return f.message ?? s.authErrorInvalidFields;
      default:
        break;
    }
    if (f.message != null && f.message!.trim().isNotEmpty) {
      return f.message!.trim();
    }
    return '${s.authErrorBadResponse} (${f.statusCode})';
  }

  String _socialFailureMessage(AuthApiFailure f, AppStrings s, String provider) {
    switch (f.errorKey) {
      case 'unauthorized_admin_token':
        return s.authErrorMobileAdminToken;
      case 'route_not_found':
        return provider == 'wechat'
            ? s.authErrorWeChatServerRoute
            : s.authErrorAppleServerRoute;
      case 'invalid_token':
        return provider == 'apple'
            ? s.authErrorAppleTokenRejected
            : s.authErrorWeChatFailed;
      case 'invalid_credentials':
        return provider == 'apple'
            ? s.authErrorAppleTokenRejected
            : s.authErrorWeChatFailed;
      default:
        break;
    }
    if (f.statusCode >= 500 || f.errorKey == 'server_error') {
      return s.authErrorServer;
    }
    if (f.message != null && f.message!.trim().isNotEmpty) {
      return f.message!.trim();
    }
    return provider == 'apple' ? s.authErrorAppleFailed : s.authErrorWeChatFailed;
  }

  Future<void> _submitLogin() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    if (Validators.emailError(_email.text) != null ||
        Validators.passwordError(_password.text) != null) {
      _showAuthMessage(s.authErrorInvalidFields);
      return;
    }
    setState(() => _busy = true);
    final r = await _auth.login(email: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r is AuthApiSuccess) {
      await _finishAuthSession(r);
      return;
    }
    if (r is AuthApiFailure) _showAuthMessage(_failureMessage(r, s));
  }

  Future<void> _submitRegister() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    if (Validators.emailError(_regEmail.text) != null ||
        Validators.passwordError(_regPassword.text) != null ||
        Validators.nameError(_regName.text) != null) {
      _showAuthMessage(s.authErrorRegisterFields);
      return;
    }
    setState(() => _busy = true);
    final r = await _auth.register(
      email: _regEmail.text,
      password: _regPassword.text,
      name: _regName.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r is AuthApiSuccess) {
      if (r.token.isNotEmpty) {
        await _finishAuthSession(r);
      } else {
        _showVerificationSent();
      }
      return;
    }
    if (r is AuthApiFailure) _showAuthMessage(_failureMessage(r, s));
  }

  void _showVerificationSent() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).verifyEmailTitle),
        content: Text(AppStrings.of(context).verifyEmailSent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(AppStrings.of(context).coachGotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _onAppleTap() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    if (!Platform.isIOS) {
      _showAuthMessage(s.authAppleOnlyOnIos);
      return;
    }
    await _appleSignIn();
  }

  Future<void> _appleSignIn() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    setState(() => _busy = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        _showAuthMessage(s.authErrorInvalidFields);
        return;
      }
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
      final r = await _auth.loginWithApple(
        identityToken: token,
        authorizationCode: credential.authorizationCode,
        userIdentifier: credential.userIdentifier,
        email: credential.email,
        name: fullName.isEmpty ? null : fullName,
      );
      if (!mounted) return;
      if (r is AuthApiSuccess) {
        await _finishAuthSession(r, provider: 'apple');
        return;
      }
      if (r is AuthApiFailure) {
        _showAuthMessage(_failureMessage(r, s, socialProvider: 'apple'));
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      final m = e.message;
      if (m.isNotEmpty) _showAuthMessage(m);
    } catch (e) {
      _showAuthMessage('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignInFlow() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    setState(() => _busy = true);
    try {
      // Android: native account picker only (no second browser step).
      if (Platform.isAndroid) {
        await _googleSignInNativeOnly(s);
        return;
      }

      // iOS: native in-app picker (same as Android).
      if (Platform.isIOS) {
        await _googleSignInNativeOnly(s);
        return;
      }
      await _googleSignInHosted(s);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// In-app Google account picker → API. Returns true when session finished.
  Future<bool> _googleSignInNativeOnly(AppStrings s) async {
    try {
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn
            .signInSilently(suppressErrors: true)
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        account = null;
      }
      account ??= await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
      );
      if (account == null) {
        _showAuthMessage(s.authGoogleCanceled);
        return false;
      }
      final idToken = (await account.authentication).idToken;
      if (idToken == null || idToken.isEmpty) {
        _showAuthMessage(s.authGoogleNoIdToken);
        return false;
      }
      final r = await _auth.loginWithGoogle(idToken: idToken);
      if (!mounted) return false;
      if (r is AuthApiSuccess) {
        await _finishAuthSession(r, provider: 'google');
        return true;
      }
      if (r is AuthApiFailure) {
        _showAuthMessage(_failureMessage(r, s));
      }
      return false;
    } on TimeoutException {
      _showAuthMessage(s.authGoogleCanceled);
      return false;
    } catch (e) {
      _showAuthMessage(googleSignInErrorMessage(e, s));
      return false;
    }
  }

  Future<void> _googleSignInHosted(AppStrings s) async {
    _waitingForGoogleBrowser = true;
    try {
      final result = await GoogleSignInBridge.signIn(useCustomTab: true);
      if (!mounted) return;
      await _finishAuthSession(
        AuthApiSuccess(
          token: result.token,
          user: AuthUserPayload(
            id: result.userId,
            email: result.email,
            name: result.name,
          ),
        ),
        provider: 'google',
      );
    } on TimeoutException {
      if (!mounted) return;
      MobileAuthDeepLink.cancelPendingGoogle();
      _showAuthMessage(s.authGoogleBrowserHint);
    } catch (e) {
      if (!mounted) return;
      MobileAuthDeepLink.cancelPendingGoogle();
      final msg = e.toString();
      if (msg.contains('google_server_secret_missing')) {
        _showAuthMessage(
          'Google sign-in cannot finish yet: the API is missing GOOGLE_OAUTH_CLIENT_SECRET. Set it on the VPS backend, then restart the API.',
        );
      } else if (msg.contains('google_hosted_route_missing')) {
        _showAuthMessage(
          'Google sign-in route is missing on myframe.ink. The app now uses the API host, but the public website still needs the mobile Google route or proxy.',
        );
      } else {
        _showAuthMessage(s.authGoogleCanceled);
      }
    } finally {
      _waitingForGoogleBrowser = false;
    }
  }

  Future<void> _weChatTap() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    setState(() => _busy = true);
    try {
      final code = await WeChatSignInService.instance.requestAuthCode();
      final r = await _auth.loginWithWeChat(code: code);
      if (!mounted) return;
      if (r is AuthApiSuccess) {
        await _finishAuthSession(r, provider: 'wechat');
        return;
      }
      if (r is AuthApiFailure) {
        _showAuthMessage(_failureMessage(r, s, socialProvider: 'wechat'));
      }
    } on TimeoutException {
      if (!mounted) return;
      _showAuthMessage(s.authErrorWeChatTimeout);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('wechat_not_installed')) {
        _showAuthMessage(
          Platform.isIOS
              ? 'WeChat is not installed on this iPhone.'
              : 'WeChat is not installed on this device.',
        );
      } else if (msg.contains('wechat_register_failed')) {
        _showAuthMessage('WeChat could not be registered for this app.');
      } else if (msg.contains('wechat_launch_failed')) {
        _showAuthMessage('Could not open WeChat.');
      } else {
        _showAuthMessage('WeChat sign-in failed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _underlineField(
    ColorScheme cs,
    String label, {
    String? hint,
  }) {
    final subtle = cs.onSurface.withValues(alpha: 0.28);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.75)),
      floatingLabelStyle: TextStyle(color: cs.primary),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 12, bottom: 14),
      border: UnderlineInputBorder(borderSide: BorderSide(color: subtle)),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: subtle),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: subtle.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _languageSwitcher(AppStrings s, ColorScheme cs) {
    final app = AppSettingsScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          s.language,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          height: 32,
          child: PopupMenuButton<String?>(
            tooltip: s.onboardingLanguageHint,
            onSelected: (code) async {
              await app.setLanguageCode(code);
              if (!context.mounted) return;
              setState(() {});
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    const Text('🌐', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(s.languageSystem),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    const Text('🇬🇧', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(s.languageEnglish),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'zh',
                child: Row(
                  children: [
                    const Text('🇨🇳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(s.languageChinese),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ja',
                child: Row(
                  children: [
                    const Text('🇯🇵', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(s.languageJapanese),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'es',
                child: Row(
                  children: [
                    const Text('🇪🇸', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(s.languageSpanish),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'fr',
                child: Row(
                  children: [
                    const Text('🇫🇷', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(s.languageFrench),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'de',
                child: Row(
                  children: [
                    const Text('🇩🇪', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(s.languageGerman),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.translate_rounded, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _segmentedTabs(AppStrings s, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segmentChip(
              label: s.loginLabel,
              selected: _authTab == 0,
              onTap: () {
                if (_busy) return;
                setState(() => _authTab = 0);
              },
              cs: cs,
            ),
          ),
          Expanded(
            child: _segmentChip(
              label: s.registerLabel,
              selected: _authTab == 1,
              onTap: () {
                if (_busy) return;
                setState(() => _authTab = 1);
              },
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: cs.outlineVariant.withValues(alpha: 0.65))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialRow(AppStrings s, ColorScheme cs) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.25))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                s.authSocialDividerLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.25))),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (Platform.isIOS)
              _socialCircle(
                tooltip: s.continueApple,
                onTap: _busy ? null : _onAppleTap,
                color: Colors.black,
                child: const Icon(Icons.apple, color: Colors.white, size: 26),
              ),
            _socialCircle(
              tooltip: s.continueGoogle,
              onTap: _busy ? null : _googleSignInFlow,
              color: Colors.white,
              borderColor: cs.outline.withValues(alpha: 0.35),
              child: const _GoogleLogoMark(size: 26),
            ),
            _socialCircle(
              tooltip: s.continueWeChat,
              onTap: _busy ? null : () => unawaited(_weChatTap()),
              color: _weChatGreen,
              child: const _WeChatLogoMark(size: 26),
            ),
          ],
        ),
      ],
    );
  }

  Widget _socialCircle({
    required String tooltip,
    required VoidCallback? onTap,
    required Color color,
    Color? borderColor,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: onTap == null ? 0 : 1,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: borderColor != null
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  )
                : null,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                children: [
                  const Center(child: MyFrameBrandingLockup(width: 260)),
                  const SizedBox(height: 12),
                  Text(
                    s.authScreenTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                            child: _languageSwitcher(s, cs),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                            child: _segmentedTabs(s, cs),
                          ),
                      Expanded(
                        child: Stack(
                          children: [
                            IndexedStack(
                              index: _authTab,
                              children: [
                                _authScroll(
                                  s,
                                  cs,
                                  children: [
                                    TextField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      style: TextStyle(color: cs.onSurface),
                                      decoration: _underlineField(cs, s.emailLabel),
                                      enabled: !_busy,
                                    ),
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _password,
                                      obscureText: true,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _submitLogin(),
                                      style: TextStyle(color: cs.onSurface),
                                      decoration: _underlineField(
                                        cs,
                                        s.passwordLabel,
                                      ),
                                      enabled: !_busy,
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const ForgotPasswordScreen(),
                                                  ),
                                                ),
                                        child: Text(
                                          s.forgotPasswordLink,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 52,
                                      child: FilledButton(
                                        onPressed: _busy ? null : _submitLogin,
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          s.loginLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    _socialRow(s, cs),
                                  ],
                                ),
                                _authScroll(
                                  s,
                                  cs,
                                  children: [
                                    TextField(
                                      controller: _regName,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization: TextCapitalization.words,
                                      style: TextStyle(color: cs.onSurface),
                                      decoration: _underlineField(
                                        cs,
                                        s.authUsernameLabel,
                                      ),
                                      enabled: !_busy,
                                    ),
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _regEmail,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      style: TextStyle(color: cs.onSurface),
                                      decoration: _underlineField(cs, s.emailLabel),
                                      enabled: !_busy,
                                    ),
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _regPassword,
                                      obscureText: true,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _submitRegister(),
                                      style: TextStyle(color: cs.onSurface),
                                      decoration: _underlineField(
                                        cs,
                                        s.passwordLabel,
                                      ),
                                      enabled: !_busy,
                                    ),
                                    const SizedBox(height: 28),
                                    SizedBox(
                                      height: 52,
                                      child: FilledButton(
                                        onPressed: _busy ? null : _submitRegister,
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          s.registerLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    _socialRow(s, cs),
                                  ],
                                ),
                              ],
                            ),
                            if (_busy)
                              Positioned.fill(
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authScroll(
    AppStrings s,
    ColorScheme cs, {
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
  }
}

class _GoogleLogoMark extends StatelessWidget {
  const _GoogleLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/branding/google_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _WeChatLogoMark extends StatelessWidget {
  const _WeChatLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WeChatLogoPainter()),
    );
  }
}

class _WeChatLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    final bubble1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.12,
        size.width * 0.52,
        size.height * 0.42,
      ),
      Radius.circular(size.width * 0.18),
    );
    final bubble2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.36,
        size.height * 0.34,
        size.width * 0.46,
        size.height * 0.36,
      ),
      Radius.circular(size.width * 0.16),
    );
    canvas.drawRRect(bubble1, white);
    canvas.drawRRect(bubble2, white);

    final tail1 = Path()
      ..moveTo(size.width * 0.24, size.height * 0.54)
      ..lineTo(size.width * 0.18, size.height * 0.73)
      ..lineTo(size.width * 0.34, size.height * 0.58)
      ..close();
    final tail2 = Path()
      ..moveTo(size.width * 0.56, size.height * 0.69)
      ..lineTo(size.width * 0.64, size.height * 0.86)
      ..lineTo(size.width * 0.70, size.height * 0.66)
      ..close();
    canvas.drawPath(tail1, white);
    canvas.drawPath(tail2, white);

    final eye = Paint()..color = const Color(0xFF07C160);
    void dot(double x, double y) =>
        canvas.drawCircle(Offset(x, y), size.width * 0.04, eye);
    dot(size.width * 0.26, size.height * 0.30);
    dot(size.width * 0.42, size.height * 0.30);
    dot(size.width * 0.50, size.height * 0.48);
    dot(size.width * 0.64, size.height * 0.48);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
