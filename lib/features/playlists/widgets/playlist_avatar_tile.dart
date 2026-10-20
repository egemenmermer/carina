import 'package:flutter/material.dart';

import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart' show PlaylistRow;
import 'package:carina/l10n/gen/app_localizations.dart';

/// A playlist on the Playlist Manager: a large circular avatar (≈140 px)
/// with the name underneath. Hover and keyboard focus scale the avatar and
/// draw a white ring; a ••• button appears at its top-right corner. Click /
/// Enter opens the playlist; right-click, long-press, the Menu key and the
/// ••• button open the playlist menu.
class PlaylistAvatarTile extends StatefulWidget {
  const PlaylistAvatarTile({
    super.key,
    required this.playlist,
    required this.onOpen,
    required this.onMenu,
    this.autofocus = false,
    this.focusNode,
    this.updateProgress,
    this.avatarSize = 140,
    this.active = false,
  });

  final PlaylistRow playlist;
  final VoidCallback onOpen;

  /// Opens the playlist menu at a global position.
  final ValueChanged<Offset> onMenu;
  final bool autofocus;
  final FocusNode? focusNode;

  /// 0…1 while a background reload runs; null when idle.
  final double? updateProgress;
  final double avatarSize;

  /// Keeps the focused look while the playlist's menu is open.
  final bool active;

  /// Width of a tile (avatar plus room for two-line names).
  static double widthFor(double avatarSize) => avatarSize + 52;

  @override
  State<PlaylistAvatarTile> createState() => _PlaylistAvatarTileState();
}

class _PlaylistAvatarTileState extends State<PlaylistAvatarTile> {
  bool _hovered = false;
  bool _focused = false;

  /// The Menu key reports the tile's center; open the menu beside the
  /// avatar instead. Right-clicks keep the pointer position.
  Offset _menuAnchor(BuildContext context, Offset position) {
    final rect = kGlobalRectOf(context);
    if (rect.isEmpty || (position - rect.center).distance > 1) return position;
    final size = widget.avatarSize;
    return Offset(rect.center.dx + size / 2 + 18, rect.top);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final row = widget.playlist;
    final size = widget.avatarSize;
    final duration = KMotion.of(context, KDurations.hover);
    final showMore = (_hovered || _focused) && !widget.active;
    final progress = widget.updateProgress;

    final tile = KInteractive(
      onTap: widget.onOpen,
      onContextMenu: (position) =>
          widget.onMenu(_menuAnchor(context, position)),
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        if (mounted && focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      semanticLabel: row.name,
      builder: (context, state, _) {
        final lit = state.highlighted || widget.active;
        Widget avatar = SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              KAvatar(row.avatarId, size, fallbackName: row.name),
              if (row.hasAccessPin)
                Positioned(
                  right: size * 0.02,
                  bottom: size * 0.02,
                  child: Tooltip(
                    message: l10n.playlistsProtected,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xE6141416),
                        shape: BoxShape.circle,
                        border: Border.all(color: KColors.bg, width: 2),
                      ),
                      child: const Icon(
                        PhosphorIconsFill.lockSimple,
                        size: 16,
                        color: KColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        avatar = KFocusRing(
          visible: lit,
          circle: true,
          gap: 5,
          width: 3,
          child: avatar,
        );
        avatar = AnimatedScale(
          scale: state.pressed
              ? 1.02
              : lit
              ? 1.08
              : 1,
          duration: duration,
          curve: KMotion.hover,
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: lit ? KShadows.focus : const [],
            ),
            child: avatar,
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            const SizedBox(height: 20),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: KText.cardTitle.copyWith(
                fontSize: 16,
                fontWeight: lit ? FontWeight.w700 : FontWeight.w600,
                color: lit ? KColors.textPrimary : const Color(0xFFC7C7C9),
                height: 1.25,
              ),
              child: Text(
                row.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: size * 0.6,
                child: KProgressBar(value: progress, height: 3),
              ),
              const SizedBox(height: 5),
              Text(
                l10n.playlistsUpdatingPercent((progress * 100).round()),
                style: KText.caption.copyWith(fontFeatures: KText.tabular),
              ),
            ],
          ],
        );
      },
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: PlaylistAvatarTile.widthFor(size),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(alignment: Alignment.topCenter, child: tile),
            Positioned(
              top: -2,
              left: PlaylistAvatarTile.widthFor(size) / 2 + size / 2 - 26,
              child: IgnorePointer(
                ignoring: !showMore,
                child: AnimatedOpacity(
                  opacity: showMore ? 1 : 0,
                  duration: duration,
                  child: Builder(
                    builder: (buttonContext) => KIconButton(
                      icon: PhosphorIconsBold.dotsThree,
                      size: 34,
                      iconSize: 18,
                      focusable: false,
                      background: const Color(0xE61C1C1E),
                      tooltip: l10n.playlistsMoreActions,
                      onPressed: () {
                        final rect = kGlobalRectOf(buttonContext);
                        widget.onMenu(rect.bottomLeft + const Offset(0, 6));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
