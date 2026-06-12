import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';

class SettingsAccountScreen extends StatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  State<SettingsAccountScreen> createState() => _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends State<SettingsAccountScreen> {
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _birthdayCtrl = TextEditingController();
  var _loaded = false;
  DateTime? _birthday;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final app = AppSettingsScope.of(context);
    _name.text = app.profileName;
    _email.text = app.accountEmail;
    _birthday = _parseDate(app.birthday);
    _birthdayCtrl.text = _formatBirthdayField(_birthday);
    _loaded = true;
  }

  DateTime? _parseDate(String s) {
    if (s.trim().isEmpty) return null;
    final p = s.trim().split('-');
    if (p.length == 3) {
      final y = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final d = int.tryParse(p[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  String _formatBirthdayField(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String get _birthdayString => _formatBirthdayField(_birthday);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _birthdayCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppSettingsScope.of(context);
    await app.setAccountProfile(
      name: _name.text,
      email: _email.text,
      birthdayValue: _birthdayString,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).saveLabel)),
    );
  }

  Future<void> _pickBirthday() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      _birthday = d;
      _birthdayCtrl.text = _formatBirthdayField(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.account)),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
          Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  _ProfileAvatar(gradient: _avatarGradient(cs)),
                  const SizedBox(height: 12),
                  Text(
                    _name.text.trim().isEmpty ? '—' : _name.text.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email.text.trim().isEmpty ? '—' : _email.text.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.accountProfileSection,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _AccountFormField(
            label: s.accountDisplayNameLabel,
            child: TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: _formDecoration(context, hint: ''),
            ),
          ),
          _AccountFormField(
            label: s.emailLabel,
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: _formDecoration(context, hint: ''),
            ),
          ),
          _AccountFormField(
            label: s.accountBirthdayLabel,
            child: TextField(
              controller: _birthdayCtrl,
              readOnly: true,
              onTap: _pickBirthday,
              decoration: _formDecoration(context, hint: 'YYYY-MM-DD'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              label: Text(s.accountSaveChangesButton),
            ),
          ),
            ],
          );
        },
      ),
    );
  }

  LinearGradient _avatarGradient(ColorScheme cs) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        cs.primary,
        const Color(0xFFE11D48),
      ],
    );
  }

  static InputDecoration _formDecoration(BuildContext context, {required String hint}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintText: hint.isEmpty ? null : hint,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.2),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.gradient});

  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
      ),
      child: const Icon(
        Icons.person,
        size: 36,
        color: Colors.white,
      ),
    );
  }
}

class _AccountFormField extends StatelessWidget {
  const _AccountFormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
