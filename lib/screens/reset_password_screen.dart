import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_api_service.dart';
import '../utils/validators.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthApiService();
  var _busy = false;
  var _done = false;
  var _tokenValid = true;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _checkToken() async {
    final r = await _auth.validateResetToken(token: widget.token);
    if (!mounted) return;
    if (r is AuthApiFailure) {
      setState(() => _tokenValid = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    if (Validators.passwordError(_password.text) != null) {
      _showMessage(s.authErrorPasswordLength);
      return;
    }
    if (_password.text != _confirm.text) {
      _showMessage(s.resetPasswordMismatch);
      return;
    }
    setState(() => _busy = true);
    final r = await _auth.resetPassword(token: widget.token, password: _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
    if (r is AuthApiFailure) {
      _showMessage(_failureMessage(r, s));
      return;
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _failureMessage(AuthApiFailure f, AppStrings s) {
    if (f.errorKey == 'network_error') return s.authErrorNetwork;
    if (f.errorKey == 'invalid_token') return s.resetPasswordInvalidToken;
    if (f.errorKey == 'token_expired') return s.resetPasswordExpired;
    if (f.errorKey == 'token_already_used') return s.resetPasswordAlreadyUsed;
    if (f.statusCode >= 500 || f.errorKey == 'server_error') return s.authErrorServer;
    return f.message ?? s.authErrorInvalidFields;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.resetPasswordTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _tokenValid
              ? (_done ? _doneView(s, cs) : _formView(s, cs))
              : _invalidView(s, cs),
        ),
      ),
    );
  }

  Widget _formView(AppStrings s, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.resetPasswordDescription,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: s.passwordLabel,
            border: const OutlineInputBorder(),
          ),
          enabled: !_busy,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirm,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: s.resetPasswordConfirm,
            border: const OutlineInputBorder(),
          ),
          enabled: !_busy,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(_busy ? s.authBusyLabel : s.resetPasswordSubmit),
        ),
      ],
    );
  }

  Widget _doneView(AppStrings s, ColorScheme cs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, size: 64, color: cs.primary),
        const SizedBox(height: 16),
        Text(
          s.resetPasswordSuccess,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(s.resetPasswordGoToLogin),
        ),
      ],
    );
  }

  Widget _invalidView(AppStrings s, ColorScheme cs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: cs.error),
        const SizedBox(height: 16),
        Text(
          s.resetPasswordInvalidToken,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: cs.onSurface),
        ),
      ],
    );
  }
}
