import 'package:flutter/widgets.dart';

import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_interactive.dart';
import 'package:carina/core/widgets/k_tv.dart';

/// Width of the white focus border.
enum KFocusRingWidth {
  /// 2 px — mouse hover and desktop focus.
  desktop(2),

  /// 3 px — tvOS-style keyboard focus (selected channel card).
  tv(3);

  const KFocusRingWidth(this.pixels);

  /// Border width in logical pixels.
  final double pixels;
}

/// tvOS-style focus treatment for any card-like child.
///
/// On hover or keyboard focus the child scales to [scale] (1.04, 120 ms
/// ease-out), gets a white border ([ringWidth]) and a soft shadow. Enter /
/// Space call [onTap]; right-click and long-press call [onContextMenu] with
/// the pointer position; the Menu key and Shift+F10 call it with the
/// widget's center. [selected] keeps the white border without scaling (the
/// "current channel" look). Disabled children are dimmed and inert.
///
/// The child should paint its own background and clip its content to
/// [borderRadius]; [FocusableCard] does that for the common case.
class KFocusable extends StatelessWidget {
  const KFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onContextMenu,
    this.onFocusChange,
    this.onHoverChange,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.selected = false,
    this.borderRadius = KRadii.card,
    this.scale = 1.04,
    this.ringWidth = KFocusRingWidth.desktop,
    this.showShadow = true,
    this.semanticLabel,
  });

  /// The card content.
  final Widget child;

  /// Primary activation (click, Enter, Space).
  final VoidCallback? onTap;

  /// Optional double-click handler (delays single taps; use sparingly).
  final VoidCallback? onDoubleTap;

  /// Context menu request (right-click, long-press, Menu key, Shift+F10).
  final KContextMenuCallback? onContextMenu;

  /// Keyboard focus entered or left the card (drive previews/hero updates).
  final ValueChanged<bool>? onFocusChange;

  /// Mouse hover entered or left the card.
  final ValueChanged<bool>? onHoverChange;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Request focus when first built.
  final bool autofocus;

  /// When false the card is dimmed and ignores input.
  final bool enabled;

  /// Keep the white border (without scaling) to mark the current item.
  final bool selected;

  /// Corner radius of the child.
  final double borderRadius;

  /// Scale while hovered or focused.
  final double scale;

  /// Border width while hovered/focused/selected ([KFocusRingWidth.tv] at
  /// least under [KTvMode]).
  final KFocusRingWidth ringWidth;

  /// Whether to add the soft shadow while highlighted.
  final bool showShadow;

  /// Accessibility label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onContextMenu: onContextMenu,
      onFocusChange: onFocusChange,
      onHoverChange: onHoverChange,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      selected: selected,
      semanticLabel: semanticLabel,
      child: child,
      builder: (context, state, child) {
        final duration = KMotion.of(context, KDurations.hover);
        final active = state.highlighted;
        final bordered = active || selected;
        final targetScale = active
            ? (state.pressed ? 1 + (scale - 1) / 2 : scale)
            : (state.pressed ? 0.98 : 1.0);
        final radius = BorderRadius.circular(borderRadius);
        final ring = KTvMode.of(context) ? KFocusRingWidth.tv : ringWidth;
        Widget card = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: active && showShadow ? KShadows.focus : const [],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: bordered ? KColors.focusRing : const Color(0x00F5F5F5),
              width: ring.pixels,
            ),
          ),
          child: child,
        );
        card = AnimatedScale(
          scale: targetScale,
          duration: duration,
          curve: KMotion.hover,
          child: card,
        );
        if (!enabled) card = Opacity(opacity: 0.4, child: card);
        return card;
      },
    );
  }
}

/// A [KFocusable] card with the standard surface: [color] fill, 1 px stroke,
/// [borderRadius] corners and clipped content.
///
/// ```dart
/// FocusableCard(
///   onTap: () => preview(channel),
///   onContextMenu: (pos) => openChannelMenu(pos),
///   padding: const EdgeInsets.all(14),
///   child: ChannelCardContent(channel),
/// )
/// ```
class FocusableCard extends StatelessWidget {
  const FocusableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onContextMenu,
    this.onFocusChange,
    this.onHoverChange,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.selected = false,
    this.color = KColors.surface1,
    this.borderRadius = KRadii.card,
    this.padding,
    this.width,
    this.height,
    this.showStroke = true,
    this.scale = 1.04,
    this.ringWidth = KFocusRingWidth.desktop,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final KContextMenuCallback? onContextMenu;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool selected;

  /// Card fill (surface1 by default).
  final Color color;

  /// Corner radius (card 10 by default; use [KRadii.poster] for posters).
  final double borderRadius;

  /// Inner padding.
  final EdgeInsetsGeometry? padding;

  /// Optional fixed size.
  final double? width;
  final double? height;

  /// Draw the 1 px [KColors.stroke] border.
  final bool showStroke;
  final double scale;
  final KFocusRingWidth ringWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return KFocusable(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onContextMenu: onContextMenu,
      onFocusChange: onFocusChange,
      onHoverChange: onHoverChange,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      selected: selected,
      borderRadius: borderRadius,
      scale: scale,
      ringWidth: ringWidth,
      semanticLabel: semanticLabel,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: showStroke ? Border.all(color: KColors.stroke) : null,
        ),
        clipBehavior: Clip.antiAlias,
        padding: padding,
        child: child,
      ),
    );
  }
}
