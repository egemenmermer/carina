import 'package:flutter/material.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../engine/playback_engine.dart';
import '../player_controller.dart';
import '../player_texts.dart';
import 'player_button.dart';

/// Thin ring + "Buffering 43%" (or "Reconnecting… (2/3)").
class PlayerBufferingIndicator extends StatelessWidget {
  const PlayerBufferingIndicator({
    super.key,
    required this.state,
    required this.reconnectTotal,
  });

  final EngineState state;
  final int reconnectTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    String? label;
    if (state.reconnecting) {
      label = l10n.playerReconnecting(state.reconnectAttempt, reconnectTotal);
    } else if (state.buffering && state.bufferingPercent > 0) {
      label = KStrings.of(context)
          .buffering(state.bufferingPercent.clamp(0, 100).round());
    }
    return IgnorePointer(
      child: KSpinner(size: 52, strokeWidth: 2.5, label: label),
    );
  }
}

/// Readable error with Retry (primary), Switch player and Back.
class PlayerErrorOverlay extends StatelessWidget {
  const PlayerErrorOverlay({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onSwitchPlayer,
    required this.onBack,
    this.switchPlayerKey,
  });

  final PlayerFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onSwitchPlayer;
  final VoidCallback onBack;

  /// Anchor for the SWITCH PLAYER popover.
  final GlobalKey? switchPlayerKey;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final engineFailure = failure.kind == PlayerFailureKind.engine;
    return ColoredBox(
      color: const Color(0xB3000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsLight.warningCircle,
                    size: 56,
                    color: KColors.accent,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.playerErrorTitle,
                    textAlign: TextAlign.center,
                    style: KText.title.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    failureMessage(l10n, failure),
                    key: const ValueKey('player-error-message'),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: KText.bodySecondary.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (failure.retryable)
                        FocusOnMount(
                          builder: (context, node) => PlayerPillButton(
                            label: l10n.retry,
                            icon: PhosphorIconsBold.arrowClockwise,
                            primary: true,
                            focusNode: node,
                            minWidth: 130,
                            onPressed: onRetry,
                          ),
                        ),
                      if (engineFailure)
                        PlayerPillButton(
                          key: switchPlayerKey,
                          label: l10n.playerSwitchPlayer,
                          icon: PhosphorIconsLight.arrowsClockwise,
                          minWidth: 130,
                          onPressed: onSwitchPlayer,
                        ),
                      if (failure.retryable)
                        PlayerPillButton(
                          label: l10n.back,
                          icon: PhosphorIconsLight.arrowLeft,
                          minWidth: 130,
                          onPressed: onBack,
                        )
                      else
                        FocusOnMount(
                          builder: (context, node) => PlayerPillButton(
                            label: l10n.back,
                            icon: PhosphorIconsLight.arrowLeft,
                            focusNode: node,
                            minWidth: 130,
                            onPressed: onBack,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Continue watching · Resume from 12:34 / From the beginning".
class PlayerResumePrompt extends StatelessWidget {
  const PlayerResumePrompt({
    super.key,
    required this.title,
    required this.position,
    required this.onResume,
    required this.onStartOver,
  });

  final String title;
  final Duration position;
  final VoidCallback onResume;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: KFrostedPanel(
          width: 400,
          borderRadius: KRadii.sheet,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.playerResumeTitle,
                    textAlign: TextAlign.center,
                    style: KText.title,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KText.caption.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  FocusOnMount(
                    builder: (context, node) => _SheetPill(
                      label: l10n.playerResumeFrom(
                        CarinaTimeFormat.clock(position),
                      ),
                      focusNode: node,
                      onTap: onResume,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SheetPill(
                    label: l10n.playerFromBeginning,
                    onTap: onStartOver,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacked pill of the resume prompt and the live action sheet: dark grey,
/// white when hovered or focused.
class SheetPill extends StatelessWidget {
  const SheetPill({
    super.key,
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.strong = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final bool strong;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => _SheetPill(
    label: label,
    onTap: onTap,
    autofocus: autofocus,
    strong: strong,
    focusNode: focusNode,
  );
}

class _SheetPill extends StatelessWidget {
  const _SheetPill({
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.strong = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final bool strong;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      autofocus: autofocus,
      focusNode: focusNode,
      onTap: onTap,
      semanticLabel: label,
      builder: (context, state, _) {
        final white = state.highlighted;
        return AnimatedContainer(
          duration: KMotion.of(context, const Duration(milliseconds: 90)),
          curve: KMotion.hover,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: white
                ? KColors.focusRing
                : state.pressed
                ? const Color(0xFF333336)
                : const Color(0xFF2A2A2C),
            borderRadius: KRadii.pillBorder,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: KText.menu.copyWith(
              fontSize: 15,
              color: white ? Colors.black : KColors.textPrimary,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

/// Bottom-right "Next episode" card with the countdown.
class NextEpisodeCard extends StatelessWidget {
  const NextEpisodeCard({
    super.key,
    required this.offer,
    required this.onPlay,
    required this.onDismiss,
  });

  final NextEpisodeOffer offer;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final e = offer.episode;
    final countdown = offer.countdown;
    return Container(
      key: const ValueKey('player-next-episode'),
      width: 420,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEB121214),
        borderRadius: KRadii.panelBorder,
        border: Border.all(color: KColors.materialStroke),
        boxShadow: KShadows.menu,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: KRadii.posterBorder,
            child: SizedBox(
              width: 150,
              height: 84,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KImage(
                    e.image,
                    placeholder: const ColoredBox(color: KColors.surface2),
                  ),
                  const Center(
                    child: Icon(
                      PhosphorIconsFill.playCircle,
                      size: 34,
                      color: Color(0xE6FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.playerNextEpisode.toUpperCase(),
                        style: KText.menuHeader.copyWith(color: KColors.accent),
                      ),
                    ),
                    KIconButton(
                      icon: PhosphorIconsBold.x,
                      size: 26,
                      iconSize: 12,
                      focusable: false,
                      tooltip: l10n.close,
                      onPressed: onDismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  e.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KText.cardTitle,
                ),
                const SizedBox(height: 10),
                PlayerPillButton(
                  label: countdown == null
                      ? l10n.playerPlayNow
                      : l10n.playerNextEpisodeIn(countdown),
                  icon: PhosphorIconsFill.play,
                  primary: true,
                  onPressed: onPlay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Skip intro" pill (bottom-right while an intro chapter plays).
class SkipIntroPill extends StatelessWidget {
  const SkipIntroPill({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PlayerPillButton(
    label: L10n.of(context).playerSkipIntro,
    icon: PhosphorIconsFill.skipForward,
    primary: true,
    onPressed: onPressed,
  );
}

/// Quick-switch OSD at the top center: channel name + programme on air.
class ZapOsd extends StatelessWidget {
  const ZapOsd({super.key, required this.channel, required this.nowNext});

  final ChannelView channel;
  final NowNext nowNext;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final programme = nowNext.now?.title;
    return Container(
      key: const ValueKey('player-zap-osd'),
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(12, 10, 22, 10),
      decoration: BoxDecoration(
        color: const Color(0xD90D0D0D),
        borderRadius: KRadii.panelBorder,
        border: Border.all(color: KColors.materialStroke),
        boxShadow: KShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel.number != null) ...[
            SizedBox(
              width: 44,
              child: Text(
                '${channel.number}',
                textAlign: TextAlign.center,
                style: KText.timeLarge.copyWith(color: KColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
          ],
          KLogoTile(name: channel.displayName, url: channel.logo, size: 44),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.channelName.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  programme ?? l10n.playerNoEpg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.programme.copyWith(color: KColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Typed channel number (top-right).
class NumberOsd extends StatelessWidget {
  const NumberOsd({super.key, required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player-number-osd'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD90D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KColors.materialStroke),
      ),
      child: Text(
        digits,
        style: KText.heroTitle.copyWith(
          fontSize: 44,
          fontFeatures: KText.tabular,
        ),
      ),
    );
  }
}

/// Volume level pill (top-right).
class VolumeOsd extends StatelessWidget {
  const VolumeOsd({super.key, required this.volume, required this.muted});

  final double volume;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final icon = muted || volume <= 0
        ? PhosphorIconsFill.speakerSlash
        : volume < 50
        ? PhosphorIconsFill.speakerLow
        : PhosphorIconsFill.speakerHigh;
    return Container(
      key: const ValueKey('player-volume-osd'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xD90D0D0D),
        borderRadius: KRadii.pillBorder,
        border: Border.all(color: KColors.materialStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: KProgressBar(
              value: muted ? 0 : volume / 100,
              height: 5,
              color: Colors.white,
              trackColor: const Color(0x40FFFFFF),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              muted ? l10n.playerMuted : '${volume.round()}',
              textAlign: TextAlign.right,
              style: KText.chip.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small persistent "muted" badge (top-right) while the sound is off.
class MuteIndicator extends StatelessWidget {
  const MuteIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L10n.of(context).playerMuted,
      child: Container(
        key: const ValueKey('player-mute-indicator'),
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xB3000000),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          PhosphorIconsFill.speakerSlash,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// One-line feedback (delays, "No channel with number 12").
class FlashOsd extends StatelessWidget {
  const FlashOsd({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player-flash-osd'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD90D0D0D),
        borderRadius: KRadii.pillBorder,
        border: Border.all(color: KColors.materialStroke),
      ),
      child: Text(text, style: KText.button.copyWith(fontSize: 16)),
    );
  }
}

/// Big translucent play button in the middle while a VOD is paused.
class PausedIndicator extends StatelessWidget {
  const PausedIndicator({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PlayerIconButton(
      icon: PhosphorIconsFill.play,
      tooltip: L10n.of(context).playerPlay,
      size: 84,
      iconSize: 36,
      background: const Color(0x66000000),
      onPressed: onPressed,
    );
  }
}

/// The hidden technical overlay (Ctrl+Shift+D): every [EngineStats] value.
class PlayerStatsOverlay extends StatelessWidget {
  const PlayerStatsOverlay({
    super.key,
    required this.stats,
    required this.state,
    required this.profileName,
    this.source,
  });

  final EngineStats stats;
  final EngineState state;
  final String profileName;

  /// Masked stream URL.
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    String yesNo(bool v) => v ? l10n.yes : l10n.no;
    final audio = [
      if (stats.audioCodec != null) codecDisplayName(stats.audioCodec!),
      ?channelLayoutLabel(stats.audioChannels),
      if (stats.sampleRate > 0)
        '${(stats.sampleRate / 1000).toStringAsFixed(1)} kHz',
    ].join(' · ');
    String rate(int bps) => bps >= 1000000
        ? '${(bps / 1000000).toStringAsFixed(2)} Mbps'
        : '${(bps / 1000).round()} kbps';
    final bitrate = [
      if (stats.videoBitrate != null) rate(stats.videoBitrate!),
      if (stats.audioBitrate != null) rate(stats.audioBitrate!),
    ].join(' + ');
    final rows = <(String, String)>[
      (l10n.playerStatsProfile, profileName),
      (l10n.playerStatsDecoder, stats.hwdec ?? '—'),
      (l10n.playerStatsResolution, stats.sizeLabel ?? '—'),
      (l10n.playerStatsFps, stats.fps > 0 ? stats.fps.toStringAsFixed(2) : '—'),
      (
        l10n.playerStatsVideo,
        stats.videoCodec == null ? '—' : codecDisplayName(stats.videoCodec!),
      ),
      (l10n.playerStatsAudio, audio.isEmpty ? '—' : audio),
      (l10n.playerStatsCache, '${stats.cacheDurationSec.toStringAsFixed(1)} s'),
      (l10n.playerStatsBuffering, '${stats.bufferingPercent.round()}%'),
      (l10n.playerStatsDropped, '${stats.droppedFrames}'),
      (l10n.playerStatsBitrate, bitrate.isEmpty ? '—' : bitrate),
      (l10n.playerStatsDeinterlace, yesNo(stats.deinterlacing)),
      (l10n.playerStatsFallback, yesNo(stats.fallbackHappened)),
      (
        l10n.playerStatsPosition,
        state.duration > Duration.zero
            ? '${CarinaTimeFormat.clock(state.position)} / '
                  '${CarinaTimeFormat.clock(state.duration)}'
            : CarinaTimeFormat.clock(state.position),
      ),
      if (source != null) (l10n.playerStatsSource, source!),
    ];
    return Container(
      key: const ValueKey('player-stats'),
      width: 380,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KColors.materialStroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.playerStatistics.toUpperCase(),
            style: KText.menuHeader.copyWith(color: KColors.textPrimary),
          ),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      label,
                      style: KText.caption.copyWith(
                        color: KColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KText.caption.copyWith(
                        color: KColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFeatures: KText.tabular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            l10n.playerStatsHint,
            style: KText.caption.copyWith(
              fontSize: 12,
              color: KColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
