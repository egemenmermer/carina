import 'package:flutter/material.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/brand/carina_mark.dart';
import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_caption_buttons.dart';
import 'package:carina/core/widgets/k_interactive.dart';
import 'package:carina/core/widgets/k_popup.dart';
import 'package:carina/core/window/window_controls.dart';

/// A tab of [KTopNav] / [KUnderlineTabs].
@immutable
class KNavTab {
  /// Text tab ("Movies", "Settings").
  const KNavTab({required this.id, required this.label}) : icon = null;

  /// Icon-only tab (search); [label] is the tooltip and accessibility label.
  const KNavTab.icon({
    required this.id,
    required IconData this.icon,
    required this.label,
  });

  final String id;
  final String label;
  final IconData? icon;
}

/// The top navigation as a pure component (no routing).
///
/// * Left: the Carina mark ([logoSize] 52, so the glyph is ≈30 px tall) and the date/time text supplied by the caller
///   ("Wed, May 20 • 00:26").
/// * Center (centered in the window): text tabs 17/500 — inactive grey,
///   hover brighter, active white with a 3 px red underline as wide as the
///   text — plus icon tabs (search).
/// * Right: [trailing] widgets (e.g. a [KProgressChip] during a background
///   reload), then the playlist [avatar] with a small chevron badge.
/// * On Windows/Linux the dark caption buttons sit in the top-right corner.
///
/// Empty areas of the bar drag the window and double-click toggles
/// maximize via [KWindowControls] (no-op in tests). Height defaults to
/// [KSpacing.navHeight] (72).
class KTopNav extends StatelessWidget {
  const KTopNav({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onTabSelected,
    this.tabFocusNodes,
    this.dateTimeText,
    this.avatar,
    this.onAvatarTap,
    this.avatarTooltip,
    this.trailing = const [],
    this.onLogoTap,
    this.height = KSpacing.navHeight,
    this.leadingInset = 0,
    this.horizontalPadding = 32,
    this.backgroundColor = Colors.transparent,
    this.windowControls,
    this.enableWindowDrag = true,
    this.showCaptionButtons,
    this.logoSize = 52,
  });

  final List<KNavTab> tabs;

  /// Id of the active tab (null: none).
  final String? activeTabId;
  final ValueChanged<String> onTabSelected;

  /// Optional focus nodes of the tabs by id, so the caller can move focus
  /// to a tab (the TV shell focuses the active tab).
  final Map<String, FocusNode>? tabFocusNodes;

  /// Date/time text next to the logo, formatted by the caller.
  final String? dateTimeText;

  /// Avatar content, typically `KAvatar(playlist.avatarId, 44)`.
  final Widget? avatar;

  /// Avatar clicked; receives the avatar's global rectangle so the caller
  /// can anchor the "Switch playlist" menu below it.
  final ValueChanged<Rect>? onAvatarTap;

  /// Tooltip of the avatar (defaults to "Switch playlist").
  final String? avatarTooltip;

  /// Widgets left of the avatar.
  final List<Widget> trailing;
  final VoidCallback? onLogoTap;
  final double height;

  /// Extra space on the left (macOS traffic lights with a hidden title bar).
  final double leadingInset;
  final double horizontalPadding;
  final Color backgroundColor;

  /// Overrides [KWindowControls.of].
  final KWindowControls? windowControls;

  /// Drag the window from empty areas / double-click to maximize.
  final bool enableWindowDrag;

