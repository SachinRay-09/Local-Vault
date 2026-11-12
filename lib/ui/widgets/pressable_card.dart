import 'dart:io';
import 'package:flutter/material.dart';

/// A pressable surface that provides:
/// - TweenAnimationBuilder scale (1.0 → 0.96 on press-down, elasticOut spring back)
/// - Material + InkWell ripple (InkSparkle on Android, InkRipple on desktop)
/// - MouseRegion hover with M3 state-layer (onSurface @ 8%) + elevation hint (desktop only)
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

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  InteractiveInkFeatureFactory get _splashFactory {
    if (Platform.isAndroid) return InkSparkle.splashFactory;
    return InkRipple.splashFactory;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHovered = _hovered && _isDesktop;

    // Build the inner Material+InkWell tree once as a const-stable child
    // so TweenAnimationBuilder does not rebuild it on every tick.
    final inkChild = Material(
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
    );

    return GestureDetector(
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: _pressed ? 0.96 : 1.0),
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 150),
        curve: _pressed ? Curves.easeInOut : Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: _isDesktop
            ? MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    // M3 state-layer: onSurface at 3% (light) / 8% (dark) for hover, 0% for rest.
                    // Light mode cards now use surfaceContainerLowest (near-white) so
                    // even 3% reads cleanly; dark mode keeps 8% (near-white tint on
                    // dark surface = gentle bloom). Same color space => no dark-flash.
                    color: isHovered
                        ? colorScheme.onSurface.withOpacity(
                            colorScheme.brightness == Brightness.dark
                                ? 0.08
                                : 0.03,
                          )
                        : colorScheme.onSurface.withOpacity(0.0),
                    borderRadius: widget.borderRadius,
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.04),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: inkChild,
                ),
              )
            : inkChild,
      ),
    );
  }
}
