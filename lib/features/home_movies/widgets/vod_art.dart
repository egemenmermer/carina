import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Artwork of a movie or show with graceful fallbacks, so cards and heroes
/// look finished without TMDb and when images fail:
///
/// * [url] (poster, backdrop or episode still) when it loads;
/// * otherwise [blurUrl] (usually the poster) scaled to fill and blurred,
///   for wide slots without a backdrop;
/// * otherwise a [VodTextPoster] with the [title].
class VodArt extends StatelessWidget {
  const VodArt({
    super.key,
    required this.url,
    required this.title,
    this.blurUrl,
    this.year,
    this.alignment = Alignment.center,
    this.wide = false,
  });

  final String? url;
  final String title;
  final String? blurUrl;
  final int? year;
  final Alignment alignment;

  /// Wide (16:9) slot: the text fallback uses a horizontal layout.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context) {
      final blur = blurUrl;
      if (blur != null && blur != url) {
        return VodBlurredArt(
          url: blur,
          fallback: VodTextPoster(title: title, year: year, wide: wide),
        );
      }
      return VodTextPoster(title: title, year: year, wide: wide);
    }

    if (url == null || url!.trim().isEmpty) return fallback(context);
    return KImage(
      url,
      alignment: alignment,
      placeholder: const ColoredBox(color: KColors.surface2),
      errorBuilder: fallback,
    );
  }
}

/// A poster (or any artwork) scaled to cover the slot and blurred: the
/// hero and wide-card fallback when there is no backdrop.
class VodBlurredArt extends StatelessWidget {
  const VodBlurredArt({
    super.key,
    required this.url,
    this.sigma = 22,
    this.dim = 0.25,
    this.fallback,
  });

  final String url;
  final double sigma;

  /// Black overlay opacity on top of the blurred image.
  final double dim;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Transform.scale(
              scale: 1.15,
              child: KImage(
                url,
                decodeWidth: 256,
                placeholder: const ColoredBox(color: KColors.surface2),
                errorBuilder: fallback == null ? null : (_) => fallback!,
              ),
            ),
          ),
        ),
        if (dim > 0) ColoredBox(color: Colors.black.withValues(alpha: dim)),
      ],
    );
  }
}

/// Generated "text poster": a deterministic dark gradient with the title,
/// for items without artwork.
class VodTextPoster extends StatelessWidget {
  const VodTextPoster({
    super.key,
    required this.title,
    this.year,
    this.wide = false,
  });

  final String title;
  final int? year;
  final bool wide;

  static const List<List<Color>> _palettes = [
    [Color(0xFF3A1622), Color(0xFF120709)],
    [Color(0xFF16313D), Color(0xFF070F14)],
    [Color(0xFF1F3324), Color(0xFF09110B)],
    [Color(0xFF2E2140), Color(0xFF0E0A15)],
    [Color(0xFF3D2F16), Color(0xFF130E06)],
    [Color(0xFF163A36), Color(0xFF061210)],
    [Color(0xFF3D1C16), Color(0xFF140807)],
    [Color(0xFF222842), Color(0xFF0A0C16)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[KMonogram.stableHash(title) % _palettes.length];
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 160.0;
        final fontSize = (wide ? w * 0.075 : w * 0.12).clamp(12.0, 26.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.4, -0.7),
                    radius: 1.1,
                    colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: wide ? 2 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: KText.heroTitle.copyWith(
                          fontSize: fontSize,
                          letterSpacing: -0.02 * fontSize,
                          height: 1.1,
                          color: const Color(0xF2FFFFFF),
                        ),
                      ),
                      if (year != null) ...[
                        SizedBox(height: fontSize * 0.45),
                        Text(
                          '$year',
                          style: KText.caption.copyWith(
                            fontSize: (fontSize * 0.62).clamp(11.0, 15.0),
                            color: const Color(0x99FFFFFF),
                            fontFeatures: KText.tabular,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// White ring with a play triangle (cards, sheet backdrops, episodes).
class VodPlayRing extends StatelessWidget {
  const VodPlayRing({super.key, this.size = 46, this.highlighted = false});

  final double size;

  /// Filled white with a black triangle (hover / focus).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final stroke = (size * 0.055).clamp(2.0, 4.5);
    return AnimatedContainer(
      duration: KMotion.of(context, KDurations.hover),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? Colors.white : const Color(0x59000000),
        border: Border.all(color: Colors.white, width: stroke),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(left: size * 0.06),
        child: Icon(
          PhosphorIconsFill.play,
          size: size * 0.42,
          color: highlighted ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

/// Small "watched" badge for cards: a red eye on a dark disc.
class VodWatchedBadge extends StatelessWidget {
  const VodWatchedBadge({super.key, this.size = 24, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xCC000000),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          PhosphorIconsFill.eye,
          size: size * 0.62,
          color: KColors.accent,
        ),
      ),
    );
  }
}