  /// Defaults to [KCaptionButtons.platformUsesCaptionButtons].
  final bool? showCaptionButtons;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final controls = enableWindowDrag
        ? (windowControls ?? KWindowControls.of(context))
        : null;
    final captions =
        showCaptionButtons ?? KCaptionButtons.platformUsesCaptionButtons;
    const captionButtons = KCaptionButtons(forceVisible: true);
    final captionWidth = captions ? captionButtons.width + 8 : 0.0;
    final strings = KStrings.of(context);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1280;
          final tabPadding = compact ? 11.0 : 16.0;
          return Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Positioned.fill(
                child: KNavDragArea(
                  controls: controls,
                  enabled: enableWindowDrag,
                  child: ColoredBox(color: backgroundColor),
                ),
              ),
              Padding(
                // Symmetric so the tabs are centered in the window; the
                // caption buttons only push the right-hand group inward.
                padding: EdgeInsets.only(
                  left: leadingInset + horizontalPadding,
                  right: horizontalPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _NavLogo(size: logoSize, onTap: onLogoTap),
                          if (dateTimeText != null) ...[
                            const SizedBox(width: 18),
                            Flexible(
                              child: Text(
                                dateTimeText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: KText.navDate,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final tab in tabs)
                          _NavTabButton(
                            tab: tab,
                            active: tab.id == activeTabId,
                            horizontalPadding: tabPadding,
                            focusNode: tabFocusNodes?[tab.id],
                            onTap: () => onTabSelected(tab.id),
                          ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16, right: captionWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final w in trailing) ...[
                              Flexible(child: w),
                              const SizedBox(width: 16),
                            ],
                            if (avatar != null)
                              _NavAvatar(
                                tooltip:
                                    avatarTooltip ?? strings.switchPlaylist,
                                onTap: onAvatarTap,
                                child: avatar!,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (captions)
                Positioned(
                  top: 0,
                  right: 0,
                  child: KCaptionButtons(
                    controls: controls,
                    forceVisible: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Makes [child] drag the window on pan and toggle maximize on
/// double-click. Wrap empty title-bar regions with it. Does nothing when
/// no [KWindowControls] are available (tests) or [enabled] is false.
class KNavDragArea extends StatelessWidget {
  const KNavDragArea({
    super.key,
    required this.child,
    this.controls,
    this.enabled = true,
  });

  final Widget child;
  final KWindowControls? controls;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = enabled ? (controls ?? KWindowControls.of(context)) : null;
    if (c == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => c.startDragging(),
      onDoubleTap: c.toggleMaximize,
      child: child,
    );
  }
}

class _NavLogo extends StatelessWidget {
  const _NavLogo({required this.size, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mark = CarinaMark(size: size);
    if (onTap == null) return mark;
    return KInteractive(
      onTap: onTap,
      semanticLabel: 'Carina',
      builder: (context, state, _) => KFocusRing(
        visible: state.focused,
        borderRadius: 8,
        child: AnimatedScale(
          scale: state.highlighted ? 1.05 : 1.0,
          duration: KMotion.of(context, KDurations.hover),
          child: mark,
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.tab,
    required this.active,
    required this.horizontalPadding,
    required this.onTap,
    this.focusNode,
  });

  final KNavTab tab;
  final bool active;
  final double horizontalPadding;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    Widget button = KInteractive(
      onTap: onTap,
      focusNode: focusNode,
      selected: active,
      semanticLabel: tab.label,
      builder: (context, state, _) {
        final color = active
            ? Colors.white
            : state.pressed
            ? const Color(0xFFE6E6E6)
            : state.highlighted
            ? const Color(0xFFD2D2D2)
            : KColors.navInactive;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _UnderlinedLabel(
            active: active,
            focused: state.focused,
            label: tab.icon != null
                ? Icon(tab.icon, size: 25, color: color)
                : _StableWeightText(
                    tab.label,
                    style: KText.nav.copyWith(color: color),
                    bold: active,
                  ),
          ),
        );
      },
    );
    if (tab.icon != null && Overlay.maybeOf(context) != null) {
      button = Tooltip(
        message: tab.label,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return button;
  }
}

/// Label with a 3 px red underline exactly as wide as the label, plus a
/// matching spacer above so the label stays vertically centered.
class _UnderlinedLabel extends StatelessWidget {
  const _UnderlinedLabel({
    required this.label,
    required this.active,
    required this.focused,
    this.balance = true,
  });

  final Widget label;
  final bool active;
  final bool focused;

  /// Add a spacer above the label as tall as the underline area.
  final bool balance;

  static const double _gap = 7;
  static const double _bar = 3;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (balance) const SizedBox(height: _gap + _bar),
          KFocusRing(
            visible: focused,
            borderRadius: 6,
            gap: 5,
            child: Center(widthFactor: 1, child: label),
          ),
          const SizedBox(height: _gap),
          AnimatedContainer(
            duration: KMotion.of(context, const Duration(milliseconds: 180)),
            height: _bar,
            decoration: BoxDecoration(
              color: active ? KColors.accent : const Color(0x00FF2500),
              borderRadius: BorderRadius.circular(_bar / 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text that reserves the width of its bold variant, so switching the
/// active tab never shifts the layout.
class _StableWeightText extends StatelessWidget {
  const _StableWeightText(this.text, {required this.style, required this.bold});

  final String text;
  final TextStyle style;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final boldStyle = style.copyWith(fontWeight: FontWeight.w600);
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: Text(text, maxLines: 1, style: boldStyle)),
        Text(text, maxLines: 1, style: bold ? boldStyle : style),
      ],
    );
  }
}

class _NavAvatar extends StatelessWidget {
  const _NavAvatar({required this.child, required this.tooltip, this.onTap});

  final Widget child;
  final String tooltip;
  final ValueChanged<Rect>? onTap;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    Widget avatar = Builder(
      builder: (context) => KInteractive(
        onTap: onTap == null ? null : () => onTap!(kGlobalRectOf(context)),
        semanticLabel: tooltip,
        builder: (context, state, _) => AnimatedScale(
          scale: state.pressed
              ? 0.96
              : state.highlighted
              ? 1.06
              : 1.0,
          duration: KMotion.of(context, KDurations.hover),
          curve: KMotion.hover,
          child: KFocusRing(
            visible: state.focused,
            circle: true,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xD9FFFFFF),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: FittedBox(fit: BoxFit.cover, child: child),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.3),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.caretDown,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (Overlay.maybeOf(context) != null) {
      avatar = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: avatar,
      );
    }
    return avatar;
  }
}

/// Horizontal text tabs with the red underline (season tabs in the series
/// sheet, "Season 1 · Season 2 · Special contents"). Scrolls horizontally
/// when the tabs do not fit.
class KUnderlineTabs extends StatelessWidget {
  const KUnderlineTabs({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onTabSelected,
    this.style = KText.button,
    this.spacing = 28,
    this.padding = EdgeInsets.zero,
  });

  final List<KNavTab> tabs;
  final String? activeTabId;
  final ValueChanged<String> onTabSelected;
  final TextStyle style;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == tabs.length - 1 ? 0 : spacing,
              ),
              child: KInteractive(
                onTap: () => onTabSelected(tabs[i].id),
                selected: tabs[i].id == activeTabId,
                semanticLabel: tabs[i].label,
                builder: (context, state, _) {
                  final active = tabs[i].id == activeTabId;
                  final color = active
                      ? Colors.white
                      : state.highlighted
                      ? const Color(0xFFD2D2D2)
                      : KColors.navInactive;
                  return _UnderlinedLabel(
                    active: active,
                    focused: state.focused,
                    balance: false,
                    label: tabs[i].icon != null
                        ? Icon(
                            tabs[i].icon,
                            size: (style.fontSize ?? 15) + 4,
                            color: color,
                          )
                        : _StableWeightText(
                            tabs[i].label,
                            style: style.copyWith(
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                            bold: active,
                          ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
