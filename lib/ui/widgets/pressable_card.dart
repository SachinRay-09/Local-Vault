import 'dart:io';
import 'package:flutter/material.dart';

/// A pressable surface that provides:
/// - AnimatedScale (1.0 → 0.97 on press-down, spring back on release)
/// - Material + InkWell ripple (InkSparkle on Android, InkRipple on desktop)
/// - MouseRegion hover tint using colorScheme.surfaceContainerHigh (desktop only)
/// - Accepts onTap, onLongPress, onSecondaryTapDown callbacks + borderRadius
class PressableCard extends StatefulWidget {
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final BorderRadius borderRadius;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;
  bool _hovered = false;

  // Choose splash factory by platform: InkSparkle on Android,
  // InkRipple everywhere else (Windows/Linux/macOS).
  InteractiveInkFeatureFactory get _splashFactory {
    if (Platform.isAndroid) return InkSparkle.splashFactory;
    return InkRipple.splashFactory;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      // Capture secondary (right-click) taps before InkWell consumes them
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              // Hover tint: subtle surfaceContainerHigh shift on desktop,
              // fully transparent on mobile (touch has ripple, no hover).
              // This app targets Windows and Android only (no iOS directory);
              // !Platform.isAndroid correctly selects desktop for both platforms.
              // Colors.transparent is used intentionally as a zero-opacity
              // sentinel — not a themed color — because the parent widget
              // supplies its own background and we want no overlay at all.
              color: _hovered && !Platform.isAndroid
                  ? colorScheme.surfaceContainerHigh.withOpacity(0.6)
                  : Colors.transparent,
              borderRadius: widget.borderRadius,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                splashFactory: _splashFactory,
                borderRadius: widget.borderRadius,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
