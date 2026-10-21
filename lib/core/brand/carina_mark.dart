import 'package:flutter/widgets.dart';

/// The Carina mark: a flat-deck hull carrying a play button, under a star
/// (Canopus, the brightest star of the Carina constellation). Geometry is
/// defined on a 64×64 grid (see ARCHITECTURE.md); the app icon generator uses
/// the same painter.
class CarinaMark extends StatelessWidget {
  const CarinaMark({super.key, this.size = 40, this.color, this.background});

  final double size;

  /// Solid fill. When null the mark uses the brand gradient.
  final Color? color;

  /// When set, paints the rounded-square tile behind the mark (app icon look).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CarinaMarkPainter(color: color, background: background),
      ),
    );
  }
}

class CarinaMarkPainter extends CustomPainter {
  const CarinaMarkPainter({this.color, this.background});

  final Color? color;
  final Color? background;

  /// Brand gradient, top-left to bottom-right.
  static const gradientStart = Color(0xFFFFB46B);
  static const gradientEnd = Color(0xFFFF5E57);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 64;
    canvas.save();
    canvas.scale(s);
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 64, 64),
          const Radius.circular(14),
        ),
        Paint()..color = background!,
      );
    }
    final paint = Paint()..isAntiAlias = true;
    if (color != null) {
      paint.color = color!;
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      ).createShader(const Rect.fromLTWH(0, 0, 64, 64));
    }

    // Canopus.
    canvas.drawCircle(const Offset(47, 18), 3.4, paint);

    // The hull with the play button cut out of it.
    final hull = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(8, 31)
      ..lineTo(58, 31)
      ..lineTo(48.6, 48.3)
      ..cubicTo(48, 49.4, 46.8, 50, 45.6, 50)
      ..lineTo(20.6, 50)
      ..cubicTo(19, 50, 17.6, 49.1, 17, 47.7)
      ..close()
      ..moveTo(28.6, 35.6)
      ..lineTo(28.6, 45.4)
      ..cubicTo(28.6, 46.2, 29.5, 46.7, 30.2, 46.3)
      ..lineTo(38.2, 41.4)
      ..cubicTo(38.8, 41, 38.8, 40.1, 38.2, 39.7)
      ..lineTo(30.2, 34.8)
      ..cubicTo(29.5, 34.4, 28.6, 34.9, 28.6, 35.6)
      ..close();
    canvas.drawPath(hull, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CarinaMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.background != background;
}
