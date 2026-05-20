import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/payment_gateway_service.dart';
import '../settings/app_settings.dart';

class SettingsProScreen extends StatelessWidget {
  const SettingsProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.plansAndStorageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (app.isProMember) _ProMemberHero(s: s, cs: cs) else _ProUpgradeCard(s: s, cs: cs),
          const SizedBox(height: 16),
          Text(s.premiumSub, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _FeatureRow(icon: Icons.auto_awesome_outlined, title: s.proFeatureAi, ok: app.isProMember),
                _FeatureRow(icon: Icons.playlist_play, title: s.proFeaturePlaylists, ok: app.isProMember),
                _FeatureRow(icon: Icons.cloud_outlined, title: s.proFeatureStorage, ok: app.isProMember),
                _FeatureRow(icon: Icons.bolt_outlined, title: s.proFeaturePriority, ok: app.isProMember),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final r = await PaymentGatewayService.instance.purchaseSubscription(
                productSku: 'myframe_pro_monthly',
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(r.ok ? s.saveLabel : s.subscriptionComingLater),
                ),
              );
            },
            icon: const Icon(Icons.credit_card),
            label: Text(s.manageSubscription),
          ),
          if (!app.isProMember) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await app.setProMember(true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.saveLabel)),
                );
              },
              child: Text(s.proUpgradeTitle),
            ),
          ],
          if (app.isProMember) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await app.setProMember(false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.saveLabel)),
                );
              },
              child: Text(s.freePlanTitle),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(s.freePlanTitle),
              subtitle: Text(s.freePlanStorage300),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProMemberHero extends StatelessWidget {
  const _ProMemberHero({required this.s, required this.cs});

  final AppStrings s;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text('👑', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
            s.proYouAreMember,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            s.proHeroSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Text(
                    s.proValidThrough,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProUpgradeCard extends StatelessWidget {
  const _ProUpgradeCard({required this.s, required this.cs});

  final AppStrings s;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: cs.primary),
                const SizedBox(width: 8),
                Text(s.proUpgradeTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            Text(s.proUpgradeBody, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.ok});

  final IconData icon;
  final String title;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(title),
      trailing: Icon(
        ok ? Icons.check_circle : Icons.lock_outline,
        color: ok ? Colors.green : cs.onSurfaceVariant,
      ),
    );
  }
}
