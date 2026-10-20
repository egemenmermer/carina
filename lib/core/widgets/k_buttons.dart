import 'package:flutter/material.dart';

import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_interactive.dart';

/// Visual variants of [KButton].
enum KButtonVariant {
  /// White rounded rectangle with black icon + text (iPad hero "▶ Play").
  primaryWhite,

  /// Red filled (empty-state "Add playlist", confirmations).
  accent,

  /// Dark translucent fill with white text.
  secondary,

  /// Icon above a label, no fill ("☆ Favorites", "ⓘ Info").
  ghostIconLabel,

  /// Dark red-tinted fill with red text (Remove, Delete).
  destructive,
}

/// Sizes of [KButton].
enum KButtonSize {
  /// 32 px tall, 13/600.
  small(height: 32, padding: 12, gap: 6, icon: 15, text: KText.buttonSmall),

  /// 40 px tall, 15/600.
  medium(height: 40, padding: 18, gap: 8, icon: 18, text: KText.button),

  /// 48 px tall, 17/600 (hero Play button).
  large(height: 48, padding: 26, gap: 9, icon: 21, text: KText.buttonLarge);

  const KButtonSize({
    required this.height,
    required this.padding,
    required this.gap,
    required this.icon,
    required this.text,
  });

  final double height;
  final double padding;
  final double gap;
  final double icon;
  final TextStyle text;
}

/// Carina button.
///
/// Hover brightens and scales slightly, pressing darkens, keyboard focus
/// draws an outer white ring. Disabled when [onPressed] is null.
///
/// ```dart
/// KButton.primaryWhite(label: 'Play', icon: PhosphorIconsFill.play, onPressed: play, size: KButtonSize.large)
/// KButton.ghostIconLabel(label: 'Favorites', icon: PhosphorIconsLight.star, onPressed: toggleFavorite)
/// KButton.accent(label: 'Add playlist', icon: PhosphorIconsBold.plus, onPressed: add)
/// ```
class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = KButtonVariant.secondary,
    this.size = KButtonSize.medium,
    this.focusNode,
    this.autofocus = false,
    this.expand = false,
    this.minWidth,
    this.semanticLabel,
  });

  const KButton.primaryWhite({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.size = KButtonSize.medium,
    this.focusNode,
    this.autofocus = false,
    this.expand = false,
    this.minWidth,
    this.semanticLabel,
  }) : variant = KButtonVariant.primaryWhite;

  const KButton.accent({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.size = KButtonSize.medium,
    this.focusNode,
    this.autofocus = false,
    this.expand = false,
    this.minWidth,
    this.semanticLabel,
  }) : variant = KButtonVariant.accent;

  const KButton.secondary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.size = KButtonSize.medium,
    this.focusNode,
    this.autofocus = false,
    this.expand = false,
    this.minWidth,
    this.semanticLabel,
  }) : variant = KButtonVariant.secondary;

  const KButton.ghostIconLabel({
    super.key,
    required this.label,
    required IconData this.icon,
    this.onPressed,
    this.size = KButtonSize.medium,
    this.focusNode,
    this.autofocus = false,
    this.minWidth,
    this.semanticLabel,
  }) : variant = KButtonVariant.ghostIconLabel,
       expand = false;

  const KButton.destructive({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.size = KButtonSize.medium,
    this.focusNode,
    this.autofocus = false,
    this.expand = false,
    this.minWidth,
    this.semanticLabel,
  }) : variant = KButtonVariant.destructive;

  /// Button text.
  final String label;

  /// Leading icon (or the top icon for [KButtonVariant.ghostIconLabel]).
  final IconData? icon;

  /// Activation callback; null disables the button.
  final VoidCallback? onPressed;

  final KButtonVariant variant;
  final KButtonSize size;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Stretch to the available width.
  final bool expand;

  /// Minimum width (e.g. 150 for the hero Play button).
  final double? minWidth;
  final String? semanticLabel;

  /// Text color of [KButtonVariant.destructive].
  static const destructiveForeground = Color(0xFFFF5C40);

  @override
  Widget build(BuildContext context) {
    if (variant == KButtonVariant.ghostIconLabel) {
      return _GhostIconLabelButton(
        label: label,
        icon: icon!,
        onPressed: onPressed,
        size: size,
        focusNode: focusNode,
        autofocus: autofocus,
        minWidth: minWidth,
        semanticLabel: semanticLabel,
      );
    }
    return KInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? label,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final (background, foreground, shadow) = _colors(state);
        final scale = state.pressed
            ? 0.97
            : state.highlighted
            ? 1.03
            : 1.0;
        Widget content = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: size.icon, color: foreground),
              SizedBox(width: size.gap),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: size.text.copyWith(color: foreground),
              ),
            ),
          ],
        );
        Widget box = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          height: size.height,
          width: expand ? double.infinity : null,
          constraints: BoxConstraints(minWidth: minWidth ?? 0),
          padding: EdgeInsets.symmetric(horizontal: size.padding),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(KRadii.button),
            boxShadow: shadow ? KShadows.floating : const [],
          ),
          // Factors keep the button hugging its label inside Columns
          // (Container.alignment would stretch it to the full width).
          child: Center(widthFactor: 1, heightFactor: 1, child: content),
        );
        box = KFocusRing(
          visible: state.focused,
          borderRadius: KRadii.button,
          child: box,
        );
        box = AnimatedScale(
          scale: scale,
          duration: duration,
          curve: KMotion.hover,
          child: box,
        );
        if (!state.enabled) box = Opacity(opacity: 0.4, child: box);
        return box;
      },
    );
  }

  (Color, Color, bool) _colors(KInteractionState s) {
    switch (variant) {
      case KButtonVariant.primaryWhite:
        return (
          s.pressed ? const Color(0xFFD9D9D9) : Colors.white,
          Colors.black,
          s.highlighted,
        );
      case KButtonVariant.accent:
        return (
          s.pressed
              ? KColors.accentPressed
              : s.highlighted
              ? KColors.accentHover
              : KColors.accent,
          Colors.white,
          s.highlighted,
        );
      case KButtonVariant.destructive:
        return (
          KColors.accent.withValues(
            alpha: s.pressed
                ? 0.12
                : s.highlighted
                ? 0.26
                : 0.16,
          ),
          destructiveForeground,
          false,
        );
      case KButtonVariant.secondary:
      case KButtonVariant.ghostIconLabel:
        return (
          s.pressed
              ? const Color(0x1FFFFFFF)
              : s.highlighted
              ? KColors.glassHover
              : KColors.glass,
          Colors.white,
          false,
        );
    }
  }
}

