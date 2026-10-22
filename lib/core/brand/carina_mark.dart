import 'package:flutter/widgets.dart';

/// The Carina mark: a sailing hull with its wake line under a four-point star
/// (Canopus, the brightest star of the Carina constellation). Geometry is on a
/// 64×64 grid, traced from the master artwork `tools/icons/source.png` (see
/// tools/icons/README.md); the app icon generator uses the same painter.
class CarinaMark extends StatelessWidget {
  const CarinaMark({super.key, this.size = 40, this.color, this.tile = false});

  final double size;

  /// Solid fill. When null the mark uses the brand gradient.
  final Color? color;

  /// Paints the navy rounded-square tile behind the mark (app icon look).
  final bool tile;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CarinaMarkPainter(color: color, tile: tile),
      ),
    );
  }
}

class CarinaMarkPainter extends CustomPainter {
  const CarinaMarkPainter({this.color, this.tile = false});

  final Color? color;
  final bool tile;

  /// Tile gradient, top-right (lit corner) to bottom-left.
  static const tileColors = [
    Color(0xFF3A5598),
    Color(0xFF0F1F49),
    Color(0xFF030820),
  ];

  /// Tile corner radius on the 64 grid.
  static const tileRadius = 22.5;

  /// Mark gradient, top to bottom: pale blue star, white sail, blue keel.
  static const markColors = [
    Color(0xFFD3E3F9),
    Color(0xFFF2F5FB),
    Color(0xFF86AEEE),
  ];

  /// Bounds of the mark on the 64 grid (star top to keel bottom).
  static const markBounds = Rect.fromLTRB(6.87, 12.9, 57.73, 54.13);

  static final Path _star = Path()
    ..moveTo(27.64, 12.97)
    ..cubicTo(27.57, 13.03, 27.56, 13.05, 27.41, 13.78)
    ..cubicTo(27.34, 14.13, 27.25, 14.56, 27.21, 14.73)
    ..cubicTo(27.17, 14.9, 27.12, 15.16, 27.09, 15.3)
    ..cubicTo(27.01, 15.66, 26.68, 16.95, 26.5, 17.57)
    ..cubicTo(25.93, 19.5, 25.76, 19.73, 24.53, 20.19)
    ..cubicTo(23.79, 20.47, 21.44, 21.18, 20.26, 21.47)
    ..cubicTo(19.85, 21.57, 19.77, 21.61, 19.72, 21.69)
    ..cubicTo(19.63, 21.87, 19.75, 21.94, 20.31, 22.05)
    ..cubicTo(20.7, 22.13, 20.87, 22.17, 21.33, 22.28)
    ..cubicTo(21.53, 22.33, 21.81, 22.4, 21.95, 22.43)
    ..cubicTo(22.88, 22.62, 24.35, 23.03, 24.83, 23.21)
    ..cubicTo(25.45, 23.45, 25.78, 23.75, 26.02, 24.29)
    ..cubicTo(26.13, 24.55, 26.5, 25.58, 26.59, 25.88)
    ..cubicTo(26.75, 26.45, 27.28, 28.62, 27.38, 29.11)
    ..cubicTo(27.57, 30.09, 27.62, 30.28, 27.7, 30.33)
    ..cubicTo(27.83, 30.39, 27.86, 30.31, 27.99, 29.67)
    ..cubicTo(28.05, 29.38, 28.13, 29.02, 28.17, 28.86)
    ..cubicTo(28.2, 28.71, 28.26, 28.43, 28.3, 28.26)
    ..cubicTo(28.64, 26.61, 29.15, 24.92, 29.51, 24.18)
    ..cubicTo(29.92, 23.33, 30.42, 23.13, 34.41, 22.21)
    ..cubicTo(34.61, 22.17, 34.92, 22.1, 35.11, 22.06)
    ..cubicTo(35.64, 21.95, 35.75, 21.9, 35.75, 21.76)
    ..cubicTo(35.75, 21.64, 35.69, 21.6, 35.2, 21.47)
    ..cubicTo(34.99, 21.41, 34.58, 21.3, 34.3, 21.22)
    ..cubicTo(33.7, 21.06, 33.13, 20.89, 32.77, 20.78)
    ..cubicTo(32.63, 20.74, 32.33, 20.65, 32.1, 20.58)
    ..cubicTo(30.16, 20.01, 29.74, 19.73, 29.38, 18.75)
    ..cubicTo(28.95, 17.63, 28.52, 16.02, 28.18, 14.3)
    ..cubicTo(28.02, 13.49, 27.93, 13.09, 27.89, 13.03)
    ..cubicTo(27.82, 12.93, 27.73, 12.9, 27.64, 12.97)
    ..close();

