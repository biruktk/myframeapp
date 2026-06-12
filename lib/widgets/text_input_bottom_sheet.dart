import 'package:flutter/material.dart';

/// Single-field bottom sheet. The [TextEditingController] lives in sheet [State]
/// so it is never disposed while the route exit animation still has dependents.
class TextInputBottomSheet extends StatefulWidget {
  const TextInputBottomSheet({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.initialText = '',
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialText;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String confirmLabel,
    String initialText = '',
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => TextInputBottomSheet(
        title: title,
        label: label,
        confirmLabel: confirmLabel,
        initialText: initialText,
        textCapitalization: textCapitalization,
        autocorrect: autocorrect,
      ),
    );
  }

  @override
  State<TextInputBottomSheet> createState() => _TextInputBottomSheetState();
}

class _TextInputBottomSheetState extends State<TextInputBottomSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: widget.textCapitalization,
            autocorrect: widget.autocorrect,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
