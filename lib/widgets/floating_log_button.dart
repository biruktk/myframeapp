import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/protocol_logger_service.dart';

class FloatingLogOverlay extends StatefulWidget {
  final Widget child;

  const FloatingLogOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<FloatingLogOverlay> createState() => _FloatingLogOverlayState();
}

class _FloatingLogOverlayState extends State<FloatingLogOverlay> {
  Offset? _position;

  void _openLogSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _ProtocolLogSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final defaultPos = Offset(size.width - 80, size.height * 0.45);
    final currentPos = _position ?? defaultPos;

    final maxX = size.width - 64;
    final maxY = size.height - 64;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: currentPos.dx.clamp(0.0, maxX),
          top: currentPos.dy.clamp(0.0, maxY),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final nextDx = (currentPos.dx + details.delta.dx).clamp(0.0, maxX);
                final nextDy = (currentPos.dy + details.delta.dy).clamp(0.0, maxY);
                _position = Offset(nextDx, nextDy);
              });
            },
            onTap: () => _openLogSheet(context),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFE5252A),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: ValueListenableBuilder<int>(
                  valueListenable: ProtocolLoggerService.instance.logCountNotifier,
                  builder: (context, count, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bug_report, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'LOGS ($count)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
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
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.70,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        ProtocolLoggerService.instance.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white70),
                      label: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
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
                  final logs = ProtocolLoggerService.instance.logs;
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No logs recorded yet.\nPerform an MQTT or API action to capture logs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(8),
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
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '[${entry.formattedTime}] ',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                TextSpan(
                                  text: '[${entry.category}] ',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                TextSpan(
                                  text: entry.message,
                                  style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 12),
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
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5252A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
              icon: const Icon(Icons.copy, color: Colors.white, size: 18),
              label: const Text(
                'Copy All Logs',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
