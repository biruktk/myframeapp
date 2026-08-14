import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../services/app_local_reset.dart';
import '../services/auth_session_manager.dart';
import '../services/network_link.dart';
import '../services/device_store.dart';
import '../services/protocol_logger_service.dart';
import '../settings/app_settings.dart';
import '../widgets/floating_log_button.dart';

class SettingsDebugScreen extends StatefulWidget {
  const SettingsDebugScreen({super.key});

  @override
  State<SettingsDebugScreen> createState() => _SettingsDebugScreenState();
}

class _SettingsDebugScreenState extends State<SettingsDebugScreen> {
  bool? _onLink;
  PairedFrame? _paired;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final onLink = await NetworkLink.onHomeLink();
    await DeviceStore.instance.load();
    if (!mounted) return;
    setState(() {
      _onLink = onLink;
      _paired = DeviceStore.instance.cached;
    });
  }

  String _exportBody(AppStrings s) {
    final buf = StringBuffer();
    buf.writeln('MyFrame debug export');
    buf.writeln('Data link: ${_onLink == true ? s.connected : s.notPaired}');
    buf.writeln('Paired: ${_paired?.deviceId ?? s.notPaired}');
    buf.writeln('API: ${_paired?.apiUrl ?? s.debugNoApi}');
    return buf.toString();
  }

  void _openProtocolLogs(BuildContext context) {
    final navContext = appNavigatorKey.currentContext ?? appNavigatorKey.currentState?.context ?? context;
    showModalBottomSheet<void>(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const ProtocolLogSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final app = AppSettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.debugModeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              leading: CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(Icons.bug_report, color: cs.primary),
              ),
              title: Text(s.debugModeTitle),
              subtitle: Text(s.debugOnlySubtitle),
              trailing: Switch.adaptive(
                value: app.debugModeEnabled,
                onChanged: (v) async {
                  await app.setDebugModeEnabled(v);
                  setState(() {});
                },
              ),
            ),
          ),
          if (app.debugModeEnabled) ...[
            _DebugBlock(
              title: s.debugCardNetwork,
              items: [
                (s.debugLabelWifi, _onLink == null ? s.loadingEllipsis : (_onLink! ? s.connected : s.notPaired)),
                (s.debugLabelServer, _paired?.apiUrl == null || _paired!.apiUrl!.isEmpty ? s.debugNoApi : s.connected),
              ],
            ),
            _DebugBlock(
              title: s.debugCardDevice,
              items: [
                (s.openDeviceInfo, _paired == null ? s.notPaired : _paired!.deviceId),
                (s.premiumTitle, s.notAvailable),
                (s.debugDeviceMemory, s.notAvailable),
              ],
            ),
            _DebugBlock(
              title: s.debugCardLogs,
              items: [
                (s.debugLabelSync, s.notAvailable),
                (s.debugLabelErrors, '0'),
                (s.debugLabelCache, s.notAvailable),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.bug_report, color: cs.primary),
                title: Text('Protocol Logs'),
                subtitle: Text('View MQTT/API logs (tap to open)'),
                trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                onTap: () => _openProtocolLogs(context),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Share.share(_exportBody(s), subject: s.debugModeTitle);
              },
              icon: const Icon(Icons.download),
              label: Text(s.exportLogs),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
              onPressed: () async {
                final go = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(s.factoryResetTitle),
                    content: Text(s.factoryResetBody),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(s.confirmErase),
                      ),
                    ],
                  ),
                );
                if (go != true || !context.mounted) return;
                await AppLocalReset.wipeAllLocalData();
                if (!context.mounted) return;
                await AppSettingsScope.of(context).reload();
                await _load();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.factoryResetDone)));
              },
              icon: const Icon(Icons.restart_alt),
              label: Text(s.factoryReset),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(s.refreshAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _DebugBlock extends StatelessWidget {
  const _DebugBlock({required this.title, required this.items});

  final String title;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.$1, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ),
                    Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProtocolLogSheet extends StatefulWidget {
  const _ProtocolLogSheet({Key? key}) : super(key: key);

  @override
  State<_ProtocolLogSheet> createState() => _ProtocolLogSheetState();
}

class _ProtocolLogSheetState extends State<_ProtocolLogSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ProtocolLoggerService.instance.logs;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, color: Color(0xFFE5252A), size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Protocol Logs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5252A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final ok = await ProtocolLoggerService.instance.copyToClipboard();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Logs copied to clipboard!' : 'No logs to copy'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.orange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy All', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        ProtocolLoggerService.instance.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white70),
                      label: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: ProtocolLoggerService.instance.logCountNotifier,
                builder: (context, _, __) {
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No logs recorded yet.\nPerform an MQTT or API action to capture logs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final entry = logs[index];
                        final isMqttOut = entry.category.contains('MQTT OUT');
                        final isMqttIn = entry.category.contains('MQTT IN');
                        final color = isMqttOut
                            ? const Color(0xFF4CAF50)
                            : isMqttIn
                                ? const Color(0xFF2196F3)
                                : const Color(0xFFFFB74D);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '[${entry.formattedTime}] ',
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                TextSpan(
                                  text: '[${entry.category}] ',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: entry.message,
                                  style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 13),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5252A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final ok = await ProtocolLoggerService.instance.copyToClipboard();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Logs copied to clipboard!' : 'No logs to copy'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.orange,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, color: Colors.white, size: 22),
              label: const Text(
                'Copy All Logs',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
