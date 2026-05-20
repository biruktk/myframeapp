import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/google_auth_config.dart';
import '../l10n/app_strings.dart';
import '../services/auth_api_service.dart';
import '../utils/validators.dart';
import '../services/google_sign_in_errors.dart';
import '../settings/app_settings.dart';
import '../widgets/app_logo.dart';
import '../widgets/main_shell.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppSettingsScope.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.onboardingDone) {
          return Localizations.override(
            context: context,
            locale: const Locale('en'),
            child: _OnboardingScreen(
              onDone: () async {
                await app.setOnboardingDone(true);
                await app.setSignedIn(value: false);
                if (!mounted) return;
                setState(() => _showSplash = false);
              },
            ),
          );
        }
        if (!app.hasAuthenticatedSession) {
          return Localizations.override(
            context: context,
            locale: const Locale('en'),
            child: _AuthScreen(
              onAuthenticated: () {
                if (!mounted) return;
                setState(() => _showSplash = false);
              },
            ),
          );
        }
        if (_showSplash) {
          return _SplashScreen(
            manualContinue: kDebugMode,
            onContinue: () {
              if (!mounted) return;
              setState(() => _showSplash = false);
            },
            onDebugShowWelcomeAuth: kDebugMode
                ? () async {
                    await app.setOnboardingDone(false);
                    await app.setSignedIn(value: false);
                    if (!mounted) return;
                    setState(() => _showSplash = false);
                  }
                : null,
          );
        }
        return const MainShell();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({
    required this.manualContinue,
    this.onContinue,
    this.onDebugShowWelcomeAuth,
  });

  /// When `true` (debug), splash does not auto-dismiss; user taps **Continue** or a test action.
  final bool manualContinue;
  final VoidCallback? onContinue;
  final Future<void> Function()? onDebugShowWelcomeAuth;

  @override
  Widget build(BuildContext context) {
    final bottom = manualContinue && onContinue != null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: onContinue,
                  child: const Text('Continue'),
                ),
                if (onDebugShowWelcomeAuth != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => onDebugShowWelcomeAuth!(),
                    child: const Text('Show welcome & sign-in'),
                  ),
                ],
              ],
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 176),
                const SizedBox(height: 16),
                Text(
                  AppStrings.of(context).appName,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Spacer(flex: 3),
            if (bottom != null) bottom,
          ],
        ),
      ),
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
  static const _bgGrey = Color(0xFFF5F5F7);
  /// Light pink icon wells (matches product welcome mockup).
  static const _wellPink = Color(0xFFFFE4E8);

  Widget _heroIllustration(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: BoxDecoration(
        color: _wellPink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline_rounded, size: 40, color: cs.primary),
          const SizedBox(width: 10),
          Icon(Icons.wifi_rounded, size: 32, color: cs.primary),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 22, color: cs.primary.withValues(alpha: 0.65)),
          const SizedBox(width: 8),
          Icon(Icons.photo_size_select_actual_rounded, size: 36, color: cs.primary),
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
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _wellPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _wellPink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$n',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: cs.primary),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    return Scaffold(
      backgroundColor: _bgGrey,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String?>(
                  tooltip: s.onboardingLanguageHint,
                  icon: Icon(Icons.language_rounded, color: cs.onSurfaceVariant),
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
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppLogo(size: 36, fit: BoxFit.contain),
                        const SizedBox(width: 10),
                        Text(
                          s.appName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _shadowCard(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          children: [
                            _heroIllustration(cs),
                            const SizedBox(height: 22),
                            Text(
                              s.welcomeInkTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.welcomeInkSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          ),
                          _stepRow(
                            context,
                            n: 2,
                            icon: Icons.add_rounded,
                            title: s.onboardStepPairTitle,
                            subtitle: s.onboardStepPairBody,
                            showDivider: true,
                          ),
                          _stepRow(
                            context,
                            n: 3,
                            icon: Icons.send_rounded,
                            title: s.onboardStepSendTitle,
                            subtitle: s.onboardStepSendBody,
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(s.onboardingConnectNow, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _finish,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.white,
                      foregroundColor: cs.onSurfaceVariant,
                      side: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(s.onboardingLater, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
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

class _AuthScreenState extends State<_AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  final _regName = TextEditingController();
  final _auth = AuthApiService();
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>['email', 'profile'],
    serverClientId: GoogleAuthConfig.serverClientId,
  );
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() {
      if (_tc.indexIsChanging) return;
      setState(() {});
    });
  }

  /// Modern Chinese–inspired auth shell: warm paper tones + vermillion accents.
  static const _creamBg = Color(0xFFF7F2ED);
  static const _paperWhite = Color(0xFFFFFBF8);
  static const _weChatGreen = Color(0xFF07C160);

  @override
  void dispose() {
    _tc.dispose();
    _email.dispose();
    _password.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regName.dispose();
    super.dispose();
  }

  Future<void> _finishAuthSession(AuthApiSuccess data, {String provider = 'email'}) async {
    final app = AppSettingsScope.of(context);
    await app.setAccountProfile(name: data.user.name, email: data.user.email);
    await app.completeAuthenticatedSession(
      token: data.token,
      userId: data.user.id,
      provider: provider,
    );
    if (!mounted) return;
    widget.onAuthenticated();
  }

  void _showAuthMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _failureMessage(AuthApiFailure f, AppStrings s) {
    if (f.errorKey == 'network_error') {
      return s.authErrorNetwork;
    }
    if (f.fieldErrors.isNotEmpty) {
      return f.fieldErrors.join('\n');
    }
    final sc = f.statusCode;
    if (sc == 401 || f.errorKey == 'invalid_credentials') {
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
          return (f.message != null && f.message!.trim().isNotEmpty) ? f.message!.trim() : s.authErrorInvalidCredentials;
        case 'invalid_name':
          return (f.message != null && f.message!.trim().isNotEmpty) ? f.message!.trim() : s.authErrorInvalidFields;
        case 'invalid_credentials':
          return (f.message != null && f.message!.trim().isNotEmpty) ? f.message!.trim() : s.authErrorInvalidFields;
        default:
          final m400 = f.message;
          return (m400 != null && m400.trim().isNotEmpty) ? m400.trim() : s.authErrorInvalidFields;
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

  Future<void> _submitLogin() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    if (Validators.emailError(_email.text) != null || Validators.passwordError(_password.text) != null) {
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
      await _finishAuthSession(r);
      return;
    }
    if (r is AuthApiFailure) _showAuthMessage(_failureMessage(r, s));
  }

  Future<void> _quickTestEnter() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    setState(() => _busy = true);
    final reg = await _auth.testLogin();
    if (!mounted) return;
    setState(() => _busy = false);
    if (reg is AuthApiSuccess) {
      await _finishAuthSession(reg);
      return;
    }
    if (reg is AuthApiFailure) _showAuthMessage(_failureMessage(reg, s));
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
      final r = await _auth.loginWithApple(identityToken: token);
      if (!mounted) return;
      if (r is AuthApiSuccess) {
        await _finishAuthSession(r, provider: 'apple');
        return;
      }
      if (r is AuthApiFailure) _showAuthMessage(_failureMessage(r, s));
    } on SignInWithAppleAuthorizationException catch (e) {
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
    if (!GoogleAuthConfig.isConfigured) {
      _showAuthMessage(s.authGoogleNotConfigured);
      return;
    }
    setState(() => _busy = true);
    try {
      // In-app Google account picker (no external browser).
      GoogleSignInAccount? account = await _googleSignIn.signInSilently(suppressErrors: true);
      account ??= await _googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        _showAuthMessage(s.authGoogleNoIdToken);
        return;
      }
      final r = await _auth.loginWithGoogle(idToken: idToken);
      if (!mounted) return;
      if (r is AuthApiSuccess) {
        await _finishAuthSession(r, provider: 'google');
        return;
      }
      if (r is AuthApiFailure) _showAuthMessage(_failureMessage(r, s));
    } catch (e) {
      _showAuthMessage(googleSignInErrorMessage(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _weChatTap() {
    _showAuthMessage(AppStrings.of(context).authWeChatSoon);
  }

  InputDecoration _underlineField(ColorScheme cs, String label, {String? hint}) {
    final subtle = cs.onSurface.withValues(alpha: 0.28);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 12, bottom: 14),
      border: UnderlineInputBorder(borderSide: BorderSide(color: subtle)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: subtle)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary, width: 2)),
      disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: subtle.withValues(alpha: 0.5))),
    );
  }

  Widget _segmentedTabs(AppStrings s, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segmentChip(
              label: s.loginLabel,
              selected: _tc.index == 0,
              onTap: () {
                if (_busy) return;
                _tc.animateTo(0);
                setState(() {});
              },
              cs: cs,
            ),
          ),
          Expanded(
            child: _segmentChip(
              label: s.registerLabel,
              selected: _tc.index == 1,
              onTap: () {
                if (_busy) return;
                _tc.animateTo(1);
                setState(() {});
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
            color: selected ? _paperWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: cs.primary.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
                color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.55),
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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.2),
              ),
            ),
            Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.25))),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
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
              child: Text(
                'G',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary),
              ),
            ),
            _socialCircle(
              tooltip: s.continueWeChat,
              onTap: _busy ? null : _weChatTap,
              color: _weChatGreen,
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
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
            decoration: borderColor != null ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor)) : null,
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
    return Scaffold(
      backgroundColor: _creamBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                children: [
                  const AppLogo(size: 48),
                  const SizedBox(height: 10),
                  Text(
                    s.appName,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: cs.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.authScreenTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.35, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _paperWhite,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                        child: _segmentedTabs(s, cs),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tc,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _authScroll(
                              s,
                              cs,
                              children: [
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: _underlineField(cs, s.emailLabel),
                                  enabled: !_busy,
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _password,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submitLogin(),
                                  decoration: _underlineField(cs, s.passwordLabel),
                                  enabled: !_busy,
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submitLogin,
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text(s.loginLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                                  decoration: _underlineField(cs, s.authUsernameLabel),
                                  enabled: !_busy,
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _regEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: _underlineField(cs, s.emailLabel),
                                  enabled: !_busy,
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _regPassword,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submitRegister(),
                                  decoration: _underlineField(cs, s.passwordLabel),
                                  enabled: !_busy,
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submitRegister,
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text(s.registerLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _socialRow(s, cs),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (kDebugMode)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: TextButton.icon(
                            onPressed: _busy ? null : _quickTestEnter,
                            icon: _busy
                                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                                : Icon(Icons.science_outlined, size: 18, color: cs.primary.withValues(alpha: 0.8)),
                            label: Text(_busy ? s.authBusyLabel : s.authQuickTestButton, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
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

  Widget _authScroll(AppStrings s, ColorScheme cs, {required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
  }
}
