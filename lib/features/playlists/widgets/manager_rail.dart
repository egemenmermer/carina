import 'package:flutter/material.dart';

import 'package:carina/core/core.dart';

/// One entry of [ManagerRail].
@immutable
class ManagerRailItem {
  const ManagerRailItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Key of the item's row (tests).
  final Key? key;
}

/// Slim left icon rail of the Playlist Manager: the Carina
/// mark at the top and round icon buttons in the middle. It
/// widens to show the labels while the pointer is over it or one of its
/// items has keyboard focus; the wide rail floats over the content.
class ManagerRail extends StatefulWidget {
  const ManagerRail({
    super.key,
    required this.items,
    this.collapsedWidth = 68,
    this.expandedWidth = 240,
    this.title,
  });

  final List<ManagerRailItem> items;
  final double collapsedWidth;
  final double expandedWidth;

  /// Text next to the mark while expanded ("Carina").
  final String? title;

  @override
  State<ManagerRail> createState() => _ManagerRailState();
}

class _ManagerRailState extends State<ManagerRail> {
  bool _hovered = false;
  bool _focused = false;

  bool get _expanded => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, const Duration(milliseconds: 200));
    final expanded = _expanded;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: duration,
          curve: KMotion.enter,
          width: expanded ? widget.expandedWidth : widget.collapsedWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: expanded ? const Color(0xF2111113) : KColors.surface1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: KColors.stroke),
            boxShadow: expanded ? KShadows.menu : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              _RailHeader(
                title: widget.title,
                expanded: expanded,
                collapsedWidth: widget.collapsedWidth,
              ),
              const Spacer(flex: 2),
              for (final item in widget.items)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  child: _RailButton(
                    key: item.key,
                    item: item,
                    expanded: expanded,
                  ),
                ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.title,
    required this.expanded,
    required this.collapsedWidth,
  });

  final String? title;
  final bool expanded;
  final double collapsedWidth;

  @override
  Widget build(BuildContext context) {
    const markSize = 36.0;
    return SizedBox(
      height: markSize,
      child: Row(
        children: [
          SizedBox(width: (collapsedWidth - 2 - markSize) / 2),
          const CarinaMark(size: markSize),
          if (title != null)
            Expanded(
              child: AnimatedOpacity(
                opacity: expanded ? 1 : 0,
                duration: KMotion.of(context, KDurations.hover),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    title!,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: KText.sectionTitle.copyWith(fontSize: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({super.key, required this.item, required this.expanded});

  final ManagerRailItem item;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: item.onTap,
      semanticLabel: item.label,
      builder: (context, state, _) {
        final lit = state.highlighted;
        final fg = lit ? Colors.black : KColors.textPrimary;
        final duration = KMotion.of(context, KDurations.hover);
        return AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          height: 48,
          decoration: BoxDecoration(
            color: state.pressed
                ? const Color(0xFFDADADA)
                : lit
                ? KColors.focusRing
                : const Color(0x00F5F5F5),
            borderRadius: KRadii.pillBorder,
          ),
          child: Row(
            children: [
              const SizedBox(width: 13),
              Icon(item.icon, size: 22, color: fg),
              Expanded(
                child: AnimatedOpacity(
                  opacity: expanded ? 1 : 0,
                  duration: duration,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 12),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: KText.settingsTitle.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
