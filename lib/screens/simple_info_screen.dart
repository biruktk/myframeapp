import 'package:flutter/material.dart';

/// Lightweight detail page for Settings rows and similar (matches mockup “sub settings” pages).
class SimpleInfoScreen extends StatelessWidget {
  const SimpleInfoScreen({required this.title, required this.body, this.leading, super.key});

  final String title;
  final String body;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (leading != null) ...[
            Icon(leading, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
          ],
          Text(body, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, height: 1.45, fontSize: 16)),
        ],
      ),
    );
  }
}
