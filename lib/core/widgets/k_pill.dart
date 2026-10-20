import 'package:flutter/material.dart';

import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_interactive.dart';

/// Rounded pill: filter chips, category items, the floating category pill.
///
/// * selected → white fill, black text;
/// * unselected → translucent dark fill, white text;
/// * [outlined] → dark fill with a light 1.5 px outline (the floating
///   "🇹🇷 Ulusal" pill above the TV Live grid).
///
/// [leading] typically holds a flag emoji or an icon; [trailing] a count.
class KPill extends StatelessWidget {
  const KPill({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.outlined = false,
    this.leading,
    this.trailing,
    this.large = false,
    this.focusNode,
    this.autofocus = false,
    this.onContextMenu,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool outlined;

  /// Leading widget (flag emoji text, icon).
  final Widget? leading;

  /// Trailing text, e.g. an item count.
  final String? trailing;

  /// 44 px tall with 17 pt text instead of 36 px / 15 pt.
  final bool large;
  final FocusNode? focusNode;
  final bool autofocus;
  final KContextMenuCallback? onContextMenu;

  @override
  Widget build(BuildContext context) {
    final height = large ? 44.0 : 36.0;
    final base = large ? KText.nav : KText.button;
    return KInteractive(
      onTap: onTap,
      onContextMenu: onContextMenu,
      enabled: onTap != null || onContextMenu != null,
      selected: selected,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: label,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final Color fill;
        final Color fg;
        if (selected) {
          fill = state.pressed ? const Color(0xFFDDDDDD) : Colors.white;
          fg = Colors.black;
        } else if (outlined) {
          fill = state.highlighted
              ? const Color(0xE6202022)
              : const Color(0xD9121214);
          fg = Colors.white;
        } else {
          fill = state.pressed
              ? const Color(0x14FFFFFF)
              : state.highlighted
              ? const Color(0x2EFFFFFF)
              : const Color(0x1AFFFFFF);
          fg = Colors.white;
        }
        Widget pill = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: large ? 20 : 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: KRadii.pillBorder,
            border: outlined && !selected
                ? Border.all(
                    color: state.highlighted
                        ? Colors.white
                        : const Color(0xFFCFCFD3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                DefaultTextStyle.merge(
                  style: base.copyWith(
                    color: fg,
                    fontFamilyFallback: KText.emojiFallback,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(color: fg, size: large ? 20 : 17),
                    child: leading!,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: base.copyWith(
                    color: selected
                        ? const Color(0xFF555555)
                        : KColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontFeatures: KText.tabular,
                  ),
                ),
              ],
            ],
          ),
        );
        pill = KFocusRing(
          visible: state.focused,
          borderRadius: height / 2,
          gap: 2,
          child: pill,
        );
        return AnimatedScale(
          scale: state.pressed
              ? 0.97
              : state.highlighted
              ? 1.03
              : 1.0,
          duration: duration,
          curve: KMotion.hover,
          child: pill,
        );
      },
    );
  }
}

/// One segment of [KSegmented].
@immutable
class KSegment<T> {
  const KSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Apple TV style pill segmented control: dark track, the selected segment
/// is a lighter pill that slides between options (track #191919, selection
/// #303030).
///
/// Each segment is focusable; Enter/Space or a click selects it.
class KSegmented<T> extends StatelessWidget {
  const KSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 44,
    this.textStyle = KText.nav,
  });

  final List<KSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final TextStyle textStyle;

  static const double _pad = 4;
  static const double _hPad = 22;

  @override
  Widget build(BuildContext context) {
    final style = textStyle.copyWith(fontWeight: FontWeight.w600);
    final scaler = MediaQuery.textScalerOf(context);
    final widths = <double>[
      for (final s in segments) _measure(s, style, scaler) + _hPad * 2,
    ];
    final index = segments.indexWhere((s) => s.value == value);
    double left = 0;
    for (var i = 0; i < index; i++) {
      left += widths[i];
    }
    final total = widths.fold<double>(0, (a, b) => a + b);
    final duration = KMotion.of(context, const Duration(milliseconds: 220));
    return Container(
      height: height,
      padding: const EdgeInsets.all(_pad),
      decoration: const BoxDecoration(
        color: KColors.segmentTrack,
        borderRadius: KRadii.pillBorder,
      ),
      child: SizedBox(
        width: total,
        child: Stack(
          children: [
            if (index >= 0)
              AnimatedPositioned(
                duration: duration,
                curve: KMotion.enter,
                left: left,
                top: 0,
                bottom: 0,
                width: widths[index],
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: KColors.segmentActive,
                    borderRadius: KRadii.pillBorder,
                  ),
                ),
              ),
            Row(
              children: [
                for (var i = 0; i < segments.length; i++)
                  SizedBox(
                    width: widths[i],
                    child: _SegmentButton<T>(
                      segment: segments[i],
                      selected: i == index,
                      style: style,
                      height: height - _pad * 2,
                      onTap: () => onChanged(segments[i].value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _measure(KSegment<T> s, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: s.label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width =
        painter.width + (s.icon != null ? (style.fontSize ?? 17) + 8 : 0);
    painter.dispose();
    return width.ceilToDouble();
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.style,
    required this.height,
    required this.onTap,
  });

  final KSegment<T> segment;
  final bool selected;
  final TextStyle style;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      selected: selected,
      semanticLabel: segment.label,
      builder: (context, state, _) {
        final color = selected
            ? Colors.white
            : state.highlighted
            ? const Color(0xFFB5B5B5)
            : KColors.textTertiary;
        return KFocusRing(
          visible: state.focused,
          borderRadius: height / 2,
          gap: 1,
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (segment.icon != null) ...[
                  Icon(segment.icon, size: style.fontSize, color: color),
                  const SizedBox(width: 8),
                ],
                Text(segment.label, style: style.copyWith(color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}
