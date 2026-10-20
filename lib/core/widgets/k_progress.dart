import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:carina/core/tokens.dart';

/// Thin progress bar: red played part on a grey track, rounded ends.
///
/// Used under continue-watching cards, on channel cards (programme
/// progress) and in the players.
class KProgressBar extends StatelessWidget {
  const KProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.color = KColors.accent,
    this.trackColor = KColors.progressTrack,
    this.rounded = true,
  });

  /// Progress 0..1 (clamped).
  final double value;
  final double height;
  final Color color;
  final Color trackColor;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final radius = rounded
        ? BorderRadius.circular(height / 2)
        : BorderRadius.zero;
    return Semantics(
      value: '${(v * 100).round()}%',
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _BarPainter(v, color, trackColor, rounded),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.value, this.color, this.track, this.rounded);

  final double value;
  final Color color;
  final Color track;
  final bool rounded;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    if (value <= 0) return;
    final width = size.width * value;
    final rect = Rect.fromLTWH(0, 0, width, size.height);
    final paint = Paint()..color = color;
    if (rounded) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
        paint,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.rounded != rounded;
}

/// Thin spinning ring (player buffering, loading states) with an optional
/// label such as "Buffering 43%".
class KSpinner extends StatefulWidget {
  const KSpinner({
    super.key,
    this.size = 40,
    this.strokeWidth = 2.5,
    this.color = KColors.textPrimary,
    this.label,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  /// Text under the ring (e.g. `KStrings.of(context).buffering(43)`).
  final String? label;

  @override
  State<KSpinner> createState() => _KSpinnerState();
}

class _KSpinnerState extends State<KSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = SizedBox.square(
      dimension: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _RingPainter(widget.color, widget.strokeWidth),
        ),
      ),
    );
    final label = widget.label;
    if (label == null) return ring;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        const SizedBox(height: 14),
        Text(
          label,
          style: KText.button.copyWith(
            color: KColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontFeatures: KText.tabular,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.stroke);

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.16),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0), color],
        stops: const [0.15, 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2 + 0.6, math.pi * 1.6, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.stroke != stroke;
}
