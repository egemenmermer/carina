import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/repositories/stream_url_resolver.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../player/engine/playback_engine.dart';
import 'live_preview_controller.dart';

/// The live preview surface: the shared engine's video (cover fit) with the
/// red ● LIVE pill, the resolution and FPS chips read from the engine
/// stats, a spinner while loading, an error line, a blurred picture for
/// locked channels, and a poster (logo, name, hint) when nothing plays.
///
/// A click calls [onActivate] (full-screen playback when the channel is
/// already previewed); right-click / long-press call [onContextMenu].
class LivePreviewView extends StatefulWidget {
  const LivePreviewView({
    super.key,
    required this.controller,
    required this.channel,
    required this.locked,
    required this.onActivate,
    this.onContextMenu,
    this.sizeIndicator = false,
    this.compact = false,
    this.previewEnabled = true,
    this.borderRadius = KRadii.video,
  });

  final LivePreviewController controller;

  /// The selected channel (null when the list is empty).
  final ChannelView? channel;

  /// Locked and not unlocked for the session: blur the picture.
  final bool locked;
  final VoidCallback onActivate;
  final KContextMenuCallback? onContextMenu;

  /// `1920×1080` instead of `FHD` (the resolution indicator setting).
  final bool sizeIndicator;

  /// Small chips and no poster text (the grid tile).
  final bool compact;

  /// The live preview setting; when off the poster says so.
  final bool previewEnabled;
  final double borderRadius;

  @override
  State<LivePreviewView> createState() => _LivePreviewViewState();
}

class _LivePreviewViewState extends State<LivePreviewView> {
  PlaybackEngine? _videoEngine;
  Widget? _video;

  /// One video widget per engine instance (rebuilt only when the engine
  /// changes, so the texture is not re-created on every status change).
  Widget? _videoFor(PlaybackEngine? engine) {
    if (engine == null) return null;
    if (!identical(engine, _videoEngine)) {
      _videoEngine = engine;
      _video = engine.buildVideo(fit: BoxFit.cover);
    }
    return _video;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LivePreviewStatus>(
      valueListenable: widget.controller.status,
      builder: (context, status, _) {
        final channel = widget.channel;
        final showing =
            channel != null && status.channelId == channel.providerId;
        final video = showing && !status.hasError
            ? _videoFor(widget.controller.engine)
            : null;
        return KInteractive(
          focusable: false,
          onTap: channel == null ? null : widget.onActivate,
          onContextMenu: channel == null ? null : widget.onContextMenu,
          semanticLabel: channel?.displayName,
          builder: (context, state, _) => ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: ColoredBox(
              color: KColors.surface1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video == null)
                    _Poster(
                      channel: channel,
                      compact: widget.compact,
                      hint: _posterHint(context, status, showing),
                      error: showing && status.hasError,
                    )
                  else
                    _blurIfLocked(video),
                  if (video != null && widget.locked)
                    _LockedOverlay(compact: widget.compact),
                  if (showing && status.loading && !widget.locked)
                    Center(child: KSpinner(size: widget.compact ? 26 : 38)),
                  if (showing && !status.hasError)
                    Positioned(
                      left: widget.compact ? 10 : 16,
                      top: widget.compact ? 10 : 16,
                      child: _StatsChips(
                        status: status,
                        sizeIndicator: widget.sizeIndicator,
                        compact: widget.compact,
                      ),
                    ),
                  if (state.hovered && video != null && !widget.locked)
                    _HoverPlay(compact: widget.compact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _blurIfLocked(Widget video) {
    if (!widget.locked) return video;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 36,
        sigmaY: 36,
        tileMode: TileMode.decal,
      ),
      child: video,
    );
  }

  String? _posterHint(
    BuildContext context,
    LivePreviewStatus status,
    bool showing,
  ) {
    final l10n = L10n.of(context);
    if (showing && status.hasError) {
      return status.resolveError == StreamResolveError.unsupported
          ? l10n.livePreviewUnsupported
          : l10n.livePreviewError;
    }
    if (widget.locked) return l10n.liveLockedHint;
    return widget.previewEnabled
        ? l10n.livePreviewSelectHint
        : l10n.livePreviewWatchHint;
  }
}

/// ● LIVE + resolution + FPS (from the engine stats).
class _StatsChips extends StatelessWidget {
  const _StatsChips({
    required this.status,
    required this.sizeIndicator,
    required this.compact,
  });

  final LivePreviewStatus status;
  final bool sizeIndicator;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stats = status.stats;
    final resolution = sizeIndicator ? stats.sizeLabel : stats.qualityLabel;
    final fps = stats.fps > 0 ? '${stats.fps.round()} FPS' : null;
    final gap = SizedBox(width: compact ? 6 : 10);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KLivePill(large: !compact),
        if (resolution != null) ...[
          gap,
          KChip(resolution, overlay: true, large: !compact),
        ],
        if (fps != null) ...[gap, KChip(fps, overlay: true, large: !compact)],
      ],
    );
  }
}

/// Logo, name and a hint when the selected channel is not previewed
/// (preview off, "start on select", an error, or nothing selected).
class _Poster extends StatelessWidget {
  const _Poster({
    required this.channel,
    required this.compact,
    required this.hint,
    required this.error,
  });

  final ChannelView? channel;
  final bool compact;
  final String? hint;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = channel;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KColors.surface2, KColors.surface1],
        ),
      ),
      child: c == null
          ? const SizedBox.expand()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error)
                      Icon(
                        PhosphorIconsLight.warningCircle,
                        size: compact ? 30 : 44,
                        color: KColors.accent,
                      )
                    else
                      KLogoTile(
                        name: c.displayName,
                        url: c.logo,
                        size: compact ? 52 : 88,
                      ),
                    if (!compact) ...[
                      const SizedBox(height: 14),
                      Text(
                        c.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.title,
                      ),
                    ],
                    if (hint != null) ...[
                      SizedBox(height: compact ? 8 : 6),
                      Text(
                        hint!,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: KText.caption.copyWith(
                          color: error
                              ? KColors.textPrimary
                              : KColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// Dark scrim with a lock over the blurred picture of a locked channel.
class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ColoredBox(
      color: KColors.scrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 44 : 64,
              height: compact ? 44 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KColors.overlay,
                border: Border.all(color: KColors.success, width: 2),
              ),
              child: Icon(
                PhosphorIconsLight.lockSimple,
                size: compact ? 22 : 30,
                color: KColors.success,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 14),
              Text(l10n.liveLockedTitle, style: KText.title),
              const SizedBox(height: 6),
              Text(
                l10n.liveLockedHint,
                style: KText.caption.copyWith(color: KColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Play affordance while the pointer is over the preview.
class _HoverPlay extends StatelessWidget {
  const _HoverPlay({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 52.0 : 76.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KColors.overlay,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: Icon(
          PhosphorIconsFill.play,
          size: size * 0.42,
          color: Colors.white,
        ),
      ),
    );
  }
}
