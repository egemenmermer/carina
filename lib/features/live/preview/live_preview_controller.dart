import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/repository_models.dart';
import '../../../data/repositories/stream_url_resolver.dart';
import '../../../data/settings/settings_store.dart';
import '../../../player/engine/playback_engine.dart';

/// What the live preview shows right now.
@immutable
class LivePreviewStatus {
  const LivePreviewStatus({
    this.channelId,
    this.state = const EngineState(),
    this.stats = const EngineStats(),
    this.resolveError,
    this.failed = false,
  });

  /// The channel loaded into the preview; null when idle.
  final String? channelId;
  final EngineState state;
  final EngineStats stats;

  /// The stream could not be resolved (DRM, missing URL or credentials).
  final StreamResolveError? resolveError;

  /// Resolving failed for another reason.
  final bool failed;

  bool get active => channelId != null;

  bool get hasError => resolveError != null || failed || state.hasError;

  /// Waiting for the first frame (or rebuffering).
  bool get loading =>
      active && !hasError && (state.buffering || !state.hasVideo);

  LivePreviewStatus copyWith({EngineState? state, EngineStats? stats}) =>
      LivePreviewStatus(
        channelId: channelId,
        state: state ?? this.state,
        stats: stats ?? this.stats,
        resolveError: resolveError,
        failed: failed,
      );
}

/// Owns the one long-lived preview [PlaybackEngine] of TV Live ("one long-lived
/// Player is reused"). The engine is created on the first [open], re-opened
/// with a new URL on every channel switch, stopped while the full-screen player
/// runs and disposed with the screen.
class LivePreviewController {
  LivePreviewController({
    required this.playlistId,
    required this._factory,
    required this._resolver,
    required this._options,
  });

  final int playlistId;
  final PlaybackEngineFactory _factory;
  final StreamUrlResolver _resolver;
  final EngineOptions Function() _options;

  /// Current status; widgets listen to it.
  final ValueNotifier<LivePreviewStatus> status = ValueNotifier(
    const LivePreviewStatus(),
  );

  PlaybackEngine? _engine;
  StreamSubscription<EngineState>? _stateSub;
  StreamSubscription<EngineStats>? _statsSub;
  int _seq = 0;
  String? _url;
  bool _disposed = false;

  /// The engine, once a preview was opened (null before and after
  /// [dispose]).
  PlaybackEngine? get engine => _engine;

  /// The channel in the preview, or null.
  String? get channelId => status.value.channelId;

  bool get isDisposed => _disposed;

  PlaybackEngine _ensureEngine() {
    final existing = _engine;
    if (existing != null) return existing;
    final engine = _factory.create(options: _options(), preview: true);
    _engine = engine;
    _stateSub = engine.stateStream.listen(_onState);
    _statsSub = engine.statsStream.listen(_onStats);
    return engine;
  }

  void _onState(EngineState state) {
    if (_disposed || !status.value.active) return;
    final source = state.source;
    // Late events of the previous channel, or the idle state of stop().
    if (source == null || source.url != _url) return;
    status.value = status.value.copyWith(
      state: state,
      stats: _engine?.stats ?? status.value.stats,
    );
  }

  void _onStats(EngineStats stats) {
    if (_disposed || !status.value.active) return;
    status.value = status.value.copyWith(stats: stats);
  }

  /// Loads [channel] (muted when [muted]). Calls that overlap are
  /// superseded: only the latest one opens.
  Future<void> open(ChannelView channel, {required bool muted}) async {
    if (_disposed) return;
    final seq = ++_seq;
    _url = null;
    status.value = LivePreviewStatus(channelId: channel.providerId);
    final ResolvedStream stream;
    try {
      stream = await _resolver.live(playlistId, channel.row);
    } on StreamResolveException catch (e) {
      if (seq != _seq || _disposed) return;
      await _engine?.stop();
      status.value = LivePreviewStatus(
        channelId: channel.providerId,
        resolveError: e.error,
      );
      return;
    } on Object {
      if (seq != _seq || _disposed) return;
      await _engine?.stop();
      status.value = LivePreviewStatus(
        channelId: channel.providerId,
        failed: true,
      );
      return;
    }
    if (seq != _seq || _disposed) return;
    try {
      final engine = _ensureEngine();
      _url = stream.url;
      if (engine.state.muted != muted) await engine.setMuted(muted);
      if (seq != _seq || _disposed) return;
      await engine.open(
        PlaybackSource(
          url: stream.url,
          headers: stream.headers,
          userAgent: stream.userAgent,
          referer: stream.referer,
          isLive: true,
          title: channel.displayName,
        ),
      );
    } on Object catch (e) {
      // No player backend (libmpv missing) or a failing engine: show the
      // error poster instead of crashing the screen.
      debugPrint('Live preview failed: $e');
      if (seq != _seq || _disposed) return;
      status.value = LivePreviewStatus(
        channelId: channel.providerId,
        failed: true,
      );
    }
  }

  /// Mutes or unmutes the running preview.
  Future<void> setMuted(bool muted) async {
    final engine = _engine;
    if (engine == null || _disposed) return;
    if (engine.state.muted != muted) await engine.setMuted(muted);
  }

  /// Stops the preview (the engine stays for the next [open]).
  Future<void> stop() async {
    if (_disposed) return;
    ++_seq;
    _url = null;
    if (status.value.active) status.value = const LivePreviewStatus();
    await _engine?.stop();
  }

  /// Frees the engine. Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_seq;
    final engine = _engine;
    _engine = null;
    final subs = [_stateSub, _statsSub];
    _stateSub = null;
    _statsSub = null;
    status.dispose();
    for (final s in subs) {
      await s?.cancel();
    }
    await engine?.dispose();
  }
}

/// Engine options of the preview from the playlist's player settings.
/// Previews always use the low-latency profile and start muted.
EngineOptions livePreviewEngineOptions(SettingsStore settings, int playlistId) {
  T get<T>(SettingKey<T> key) => settings.get(key, playlistId: playlistId);
  return EngineOptions(
    profile: EngineProfile.lowLatency,
    bufferPolicy: BufferPolicy.small,
    hardwareAcceleration: get(PlaylistSettings.hardwareAcceleration),
    deinterlaceMode: switch (get(PlaylistSettings.deinterlace)) {
      'on' => DeinterlaceMode.on,
      'off' => DeinterlaceMode.off,
      _ => DeinterlaceMode.auto,
    },
    deinterlaceMethod: get(PlaylistSettings.deinterlaceMethod) == 'yadif'
        ? DeinterlaceMethod.yadif
        : DeinterlaceMethod.bwdif,
    reconnectAttempts: get(PlaylistSettings.liveReconnectAttempts),
    muted: true,
  );
}
