import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_interactive.dart';
import 'package:carina/core/window/window_controls.dart';

/// Dark Windows-style caption buttons (minimize, maximize/restore, close;
/// close turns red on hover) for the frameless window. Hidden on macOS,
/// which keeps its native traffic lights, unless [forceVisible].
///
/// Uses [KWindowControls.of] unless [controls] is given; without controls
/// the buttons render but do nothing (tests, captures).
class KCaptionButtons extends StatelessWidget {
  const KCaptionButtons({
    super.key,
    this.controls,
    this.forceVisible = false,
    this.height = 32,
    this.buttonWidth = 46,
  });

  final KWindowControls? controls;
  final bool forceVisible;
  final double height;
  final double buttonWidth;

  /// Whether this platform draws its own caption buttons (Windows, Linux).
  static bool get platformUsesCaptionButtons =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Total width of the three buttons.
  double get width => buttonWidth * 3;

  @override
  Widget build(BuildContext context) {
    if (!forceVisible && !platformUsesCaptionButtons) {
      return const SizedBox.shrink();
    }
    final strings = KStrings.of(context);
    final c = controls ?? KWindowControls.of(context);
    Widget buttons(bool maximized) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          glyph: _Glyph.minimize,
          tooltip: strings.windowMinimize,
          width: buttonWidth,
          height: height,
          onTap: () => c?.minimize(),
        ),
        _CaptionButton(
          glyph: maximized ? _Glyph.restore : _Glyph.maximize,
          tooltip: maximized ? strings.windowRestore : strings.windowMaximize,
          width: buttonWidth,
          height: height,
          onTap: () => c?.toggleMaximize(),
        ),
        _CaptionButton(
          glyph: _Glyph.close,
          tooltip: strings.windowClose,
          width: buttonWidth,
          height: height,
          onTap: () => c?.close(),
        ),
      ],
    );
    if (c == null) return buttons(false);
    return ValueListenableBuilder<bool>(
      valueListenable: c.isMaximized,
      builder: (context, maximized, _) => buttons(maximized),
    );
  }
}

enum _Glyph { minimize, maximize, restore, close }

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.glyph,
    required this.tooltip,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final _Glyph glyph;
  final String tooltip;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isClose = glyph == _Glyph.close;
    Widget button = KInteractive(
      onTap: onTap,
      focusable: false,
      // Native caption buttons keep the arrow cursor.
      mouseCursor: SystemMouseCursors.basic,
      semanticLabel: tooltip,
      builder: (context, state, _) {
        final Color fill;
        if (isClose && (state.hovered || state.pressed)) {
          fill = state.pressed
              ? const Color(0xFFA8241A)
              : KColors.windowsCloseHover;
        } else if (state.pressed) {
          fill = const Color(0x0FFFFFFF);
        } else if (state.hovered) {
          fill = const Color(0x1AFFFFFF);
        } else {
          fill = const Color(0x00FFFFFF);
        }
        final iconColor = isClose && state.hovered
            ? Colors.white
            : const Color(0xE6FFFFFF);
        return AnimatedContainer(
          duration: KMotion.of(context, const Duration(milliseconds: 90)),
          width: width,
          height: height,
          color: fill,
          child: CustomPaint(painter: _GlyphPainter(glyph, iconColor)),
        );
      },
    );
    if (Overlay.maybeOf(context) != null) {
      button = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        waitDuration: const Duration(milliseconds: 700),
        child: button,
      );
    }
    return button;
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = glyph == _Glyph.close;
    final left = (size.width / 2 - 5).roundToDouble() + 0.5;
    final top = (size.height / 2 - 5).roundToDouble() + 0.5;
    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(
          Offset(left, top + 5),
          Offset(left + 10, top + 5),
          paint,
        );
      case _Glyph.maximize:
        canvas.drawRect(Rect.fromLTWH(left, top, 10, 10), paint);
      case _Glyph.restore:
        canvas.drawRect(Rect.fromLTWH(left, top + 2, 8, 8), paint);
        final path = Path()
          ..moveTo(left + 2, top + 2)
          ..lineTo(left + 2, top)
          ..lineTo(left + 10, top)
          ..lineTo(left + 10, top + 8)
          ..lineTo(left + 8, top + 8);
        canvas.drawPath(path, paint);
      case _Glyph.close:
        canvas.drawLine(Offset(left, top), Offset(left + 10, top + 10), paint);
        canvas.drawLine(Offset(left + 10, top), Offset(left, top + 10), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
