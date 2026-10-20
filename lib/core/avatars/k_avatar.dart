import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:carina/core/avatars/avatar_catalog.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_logo_tile.dart';

/// A playlist avatar: gradient circle + glyph, [size] px wide.
///
/// [id] is an [AvatarCatalog] id. Initials avatars (and unknown or null
/// ids) draw the initials of [fallbackName]; without a name they show "?".
///
/// ```dart
/// KAvatar(playlist.avatarId, 140, fallbackName: playlist.name)
/// ```
class KAvatar extends StatelessWidget {
  const KAvatar(this.id, this.size, {super.key, this.fallbackName});

  final String? id;
  final double size;
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    final spec =
        AvatarCatalog.byId(id) ?? AvatarCatalog.initialsFor(fallbackName ?? '');
    Widget glyph;
    if (spec.emoji != null) {
      glyph = Text(
        spec.emoji!,
        textAlign: TextAlign.center,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(
          fontFamily: KText.family,
          fontFamilyFallback: KText.emojiFallback,
          fontSize: size * 0.5,
          height: 1.0,
          shadows: [
            Shadow(
              color: const Color(0x40000000),
              blurRadius: size * 0.05,
              offset: Offset(0, size * 0.02),
            ),
          ],
        ),
      );
      // Color emoji glyphs sit high in their line box; nudge them to the
      // optical center of the circle.
      glyph = Transform.translate(offset: Offset(0, size * 0.05), child: glyph);
    } else if (spec.shape != null) {
      glyph = CustomPaint(
        size: Size.square(size * 0.56),
        painter: _ShapePainter(spec.shape!),
      );
    } else {
      final initials = KMonogram.initialsOf(fallbackName ?? '');
      glyph = Text(
        initials,
        maxLines: 1,
        style: TextStyle(
          fontFamily: KText.family,
          fontSize: size * (initials.length > 1 ? 0.38 : 0.46),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.025 * size,
          height: 1.0,
          color: const Color(0xFFFFFFFF),
          shadows: [
            Shadow(
              color: const Color(0x33000000),
              blurRadius: size * 0.04,
              offset: Offset(0, size * 0.015),
            ),
          ],
        ),
      );
    }
    return Semantics(
      image: true,
      label: spec.usesInitials ? (fallbackName ?? spec.name) : spec.name,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: spec.gradient,
            ),
          ),
          child: DecoratedBox(
            // Soft top-left sheen for depth.
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.45, -0.55),
                radius: 0.9,
                colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
            child: Center(child: glyph),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape);

  final AvatarShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final fill = Paint()..color = const Color(0xF2FFFFFF);
    final soft = Paint()..color = const Color(0x8CFFFFFF);
    Paint stroke(double w, [Color color = const Color(0xF2FFFFFF)]) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case AvatarShape.rings:
        canvas.drawCircle(c, s * 0.46, stroke(s * 0.07));
        canvas.drawCircle(
          c,
          s * 0.29,
          stroke(s * 0.07, const Color(0xB3FFFFFF)),
        );
        canvas.drawCircle(c, s * 0.12, fill);
      case AvatarShape.triangles:
        final back = Path()
          ..moveTo(c.dx - s * 0.12, c.dy - s * 0.42)
          ..lineTo(c.dx + s * 0.40, c.dy + s * 0.34)
          ..lineTo(c.dx - s * 0.48, c.dy + s * 0.34)
          ..close();
        canvas.drawPath(back, soft);
        final front = Path()
          ..moveTo(c.dx + s * 0.14, c.dy - s * 0.30)
          ..lineTo(c.dx + s * 0.48, c.dy + s * 0.40)
          ..lineTo(c.dx - s * 0.20, c.dy + s * 0.40)
          ..close();
        canvas.drawPath(front, fill);
      case AvatarShape.waves:
        for (var i = 0; i < 3; i++) {
          final y = c.dy - s * 0.26 + i * s * 0.26;
          final path = Path()..moveTo(c.dx - s * 0.46, y);
          for (var x = -0.46; x <= 0.46; x += 0.02) {
            path.lineTo(
              c.dx + x * s,
              y + math.sin((x + 0.46) * math.pi * 2.2) * s * 0.07,
            );
          }
          canvas.drawPath(
            path,
            stroke(
              s * 0.075,
              i == 1 ? const Color(0xF2FFFFFF) : const Color(0x99FFFFFF),
            ),
          );
        }
      case AvatarShape.dots:
        for (var row = -1; row <= 1; row++) {
          for (var col = -1; col <= 1; col++) {
            final big = (row + col).isEven;
            canvas.drawCircle(
              c + Offset(col * s * 0.33, row * s * 0.33),
              s * (big ? 0.11 : 0.075),
              big ? fill : soft,
            );
          }
        }
      case AvatarShape.diamond:
        Path diamond(double r) => Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
        canvas.drawPath(diamond(s * 0.48), stroke(s * 0.07));
        canvas.drawPath(diamond(s * 0.24), fill);
      case AvatarShape.crescent:
        final moon = Path()
          ..addOval(Rect.fromCircle(center: c, radius: s * 0.42));
        final bite = Path()
          ..addOval(
            Rect.fromCircle(
              center: c + Offset(s * 0.2, -s * 0.12),
              radius: s * 0.36,
            ),
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, moon, bite),
          fill,
        );
        canvas.drawCircle(c + Offset(s * 0.32, s * 0.26), s * 0.06, soft);
      case AvatarShape.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? s * 0.5 : s * 0.22;
          final a = -math.pi / 2 + i * math.pi / 5;
          final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, fill);
      case AvatarShape.stripes:
        canvas.save();
        canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.48)),
        );
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-math.pi / 4);
        for (var i = -3; i <= 3; i++) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(i * s * 0.16, 0),
              width: s * 0.07,
              height: s * 1.2,
            ),
            i.isEven ? fill : soft,
          );
        }
        canvas.restore();
      case AvatarShape.hexagon:
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * math.pi / 3;
          final p = c + Offset(math.cos(a) * s * 0.46, math.sin(a) * s * 0.46);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, stroke(s * 0.075));
        canvas.drawCircle(c, s * 0.14, fill);
      case AvatarShape.orbit:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: s * 0.98, height: s * 0.42),
          stroke(s * 0.05, const Color(0xB3FFFFFF)),
        );
        canvas.drawCircle(c, s * 0.2, fill);
        canvas.drawCircle(c + Offset(s * 0.42, -s * 0.12), s * 0.07, fill);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) => oldDelegate.shape != shape;
}
