import 'package:flutter/widgets.dart';

import 'package:carina/core/text_case.dart';
import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';

/// Panel header: 3 px red vertical bar + 15/700 uppercase title
/// ("NOW ON AIR", "UPCOMING", "CHANNEL FUNCTIONS").
class PanelHeader extends StatelessWidget {
  const PanelHeader(
    this.title, {
    super.key,
    this.trailing,
    this.showBar = true,
  });

  final String title;

  /// Optional widget at the right end.
  final Widget? trailing;

  /// Hide the red bar for sub-headers such as "CHANNEL FUNCTIONS".
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBar) ...[
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              color: KColors.accent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(
            title.upper(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: showBar
                ? KText.panelHeader
                : KText.panelHeader.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: KColors.textSecondary,
                  ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Panel surface: surface1 fill, 1 px stroke, radius 14.
class KPanel extends StatelessWidget {
  const KPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = KColors.surface1,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: KRadii.panelBorder,
        border: Border.all(color: KColors.stroke),
      ),
      child: child,
    );
  }
}

/// Info tile: icon + label + value ("Time / 3:15 PM – 4:15 PM").
class KInfoTile extends StatelessWidget {
  const KInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = KColors.textPrimary,
    this.valueColor = KColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: KColors.tile,
        borderRadius: BorderRadius.circular(KRadii.tile),
        border: Border.all(color: KColors.stroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.caption.copyWith(color: KColors.textSecondary),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.time.copyWith(color: valueColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Row section header: 22/700 title on the left, red "See All" (15/600,
/// underline on hover) on the right.
class KSectionHeader extends StatelessWidget {
  const KSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: KSpacing.gutter),
  });

  final String title;

  /// Shows the "See All" link when set.
  final VoidCallback? onSeeAll;

  /// Overrides the localized "See All".
  final String? seeAllLabel;

  /// Extra widget before the link (e.g. a sort button).
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.sectionTitle,
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 16)],
          if (onSeeAll != null)
            KLink(
              label: seeAllLabel ?? KStrings.of(context).seeAll,
              onTap: onSeeAll,
            ),
        ],
      ),
    );
  }
}
