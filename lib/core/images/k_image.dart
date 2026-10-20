import 'package:flutter/widgets.dart';

import 'package:carina/core/images/k_network_image.dart';
import 'package:carina/core/tokens.dart';

/// Remote image with a placeholder, a 200 ms fade-in and an error fallback.
///
/// Decodes at the laid-out width × device pixel ratio (rounded up to a
/// multiple of 64 px) through [ResizeImage] over [KNetworkImage]. Give it a
/// size: tight constraints (inside a sized card / AspectRatio) or
/// [width]/[height]. A null or empty [url] shows the fallback directly.
class KImage extends StatelessWidget {
  const KImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorBuilder,
    this.headers,
    this.fadeDuration = KDurations.imageFade,
    this.decodeWidth,
    this.imagePadding,
    this.imageBackground,
    this.semanticLabel,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// Shown while loading (defaults to a surface2 box).
  final Widget? placeholder;

  /// Shown when the image fails or [url] is empty (defaults to
  /// [placeholder]).
  final WidgetBuilder? errorBuilder;
  final Map<String, String>? headers;
  final Duration fadeDuration;

  /// Explicit decode width in physical pixels.
  final int? decodeWidth;

  /// Padding around the loaded image only (logo tiles).
  final EdgeInsetsGeometry? imagePadding;

  /// Background behind the loaded image only (logo tiles).
  final Color? imageBackground;
  final String? semanticLabel;

  static int _bucket(double pixels) =>
      ((pixels / 64).ceil() * 64).clamp(64, 4096).toInt();

  Widget _placeholder() =>
      placeholder ??
      Container(width: width, height: height, color: KColors.surface2);

  Widget _fallback(BuildContext context) =>
      errorBuilder?.call(context) ?? _placeholder();

  @override
  Widget build(BuildContext context) {
    final u = url;
    Widget result;
    if (u == null || u.trim().isEmpty) {
      result = _fallback(context);
    } else {
      result = LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
          final logicalWidth =
              width ??
              (constraints.hasBoundedWidth ? constraints.maxWidth : null);
          final cacheWidth =
              decodeWidth ??
              (logicalWidth != null && logicalWidth > 0
                  ? _bucket(logicalWidth * dpr)
                  : null);
          final provider = ResizeImage.resizeIfNeeded(
            cacheWidth,
            null,
            KNetworkImage(u, headers: headers),
          );
          final fade = KMotion.of(context, fadeDuration);
          return Image(
            image: provider,
            fit: fit,
            alignment: alignment,
            width: width,
            height: height,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            semanticLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
            frameBuilder: (context, child, frame, wasSync) {
              Widget image = child;
              if (imagePadding != null || imageBackground != null) {
                image = Container(
                  color: imageBackground,
                  padding: imagePadding,
                  child: image,
                );
              }
              if (wasSync) return image;
              return Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(child: _placeholder()),
                  AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: fade,
                    curve: Curves.easeOut,
                    child: image,
                  ),
                ],
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Drop the failed entry so a later rebuild may retry (the
              // loader's failure cache rate-limits retries).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                provider.evict();
              });
              return _fallback(context);
            },
          );
        },
      );
    }
    final radius = borderRadius;
    if (radius != null) {
      result = ClipRRect(borderRadius: radius, child: result);
    }
    return result;
  }
}