  static final Path _hull = Path()
    ..moveTo(57.29, 22.18)
    ..cubicTo(57.2, 22.2, 56.96, 22.37, 56.63, 22.63)
    ..cubicTo(55.3, 23.67, 52.35, 25.62, 50.46, 26.72)
    ..cubicTo(50.24, 26.84, 50.01, 26.98, 49.93, 27.03)
    ..cubicTo(49.85, 27.07, 49.61, 27.21, 49.4, 27.33)
    ..cubicTo(49.19, 27.44, 48.89, 27.61, 48.73, 27.7)
    ..cubicTo(47.75, 28.26, 45.86, 29.25, 44.79, 29.77)
    ..cubicTo(43.6, 30.35, 43.09, 30.59, 42.82, 30.71)
    ..cubicTo(42.66, 30.78, 42.39, 30.89, 42.23, 30.97)
    ..cubicTo(42.06, 31.05, 41.8, 31.17, 41.65, 31.24)
    ..cubicTo(41.27, 31.41, 40.52, 31.74, 40.07, 31.92)
    ..cubicTo(39.85, 32.01, 39.54, 32.14, 39.36, 32.21)
    ..cubicTo(39.05, 32.35, 38.68, 32.49, 37.72, 32.86)
    ..cubicTo(36.72, 33.25, 36.8, 33.22, 34.4, 34.09)
    ..cubicTo(33.72, 34.33, 32.87, 34.61, 30.84, 35.25)
    ..cubicTo(29.19, 35.77, 28.97, 35.83, 28.12, 36.07)
    ..cubicTo(27.81, 36.15, 27.43, 36.26, 27.28, 36.3)
    ..cubicTo(26.58, 36.5, 25.91, 36.68, 25.68, 36.74)
    ..cubicTo(25.55, 36.78, 25.21, 36.87, 24.94, 36.94)
    ..cubicTo(23.74, 37.28, 19.16, 38.4, 17.81, 38.69)
    ..cubicTo(17.47, 38.76, 16.94, 38.88, 16.62, 38.95)
    ..cubicTo(15.56, 39.19, 14.97, 39.32, 14.2, 39.49)
    ..cubicTo(13.79, 39.58, 13.26, 39.69, 13.03, 39.74)
    ..cubicTo(12.4, 39.87, 11.76, 40.01, 10.56, 40.25)
    ..cubicTo(9.96, 40.38, 9.4, 40.49, 9.32, 40.51)
    ..cubicTo(9.24, 40.53, 8.94, 40.6, 8.66, 40.65)
    ..cubicTo(8.18, 40.75, 7.47, 40.9, 7.16, 40.97)
    ..cubicTo(6.98, 41.01, 6.87, 41.05, 6.89, 41.08)
    ..cubicTo(6.91, 41.11, 7.15, 41.1, 7.52, 41.04)
    ..cubicTo(7.77, 41, 8.07, 40.96, 9.78, 40.75)
    ..cubicTo(10.9, 40.61, 11.98, 40.46, 13.28, 40.28)
    ..cubicTo(13.47, 40.25, 13.99, 40.18, 14.44, 40.12)
    ..cubicTo(15.56, 39.97, 17.47, 39.69, 17.67, 39.66)
    ..cubicTo(17.77, 39.64, 18.07, 39.59, 18.35, 39.56)
    ..cubicTo(18.85, 39.48, 19.08, 39.45, 20.63, 39.19)
    ..cubicTo(22.67, 38.86, 23.23, 38.76, 24.87, 38.46)
    ..cubicTo(25.87, 38.27, 28.5, 37.73, 29.33, 37.55)
    ..cubicTo(31.61, 37.03, 33.22, 36.63, 34.95, 36.14)
    ..cubicTo(35.18, 36.07, 35.49, 35.99, 35.62, 35.95)
    ..cubicTo(36.08, 35.82, 36.63, 35.65, 37.46, 35.38)
    ..cubicTo(37.91, 35.23, 38.41, 35.07, 38.57, 35.02)
    ..cubicTo(40.06, 34.55, 42.98, 33.42, 44.41, 32.76)
    ..cubicTo(44.57, 32.68, 44.85, 32.56, 45.03, 32.48)
    ..cubicTo(45.22, 32.4, 45.75, 32.15, 46.22, 31.92)
    ..cubicTo(46.7, 31.68, 47.16, 31.46, 47.25, 31.41)
    ..cubicTo(47.34, 31.37, 47.64, 31.21, 47.91, 31.06)
    ..cubicTo(48.19, 30.91, 48.58, 30.69, 48.78, 30.58)
    ..cubicTo(49.11, 30.41, 49.34, 30.27, 50.21, 29.76)
    ..cubicTo(50.75, 29.45, 50.8, 29.42, 50.8, 29.48)
    ..cubicTo(50.8, 29.55, 50.21, 30.18, 49.48, 30.88)
    ..cubicTo(47.6, 32.69, 45.12, 34.49, 42.36, 36.06)
    ..cubicTo(41.13, 36.76, 39.9, 37.37, 38.07, 38.21)
    ..cubicTo(37.27, 38.58, 35.21, 39.43, 34.54, 39.67)
    ..cubicTo(34.4, 39.72, 33.97, 39.88, 33.57, 40.03)
    ..cubicTo(32.21, 40.52, 29.85, 41.29, 28.63, 41.62)
    ..cubicTo(28.5, 41.66, 28.28, 41.72, 28.14, 41.77)
    ..cubicTo(27.9, 41.84, 27.62, 41.91, 26.48, 42.21)
    ..cubicTo(24.09, 42.84, 20.59, 43.63, 18.92, 43.92)
    ..cubicTo(18.51, 43.98, 18.14, 44.05, 17.83, 44.12)
    ..cubicTo(17.68, 44.14, 17.34, 44.2, 17.07, 44.25)
    ..cubicTo(16.8, 44.29, 16.33, 44.37, 16.03, 44.42)
    ..cubicTo(15.73, 44.47, 15.29, 44.54, 15.04, 44.57)
    ..cubicTo(14.8, 44.6, 14.38, 44.67, 14.12, 44.71)
    ..cubicTo(13.86, 44.75, 13.53, 44.8, 13.39, 44.82)
    ..cubicTo(13.24, 44.84, 12.92, 44.89, 12.66, 44.92)
    ..cubicTo(12.41, 44.96, 11.97, 45.02, 11.69, 45.05)
    ..cubicTo(10.58, 45.19, 10.47, 45.21, 10.37, 45.33)
    ..cubicTo(10.23, 45.49, 10.28, 45.56, 11.01, 46.24)
    ..cubicTo(11.71, 46.89, 11.83, 47, 12.05, 47.17)
    ..cubicTo(12.15, 47.25, 12.38, 47.44, 12.55, 47.59)
    ..cubicTo(14.31, 49.05, 16.89, 50.66, 18.91, 51.56)
    ..cubicTo(19.05, 51.62, 19.23, 51.7, 19.32, 51.74)
    ..cubicTo(19.41, 51.78, 19.6, 51.87, 19.74, 51.92)
    ..cubicTo(19.89, 51.98, 20.11, 52.07, 20.24, 52.13)
    ..cubicTo(21.68, 52.72, 23.75, 53.31, 25.5, 53.63)
    ..cubicTo(26.08, 53.73, 27.17, 53.89, 27.58, 53.93)
    ..cubicTo(27.96, 53.97, 28.7, 54.03, 29.06, 54.06)
    ..cubicTo(30.12, 54.13, 32.19, 54.08, 33.48, 53.93)
    ..cubicTo(39.02, 53.31, 43.9, 50.81, 47.84, 46.57)
    ..cubicTo(48.64, 45.71, 48.76, 45.58, 49.37, 44.81)
    ..cubicTo(50.15, 43.84, 50.92, 42.76, 51.53, 41.78)
    ..cubicTo(53.83, 38.1, 55.49, 34.15, 56.61, 29.74)
    ..cubicTo(56.97, 28.31, 57.29, 26.58, 57.5, 24.97)
    ..cubicTo(57.61, 24.18, 57.73, 22.69, 57.7, 22.52)
    ..cubicTo(57.67, 22.25, 57.5, 22.11, 57.29, 22.18)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 64;
    canvas.save();
    canvas.scale(s);
    if (tile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 64, 64),
          const Radius.circular(tileRadius),
        ),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: tileColors,
          ).createShader(const Rect.fromLTWH(0, 0, 64, 64)),
      );
    }
    final paint = Paint()..isAntiAlias = true;
    if (color != null) {
      paint.color = color!;
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: markColors,
        stops: [0, 0.55, 1],
      ).createShader(markBounds);
    }
    canvas
      ..drawPath(_star, paint)
      ..drawPath(_hull, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(CarinaMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tile != tile;
}
