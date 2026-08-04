import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/faq_service.dart';
import '../widgets/app_status_toast.dart';

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
          // 1) Contact / Email first
          Text(
            s.helpContactUs,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          _ContactCard(s: s, cs: cs),
          const SizedBox(height: 24),
          // 2) FAQ second
          Text(
            s.faqSectionTitle,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (e) => _FaqItem(
              q: e.question,
              a: e.answer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.s, required this.cs});

  final AppStrings s;
  final ColorScheme cs;

  static String _mailtoQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  Future<void> _launchEmailSupport(BuildContext context) async {
    final email = s.supportEmail.trim();
    final emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _mailtoQuery({'subject': s.supportEmailSubject}),
    );

    var launched = false;
    try {
      launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (launched) return;
    if (!context.mounted) return;

    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    AppStatusToast.show(
      context,
      title: s.supportEmailCopied,
      message: s.supportEmailOpenFailed,
      tone: AppStatusTone.info,
      icon: Icons.content_copy_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest,
          child: Icon(Icons.email_outlined, color: cs.primary),
        ),
        title: Text(s.emailLabel),
        subtitle: Text('${s.supportEmail}\n${s.supportEmailSub}'),
        isThreeLine: true,
        trailing: Icon(Icons.open_in_new_rounded, color: cs.onSurfaceVariant),
        onTap: () => _launchEmailSupport(context),
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
