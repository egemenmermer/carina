/// media_kit (libmpv) implementation of [PlaybackEngine].
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'engine_errors.dart';
import 'engine_mapping.dart';
import 'http_probe.dart';
import 'playback_engine.dart';
import 'track_language.dart';

/// Creates [MpvEngine]s.
class MpvEngineFactory implements PlaybackEngineFactory {
  const MpvEngineFactory();

  @override
  PlaybackEngine create({
    required EngineOptions options,
    bool preview = false,
  }) => MpvEngine(options: options, preview: preview);
}

/// One libmpv player plus its video texture.
///
/// mpv properties are computed by [mpvPropertiesFor] and applied before
/// every `open()`. Previews are muted and use the low-latency profile.
class MpvEngine implements PlaybackEngine {
  MpvEngine({required EngineOptions options, this.preview = false})
    : _options = options,
      _profile = preview ? EngineProfile.lowLatency : options.profile,
      _audioDelay = options.audioDelay,
      _subtitleDelay = options.subtitleDelay,
      _subtitleScale = options.subtitleScale,
      _deinterlace = options.deinterlaceMode,
      _aspect = ValueNotifier<AspectMode>(options.aspect) {
    MediaKit.ensureInitialized();
    _player = Player(
      configuration: PlayerConfiguration(
        title: 'Carina',
        logLevel: MPVLogLevel.warn,
        bufferSize: preview ? 16 * 1024 * 1024 : 32 * 1024 * 1024,
        // libass renders subtitles (text and bitmap) into the video texture,
        // so `sub-scale` / `sub-delay` apply directly.
        libass: true,
      ),
    );
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        hwdec: hwdecFor(
          profile: _profile,
          hardwareAcceleration: options.hardwareAcceleration,
        ),
        enableHardwareAcceleration: options.hardwareAcceleration,
      ),
    );
    _state = EngineState(muted: preview || options.muted);
    _stats = EngineStats(profile: _concreteProfile);
    _listen();
    _ready = _initialize();
  }

  /// Preview engines are muted at start and use the low-latency profile.
  final bool preview;

  final EngineOptions _options;
  EngineProfile _profile;
  late final Player _player;
  late final VideoController _controller;
  late final Future<void> _ready;

  NativePlayer get _native => _player.platform! as NativePlayer;

  final StreamController<EngineState> _stateController =
      StreamController<EngineState>.broadcast();
  late final StreamController<EngineStats> _statsController =
      StreamController<EngineStats>.broadcast(
        onListen: _startStatsTimer,
        onCancel: _stopStatsTimer,
      );
  late EngineState _state;
  late EngineStats _stats;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _disposed = false;
  Future<void>? _disposeFuture;

  // Session values the user changed in the player; they survive reopens.
  Duration _audioDelay;
  Duration _subtitleDelay;
  double _subtitleScale;
  DeinterlaceMode _deinterlace;
  final ValueNotifier<AspectMode> _aspect;

  // Per-open bookkeeping.
  PlaybackSource? _source;
  int _generation = 0;
  bool _accept = false;
  bool _collectLog = false;
  bool _firstFrameSeen = false;
  bool _mediaStarted = false;
  bool _audioPrefApplied = false;
  bool _subtitlePrefApplied = false;
  bool _autoDeinterlaceEngaged = false;
  bool _userStopped = false;
  int _diagnosingGeneration = -1;
  final Stopwatch _openClock = Stopwatch();
  _TrackRestore? _restore;
  final List<String> _openLog = [];
  final Set<String> _externalSubtitleIds = {};

  /// External subtitles added for the current source, re-added after a
  /// reopen (profile switch, retry, fallback).
  final List<String> _externalSubtitles = [];
  bool _readdExternal = false;

  // Fallback / retry.
  String? _forcedSoftwareUrl;
  bool _fallbackHappened = false;
  int _retryAttempt = 0;
  int _liveStalls = 0;

  // Timers.
  Timer? _retryTimer;
  Timer? _openWatchdog;
  Timer? _videoWatchdog;
  Timer? _healthyTimer;
  Timer? _statsTimer;
  Timer? _positionTimer;
  final List<Timer> _deinterlaceTimers = [];
  bool _statsBusy = false;

  // Position throttling (media_kit reports time-pos on every frame).
  static const Duration _positionInterval = Duration(milliseconds: 250);
  Duration? _pendingPosition;
  Duration? _pendingBuffered;
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  // Diagnostics.
  final ListQueue<String> _recentLog = ListQueue<String>();
  static const int _recentLogLimit = 200;

  /// Whether this libmpv accepts `deinterlace=auto` (checked once).
  static bool? _deinterlaceAutoSupported;

  /// Deinterlace filters this libmpv build has (checked once).
  static Set<DeinterlaceMethod>? _deinterlaceFilters;

  /// The last mpv warning/error lines (URLs masked), newest last.
  List<String> get recentLog => List.unmodifiable(_recentLog);

  /// Whether [dispose] was called.
  bool get isDisposed => _disposed;

  /// Whether this libmpv accepts `deinterlace=auto` (null until the first
  /// engine finished initializing).
  static bool? get deinterlaceAutoSupported => _deinterlaceAutoSupported;

  /// Deinterlace filters available in this libmpv build (null until the
  /// first engine finished initializing; empty with the media_kit builds).
  static Set<DeinterlaceMethod>? get deinterlaceFilters => _deinterlaceFilters;

  /// Diagnostics (stats overlay, engine probe): sets a raw mpv property.
  Future<void> setRawProperty(String name, String value) async {
    if (_disposed) return;
    await _ready;
    await _setProperty(name, value);
  }

  /// Diagnostics: runs a raw mpv command.
  Future<void> runCommand(List<String> args) async {
    if (_disposed) return;
    await _ready;
    await _command(args);
  }

  @override
  Stream<EngineState> get stateStream => _stateController.stream;

  @override
  EngineState get state => _state;

  @override
  Stream<EngineStats> get statsStream => _statsController.stream;

  @override
  EngineStats get stats => _stats;

  @override
  EngineOptions get options => _options;

  @override
  EngineProfile get profile => _profile;

  @override
  List<EngineTrack> get audioTracks => _state.audioTracks;

  @override
  List<EngineTrack> get subtitleTracks => _state.subtitleTracks;

  bool get _forceSoftware =>
      _source != null && _forcedSoftwareUrl == _source!.url;

  EngineProfile get _concreteProfile => concreteProfile(
    _profile,
    hardwareAcceleration: _options.hardwareAcceleration,
    forceSoftware: _forceSoftware,
  );

  EngineOptions get _sessionOptions => _options.copyWith(
    profile: _profile,
    audioDelay: _audioDelay,
    subtitleDelay: _subtitleDelay,
    subtitleScale: _subtitleScale,
    deinterlaceMode: _deinterlace,
    aspect: _aspect.value,
  );

  bool _stale(int generation) => _disposed || generation != _generation;

  // ---------------------------------------------------------------------------
  // Setup

  Future<void> _initialize() async {
    final muted = _state.muted;
    await _native.setProperty('mute', muted ? 'yes' : 'no');
    await _native.setProperty('audio-fallback-to-null', 'yes');
    await _native.observeProperty('idle-active', _onIdleActive);
    if (_deinterlaceAutoSupported == null) {
      await _native.setProperty('deinterlace', 'auto');
      _deinterlaceAutoSupported =
          (await _native.getProperty('deinterlace')) == 'auto';
      await _native.setProperty('deinterlace', 'no');
    }
    if (_deinterlaceFilters == null) {
      // mpv rejects `vf` values naming filters the build does not have.
      final found = <DeinterlaceMethod>{};
      for (final method in DeinterlaceMethod.values) {
        await _native.setProperty('vf', deinterlaceFilterFor(method));
        if ((await _native.getProperty('vf')).isNotEmpty) found.add(method);
        await _native.setProperty('vf', '');
      }
      _deinterlaceFilters = found;
    }
  }

  void _listen() {
    final s = _player.stream;
    _subscriptions.addAll([
      s.position.listen(_onPosition),
      s.buffer.listen(_onBuffer),
      s.duration.listen((d) {
        if (_accept) _setState(_state.copyWith(duration: d));
      }),
      // Not gated: media_kit emits `playing: true` inside open(), before the
      // engine starts accepting the new file's events.
      s.playing.listen((p) {
        if (_source != null) _setState(_state.copyWith(playing: p));
      }),
      s.buffering.listen(_onBuffering),
      s.bufferingPercentage.listen((v) {
        if (_accept) _setState(_state.copyWith(bufferingPercent: v));
      }),
      s.completed.listen(_onCompleted),
      s.width.listen((_) => _onVideoSize()),
      s.height.listen((_) => _onVideoSize()),
      s.volume.listen((v) => _setState(_state.copyWith(volume: v))),
      s.rate.listen((r) => _setState(_state.copyWith(rate: r))),
      s.tracks.listen((_) => unawaited(_onTracksChanged())),
      s.audioParams.listen(_onAudioParams),
      s.log.listen(_onLog),
      s.error.listen(_onErrorText),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Open / reopen

  @override
  Future<void> open(
    PlaybackSource source, {
    Duration? start,
    bool autoplay = true,
  }) async {
    if (_disposed) return;
    _retryAttempt = 0;
    _liveStalls = 0;
    _restore = null;
    _externalSubtitles.clear();
    if (_forcedSoftwareUrl != source.url) {
      _forcedSoftwareUrl = null;
      _fallbackHappened = false;
    }
    await _openInternal(source, start: start, autoplay: autoplay);
  }

  Future<void> _openInternal(
    PlaybackSource source, {
    Duration? start,
    bool autoplay = true,
  }) async {
    final generation = ++_generation;
    _resetOpenState();
    _source = source;
    _setState(
      EngineState(
        source: source,
        buffering: true,
        volume: _state.volume,
        muted: _state.muted,
        rate: _state.rate,
        reconnectAttempt: _retryAttempt,
      ),
      force: true,
    );
    _stats = EngineStats(
      profile: _concreteProfile,
      fallbackHappened: _fallbackHappened,
    );
    try {
      await _ready;
      if (_stale(generation)) return;
      final props = mpvPropertiesFor(
        _sessionOptions,
        source,
        profile: _profile,
        forceSoftware: _forceSoftware,
        deinterlaceAutoSupported: _deinterlaceAutoSupported ?? false,
        deinterlaceFilters: _deinterlaceFilters ?? const {},
        liveStallCount: _liveStalls,
      );
      // Unload the previous file first so hwdec/aid changes do not reinit
      // its decoders (that would slow zapping down).
      await _player.stop();
      if (_stale(generation)) return;
      await _applyProperties(props);
      if (_stale(generation)) return;
      _collectLog = true;
      _openClock
        ..reset()
        ..start();
      final startAt = start != null && start > Duration.zero ? start : null;
      await _player.open(
        Media(
          source.url,
          // Always a map (never null): media_kit caches headers per URL.
          httpHeaders: httpHeadersFor(source),
          start: startAt,
        ),
        play: autoplay,
      );
      if (_stale(generation)) return;
      _accept = true;
      _syncFromPlayer();
      _openWatchdog = Timer(
        Duration(seconds: _options.networkTimeoutSeconds + 5),
        () => _onOpenTimeout(generation),
      );
    } catch (error) {
      if (_stale(generation)) return;
      _fail(
        generation,
        EngineError(
          kind: EngineErrorKind.unknown,
          message: 'Playback failed.',
          detail: scrubUrls(error.toString()),
        ),
      );
    }
  }

  void _resetOpenState() {
    _cancelOpenTimers();
    _accept = false;
    _collectLog = false;
    _firstFrameSeen = false;
    _mediaStarted = false;
    _audioPrefApplied = false;
    _subtitlePrefApplied = false;
    _autoDeinterlaceEngaged = false;
    _userStopped = false;
    _pendingPosition = null;
    _pendingBuffered = null;
    _openLog.clear();
    _externalSubtitleIds.clear();
    _readdExternal = _externalSubtitles.isNotEmpty;
  }

  void _cancelOpenTimers() {
    _retryTimer?.cancel();
    _openWatchdog?.cancel();
    _videoWatchdog?.cancel();
    _healthyTimer?.cancel();
    _positionTimer?.cancel();
    for (final t in _deinterlaceTimers) {
      t.cancel();
    }
    _deinterlaceTimers.clear();
    _retryTimer = null;
    _openWatchdog = null;
    _videoWatchdog = null;
    _healthyTimer = null;
    _positionTimer = null;
  }

  Future<void> _applyProperties(Map<String, String> props) async {
    for (final entry in props.entries) {
      final key = entry.key;
      final value = entry.value;
      if (kMediaKitManagedProperties.contains(key)) continue;
      if (key == 'profile') {
        await _applyMpvProfile(value);
        continue;
      }
      final list = kListOptionSuffix.firstMatch(key);
      if (list != null) {
        await _command(['change-list', list.group(1)!, list.group(2)!, value]);
        continue;
      }
      await _setProperty(key, value);
    }
  }

  /// `profile=low-latency`. libmpv 0.36 accepts `profile` as a runtime property
  /// (the probe checks it; `apply-profile` works too). Failures do not matter:
  /// the explicit values that follow set the same options.
  Future<void> _applyMpvProfile(String name) async {
    await _setProperty('profile', name);
  }

  Future<void> _setProperty(String name, String value) async {
    if (_disposed) return;
    try {
      await _native.setProperty(name, value);
    } catch (error) {
      _pushLog('[carina] setProperty $name failed: $error');
    }
  }

  Future<void> _command(List<String> args) async {
    if (_disposed) return;
    try {
      await _native.command(args);
    } catch (error) {
      _pushLog('[carina] command ${args.first} failed: $error');
    }
  }

  /// Picks up values media_kit already has for the new file.
  void _syncFromPlayer() {
    final s = _player.state;
    _setState(_state.copyWith(playing: s.playing));
    _onVideoSize();
    if ((s.audioParams.channelCount ?? 0) > 0) _onAudioParams(s.audioParams);
    unawaited(_onTracksChanged());
  }

  // ---------------------------------------------------------------------------
  // media_kit events

  void _onPosition(Duration position) {
    if (!_accept) return;
    _pendingPosition = position;
    _schedulePositionEmit();
  }

  void _onBuffer(Duration buffered) {
    if (!_accept) return;
    _pendingBuffered = buffered;
    _schedulePositionEmit();
  }

  void _schedulePositionEmit() {
    if (_positionTimer?.isActive ?? false) return;
    final since = DateTime.now().difference(_lastEmit);
    if (since >= _positionInterval) {
      _setState(_state);
    } else {
      _positionTimer = Timer(_positionInterval - since, () {
        if (!_disposed) _setState(_state);
      });
    }
  }

  void _onBuffering(bool buffering) {
    if (!_accept) return;
    final source = _source;
    if (buffering &&
        _firstFrameSeen &&
        _state.playing &&
        source != null &&
        source.isLive &&
        !_state.buffering) {
      _liveStalls++;
      if (_options.bufferPolicy == BufferPolicy.auto &&
          _profile != EngineProfile.lowLatency) {
        final secs = liveCacheSecondsFor(
          BufferPolicy.auto,
          stallCount: _liveStalls,
        );
        unawaited(_setProperty('cache-secs', '$secs'));
      }
    }
    _setState(_state.copyWith(buffering: buffering));
  }

  void _onCompleted(bool completed) {
    if (!_accept) return;
    if (!completed) {
      if (_state.completed) _setState(_state.copyWith(completed: false));
      return;
    }
    final source = _source;
    if (source != null && source.isLive) {
      _onFailure(_generation, known: endedError());
      return;
    }
    _setState(
      _state.copyWith(completed: true, playing: false, buffering: false),
    );
  }

  void _onVideoSize() {
    if (!_accept) return;
    final w = _player.state.width ?? 0;
    final h = _player.state.height ?? 0;
    if (w > 0 && h > 0 && !_firstFrameSeen) {
      _firstFrameSeen = true;
      _videoWatchdog?.cancel();
      _onMediaStarted();
      _scheduleDeinterlaceDetection();
    }
    if (w != _state.width || h != _state.height) {
      _setState(_state.copyWith(width: w, height: h));
    }
  }

  void _onAudioParams(AudioParams params) {
    if (!_accept) return;
    if ((params.channelCount ?? 0) <= 0 && (params.sampleRate ?? 0) <= 0) {
      return;
    }
    if (!_mediaStarted) _onMediaStarted();
    _armVideoWatchdog();
  }

  void _onMediaStarted() {
    _mediaStarted = true;
    _openWatchdog?.cancel();
    // The buffering=false edge may have come before the file was accepted.
    if (!_player.state.buffering && _state.buffering) {
      _setState(_state.copyWith(buffering: false));
    }
    final generation = _generation;
    _healthyTimer?.cancel();
    _healthyTimer = Timer(const Duration(seconds: 10), () {
      if (_stale(generation)) return;
      _retryAttempt = 0;
      if (_state.reconnectAttempt != 0) {
        _setState(_state.copyWith(reconnectAttempt: 0));
      }
    });
  }

  /// Auto profile: audio plays but no video frame arrives → hardware
  /// decoding is broken; reopen with software decoding.
  void _armVideoWatchdog() {
    if (_firstFrameSeen || _videoWatchdog != null) return;
    if (_profile != EngineProfile.auto || _forceSoftware) return;
    if (!_options.hardwareAcceleration) return;
    final generation = _generation;
    _videoWatchdog = Timer(const Duration(seconds: 4), () {
      if (_stale(generation) || _firstFrameSeen) return;
      if (!_hasVideoTrack()) return;
      _fallbackToSoftware(
        'no video frames 4 s after audio started',
        reopen: true,
      );
    });
  }

  /// media_kit lists always contain `auto` and `no`; anything more means the
  /// file's tracks are known.
  bool _fileLoaded() {
    final t = _player.state.tracks;
    return t.video.length + t.audio.length + t.subtitle.length > 6;
  }

  bool _hasVideoTrack() => _player.state.tracks.video.any(
    (t) =>
        t.id != 'auto' && t.id != 'no' && t.albumart != true && t.image != true,
  );

  void _onLog(PlayerLog log) {
    final level = log.level.toLowerCase();
    if (level != 'error' && level != 'warn' && level != 'fatal') return;
    final line = scrubUrls('[${log.prefix}] ${log.text}');
    _pushLog(line);
    // media_kit's own command/property failures (e.g. an unsupported
    // option) are not playback errors.
    if (log.prefix == 'media_kit') return;
    if (_collectLog) {
      _openLog.add(line);
      if (_openLog.length > 100) _openLog.removeAt(0);
    }
    if (_accept && isHwdecFailureLine(log.prefix, log.text)) {
      _onHardwareDecoderFailure(line);
    }
  }

  void _onErrorText(String text) {
    if (!_collectLog) return;
    final line = scrubUrls('[error] $text');
    if (!_openLog.contains(line)) _openLog.add(line);
  }

  void _pushLog(String line) {
    _recentLog.addLast(line);
    while (_recentLog.length > _recentLogLimit) {
      _recentLog.removeFirst();
    }
  }

  /// Called from media_kit's event loop, which awaits it: never wait here
  /// (a pending mpv reply would deadlock, a delay would stall all events).
  Future<void> _onIdleActive(String value) async {
    if (value != 'yes' || !_accept || _userStopped || _source == null) return;
    final generation = _generation;
    // The notification can be stale (media_kit's open() passes through
    // idle); confirm a moment later before treating it as a failed load.
    Timer(const Duration(milliseconds: 300), () {
      unawaited(_confirmIdle(generation));
    });
  }

  Future<void> _confirmIdle(int generation) async {
    if (_stale(generation) || !_accept || _userStopped) return;
    final idle = await getProperty('idle-active');
    if (idle != 'yes' || _stale(generation)) return;
    if (_state.completed) return;
    final source = _source;
    if (source != null && source.isLive && _mediaStarted) {
      _onFailure(generation, known: endedError());
      return;
    }
    _onFailure(generation);
  }

  void _onOpenTimeout(int generation) {
    if (_stale(generation) || _mediaStarted) return;
    _onFailure(generation, timedOut: true);
  }

  void _onHardwareDecoderFailure(String line) {
    if (_forceSoftware || !_options.hardwareAcceleration) return;
    if (_profile == EngineProfile.software) return;
    _fallbackHappened = true;
    _stats = _stats.copyWith(fallbackHappened: true);
    if (_profile != EngineProfile.auto) return;
    _fallbackToSoftware(line, reopen: false);
  }

  /// Pins software decoding for the current source.
  void _fallbackToSoftware(String reason, {required bool reopen}) {
    final source = _source;
    if (source == null || _disposed) return;
    _pushLog('[carina] hwdec fallback to software: $reason');
    _fallbackHappened = true;
    _forcedSoftwareUrl = source.url;
    _stats = _stats.copyWith(
      fallbackHappened: true,
      profile: EngineProfile.software,
    );
    if (!reopen) {
      // mpv reinitialises the decoder in place.
      unawaited(_setProperty('hwdec', 'no'));
      return;
    }
    _restore = _TrackRestore.of(_state);
    final position = _state.position;
    unawaited(
      _openInternal(
        source,
        start: source.isLive ? null : position,
        autoplay: _state.playing || !_firstFrameSeen,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Errors and live auto-retry

  /// A load failed, a live stream ended, or the open watchdog fired.
  void _onFailure(int generation, {EngineError? known, bool timedOut = false}) {
    unawaited(_handleFailure(generation, known: known, timedOut: timedOut));
  }

  /// Classification from this player's own mpv messages. FFmpeg's lines
  /// (`[ffmpeg…]`) are left out: libmpv delivers them to one player only.
  EngineError _quickError({bool timedOut = false}) => errorFromLogLines(
    _openLog.where((l) => !isSharedFfmpegLine(l)),
    timedOut: timedOut,
  );

  /// The readable error for a failure that will be shown.
  Future<EngineError> _diagnose(
    PlaybackSource source, {
    required bool timedOut,
    required EngineError quick,
  }) async {
    if (quick.kind == EngineErrorKind.codec) return quick;
    if (isHttpUrl(source.url)) {
      final limit = Duration(seconds: _options.networkTimeoutSeconds);
      if (timedOut || _openClock.elapsed >= limit * 0.9) {
        return timeoutError();
      }
      final probed = await probeHttpFailure(
        source.url,
        headers: httpHeadersFor(source),
        userAgent: userAgentFor(_options, source),
        timeout: Duration(seconds: math.min(_options.networkTimeoutSeconds, 6)),
      );
      if (probed != null) return probed;
    }
    // Last resort: every line seen, FFmpeg's included.
    return errorFromLogLines(_openLog, timedOut: timedOut);
  }

  Future<void> _handleFailure(
    int generation, {
    EngineError? known,
    bool timedOut = false,
  }) async {
    if (_stale(generation) || _state.error != null) return;
    if (_diagnosingGeneration == generation) return;
    final source = _source;
    if (source == null) return;
    _cancelOpenTimers();
    _accept = false;
    _collectLog = false;
    final quick = known ?? _quickError(timedOut: timedOut);
    if (source.isLive &&
        quick.retryable &&
        _retryAttempt < _options.reconnectAttempts) {
      final error = quick;
      _retryAttempt++;
      final delay = Duration(seconds: 1 << (_retryAttempt - 1));
      _pushLog(
        '[carina] live retry $_retryAttempt/${_options.reconnectAttempts} '
        'in ${delay.inSeconds}s after ${error.kind.name}',
      );
      _setState(
        _state.copyWith(
          buffering: true,
          playing: false,
          reconnectAttempt: _retryAttempt,
          error: null,
        ),
      );
      _retryTimer = Timer(delay, () {
        if (_stale(generation)) return;
        _restore = _TrackRestore.of(_state);
        unawaited(_openInternal(source));
      });
      return;
    }
    _diagnosingGeneration = generation;
    final error =
        known ?? await _diagnose(source, timedOut: timedOut, quick: quick);
    if (_stale(generation)) return;
    _fail(generation, error);
  }

  void _fail(int generation, EngineError error) {
    if (_stale(generation)) return;
    _cancelOpenTimers();
    _accept = false;
    _pushLog('[carina] error ${error.kind.name}: ${error.message}');
    _setState(
      _state.copyWith(
        error: error,
        buffering: false,
        playing: false,
        reconnectAttempt: 0,
      ),
    );
    unawaited(_player.stop().catchError((Object _) {}));
  }

  // ---------------------------------------------------------------------------
  // Tracks

  Future<void> _onTracksChanged() async {
    if (!_accept || _player.state.completed) return;
    final generation = _generation;
    if (_readdExternal && _fileLoaded()) {
      // The file is loaded: put the external subtitles back (same order, so
      // they get the same track ids as before the reopen).
      _readdExternal = false;
      for (final path in List<String>.of(_externalSubtitles)) {
        await _addExternal(path, select: false);
        if (_stale(generation)) return;
      }
    }
    final tracks = await _readTracks();
    if (_stale(generation) || !_accept) return;
    if (tracks.audio.isEmpty &&
        tracks.subtitle.isEmpty &&
        _state.audioTracks.isEmpty &&
        _state.subtitleTracks.isEmpty &&
        tracks.selectedAudio == null) {
      return;
    }
    _setState(
      _state.copyWith(
        audioTracks: tracks.audio,
        subtitleTracks: tracks.subtitle,
        selectedAudioId: tracks.selectedAudio,
        selectedSubtitleId: tracks.selectedSubtitle,
      ),
    );
    await _applyTrackPreferences(generation);
  }

  Future<_TrackSnapshot> _readTracks() async {
    final raw = await getProperty('track-list');
    if (raw != null && raw.startsWith('[')) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return _TrackSnapshot.fromMpvJson(list, _externalSubtitleIds);
      } catch (_) {
        // Fall through to media_kit's parsed list.
      }
    }
    final aid = await getProperty('aid');
    final sid = await getProperty('sid');
    return _TrackSnapshot.fromMediaKit(
      _player.state.tracks,
      aid: aid,
      sid: sid,
      external: _externalSubtitleIds,
    );
  }

  Future<void> _applyTrackPreferences(int generation) async {
    final restore = _restore;
    final audio = _state.audioTracks;
    if (!_audioPrefApplied && audio.isNotEmpty) {
      _audioPrefApplied = true;
      final target = restore?.audioId != null
          ? audio.firstWhereOrNull((t) => t.id == restore!.audioId)
          : pickPreferredTrack(audio, _options.preferredAudioLanguage);
      if (target != null && target.id != _state.selectedAudioId) {
        await selectAudio(target);
      }
    }
    if (_stale(generation)) return;
    final subtitles = _state.subtitleTracks;
    if (!_subtitlePrefApplied && (subtitles.isNotEmpty || restore != null)) {
      if (restore != null) {
        _subtitlePrefApplied = true;
        final target = restore.subtitleId == null
            ? null
            : subtitles.firstWhereOrNull((t) => t.id == restore.subtitleId);
        if (target?.id != _state.selectedSubtitleId) {
          await selectSubtitle(target);
        }
      } else if (subtitles.isNotEmpty) {
        _subtitlePrefApplied = true;
        if (_options.subtitlesDisabled) {
          if (_state.selectedSubtitleId != null) await selectSubtitle(null);
        } else {
          final target = pickPreferredTrack(
            subtitles,
            _options.preferredSubtitleLanguage,
          );
          if (target != null && target.id != _state.selectedSubtitleId) {
            await selectSubtitle(target);
          }
        }
      }
    }
  }

  @override
  Future<void> selectAudio(EngineTrack t) async {
    if (_disposed) return;
    await _ready;
    if (_disposed) return;
    await _player.setAudioTrack(AudioTrack(t.id, t.title, t.language));
    _setState(_state.copyWith(selectedAudioId: t.id));
  }

  @override
  Future<void> selectSubtitle(EngineTrack? t) async {
    if (_disposed) return;
    await _ready;
    if (_disposed) return;
    if (t == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      _setState(_state.copyWith(selectedSubtitleId: null));
    } else {
      await _player.setSubtitleTrack(SubtitleTrack(t.id, t.title, t.language));
      _setState(_state.copyWith(selectedSubtitleId: t.id));
    }
  }

  @override
  Future<void> addExternalSubtitle(String pathOrUri) async {
    if (_disposed || _source == null) return;
    await _ready;
    if (_disposed) return;
    _externalSubtitles.add(pathOrUri);
    await _addExternal(pathOrUri, select: true);
    await _onTracksChanged();
  }

  Future<void> _addExternal(String pathOrUri, {required bool select}) async {
    final before = await getProperty('track-list/count');
    await _command([
      'sub-add',
      pathOrUri,
      select ? 'select' : 'auto',
      _basename(pathOrUri),
    ]);
    // The newest track is appended; remember its id as external in case the
    // track list JSON is unavailable.
    final count = int.tryParse(before ?? '') ?? 0;
    final id = await getProperty('track-list/$count/id');
    if (id != null) _externalSubtitleIds.add(id);
  }

  // ---------------------------------------------------------------------------
  // Transport

  @override
  Future<void> play() async {
    if (_disposed) return;
    await _ready;
    if (_disposed) return;
    final source = _source;
    if (_state.error != null && source != null) {
      // "Retry" from the error overlay.
      return open(source, start: source.isLive ? null : _state.position);
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await _ready;
    if (_disposed) return;
    await _player.pause();
  }

  @override
  Future<void> playOrPause() async {
    if (_disposed) return;
    if (_state.playing) return pause();
    return play();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await _ready;
    if (_disposed) return;
    final target = position < Duration.zero ? Duration.zero : position;
    _pendingPosition = target;
    _setState(_state.copyWith(position: target, completed: false));
    await _player.seek(target);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _generation++;
    _cancelOpenTimers();
    _userStopped = true;
    _accept = false;
    _collectLog = false;
    _source = null;
    _setState(
      EngineState(
        volume: _state.volume,
        muted: _state.muted,
        rate: _state.rate,
      ),
      force: true,
    );
    await _ready;
    if (_disposed) return;
    await _player.stop();
  }

  @override
  Future<void> setVolume(double v0to100) async {
    if (_disposed) return;
    final v = v0to100.clamp(0.0, 100.0).toDouble();
    _setState(_state.copyWith(volume: v));
    await _ready;
    if (_disposed) return;
    await _player.setVolume(v);
  }

  @override
  Future<void> setMuted(bool m) async {
    if (_disposed) return;
    _setState(_state.copyWith(muted: m));
    await _ready;
    await _setProperty('mute', m ? 'yes' : 'no');
  }

  @override
  Future<void> setRate(double rate) async {
    if (_disposed) return;
    await _ready;
    if (_disposed) return;
    await _player.setRate(rate.clamp(0.25, 4.0).toDouble());
  }

  @override
  Future<void> setAudioDelay(Duration d) async {
    if (_disposed) return;
    _audioDelay = d;
    await _ready;
    await _setProperty('audio-delay', formatSeconds(d));
  }

  @override
  Future<void> setSubtitleDelay(Duration d) async {
    if (_disposed) return;
    _subtitleDelay = d;
    await _ready;
    await _setProperty('sub-delay', formatSeconds(d));
  }

  @override
  Future<void> setSubtitleScale(double s) async {
    if (_disposed) return;
    _subtitleScale = s;
    await _ready;
    await _setProperty('sub-scale', formatScale(s));
  }

  @override
  Future<void> setAspect(AspectMode m) async {
    if (_disposed) return;
    _aspect.value = m;
    await _ready;
    for (final e in aspectPropertiesFor(m).entries) {
      await _setProperty(e.key, e.value);
    }
  }

  @override
  Future<void> setDeinterlace(DeinterlaceMode m) async {
    if (_disposed) return;
    _deinterlace = m;
    _autoDeinterlaceEngaged = false;
    for (final t in _deinterlaceTimers) {
      t.cancel();
    }
    _deinterlaceTimers.clear();
    await _ready;
    final props = deinterlacePropertiesFor(
      m,
      _options.deinterlaceMethod,
      autoSupported: _deinterlaceAutoSupported ?? false,
      availableFilters: _deinterlaceFilters ?? const {},
    );
    for (final e in props.entries) {
      await _setProperty(e.key, e.value);
    }
    if (m == DeinterlaceMode.auto && _firstFrameSeen) {
      _scheduleDeinterlaceDetection();
    }
  }

  /// libmpv 0.36 has no `deinterlace=auto`: look at the first frames and
  /// enable mpv's deinterlacer (hardware-aware) when they are interlaced.
  void _scheduleDeinterlaceDetection() {
    if (_deinterlace != DeinterlaceMode.auto) return;
    if (_deinterlaceAutoSupported ?? false) return;
    if (_autoDeinterlaceEngaged) return;
    final generation = _generation;
    for (final ms in const [200, 700, 1500, 3000]) {
      _deinterlaceTimers.add(
        Timer(Duration(milliseconds: ms), () async {
          if (_stale(generation) || _autoDeinterlaceEngaged) return;
          if (_deinterlace != DeinterlaceMode.auto) return;
          final interlaced = await getProperty('video-frame-info/interlaced');
          if (_stale(generation) || _autoDeinterlaceEngaged) return;
          if (interlaced == 'yes') {
            _autoDeinterlaceEngaged = true;
            _pushLog('[carina] interlaced video detected: deinterlace=yes');
            await _setProperty('deinterlace', 'yes');
          }
        }),
      );
    }
  }

  @override
  Future<void> switchProfile(EngineProfile p) async {
    if (_disposed) return;
    _profile = p;
    _forcedSoftwareUrl = null;
    _fallbackHappened = false;
    final source = _source;
    _stats = _stats.copyWith(
      profile: _concreteProfile,
      fallbackHappened: false,
    );
    if (source == null) return;
    final position = _state.position;
    // After a failure (the error overlay's "Switch player") the reopened
    // stream must play: `playing` is false then, and a live stream has no
    // play button.
    final autoplay = _state.playing || !_firstFrameSeen || _state.error != null;
    _restore = _TrackRestore.of(_state);
    _retryAttempt = 0;
    await _openInternal(
      source,
      start: source.isLive || position < const Duration(seconds: 1)
          ? null
          : position,
      autoplay: autoplay,
    );
  }

  @override
  Future<String?> getProperty(String mpvName) async {
    if (_disposed) return null;
    try {
      await _ready;
      if (_disposed) return null;
      final value = await _native.getProperty(mpvName);
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Stats

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_emitStats());
    });
    unawaited(_emitStats());
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> _emitStats() async {
    if (_disposed || _statsBusy) return;
    _statsBusy = true;
    try {
      final sample = await sampleStats();
      if (!_disposed && !_statsController.isClosed) {
        _statsController.add(sample);
      }
    } finally {
      _statsBusy = false;
    }
  }

  /// Reads the stats properties now.
  Future<EngineStats> sampleStats() async {
    if (_disposed || _source == null) return _stats;
    const names = [
      'video-params/w',
      'video-params/h',
      'estimated-vf-fps',
      'container-fps',
      'video-format',
      'video-codec',
      'audio-codec-name',
      'audio-params/channel-count',
      'audio-params/samplerate',
      'hwdec-current',
      'cache-buffering-state',
      'demuxer-cache-duration',
      'frame-drop-count',
      'decoder-frame-drop-count',
      'video-bitrate',
      'audio-bitrate',
      'deinterlace',
      'vf',
    ];
    final values = <String, String?>{};
    for (final name in names) {
      values[name] = await getProperty(name);
    }
    int? asInt(String name) =>
        int.tryParse(values[name] ?? '') ??
        double.tryParse(values[name] ?? '')?.round();
    double? asDouble(String name) => double.tryParse(values[name] ?? '');
    final fps = asDouble('estimated-vf-fps') ?? asDouble('container-fps') ?? 0;
    final videoCodec =
        values['video-format'] ?? values['video-codec']?.split(' ').first;
    final vf = values['vf'] ?? '';
    final sample = EngineStats(
      width: asInt('video-params/w') ?? _state.width,
      height: asInt('video-params/h') ?? _state.height,
      fps: fps,
      videoCodec: videoCodec,
      audioCodec: values['audio-codec-name'],
      audioChannels: asInt('audio-params/channel-count') ?? 0,
      sampleRate: asInt('audio-params/samplerate') ?? 0,
      hwdec: values['hwdec-current'],
      cacheDurationSec: asDouble('demuxer-cache-duration') ?? 0,
      bufferingPercent:
          asDouble('cache-buffering-state') ?? _state.bufferingPercent,
      droppedFrames:
          (asInt('frame-drop-count') ?? 0) +
          (asInt('decoder-frame-drop-count') ?? 0),
      profile: _concreteProfile,
      fallbackHappened: _fallbackHappened,
      videoBitrate: asInt('video-bitrate'),
      audioBitrate: asInt('audio-bitrate'),
      deinterlacing:
          values['deinterlace'] == 'yes' ||
          vf.contains('bwdif') ||
          vf.contains('yadif'),
    );
    _stats = sample;
    return sample;
  }

  // ---------------------------------------------------------------------------
  // State plumbing

  void _setState(EngineState next, {bool force = false}) {
    if (_disposed) return;
    var s = next;
    if (!force) {
      final p = _pendingPosition;
      final b = _pendingBuffered;
      if (p != null || b != null) {
        s = s.copyWith(position: p, buffered: b);
      }
    }
    _pendingPosition = null;
    _pendingBuffered = null;
    if (s == _state && !force) return;
    _state = s;
    _lastEmit = DateTime.now();
    if (!_stateController.isClosed) _stateController.add(s);
  }

  // ---------------------------------------------------------------------------
  // Widget

  @override
  Widget buildVideo({Key? key, BoxFit fit = BoxFit.contain}) {
    return _MpvVideoView(key: key, engine: this, fit: fit);
  }

  // ---------------------------------------------------------------------------
  // Dispose

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _generation++;
    _cancelOpenTimers();
    _stopStatsTimer();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    try {
      await _player.dispose();
    } catch (error) {
      debugPrint('MpvEngine.dispose: $error');
    }
    await _stateController.close();
    await _statsController.close();
  }
}

class _MpvVideoView extends StatelessWidget {
  const _MpvVideoView({super.key, required this.engine, required this.fit});

  final MpvEngine engine;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (engine._disposed) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    return ValueListenableBuilder<AspectMode>(
      valueListenable: engine._aspect,
      builder: (context, aspect, _) => Video(
        controller: engine._controller,
        controls: NoVideoControls,
        fit: boxFitForAspect(aspect, base: fit),
        fill: const Color(0xFF000000),
        wakelock: !engine.preview,
        pauseUponEnteringBackgroundMode: false,
        resumeUponEnteringForegroundMode: false,
      ),
    );
  }
}

/// Track choice to restore after a reopen (profile switch, retry, fallback).
class _TrackRestore {
  const _TrackRestore(this.audioId, this.subtitleId);

  factory _TrackRestore.of(EngineState s) =>
      _TrackRestore(s.selectedAudioId, s.selectedSubtitleId);

  final String? audioId;
  final String? subtitleId;
}

class _TrackSnapshot {
  const _TrackSnapshot(
    this.audio,
    this.subtitle,
    this.selectedAudio,
    this.selectedSubtitle,
  );

  /// Parses mpv's `track-list` JSON (libmpv returns node properties as JSON
  /// strings).
  factory _TrackSnapshot.fromMpvJson(
    List<dynamic> list,
    Set<String> knownExternal,
  ) {
    final audio = <EngineTrack>[];
    final subtitle = <EngineTrack>[];
    String? selectedAudio;
    String? selectedSubtitle;
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final type = item['type'];
      final id = '${item['id']}';
      final kind = switch (type) {
        'audio' => EngineTrackKind.audio,
        'sub' => EngineTrackKind.subtitle,
        _ => null,
      };
      if (kind == null) continue;
      final channels = item['demux-channel-count'] ?? item['audio-channels'];
      final track = EngineTrack(
        id: id,
        kind: kind,
        title: _nonEmpty(item['title']),
        language: _nonEmpty(item['lang']),
        codec: _nonEmpty(item['codec']),
        channels: channels is num ? channels.toInt() : null,
        isDefault: item['default'] == true,
        isExternal: item['external'] == true || knownExternal.contains(id),
      );
      final selected = item['selected'] == true;
      if (kind == EngineTrackKind.audio) {
        audio.add(track);
        if (selected) selectedAudio = id;
      } else {
        subtitle.add(track);
        if (selected) selectedSubtitle = id;
      }
    }
    return _TrackSnapshot(audio, subtitle, selectedAudio, selectedSubtitle);
  }

  factory _TrackSnapshot.fromMediaKit(
    Tracks tracks, {
    String? aid,
    String? sid,
    required Set<String> external,
  }) {
    bool real(String id) => id != 'auto' && id != 'no';
    final audio = [
      for (final t in tracks.audio)
        if (real(t.id))
          EngineTrack(
            id: t.id,
            kind: EngineTrackKind.audio,
            title: _nonEmpty(t.title),
            language: _nonEmpty(t.language),
            codec: _nonEmpty(t.codec),
            channels: t.channelscount ?? t.audiochannels,
            isDefault: t.isDefault ?? false,
          ),
    ];
    final subtitle = [
      for (final t in tracks.subtitle)
        if (real(t.id))
          EngineTrack(
            id: t.id,
            kind: EngineTrackKind.subtitle,
            title: _nonEmpty(t.title),
            language: _nonEmpty(t.language),
            codec: _nonEmpty(t.codec),
            isDefault: t.isDefault ?? false,
            isExternal: external.contains(t.id),
          ),
    ];
    String? numeric(String? v) =>
        v != null && int.tryParse(v) != null ? v : null;
    return _TrackSnapshot(audio, subtitle, numeric(aid), numeric(sid));
  }

  final List<EngineTrack> audio;
  final List<EngineTrack> subtitle;
  final String? selectedAudio;
  final String? selectedSubtitle;
}

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final v = value.trim();
  return v.isEmpty ? null : v;
}

String _basename(String pathOrUri) {
  final cleaned = pathOrUri.split('?').first;
  final parts = cleaned.split(RegExp(r'[\\/]'));
  final last = parts.lastWhere((p) => p.isNotEmpty, orElse: () => cleaned);
  return Uri.decodeComponent(last);
}
