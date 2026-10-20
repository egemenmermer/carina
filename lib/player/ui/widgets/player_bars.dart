import 'package:flutter/material.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../engine/playback_engine.dart';
import '../player_controller.dart';
import '../player_menus.dart';
import '../player_options.dart';
import 'player_button.dart';
import 'seek_bar.dart';

/// Icon and tooltip of each bar button.
(IconData, String) playerMenuButton(
  L10n l10n,
  PlayerMenu menu,
) => switch (menu) {
  PlayerMenu.switchPlayer => (
    PhosphorIconsLight.arrowsClockwise,
    l10n.playerSwitchPlayer,
  ),
  PlayerMenu.audio => (PhosphorIconsLight.speakerHigh, l10n.playerAudio),
  PlayerMenu.subtitles => (PhosphorIconsLight.subtitles, l10n.playerSubtitles),
  PlayerMenu.picture => (PhosphorIconsLight.frameCorners, l10n.playerPicture),
  PlayerMenu.speed => (PhosphorIconsLight.gauge, l10n.playerSpeed),
  PlayerMenu.more => (PhosphorIconsLight.dotsThree, l10n.playerMore),
};

/// The round buttons at the right of the bar: Switch player · Audio ·
/// Subtitles · Picture · Speed · More.
class PlayerMenuButtons extends StatelessWidget {
  const PlayerMenuButtons({
    super.key,
    required this.menus,
    required this.keys,
    required this.activeMenu,
    required this.onOpen,
  });

