import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _auth = AuthApiService();
  var _busy = false;
  var _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final s = AppStrings.of(context);
    if (Validators.emailError(_email.text) != null) {
      _showMessage(s.authErrorInvalidFields);
      return;
    }
    setState(() => _busy = true);
    final r = await _auth.forgotPassword(email: _email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
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
    if (f.errorKey == 'rate_limited') return s.forgotPasswordRateLimited;
    if (f.statusCode >= 500 || f.errorKey == 'server_error') return s.authErrorServer;
    return f.message ?? s.authErrorInvalidFields;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppAuthTheme.bgLight,
      appBar: AppBar(
        title: Text(s.forgotPasswordTitle),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                s.forgotPasswordDescription,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                enabled: !_busy && !_sent,
                style: const TextStyle(fontSize: 15),
                decoration: AppAuthTheme.inputStyle(
                  label: s.emailLabel,
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 24),
              if (_sent)
                Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: AppAuthTheme.primaryRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.forgotPasswordSent,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                )
              else
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
                            s.forgotPasswordSend,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
