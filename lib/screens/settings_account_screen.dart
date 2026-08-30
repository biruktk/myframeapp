import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_strings.dart';
import '../services/gallery_image_cache.dart';
import '../services/permission_gate.dart';
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
  var _avatarBusy = false;
  DateTime? _birthday;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final app = AppSettingsScope.of(context);
    _name.text = app.profileName;
    // WeChat accounts have no email — show the auth provider label instead
    // of an empty field so the user sees meaningful info in the account card.
    if (app.accountEmail.isNotEmpty) {
      _email.text = app.accountEmail;
    } else if (app.authProvider == 'wechat') {
      _email.text = 'WeChat Account';
    } else {
      _email.text = '';
    }
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

  Future<void> _pickAvatar() async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      final perm = await PermissionGate.photos();
      if (!perm.isGranted && !perm.isLimited) return;
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (x == null || !mounted) return;
      final stored = await GalleryImageCache.persistFromPath(x.path);
      if (stored == null || !mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).avatarUpdateFailed)),
        );
        return;
      }
      await AppSettingsScope.of(context).setProfileAvatarPath(stored);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
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
                  _ProfileAvatar(
                    gradient: _avatarGradient(cs),
                    imagePath: app.profileAvatarPath,
                    busy: _avatarBusy,
                    onTap: _pickAvatar,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.avatarChangeHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
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
  const _ProfileAvatar({
    required this.gradient,
    required this.imagePath,
    required this.onTap,
    this.busy = false,
  });

  final LinearGradient gradient;
  final String imagePath;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath.trim().isNotEmpty && File(imagePath).existsSync();
    return Semantics(
      button: true,
      label: AppStrings.of(context).avatarChangeHint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          customBorder: const CircleBorder(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasImage ? null : gradient,
                  image: hasImage
                      ? DecorationImage(
                          image: FileImage(File(imagePath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasImage
                    ? null
                    : const Icon(
                        Icons.person,
                        size: 36,
                        color: Colors.white,
                      ),
              ),
              if (busy)
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
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
