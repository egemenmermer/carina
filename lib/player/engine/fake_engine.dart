/// In-memory [PlaybackEngine] for widget and screenshot tests.
///
/// It plays nothing: `open()` moves through buffering into playing, the
/// position ticks, and it reports 2 audio + 2 subtitle tracks and
/// 1920×1080 25 fps H.264/AAC stats. Every call is recorded in [calls].
library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'engine_mapping.dart';
import 'playback_engine.dart';
import 'track_language.dart';

/// Creates [FakeEngine]s and keeps them for assertions.
class FakeEngineFactory implements PlaybackEngineFactory {
  FakeEngineFactory({
    this.autoTick = true,
    this.tickInterval = const Duration(milliseconds: 500),
    this.openDelay = Duration.zero,
    this.vodDuration = const Duration(minutes: 42, seconds: 17),
  });

  final bool autoTick;
  final Duration tickInterval;
  final Duration openDelay;
  final Duration vodDuration;

  /// Every engine created, oldest first.
  final List<FakeEngine> created = [];

  FakeEngine get last => created.last;

  @override
  FakeEngine create({required EngineOptions options, bool preview = false}) {
    final engine = FakeEngine(
      options: options,
      preview: preview,
      autoTick: autoTick,
      tickInterval: tickInterval,
      openDelay: openDelay,
      vodDuration: vodDuration,
    );
    created.add(engine);
    return engine;
  }
}

class FakeEngine implements PlaybackEngine {
  FakeEngine({
    EngineOptions options = const EngineOptions(),
    this.preview = false,
    this.autoTick = true,
    this.tickInterval = const Duration(milliseconds: 500),
    this.openDelay = Duration.zero,
    this.vodDuration = const Duration(minutes: 42, seconds: 17),
  }) : _options = options,
       _profile = preview ? EngineProfile.lowLatency : options.profile,
       _state = EngineState(muted: preview || options.muted),
       _aspect = options.aspect;

  /// Default tracks: English AAC stereo (default) + Türkçe AC3 5.1, English
  /// and Türkçe SRT.
  static const List<EngineTrack> defaultAudioTracks = [
    EngineTrack(
      id: '1',
      kind: EngineTrackKind.audio,
      title: 'English',
      language: 'eng',
      codec: 'aac',
      channels: 2,
      isDefault: true,
    ),
    EngineTrack(
      id: '2',
      kind: EngineTrackKind.audio,
      title: 'Türkçe',
      language: 'tur',
      codec: 'ac3',
      channels: 6,
    ),
  ];

  static const List<EngineTrack> defaultSubtitleTracks = [
    EngineTrack(
      id: '1',
      kind: EngineTrackKind.subtitle,
      title: 'English',
      language: 'eng',
      codec: 'subrip',
    ),
    EngineTrack(
      id: '2',
      kind: EngineTrackKind.subtitle,
      title: 'Türkçe',
      language: 'tur',
      codec: 'subrip',
    ),
  ];

  final bool preview;
  final bool autoTick;
  final Duration tickInterval;
  final Duration openDelay;
  final Duration vodDuration;

  final EngineOptions _options;
  EngineProfile _profile;
  EngineState _state;
  AspectMode _aspect;
  DeinterlaceMode? _deinterlace;
  Duration _audioDelay = Duration.zero;
  Duration _subtitleDelay = Duration.zero;
  double _subtitleScale = 1.0;
  bool _disposed = false;
  Timer? _ticker;
  Timer? _openTimer;
  int _externalCount = 0;

  final StreamController<EngineState> _stateController =
      StreamController<EngineState>.broadcast();
  final StreamController<EngineStats> _statsController =
      StreamController<EngineStats>.broadcast();

  /// Recorded calls, e.g. `open Kanal D`, `seek 0:01:00.000000`,
  /// `selectAudio 2`, `switchProfile software`.
  final List<String> calls = [];

