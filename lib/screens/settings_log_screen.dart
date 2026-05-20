import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/usage_metrics_store.dart';

class SettingsLogScreen extends StatefulWidget {
  const SettingsLogScreen({super.key});

  @override
  State<SettingsLogScreen> createState() => _SettingsLogScreenState();
}

class _SettingsLogScreenState extends State<SettingsLogScreen> {
  UsageMetrics? _m;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await UsageMetricsStore.instance.load();
    if (!mounted) return;
    setState(() => _m = data);
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _relativeAgo(DateTime? ts, AppStrings s) {
    if (ts == null) return '—';
    final d = DateTime.now().difference(ts);
    if (d.inSeconds < 45) return s.justNow;
    if (d.inMinutes < 60) return s.minutesAgo(d.inMinutes);
    if (d.inHours < 48) return s.hoursAgo(d.inHours);
    return s.daysAgo(d.inDays);
  }

  String _titleForKind(String kind, AppStrings s) {
    return switch (kind) {
      'photo' => s.logEventPhotoSent,
      'sd' => s.logEventSdImport,
      'share' => s.logEventShare,
      'delete' => s.logEventDelete,
      _ => s.logEventOther,
    };
  }

  IconData _iconForKind(String kind) {
    return switch (kind) {
      'photo' => Icons.cloud_upload_outlined,
      'sd' => Icons.sd_card_outlined,
      'share' => Icons.ios_share_outlined,
      'delete' => Icons.delete_outline,
      _ => Icons.event_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final m = _m;
    return Scaffold(
      appBar: AppBar(title: Text(s.operationLog)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  children: [
                    _StatTile(label: s.logLabelUploads, value: (m?.photosSentCount ?? 0).toString(), highlight: cs.primary),
                    _StatTile(label: s.logLabelShared, value: (m?.shareCount ?? 0).toString(), highlight: const Color(0xFF2E7D32)),
                    _StatTile(label: s.logLabelDeleted, value: (m?.deleteCount ?? 0).toString(), highlight: cs.error),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(s.logRecentEvents, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (m == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator.adaptive(strokeWidth: 2.2)),
              )
            else if (m.recentLog.isNotEmpty)
              ...m.recentLog.map(
                (e) => Card(
                  child: ListTile(
                    leading: Icon(_iconForKind(e.kind)),
                    title: Text(_titleForKind(e.kind, s)),
                    subtitle: Text('${_fmt(e.at)} · ${_relativeAgo(e.at, s)}'),
                  ),
                ),
              )
            else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(s.logEventPhotoSent),
                  subtitle: Text('${_fmt(m.lastPhotoAt)} · ${_relativeAgo(m.lastPhotoAt, s)}'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sd_card_outlined),
                  title: Text(s.logEventSdImport),
                  subtitle: Text('${_fmt(m.lastSdDetectedAt)} · ${_relativeAgo(m.lastSdDetectedAt, s)}'),
                ),
              ),
            ],
            if (m != null) ...[
              const SizedBox(height: 8),
              Text(
                s.operationLogSub,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.highlight});

  final String label;
  final String value;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: highlight),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
