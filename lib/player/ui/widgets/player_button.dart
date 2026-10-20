import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Round translucent button of the player bars. Clicking does not move
/// keyboard focus (so Space keeps toggling playback); Tab still reaches it.
/// [active] (its menu is open) turns it white with a black icon, like the
/// focused button in.
class PlayerIconButton extends StatelessWidget {
  const PlayerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.size = 40,
    this.iconSize = 20,
    this.background = KColors.glass,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final double iconSize;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget button = KInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusOnTap: false,
      selected: active,
      semanticLabel: tooltip,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final fill = active
            ? Colors.white
            : state.pressed
            ? const Color(0x1FFFFFFF)
            : state.highlighted
            ? KColors.glassHover
            : background;
        Widget box = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          width: size,
          height: size,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize,
            color: active ? Colors.black : Colors.white,
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
    if (Overlay.maybeOf(context) != null) {
      button = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }
    return button;
  }
}

/// White (primary) or translucent pill button used inside player panels
/// ("From the beginning", "Next episode", "Retry").
class PlayerPillButton extends StatelessWidget {
  const PlayerPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.autofocus = false,
    this.focusNode,
    this.minWidth = 0,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool autofocus;
  final FocusNode? focusNode;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      autofocus: autofocus,
      focusNode: focusNode,
      semanticLabel: label,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        // the focused / hovered pill is white with black text.
        final white = primary || state.highlighted;
        final fg = white ? Colors.black : Colors.white;
        final bg = white
            ? (state.pressed ? const Color(0xFFD9D9D9) : Colors.white)
            : (state.pressed ? const Color(0x1FFFFFFF) : KColors.glass);
        Widget box = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          height: 42,
          constraints: BoxConstraints(minWidth: minWidth),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: bg, borderRadius: KRadii.pillBorder),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KText.button.copyWith(color: fg),
              ),
            ],
          ),
        );
        box = KFocusRing(visible: state.focused, borderRadius: 21, child: box);
        box = AnimatedScale(
          scale: state.pressed
              ? 0.97
              : state.highlighted
              ? 1.03
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

/// Gives the widget built by [builder] keyboard focus once it is shown,
/// even when another node of the scope already has focus (where
/// `autofocus` does nothing).
class FocusOnMount extends StatefulWidget {
  const FocusOnMount({super.key, required this.builder});

  final Widget Function(BuildContext context, FocusNode node) builder;

  @override
  State<FocusOnMount> createState() => _FocusOnMountState();
}

class _FocusOnMountState extends State<FocusOnMount> {
  final FocusNode _node = FocusNode(debugLabel: 'focus on mount');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node.requestFocus();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _node);
}
