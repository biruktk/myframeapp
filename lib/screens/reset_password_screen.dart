import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_api_service.dart';
import '../theme/app_theme.dart';
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
  var _obscurePassword = true;
  var _obscureConfirm = true;

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
    return Scaffold(
      backgroundColor: AppAuthTheme.bgLight,
      appBar: AppBar(
        title: Text(s.resetPasswordTitle),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _tokenValid
              ? (_done ? _doneView(s) : _formView(s))
              : _invalidView(s),
        ),
      ),
    );
  }

  Widget _formView(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          s.resetPasswordDescription,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _password,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          enabled: !_busy,
          style: const TextStyle(fontSize: 15),
          decoration: AppAuthTheme.inputStyle(
            label: s.passwordLabel,
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _confirm,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          enabled: !_busy,
          style: const TextStyle(fontSize: 15),
          decoration: AppAuthTheme.inputStyle(
            label: s.resetPasswordConfirm,
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppAuthTheme.primaryRed,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: AppAuthTheme.primaryRed.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    s.resetPasswordSubmit,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _doneView(AppStrings s) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: AppAuthTheme.primaryRed,
        ),
        const SizedBox(height: 20),
        Text(
          s.resetPasswordSuccess,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppAuthTheme.primaryRed,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: AppAuthTheme.primaryRed.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              s.resetPasswordGoToLogin,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _invalidView(AppStrings s) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.error_outline,
          size: 72,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 20),
        Text(
          s.resetPasswordInvalidToken,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
