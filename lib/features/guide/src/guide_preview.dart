/// The guide's live preview: one shared preview engine that follows the focused
/// row after the focus delay, muted unless "Preview audio" is on, disposed with
/// the screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/repositories/parental_service.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/repositories/stream_url_resolver.dart';
import '../../../data/settings/settings_store.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../player/engine/playback_engine.dart';

enum _PreviewStatus { idle, loading, playing, hidden, locked, failed }

/// Plays [channel] in a 16:9 box. Engine stats go to [stats] (for the
/// "1920x1080" / "25 fps" chips). While [suspended] (the full player is
/// open) the stream is stopped. [progress] draws the on-air programme's
/// progress as a thin red line at the bottom.
class GuidePreview extends ConsumerStatefulWidget {
  const GuidePreview({
    super.key,
    required this.playlistId,
    required this.channel,
    required this.stats,
    this.progress,
    this.suspended = false,
  });

  final int playlistId;
  final ChannelView? channel;
  final ValueNotifier<EngineStats?> stats;
  final double? progress;
  final bool suspended;

  @override
  ConsumerState<GuidePreview> createState() => _GuidePreviewState();
}

class _GuidePreviewState extends ConsumerState<GuidePreview> {
  PlaybackEngine? _engine;
  StreamSubscription<EngineStats>? _statsSub;
  StreamSubscription<EngineState>? _stateSub;
  Timer? _debounce;
  String? _openedId;
  _PreviewStatus _status = _PreviewStatus.idle;
  int _request = 0;
  bool? _enabled;
  bool? _audio;
  bool _disposed = false;

  int get _pid => widget.playlistId;

  @override
  void initState() {
    super.initState();
    _schedule(Duration.zero);
  }

  @override
  void didUpdateWidget(GuidePreview old) {
    super.didUpdateWidget(old);
    if (old.suspended != widget.suspended) {
      if (widget.suspended) {
        _stop();
      } else {
        _schedule(Duration.zero);
      }
    } else if (old.channel?.providerId != widget.channel?.providerId ||
        old.channel?.locked != widget.channel?.locked) {
      final delay = ref
          .read(settingsStoreProvider)
          .get(PlaylistSettings.previewFocusDelayMs, playlistId: _pid);
      _schedule(Duration(milliseconds: delay.clamp(0, 3000)));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    unawaited(_statsSub?.cancel());
    unawaited(_stateSub?.cancel());
    final engine = _engine;
    _engine = null;
    if (engine != null) unawaited(engine.dispose());
    super.dispose();
  }

  void _schedule(Duration delay) {
    _debounce?.cancel();
    _request++;
    if (delay == Duration.zero) {
      // After the frame: the providers this reads may not be ready during
      // build.
      _debounce = Timer(Duration.zero, _open);
    } else {
      _debounce = Timer(delay, _open);
    }
  }

  void _setStatus(_PreviewStatus status) {
    if (_disposed || status == _status) return;
    setState(() => _status = status);
  }

  Future<void> _open() async {
    final request = _request;
    final channel = widget.channel;
    if (_disposed || channel == null || widget.suspended) return;
    final settings = ref.read(settingsStoreProvider);
    if (!settings.get(PlaylistSettings.livePreview, playlistId: _pid)) {
      _stop(_PreviewStatus.hidden);
      return;
    }
    final parental = ref.read(parentalServiceProvider);
    if (parental.isLocked(channel, ref.read(parentalSessionProvider))) {
      _stop(_PreviewStatus.locked);
      return;
    }
    if (!channel.playable) {
      _stop(_PreviewStatus.failed);
      return;
    }
    if (_openedId == channel.providerId && _status == _PreviewStatus.playing) {
      return;
    }
    _setStatus(_PreviewStatus.loading);
    final ResolvedStream resolved;
    try {
      resolved = await ref
          .read(streamUrlResolverProvider)
          .live(_pid, channel.row);
    } on StreamResolveException {
      if (!_disposed && request == _request) _stop(_PreviewStatus.failed);
      return;
    }
    if (_disposed || request != _request) return;
    final engine = _engine ??= _createEngine();
    final audio = settings.get(PlaylistSettings.previewAudio, playlistId: _pid);
    await engine.open(
      PlaybackSource(
        url: resolved.url,
        headers: resolved.headers,
        userAgent: resolved.userAgent,
        referer: resolved.referer,
        isLive: true,
        title: channel.displayName,
      ),
    );
    if (_disposed || request != _request) return;
    await engine.setMuted(!audio);
    _openedId = channel.providerId;
    _setStatus(_PreviewStatus.playing);
    _publishStats(engine.state.hasVideo ? engine.stats : null);
  }

  PlaybackEngine _createEngine() {
    final engine = ref
        .read(playbackEngineFactoryProvider)
        .create(
          options: const EngineOptions(
            profile: EngineProfile.lowLatency,
            muted: true,
          ),
          preview: true,
        );
    _statsSub = engine.statsStream.listen(_publishStats);
    _stateSub = engine.stateStream.listen((state) {
      if (state.hasError) {
        _publishStats(null);
      } else if (state.hasVideo && widget.stats.value == null) {
        _publishStats(engine.stats);
      }
    });
    return engine;
  }

  void _publishStats(EngineStats? stats) {
    if (_disposed) return;
    widget.stats.value = stats;
  }

  void _stop([_PreviewStatus status = _PreviewStatus.idle]) {
    _debounce?.cancel();
    _request++;
    _openedId = null;
    _publishStats(null);
    final engine = _engine;
    if (engine != null) unawaited(engine.stop());
    _setStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watchSetting(
      PlaylistSettings.livePreview,
      playlistId: _pid,
    );
    final audio = ref.watchSetting(
      PlaylistSettings.previewAudio,
      playlistId: _pid,
    );
    if (_enabled != null && enabled != _enabled) {
      _schedule(Duration.zero);
    }
    if (_audio != null && audio != _audio && _engine != null) {
      unawaited(_engine!.setMuted(!audio));
    }
    _enabled = enabled;
    _audio = audio;

    final l10n = L10n.of(context);
    final engine = _engine;
    final progress = widget.progress;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: KColors.surface1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (engine != null && _status == _PreviewStatus.playing)
              engine.buildVideo(),
            if (_status == _PreviewStatus.loading)
              const Center(child: KSpinner(size: 30)),
            if (_status == _PreviewStatus.hidden)
              _Placeholder(
                icon: PhosphorIconsLight.eyeSlash,
                label: l10n.guidePreviewHidden,
              ),
            if (_status == _PreviewStatus.locked)
              _Placeholder(
                icon: PhosphorIconsLight.lockSimple,
                label: l10n.guidePreviewLocked,
                color: KColors.success,
              ),
            if (_status == _PreviewStatus.failed)
              const _Placeholder(icon: PhosphorIconsLight.warningCircle),
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: KProgressBar(
                  value: progress,
                  height: 4,
                  rounded: false,
                  trackColor: const Color(0x00000000),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    this.label,
    this.color = KColors.textTertiary,
  });

  final IconData icon;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: color),
          if (label != null) ...[
            const SizedBox(height: 10),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: KText.caption.copyWith(fontSize: 15),
            ),
          ],
        ],
      ),
    );
  }
}
