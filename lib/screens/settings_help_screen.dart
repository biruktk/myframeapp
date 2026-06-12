import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/faq_item.dart';
import '../services/faq_service.dart';

class SettingsHelpScreen extends StatelessWidget {
  const SettingsHelpScreen({super.key});

  static final _faq = FaqService();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = _faq.localizedFaqs(s);
    return Scaffold(
      appBar: AppBar(title: Text(s.helpSupportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.faqSectionTitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (e) => _FaqItem(
              q: e.question,
              a: e.answer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.helpContactUs,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          _ContactCard(s: s, cs: cs),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.s, required this.cs});

  final AppStrings s;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest,
          child: Icon(Icons.email_outlined, color: cs.primary),
        ),
        title: Text(s.emailLabel),
        subtitle: Text('${s.supportEmail}\n${s.supportEmailSub}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: s.supportEmail));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.supportEmailCopied)),
          );
        },
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.q, required this.a});

  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(a),
          ),
        ],
      ),
    );
  }
}