  /// Sources passed to [open], oldest first.
  final List<PlaybackSource> openedSources = [];

  bool get isDisposed => _disposed;
  AspectMode get aspect => _aspect;
  DeinterlaceMode get deinterlace => _deinterlace ?? _options.deinterlaceMode;
  Duration get audioDelay => _audioDelay;
  Duration get subtitleDelay => _subtitleDelay;
  double get subtitleScale => _subtitleScale;

  @override
  Stream<EngineState> get stateStream => _stateController.stream;

  @override
  EngineState get state => _state;

  @override
  Stream<EngineStats> get statsStream => _statsController.stream;

  @override
  EngineStats get stats => _state.hasVideo
      ? EngineStats(
          width: 1920,
          height: 1080,
          fps: 25,
          videoCodec: 'h264',
          audioCodec: _state.selectedAudioTrack?.codec ?? 'aac',
          audioChannels: _state.selectedAudioTrack?.channels ?? 2,
          sampleRate: 48000,
          hwdec: _profile == EngineProfile.software ? 'no' : 'd3d11va',
          cacheDurationSec: _state.isLive ? 3 : 30,
          bufferingPercent: 100,
          profile: concreteProfile(
            _profile,
            hardwareAcceleration: _options.hardwareAcceleration,
          ),
          videoBitrate: 4800000,
          audioBitrate: 192000,
        )
      : EngineStats(
          profile: concreteProfile(
            _profile,
            hardwareAcceleration: _options.hardwareAcceleration,
          ),
        );

  @override
  EngineOptions get options => _options;

  @override
  EngineProfile get profile => _profile;

  @override
  List<EngineTrack> get audioTracks => _state.audioTracks;

  @override
  List<EngineTrack> get subtitleTracks => _state.subtitleTracks;

  void _record(String call) {
    if (!_disposed) calls.add(call);
  }

