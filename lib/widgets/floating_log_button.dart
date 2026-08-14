import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_session_manager.dart';
import '../services/protocol_logger_service.dart';

class FloatingLogOverlay extends StatefulWidget {
  final Widget child;

  const FloatingLogOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<FloatingLogOverlay> createState() => _FloatingLogOverlayState();
}

class _FloatingLogOverlayState extends State<FloatingLogOverlay> {
  void _openLogSheet(BuildContext context) {
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
    final mediaQuery = MediaQuery.of(context);
    final topOffset = mediaQuery.size.height * 0.42;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            right: 12,
            top: topOffset,
            child: ValueListenableBuilder<int>(
              valueListenable: ProtocolLoggerService.instance.logCountNotifier,
              builder: (context, count, _) {
                return Material(
                  color: Colors.transparent,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openLogSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5252A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bug_report, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'LOGS ($count)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProtocolLogSheet extends StatefulWidget {
  const ProtocolLogSheet({Key? key}) : super(key: key);

  @override
  State<ProtocolLogSheet> createState() => _ProtocolLogSheetState();
}

class _ProtocolLogSheetState extends State<ProtocolLogSheet> {
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