class _GhostIconLabelButton extends StatelessWidget {
  const _GhostIconLabelButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.focusNode,
    required this.autofocus,
    required this.minWidth,
    required this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final KButtonSize size;
  final FocusNode? focusNode;
  final bool autofocus;
  final double? minWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconSize = switch (size) {
      KButtonSize.small => 22.0,
      KButtonSize.medium => 28.0,
      KButtonSize.large => 32.0,
    };
    final textStyle = switch (size) {
      KButtonSize.small => KText.buttonSmall.copyWith(
        fontWeight: FontWeight.w500,
      ),
      KButtonSize.medium => KText.button.copyWith(fontWeight: FontWeight.w500),
      KButtonSize.large => KText.buttonLarge.copyWith(
        fontWeight: FontWeight.w500,
      ),
    };
    return KInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? label,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final color = state.highlighted
            ? Colors.white
            : Colors.white.withValues(alpha: 0.88);
        Widget box = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          constraints: BoxConstraints(minWidth: minWidth ?? 72),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: state.highlighted
                ? const Color(0x14FFFFFF)
                : const Color(0x00FFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: color),
              const SizedBox(height: 5),
              Text(label, style: textStyle.copyWith(color: color)),
            ],
          ),
        );
        box = KFocusRing(
          visible: state.focused,
          borderRadius: 12,
          gap: 1,
          child: box,
        );
        box = AnimatedScale(
          scale: state.pressed
              ? 0.96
              : state.highlighted
              ? 1.06
              : 1.0,
          duration: duration,
          curve: KMotion.hover,
          child: box,
        );
        if (!state.enabled) box = Opacity(opacity: 0.4, child: box);
        return box;
      },
    );
  }
}

/// Round translucent icon button (player controls, nav icons): 36 px by
/// default, white icon, optional tooltip. [selected] turns it white with a
/// black icon.
class KIconButton extends StatelessWidget {
  const KIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 36,
    this.iconSize,
    this.background,
    this.foreground = Colors.white,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
    this.focusable = true,
    this.semanticLabel,
  });

  final IconData icon;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Tooltip text (also the accessibility label). Shown only when an
  /// [Overlay] is available.
  final String? tooltip;

  /// Diameter.
  final double size;

  /// Icon size (defaults to half the diameter).
  final double? iconSize;

  /// Resting fill (translucent white by default).
  final Color? background;
  final Color foreground;
  final bool selected;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool focusable;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget button = KInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusNode: focusNode,
      autofocus: autofocus,
      focusable: focusable,
      selected: selected,
      semanticLabel: semanticLabel ?? tooltip,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final resting = background ?? KColors.glass;
        final fill = selected
            ? Colors.white
            : state.pressed
            ? resting.withValues(alpha: resting.a * 0.7)
            : state.highlighted
            ? KColors.glassHover
            : resting;
        Widget box = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          width: size,
          height: size,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize ?? size * 0.5,
            color: selected ? Colors.black : foreground,
          ),
        );
        box = KFocusRing(visible: state.focused, circle: true, child: box);
        box = AnimatedScale(
          scale: state.pressed
              ? 0.94
              : state.highlighted
              ? 1.06
              : 1.0,
          duration: duration,
          curve: KMotion.hover,
          child: box,
        );
        if (!state.enabled) box = Opacity(opacity: 0.4, child: box);
        return box;
      },
    );
    final message = tooltip;
    if (message != null && Overlay.maybeOf(context) != null) {
      button = Tooltip(
        message: message,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return button;
  }
}

/// Text link in accent red ("See All"): underline on hover, ring on focus.
class KLink extends StatelessWidget {
  const KLink({
    super.key,
    required this.label,
    required this.onTap,
    this.style = KText.seeAll,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onTap;
  final TextStyle style;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      enabled: onTap != null,
      focusNode: focusNode,
      semanticLabel: label,
      builder: (context, state, _) {
        final color = state.pressed
            ? KColors.accentPressed
            : state.highlighted
            ? KColors.accentHover
            : (style.color ?? KColors.accent);
        return KFocusRing(
          visible: state.focused,
          borderRadius: 4,
          gap: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              label,
              style: style.copyWith(
                color: color,
                decoration: state.hovered
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: color,
                decorationThickness: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