  void _emit(EngineState next) {
    if (_disposed) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  @override
  Future<void> open(
    PlaybackSource source, {
    Duration? start,
    bool autoplay = true,
  }) async {
    if (_disposed) return;
    _record('open ${source.title ?? 'untitled'}');
    openedSources.add(source);
    _openTimer?.cancel();
    _stopTicker();
    final audio = defaultAudioTracks;
    final subtitles = defaultSubtitleTracks;
    final preferredAudio =
        pickPreferredTrack(audio, _options.preferredAudioLanguage) ??
        audio.firstWhereOrNull((t) => t.isDefault) ??
        audio.first;
    final preferredSubtitle = _options.subtitlesDisabled
        ? null
        : pickPreferredTrack(subtitles, _options.preferredSubtitleLanguage);
    _emit(
      EngineState(
        source: source,
        position: start ?? Duration.zero,
        duration: source.isLive ? Duration.zero : vodDuration,
        buffering: true,
        volume: _state.volume,
        muted: _state.muted,
        rate: _state.rate,
        audioTracks: audio,
        subtitleTracks: subtitles,
        selectedAudioId: preferredAudio.id,
        selectedSubtitleId: preferredSubtitle?.id,
      ),
    );
    if (openDelay == Duration.zero) {
      _becomeReady(autoplay);
    } else {
      _openTimer = Timer(openDelay, () => _becomeReady(autoplay));
    }
  }

  void _becomeReady(bool autoplay) {
    if (_disposed || _state.source == null) return;
    _emit(
      _state.copyWith(
        buffering: false,
        bufferingPercent: 100,
        playing: autoplay,
        width: 1920,
        height: 1080,
        buffered: _state.isLive
            ? const Duration(seconds: 3)
            : _state.position + const Duration(seconds: 30),
      ),
    );
    if (autoplay) _startTicker();
  }

  void _startTicker() {
    _stopTicker();
    if (!autoTick || _disposed) return;
    _ticker = Timer.periodic(tickInterval, (_) => advance(tickInterval));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Moves playback forward by [elapsed] (scaled by the rate), as if that
  /// much time had passed while playing. VOD completes at its duration.
  void advance(Duration elapsed) {
    if (_disposed || !_state.playing || _state.source == null) return;
    final step = elapsed * _state.rate;
    var position = _state.position + step;
    if (!_state.isLive && position >= _state.duration) {
      position = _state.duration;
      _stopTicker();
      _emit(
        _state.copyWith(position: position, playing: false, completed: true),
      );
      return;
    }
    _emit(
      _state.copyWith(
        position: position,
        buffered: _state.isLive
            ? position + const Duration(seconds: 3)
            : position + const Duration(seconds: 30),
      ),
    );
    if (_statsController.hasListener) _statsController.add(stats);
  }

  /// Puts the engine into an error state (the error overlay test path).
  void simulateError(EngineError error) {
    _stopTicker();
    _emit(_state.copyWith(error: error, playing: false, buffering: false));
  }

  /// Shows "Buffering N%".
  void simulateBuffering(double percent) {
    _emit(_state.copyWith(buffering: percent < 100, bufferingPercent: percent));
  }

  /// A live reconnect in progress (attempt is 1-based).
  void simulateReconnect(int attempt) {
    _emit(
      _state.copyWith(
        reconnectAttempt: attempt,
        buffering: true,
        playing: false,
        error: null,
      ),
    );
  }

  /// Ends a VOD item now.
  void simulateCompleted() {
    _stopTicker();
    _emit(
      _state.copyWith(
        position: _state.duration,
        playing: false,
        completed: true,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    _record('play');
    if (_state.source == null) return;
    if (_state.error != null) {
      final source = _state.source!;
      return open(source, start: source.isLive ? null : _state.position);
    }
    _emit(_state.copyWith(playing: true, completed: false));
    _startTicker();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _record('pause');
    _stopTicker();
    _emit(_state.copyWith(playing: false));
  }

  @override
  Future<void> playOrPause() async {
    if (_state.playing) return pause();
    return play();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    _record('seek $position');
    final max = _state.isLive ? position : _state.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (position > max ? max : position);
    _emit(_state.copyWith(position: target, completed: false));
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _record('stop');
    _openTimer?.cancel();
    _stopTicker();
    _emit(
      EngineState(
        volume: _state.volume,
        muted: _state.muted,
        rate: _state.rate,
      ),
    );
  }

  @override
  Future<void> setVolume(double v0to100) async {
    if (_disposed) return;
    final v = v0to100.clamp(0.0, 100.0).toDouble();
    _record('setVolume ${v.toStringAsFixed(0)}');
    _emit(_state.copyWith(volume: v));
  }

  @override
  Future<void> setMuted(bool m) async {
    if (_disposed) return;
    _record('setMuted $m');
    _emit(_state.copyWith(muted: m));
  }

  @override
  Future<void> setRate(double rate) async {
    if (_disposed) return;
    _record('setRate $rate');
    _emit(_state.copyWith(rate: rate));
  }

  @override
  Future<void> selectAudio(EngineTrack t) async {
    if (_disposed) return;
    _record('selectAudio ${t.id}');
    _emit(_state.copyWith(selectedAudioId: t.id));
  }

  @override
  Future<void> selectSubtitle(EngineTrack? t) async {
    if (_disposed) return;
    _record('selectSubtitle ${t?.id ?? 'off'}');
    _emit(_state.copyWith(selectedSubtitleId: t?.id));
  }

  @override
  Future<void> addExternalSubtitle(String pathOrUri) async {
    if (_disposed) return;
    _record('addExternalSubtitle $pathOrUri');
    _externalCount++;
    final id = '${defaultSubtitleTracks.length + _externalCount}';
    final name = pathOrUri.split(RegExp(r'[\\/]')).last;
    final track = EngineTrack(
      id: id,
      kind: EngineTrackKind.subtitle,
      title: name,
      codec: 'subrip',
      isExternal: true,
    );
    _emit(
      _state.copyWith(
        subtitleTracks: [..._state.subtitleTracks, track],
        selectedSubtitleId: id,
      ),
    );
  }

  @override
  Future<void> setAudioDelay(Duration d) async {
    if (_disposed) return;
    _record('setAudioDelay ${formatSeconds(d)}');
    _audioDelay = d;
  }

  @override
  Future<void> setSubtitleDelay(Duration d) async {
    if (_disposed) return;
    _record('setSubtitleDelay ${formatSeconds(d)}');
    _subtitleDelay = d;
  }

  @override
  Future<void> setSubtitleScale(double s) async {
    if (_disposed) return;
    _record('setSubtitleScale ${formatScale(s)}');
    _subtitleScale = s;
  }

  @override
  Future<void> setAspect(AspectMode m) async {
    if (_disposed) return;
    _record('setAspect ${m.name}');
    _aspect = m;
  }

  @override
  Future<void> setDeinterlace(DeinterlaceMode m) async {
    if (_disposed) return;
    _record('setDeinterlace ${m.name}');
    _deinterlace = m;
  }

  @override
  Future<void> switchProfile(EngineProfile p) async {
    if (_disposed) return;
    _record('switchProfile ${p.name}');
    _profile = p;
    final source = _state.source;
    if (source == null) return;
    final position = _state.position;
    final audio = _state.selectedAudioId;
    final subtitle = _state.selectedSubtitleId;
    // Like MpvEngine: a reopen clears the error and plays after a failure.
    final wasPlaying = _state.playing || _state.error != null;
    _stopTicker();
    _emit(_state.copyWith(buffering: true, width: 0, height: 0, error: null));
    _emit(
      _state.copyWith(
        buffering: false,
        width: 1920,
        height: 1080,
        position: source.isLive ? Duration.zero : position,
        selectedAudioId: audio,
        selectedSubtitleId: subtitle,
        playing: wasPlaying,
      ),
    );
    if (wasPlaying) _startTicker();
  }

  @override
  Future<String?> getProperty(String mpvName) async {
    if (_disposed) return null;
    _record('getProperty $mpvName');
    if (!_state.hasVideo) return null;
    final s = stats;
    final audio = _state.selectedAudioTrack;
    return switch (mpvName) {
      'video-params/w' || 'width' => '${s.width}',
      'video-params/h' || 'height' => '${s.height}',
      'estimated-vf-fps' || 'container-fps' => '25.000000',
      'video-codec' || 'video-format' => 'h264',
      'audio-codec-name' => audio?.codec ?? 'aac',
      'audio-params/channel-count' => '${audio?.channels ?? 2}',
      'audio-params/samplerate' => '48000',
      'hwdec-current' => s.hwdec,
      'aid' => _state.selectedAudioId ?? 'no',
      'sid' => _state.selectedSubtitleId ?? 'no',
      'cache-buffering-state' => '100',
      'demuxer-cache-duration' => s.cacheDurationSec.toStringAsFixed(6),
      'time-pos' => (_state.position.inMilliseconds / 1000).toStringAsFixed(6),
      'duration' => (_state.duration.inMilliseconds / 1000).toStringAsFixed(6),
      'mute' => _state.muted ? 'yes' : 'no',
      'volume' => _state.volume.toStringAsFixed(6),
      _ => null,
    };
  }

  @override
  Widget buildVideo({Key? key, BoxFit fit = BoxFit.contain}) {
    return _FakeVideo(key: key);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    calls.add('dispose');
    _disposed = true;
    _openTimer?.cancel();
    _stopTicker();
    await _stateController.close();
    await _statsController.close();
  }
}

class _FakeVideo extends StatelessWidget {
  const _FakeVideo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20232B), Color(0xFF0B0C0F)],
        ),
      ),
      child: Center(
        child: Text(
          'VIDEO',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: Color(0x40FFFFFF),
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
        ),
      ),
    );
  }
}
