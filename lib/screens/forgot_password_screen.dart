import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_api_service.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.forgotPasswordTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.forgotPasswordDescription,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: s.emailLabel,
                  border: const OutlineInputBorder(),
                ),
                enabled: !_busy && !_sent,
              ),
              const SizedBox(height: 20),
              if (_sent)
                Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      s.forgotPasswordSent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_busy ? s.authBusyLabel : s.forgotPasswordSend),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
