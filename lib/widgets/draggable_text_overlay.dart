import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Draggable and resizable text overlay for image editor
class DraggableTextOverlay extends StatefulWidget {
  const DraggableTextOverlay({
    super.key,
    required this.text,
    required this.onChanged,
    required this.canvasSize,
    this.initialPosition = const Offset(0.5, 0.5),
    this.initialFontSize = 32.0,
    this.color = Colors.white,
    this.onDelete,
  });

  final String text;
  final Size canvasSize;
  final Offset initialPosition; // Normalized 0-1
  final double initialFontSize;
  final Color color;
  final Function(Offset position, double fontSize) onChanged;
  final VoidCallback? onDelete;

  @override
  State<DraggableTextOverlay> createState() => _DraggableTextOverlayState();
}

class _DraggableTextOverlayState extends State<DraggableTextOverlay> {
  late Offset _position;
  late double _fontSize;
  bool _isSelected = false;
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _fontSize = widget.initialFontSize;
  }

  @override
  void didUpdateWidget(DraggableTextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      setState(() {});
    }
  }

  void _notifyChanged() {
    widget.onChanged(_position, _fontSize);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    final pixelX = _position.dx * widget.canvasSize.width;
    final pixelY = _position.dy * widget.canvasSize.height;

    return Stack(
      children: [
        // Main text with drag gesture
        Positioned(
          left: pixelX,
          top: pixelY,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isSelected = !_isSelected;
              });
            },
            onPanStart: (details) {
              _dragStart = Offset(pixelX, pixelY);
              setState(() {
                _isSelected = true;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                final newX = (_dragStart!.dx + details.localPosition.dx)
                    .clamp(0.0, widget.canvasSize.width);
                final newY = (_dragStart!.dy + details.localPosition.dy)
                    .clamp(0.0, widget.canvasSize.height);
                
                _position = Offset(
                  newX / widget.canvasSize.width,
                  newY / widget.canvasSize.height,
                );
              });
              _notifyChanged();
            },
            onPanEnd: (_) {
              _dragStart = null;
            },
            child: Transform.translate(
              offset: Offset(-_fontSize * widget.text.length * 0.3, -_fontSize * 0.5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: _isSelected
                    ? BoxDecoration(
                        border: Border.all(
                          color: Colors.blue,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: _fontSize,
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Resize handle (bottom-right corner)
        if (_isSelected)
          Positioned(
            left: pixelX + _fontSize * widget.text.length * 0.3,
            top: pixelY + _fontSize * 0.3,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  final delta = (details.delta.dx + details.delta.dy) / 2;
                  _fontSize = (_fontSize + delta).clamp(16.0, 120.0);
                });
                _notifyChanged();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.open_in_full,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        // Delete button (top-right corner)
        if (_isSelected && widget.onDelete != null)
          Positioned(
            left: pixelX + _fontSize * widget.text.length * 0.3 + 8,
            top: pixelY - _fontSize * 0.5 - 8,
            child: GestureDetector(
              onTap: widget.onDelete,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Manager for multiple text overlays
class TextOverlayData {
  TextOverlayData({
    required this.text,
    required this.position,
    required this.fontSize,
    required this.color,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  final String id;
  final String text;
  final Offset position;
  final double fontSize;
  final Color color;

  TextOverlayData copyWith({
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
  }) {
    return TextOverlayData(
      id: id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
    );
  }
}