  final List<PlayerMenu> menus;
  final Map<PlayerMenu, GlobalKey> keys;
  final PlayerMenu? activeMenu;
  final ValueChanged<PlayerMenu> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < menus.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Builder(
            builder: (context) {
              final (icon, tooltip) = playerMenuButton(l10n, menus[i]);
              return PlayerIconButton(
                key: keys[menus[i]],
                icon: icon,
                tooltip: tooltip,
                active: activeMenu == menus[i],
                onPressed: () => onOpen(menus[i]),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Bottom gradient behind the bars (never takes clicks).
class PlayerScrim extends StatelessWidget {
  const PlayerScrim({super.key, this.top = false, this.height = 320});

  final bool top;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: const [Color(0xD9000000), Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }
}

/// VOD and catch-up bottom bar: title (28/800) left, round buttons right,
/// full-width progress bar with the elapsed time under the playhead and
/// the remaining time (catch-up: the programme's start / end) and the
/// "↓ for info" hint.
class VodBottomBar extends StatelessWidget {
  const VodBottomBar({
    super.key,
    required this.controller,
    required this.timeFormat,
    required this.menus,
    required this.menuKeys,
    required this.activeMenu,
    required this.onOpenMenu,
    required this.onSeek,
    required this.onInteraction,
    required this.onInfo,
  });

  final PlayerController controller;
  final CarinaTimeFormat timeFormat;
  final List<PlayerMenu> menus;
  final Map<PlayerMenu, GlobalKey> menuKeys;
  final PlayerMenu? activeMenu;
  final ValueChanged<PlayerMenu> onOpenMenu;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onInteraction;

  /// The ⓘ hint (opens the info panel).
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = controller;
    final media = c.media;
    final catchup = c.kind == PlayerKind.catchup;
    final start = c.programmeStart;
    final end = c.programmeEnd;
    final position = c.position;
    final duration = c.duration;
    final remaining = duration - position;
    String wallClock(Duration at) => start == null
        ? CarinaTimeFormat.clock(at)
        : timeFormat.time(start.add(at));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (media?.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        media!.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.button.copyWith(
                          color: KColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  Text(
                    media?.title ?? '',
                    key: const ValueKey('player-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.largeTitle.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      shadows: const [
                        Shadow(color: Color(0x80000000), blurRadius: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            PlayerMenuButtons(
              menus: menus,
              keys: menuKeys,
              activeMenu: activeMenu,
              onOpen: onOpenMenu,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PlayerSeekBar(
          key: const ValueKey('player-seek-bar'),
          position: position,
          duration: duration,
          buffered: c.state.buffered,
          onSeek: onSeek,
          onInteraction: onInteraction,
          playheadLabel: catchup ? wallClock : CarinaTimeFormat.clock,
          startLabel: catchup && start != null ? timeFormat.time(start) : null,
          endLabel: catchup && end != null
              ? timeFormat.time(end)
              : '-${CarinaTimeFormat.clock(remaining.isNegative ? Duration.zero : remaining)}',
          hoverLabel: catchup ? wallClock : null,
        ),
        const SizedBox(height: 6),
        Center(
          child: PlayerHint(
            key: const ValueKey('player-info-hint'),
            icon: PhosphorIconsLight.info,
            label: l10n.playerInfoHint,
            onTap: onInfo,
          ),
        ),
      ],
    );
  }
}

const Set<String> _resolutionBadges = {'SD', 'HD', 'FHD', 'UHD', '4K', '8K'};

/// Live top-left block: logo, name, ● LIVE and the quality / fps chips
/// read from the engine.
class LiveChannelHeader extends StatelessWidget {
  const LiveChannelHeader({
    super.key,
    required this.channel,
    required this.stats,
    required this.sizeIndicator,
  });

  final ChannelView channel;
  final EngineStats stats;

  /// `size` (1920×1080) or `label` (FHD), from the playlist setting.
  final bool sizeIndicator;

  @override
  Widget build(BuildContext context) {
    final quality = sizeIndicator ? stats.sizeLabel : stats.qualityLabel;
    return Row(
      key: const ValueKey('player-live-header'),
      mainAxisSize: MainAxisSize.min,
      children: [
        KLogoTile(name: channel.displayName, url: channel.logo, size: 60),
        const SizedBox(width: 16),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (channel.number != null)
                      TextSpan(
                        text: '${channel.number}  ',
                        style: const TextStyle(
                          color: KColors.textSecondary,
                          fontFeatures: KText.tabular,
                        ),
                      ),
                    TextSpan(text: channel.displayName),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KText.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(color: Color(0x80000000), blurRadius: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KLivePill(),
                if (quality != null) ...[
                  const SizedBox(width: 8),
                  KChip(quality),
                ],
                if (stats.fps > 0) ...[
                  const SizedBox(width: 8),
                  KChip('${stats.fps.round()} FPS'),
                ],
                // Name badges the stream does not already tell (H265…);
                // the resolution comes from the decoder once it is known.
                for (final badge in channel.badges.where(
                  (b) =>
                      !b.endsWith('FPS') &&
                      (quality == null || !_resolutionBadges.contains(b)),
                )) ...[
                  const SizedBox(width: 8),
                  KBadge(badge, color: KColors.textPrimary),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Live bottom block: programme on air, its time range and progress, and
/// "Next: 4:15 PM Title"; buttons at the right.
class LiveBottomBar extends StatelessWidget {
  const LiveBottomBar({
    super.key,
    required this.nowNext,
    required this.now,
    required this.timeFormat,
    required this.menus,
    required this.menuKeys,
    required this.activeMenu,
    required this.onOpenMenu,
    required this.onOptions,
  });

  /// The hint under the bar (opens the action sheet).
  final VoidCallback onOptions;

  final NowNext nowNext;
  final DateTime now;
  final CarinaTimeFormat timeFormat;
  final List<PlayerMenu> menus;
  final Map<PlayerMenu, GlobalKey> menuKeys;
  final PlayerMenu? activeMenu;
  final ValueChanged<PlayerMenu> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final programme = nowNext.now;
    final next = nowNext.next;
    final left = programme?.stop.difference(now.toUtc()).inMinutes;
    return Column(
      key: const ValueKey('player-live-bottom'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    programme?.title ?? l10n.playerNoEpg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.largeTitle.copyWith(
                      fontWeight: FontWeight.w800,
                      color: programme == null
                          ? KColors.textSecondary
                          : KColors.textPrimary,
                      shadows: const [
                        Shadow(color: Color(0x80000000), blurRadius: 12),
                      ],
                    ),
                  ),
                  if (programme != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          timeFormat.range(programme.start, programme.stop),
                          style: KText.time.copyWith(
                            fontSize: 15,
                            color: KColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 320,
                          child: KProgressBar(
                            value: programme.progressAt(now),
                            height: 4,
                            trackColor: const Color(0x40FFFFFF),
                          ),
                        ),
                        if (left != null && left >= 0) ...[
                          const SizedBox(width: 14),
                          Text(
                            l10n.playerMinutesLeft(left),
                            style: KText.time.copyWith(fontSize: 15),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (next != null) ...[
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${l10n.playerNextLabel} ',
                            style: const TextStyle(
                              color: KColors.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: timeFormat.time(next.start),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFeatures: KText.tabular,
                            ),
                          ),
                          TextSpan(text: '  ${next.title}'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.body.copyWith(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 24),
            PlayerMenuButtons(
              menus: menus,
              keys: menuKeys,
              activeMenu: activeMenu,
              onOpen: onOpenMenu,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: PlayerHint(
            icon: PhosphorIconsLight.dotsThreeCircle,
            label: l10n.playerLiveHint,
            onTap: onOptions,
          ),
        ),
      ],
    );
  }
}

/// Clickable hint under the bars ("ⓘ ↓ for info").
class PlayerHint extends StatelessWidget {
  const PlayerHint({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      focusable: false,
      semanticLabel: label,
      builder: (context, state, _) {
        final color = state.hovered
            ? KColors.textPrimary
            : KColors.textSecondary;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label, style: KText.caption.copyWith(color: color)),
            ],
          ),
        );
      },
    );
  }
}
