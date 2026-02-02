import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    super.key,
    required this.child,
    required this.contextMenuBuilder,
  });

  final Widget child;
  final Widget Function(BuildContext context, Offset offset) contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onLongPressStart: (details) {
        // Also support long press for touch devices
        _showContextMenu(context, details.globalPosition);
        HapticFeedback.mediumImpact();
      },
      child: child,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible barrier to close menu
          Positioned.fill(
            child: GestureDetector(
              onTap: () => overlayEntry.remove(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Context menu
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: contextMenuBuilder(context, position),
            ),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
  }
}