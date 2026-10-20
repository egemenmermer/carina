import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../state/live_card_info.dart';
import 'live_marquee.dart';

/// Height of a channel card in the horizontal list (without the gap).
const double kLiveListCardHeight = 124;

/// Gap between list cards.
const double kLiveListGap = 10;

/// Channel card of the horizontal layout:
/// logo tile, `[FHD] Name`, programme, time range, red progress bar, and a
/// separated strip of four status icons at the right. The selected card
/// keeps a white 3 px border.
class LiveListCard extends StatefulWidget {
  const LiveListCard({
    super.key,
    required this.channel,
    required this.info,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.onFocusChange,
    required this.onContextMenu,
    this.logoSize = 84,
  });

  final ChannelView channel;
  final LiveCardInfo info;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChange;
  final KContextMenuCallback onContextMenu;
  final double logoSize;

  @override
  State<LiveListCard> createState() => _LiveListCardState();
}

class _LiveListCardState extends State<LiveListCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final info = widget.info;
    return FocusableCard(
      focusNode: widget.focusNode,
      selected: widget.selected,
      ringWidth: KFocusRingWidth.tv,
      scale: 1.02,
      onTap: widget.onTap,
      onFocusChange: widget.onFocusChange,
      onHoverChange: (h) => setState(() => _hovered = h),
      onContextMenu: widget.onContextMenu,
      semanticLabel: '${channel.displayName}, ${info.title}, ${info.time}',
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 14, 0),
            child: KLogoTile(
              name: channel.displayName,
              url: channel.logo,
              size: widget.logoSize,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 16, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LiveChannelName(channel: channel, fontSize: 20),
                      const SizedBox(height: 6),
                      LiveMarquee(
                        text: info.title,
                        active: widget.selected,
                        style: KText.programme.copyWith(
                          fontSize: 15,
                          color: KColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          info.time,
                          maxLines: 1,
                          style: KText.time.copyWith(
                            fontSize: 14,
                            color: KColors.textPrimary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      KProgressBar(value: info.progress, height: 6),
                    ],
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: LiveMoreButton(
                    visible: _hovered,
                    onOpen: widget.onContextMenu,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 1,
            height: double.infinity,
            child: ColoredBox(color: KColors.stroke),
          ),
          SizedBox(
            width: 56,
            child: LiveStatusIcons(channel: channel, axis: Axis.vertical),
          ),
        ],
      ),
    );
  }
}

/// Channel card of the vertical grid: logo top-left, name with the quality
/// badge below it, time, programme, red progress bar, and a centered row of
/// four status icons.
class LiveGridCard extends StatefulWidget {
  const LiveGridCard({
    super.key,
    required this.channel,
    required this.info,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.onFocusChange,
    required this.onContextMenu,
  });

  final ChannelView channel;
  final LiveCardInfo info;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChange;
  final KContextMenuCallback onContextMenu;

  @override
  State<LiveGridCard> createState() => _LiveGridCardState();
}

class _LiveGridCardState extends State<LiveGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final info = widget.info;
    return FocusableCard(
      focusNode: widget.focusNode,
      selected: widget.selected,
      ringWidth: KFocusRingWidth.tv,
      onTap: widget.onTap,
      onFocusChange: widget.onFocusChange,
      onHoverChange: (h) => setState(() => _hovered = h),
      onContextMenu: widget.onContextMenu,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      semanticLabel: '${channel.displayName}, ${info.title}, ${info.time}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KLogoTile(name: channel.displayName, url: channel.logo, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      channel.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.channelName.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    if (channel.badges.isNotEmpty)
                      Row(
                        children: [
                          for (final b in channel.badges.take(3)) ...[
                            KBadge(b),
                            const SizedBox(width: 5),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              LiveMoreButton(visible: _hovered, onOpen: widget.onContextMenu),
            ],
          ),
          const SizedBox(height: 10),
          Text(info.time, maxLines: 1, style: KText.time),
          const SizedBox(height: 3),
          LiveMarquee(
            text: info.title,
            active: widget.selected,
            style: KText.programme,
          ),
          const SizedBox(height: 8),
          KProgressBar(value: info.progress, height: 4),
          const Spacer(),
          const SizedBox(
            height: 1,
            width: double.infinity,
            child: ColoredBox(color: KColors.stroke),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 28,
            child: LiveStatusIcons(
              channel: channel,
              axis: Axis.horizontal,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// `[FHD] [H265] Name` on one line (badges before the name, as in the
/// horizontal reference).
class LiveChannelName extends StatelessWidget {
  const LiveChannelName({super.key, required this.channel, this.fontSize = 17});

  final ChannelView channel;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final b in channel.badges.take(2)) ...[
          KBadge(b),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(
            channel.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: KText.channelName.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The four status icons of a channel card: record (P2, never active
/// yet), TV archive (bright with catch-up), reminder (red when a reminder
/// is set), parental (green when locked). Inactive icons are dim.
class LiveStatusIcons extends StatelessWidget {
  const LiveStatusIcons({
    super.key,
    required this.channel,
    required this.axis,
    this.size = 20,
  });

  final ChannelView channel;
  final Axis axis;
  final double size;

  /// Inactive status icon color.
  static final Color dim = KColors.textTertiary.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final icons = <(IconData, Color)>[
      (PhosphorIconsLight.record, dim),
      (
        PhosphorIconsLight.clockCounterClockwise,
        channel.hasArchive ? KColors.textPrimary : dim,
      ),
      (PhosphorIconsLight.bell, channel.hasReminder ? KColors.accent : dim),
      (
        channel.locked
            ? PhosphorIconsLight.lockSimple
            : PhosphorIconsLight.lockSimpleOpen,
        channel.locked ? KColors.success : dim,
      ),
    ];
    final children = [
      for (final (icon, color) in icons)
        if (axis == Axis.horizontal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Icon(icon, size: size, color: color),
          )
        else
          Icon(icon, size: size, color: color),
    ];
    return ExcludeSemantics(
      child: axis == Axis.vertical
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: children,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
    );
  }
}

/// Small round "•••" button shown while the pointer is over a card; opens
/// the channel menu at the button.
class LiveMoreButton extends StatelessWidget {
  const LiveMoreButton({
    super.key,
    required this.visible,
    required this.onOpen,
  });

  final bool visible;
  final KContextMenuCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: KMotion.of(context, KDurations.hover),
      child: IgnorePointer(
        ignoring: !visible,
        child: Builder(
          builder: (context) => KIconButton(
            icon: PhosphorIconsBold.dotsThree,
            size: 28,
            iconSize: 16,
            focusable: false,
            background: KColors.overlay,
            tooltip: L10n.of(context).liveMoreActions,
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              onOpen(box.localToGlobal(box.size.bottomCenter(Offset.zero)));
            },
          ),
        ),
      ),
    );
  }
}
