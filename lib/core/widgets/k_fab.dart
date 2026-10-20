import 'package:flutter/material.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_interactive.dart';

/// Floating red round menu button (~56 px) with a white hamburger of three
/// rounded lines. Sits at the bottom-right of Movies, Shows, TV Live and
/// TV Guide and opens the category sidebar.
class KFab extends StatelessWidget {
  const KFab({
    super.key,
    required this.onPressed,
    this.size = 56,
    this.tooltip,
    this.focusNode,
  });

  final VoidCallback? onPressed;
  final double size;

  /// Defaults to the localized "Categories".
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final label = tooltip ?? KStrings.of(context).categories;
    Widget fab = KInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusNode: focusNode,
      semanticLabel: label,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final color = state.pressed
            ? KColors.accentPressed
            : state.highlighted
            ? KColors.accentHover
            : KColors.accent;
        return AnimatedScale(
          scale: state.pressed
              ? 0.95
              : state.highlighted
              ? 1.06
              : 1.0,
          duration: duration,
          curve: KMotion.hover,
          child: KFocusRing(
            visible: state.focused,
            circle: true,
            child: AnimatedContainer(
              duration: duration,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: KShadows.floating,
              ),
              child: CustomPaint(painter: _HamburgerPainter(size)),
            ),
          ),
        );
      },
    );
    if (Overlay.maybeOf(context) != null) {
      fab = Tooltip(message: label, excludeFromSemantics: true, child: fab);
    }
    return fab;
  }
}

class _HamburgerPainter extends CustomPainter {
  _HamburgerPainter(this.diameter);

  final double diameter;

  @override
  void paint(Canvas canvas, Size size) {
    final width = diameter * 0.42;
    final stroke = diameter * 0.052;
    final gap = diameter * 0.135;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    for (final dy in [-gap, 0.0, gap]) {
      canvas.drawLine(
        center + Offset(-width / 2, dy),
        center + Offset(width / 2, dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HamburgerPainter old) => old.diameter != diameter;
}
