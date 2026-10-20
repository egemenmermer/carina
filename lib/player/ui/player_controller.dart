/// Playback session logic behind the player screen: resolves what to play,
/// drives the [PlaybackEngine], saves resume positions, zaps channels and
/// offers the next episode. Widgets only render it.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
import '../../data/app_paths.dart' show appDatabaseProvider;
import '../../data/db/database.dart';
import '../../data/repositories/epg_repository.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/repositories/stream_url_resolver.dart';
import '../../data/repositories/vod_repository.dart';
import '../../data/repositories/watch_state_repository.dart';
import '../../data/settings/settings_store.dart';
import '../engine/playback_engine.dart';
import '../player_api.dart';
import 'data/player_queries.dart';
import 'player_chapters.dart';
import 'player_options.dart';

/// Everything the controller reads. [PlayerDeps.of] takes it from the app's
/// providers.
class PlayerDeps {
  const PlayerDeps({
    required this.factory,
    required this.settings,
    required this.resolver,
    required this.live,
    required this.epg,
    required this.vod,
    required this.watchState,
    required this.queries,
    required this.clock,
  });

  factory PlayerDeps.of(WidgetRef ref) => PlayerDeps(
    factory: ref.read(playbackEngineFactoryProvider),
    settings: ref.read(settingsStoreProvider),
    resolver: ref.read(streamUrlResolverProvider),
    live: ref.read(liveRepositoryProvider),
    epg: ref.read(epgRepositoryProvider),
    vod: ref.read(vodRepositoryProvider),
    watchState: ref.read(watchStateRepositoryProvider),
    queries: PlayerQueries(ref.read(appDatabaseProvider)),
    clock: ref.read(clockSourceProvider),
  );

  final PlaybackEngineFactory factory;
  final SettingsStore settings;
  final StreamUrlResolver resolver;
  final LiveRepository live;
  final EpgRepository epg;
  final VodRepository vod;
  final WatchStateRepository watchState;
  final PlayerQueries queries;
  final DateTime Function() clock;
}

/// Why nothing plays.
enum PlayerFailureKind {
  /// The engine reported [PlayerFailure.engineError].
  engine,

  /// The movie, episode or channel no longer exists.
  notFound,

  /// The channel has no catch-up (or no usable template).
  noCatchup,

  /// DRM-protected entry.
  unsupported,

  /// Xtream credentials are missing.
  missingCredentials,

  /// An M3U item without a URL.
  noStreamUrl,

  /// The playlist was deleted.
  playlistNotFound,
}

/// A failure shown by the error overlay.
@immutable
class PlayerFailure {
  const PlayerFailure(this.kind, {this.engineError});

  factory PlayerFailure.fromResolve(StreamResolveError error) => PlayerFailure(
    switch (error) {
      StreamResolveError.playlistNotFound => PlayerFailureKind.playlistNotFound,
      StreamResolveError.missingCredentials =>
        PlayerFailureKind.missingCredentials,
      StreamResolveError.noStreamUrl => PlayerFailureKind.noStreamUrl,
      StreamResolveError.unsupported => PlayerFailureKind.unsupported,
      StreamResolveError.noCatchup => PlayerFailureKind.noCatchup,
    },
  );

  final PlayerFailureKind kind;
  final EngineError? engineError;

  /// Retry can help (network and server errors; not DRM / missing data).
  bool get retryable => switch (kind) {
    PlayerFailureKind.engine => engineError?.retryable ?? true,
    PlayerFailureKind.missingCredentials ||
    PlayerFailureKind.playlistNotFound ||
    PlayerFailureKind.unsupported ||
    PlayerFailureKind.noCatchup ||
    PlayerFailureKind.noStreamUrl ||
    PlayerFailureKind.notFound => false,
  };

  @override
  bool operator ==(Object other) =>
      other is PlayerFailure &&
      other.kind == kind &&
      other.engineError == engineError;

  @override
  int get hashCode => Object.hash(kind, engineError);

  @override
  String toString() => 'PlayerFailure(${kind.name}, $engineError)';
}

/// Title, artwork and text of what plays (VOD and catch-up).
@immutable
class PlayerMediaInfo {
  const PlayerMediaInfo({
    required this.title,
    this.subtitle,
    this.overview,
    this.image,
    this.durationHint,
    this.technical,
  });

  /// Movie name, series name, or programme title.
  final String title;

  /// `S1 E2 · Pilot` for episodes, the channel for catch-up.
  final String? subtitle;
  final String? overview;

  /// Poster, episode still or programme icon.
  final String? image;

  /// Runtime from the provider (the engine's duration wins once known).
  final Duration? durationHint;
  final MediaTechnical? technical;

  PlayerMediaInfo copyWith({
    String? title,
    String? subtitle,
    String? overview,
    String? image,
    Duration? durationHint,
    MediaTechnical? technical,
  }) => PlayerMediaInfo(
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    overview: overview ?? this.overview,
    image: image ?? this.image,
    durationHint: durationHint ?? this.durationHint,
    technical: technical ?? this.technical,
  );
}

/// The Next episode card's state.
@immutable
class NextEpisodeOffer {
  const NextEpisodeOffer({required this.episode, this.countdown});

  final EpisodeItem episode;

  /// Seconds before it plays by itself; null when autoplay is off.
  final int? countdown;
}

/// Ask the user to unlock a parental-locked channel (null: no gate).
typedef ChannelUnlocker = Future<bool> Function(String channelId);

/// The volume last set in a player; the next player starts with it (the
/// app session only; mute is not carried over).
double? playerSessionVolume;

/// The playback session of one player screen.
class PlayerController extends ChangeNotifier {
  PlayerController({
    required PlayRequest request,
    required this.deps,
    this.unlockChannel,
  }) : _request = request,
       playlistId = request.playlistId,
       kind = switch (request) {
         LivePlayRequest() => PlayerKind.live,
         CatchupPlayRequest() => PlayerKind.catchup,
         VodPlayRequest() => PlayerKind.vod,
       } {
    options = playerEngineOptions(deps.settings, playlistId, kind);
    engine = deps.factory.create(options: options);
    _aspect = options.aspect;
    _deinterlace = options.deinterlaceMode;
    _audioDelay = options.audioDelay;
    _subtitleDelay = options.subtitleDelay;
    _subtitleSize = SubtitleSize.fromScale(options.subtitleScale);
    _state = engine.state;
    _stats = engine.stats;
    _stateSub = engine.stateStream.listen(_onState);
    _statsSub = engine.statsStream.listen(_onStats);
    final volume = playerSessionVolume;
    if (volume != null && volume != _state.volume) {
      unawaited(engine.setVolume(volume));
    }
  }

  final PlayerDeps deps;
  final ChannelUnlocker? unlockChannel;
  final int playlistId;
  final PlayerKind kind;
  late final EngineOptions options;
  late final PlaybackEngine engine;

  PlayRequest _request;
  late EngineState _state;
  late EngineStats _stats;
  StreamSubscription<EngineState>? _stateSub;
  StreamSubscription<EngineStats>? _statsSub;
  bool _disposed = false;
  bool _started = false;

  /// The request currently playing (changes with the next episode).
  PlayRequest get request => _request;
  EngineState get state => _state;
  EngineStats get stats => _stats;
  EngineProfile get profile => engine.profile;
  bool get isLive => kind == PlayerKind.live;

  // -------------------------------------------------------------------------
  // Loading and failures

  bool _resolving = false;
  PlayerFailure? _resolveFailure;

  /// Looking up / resolving the stream (before the engine opens it).
  bool get resolving => _resolving;

  /// What the error overlay shows, or null.
  PlayerFailure? get failure {
    final resolve = _resolveFailure;
    if (resolve != null) return resolve;
    final error = _state.error;
    return error == null
        ? null
        : PlayerFailure(PlayerFailureKind.engine, engineError: error);
  }

  /// Spinner: resolving, opening or rebuffering (not while failed).
  bool get busy =>
      failure == null &&
      (_resolving || _state.buffering || _state.reconnecting) &&
      _resumeOffer == null;

  // -------------------------------------------------------------------------
  // Media (VOD / catch-up)

  PlayerMediaInfo? _media;
  ItemType? _vodType;
  String? _vodId;
  String? _seriesId;
  EpisodeItem? _episode;
  NextEpisodeOffer? _nextOffer;
  EpisodeItem? _nextEpisode;
  bool _nextDismissed = false;
  Timer? _countdownTimer;
  Duration? _resumeOffer;
  List<PlayerChapter> _chapters = const [];
  bool _chaptersRead = false;
  Timer? _saveTimer;
  Duration? _lastSaved;

  PlayerMediaInfo? get media => _media;
  EpisodeItem? get episode => _episode;

  /// The episode after this one (series only).
  EpisodeItem? get nextEpisode => _nextEpisode;

  /// The Next episode card, when it is showing.
  NextEpisodeOffer? get nextEpisodeOffer => _nextOffer;

  /// "Resume from 12:34" prompt position, while the prompt is open.
  Duration? get resumeOffer => _resumeOffer;
  List<PlayerChapter> get chapters => _chapters;

  /// The intro chapter playing now (Skip intro pill).
  PlayerChapter? get introChapter =>
      kind == PlayerKind.vod ? introAt(_chapters, _state.position) : null;

  // -------------------------------------------------------------------------
  // Live / catch-up channel

  ChannelView? _channel;
  NowNext _nowNext = NowNext.empty;
  List<String>? _zapIds;
  List<ChannelView>? _zapList;
  String? _categoryId;
  String? _previousChannelId;
  final Map<String, ChannelView> _views = {};
  Timer? _tuneTimer;
  Timer? _nowNextTimer;
  int _zapSerial = 0;
  String? _tunedChannelId;
  DateTime? _programmeStart;
  DateTime? _programmeEnd;
  bool _triedCatchupFallback = false;
  String? _programmeDescription;

  /// The channel shown (live: changes instantly while zapping).
  ChannelView? get channel => _channel;
  NowNext get nowNext => _nowNext;

  /// Bumped on every zap; the OSD shows while it changes.
  int get zapSerial => _zapSerial;
  String? get previousChannelId => _previousChannelId;

  /// Catch-up: the programme's own start and end (UTC).
  DateTime? get programmeStart => _programmeStart;
  DateTime? get programmeEnd => _programmeEnd;

  /// Catch-up: the programme description from the EPG.
  String? get programmeDescription => _programmeDescription;

  /// Catch-up: the programme length (the progress bar range).
  Duration? get programmeDuration {
    final s = _programmeStart;
    final e = _programmeEnd;
    if (s == null || e == null || !e.isAfter(s)) return null;
    return e.difference(s);
  }

  // -------------------------------------------------------------------------
  // Session picture / audio values (the engine API has no getters)

  late AspectMode _aspect;
  late DeinterlaceMode _deinterlace;
  late Duration _audioDelay;
  late Duration _subtitleDelay;
  late SubtitleSize _subtitleSize;

  AspectMode get aspect => _aspect;
  DeinterlaceMode get deinterlace => _deinterlace;
  Duration get audioDelay => _audioDelay;
  Duration get subtitleDelay => _subtitleDelay;
  SubtitleSize get subtitleSize => _subtitleSize;

  /// The bar's range: the programme for catch-up, else the engine duration
  /// (or the provider runtime until it is known).
  Duration get duration {
    final programme = programmeDuration;
    if (kind == PlayerKind.catchup && programme != null) return programme;
    if (_state.duration > Duration.zero) return _state.duration;
    return _media?.durationHint ?? Duration.zero;
  }

  Duration get position {
    final d = duration;
    final p = _state.position;
    if (d > Duration.zero && p > d) return d;
    return p < Duration.zero ? Duration.zero : p;
  }

  // =========================================================================
  // Start

  /// Resolves and opens [request]. Call once.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _startRequest(_request);
  }

  Future<void> _startRequest(PlayRequest request) async {
    switch (request) {
      case VodPlayRequest():
        await _startVod(request);
      case LivePlayRequest():
        await _startLive(request);
      case CatchupPlayRequest():
        await _startCatchup(request);
    }
  }

  void _setResolving(bool value) {
    if (_resolving == value) return;
    _resolving = value;
    _notify();
  }

  void _fail(PlayerFailure failure) {
    _resolving = false;
    _resolveFailure = failure;
    _notify();
  }

  PlaybackSource _source(ResolvedStream r, String? title) => PlaybackSource(
    url: r.url,
    headers: r.headers,
    userAgent: r.userAgent,
    referer: r.referer,
    isLive: r.isLive,
    title: title,
  );

  // -------------------------------------------------------------------------
  // VOD

  Future<void> _startVod(VodPlayRequest r) async {
    _setResolving(true);
    _resolveFailure = null;
    _resumeOffer = null;
    _nextOffer = null;
    _nextEpisode = null;
    _nextDismissed = false;
    _chapters = const [];
    _chaptersRead = false;
    _lastSaved = null;
    _vodType = r.type;
    _vodId = r.providerId;
    _seriesId = r.seriesId;
    _episode = null;
    try {
      final ResolvedStream resolved;
      if (r.type == ItemType.movie) {
        final row = await deps.queries.movieRow(playlistId, r.providerId);
        if (_disposed) return;
        if (row == null) {
          return _fail(const PlayerFailure(PlayerFailureKind.notFound));
        }
        _media = PlayerMediaInfo(title: row.name, image: row.poster);
        _notify();
        resolved = await deps.resolver.movie(playlistId, row);
        unawaited(_loadMovieDetails(row));
      } else {
        final row = await deps.queries.episodeRow(playlistId, r.providerId);
        if (_disposed) return;
        if (row == null) {
          return _fail(const PlayerFailure(PlayerFailureKind.notFound));
        }
        final episode = EpisodeItem.fromRow(row);
        _episode = episode;
        _seriesId = row.seriesId;
        final series = await deps.vod.item(
          playlistId,
          SectionKind.series,
          row.seriesId,
        );
        if (_disposed) return;
        _media = PlayerMediaInfo(
          title: series?.name ?? episode.title,
          subtitle: episode.label,
          overview: episode.plot ?? series?.plot,
          image: episode.image ?? series?.backdrop ?? series?.poster,
          durationHint: episode.duration,
        );
        _notify();
        _nextEpisode = await deps.vod.nextEpisode(
          playlistId,
          row.seriesId,
          row.season,
          row.episodeNum,
        );
        if (_disposed) return;
        resolved = await deps.resolver.episode(playlistId, row);
      }
      if (_disposed) return;
      final (start, autoplay, offer) = await _resumeFor(r);
      if (_disposed) return;
      _resumeOffer = offer;
      _setResolving(false);
      await engine.open(
        _source(resolved, _media?.title),
        start: start,
        autoplay: autoplay,
      );
      _startSaveTimer();
    } on StreamResolveException catch (e) {
      if (!_disposed) _fail(PlayerFailure.fromResolve(e.error));
    }
  }

  /// Start position, autoplay and the prompt position for [r].
  Future<(Duration?, bool, Duration?)> _resumeFor(VodPlayRequest r) async {
    if (r.resume == false) return (null, true, null);
    final saved = await deps.watchState.get(playlistId, r.type, r.providerId);
    final always = deps.settings.get(
      PlaylistSettings.alwaysResume,
      playlistId: playlistId,
    );
    final decision = deps.watchState.resumeFor(
      saved,
      alwaysResume: always || r.resume == true,
    );
    return switch (decision.kind) {
      ResumeKind.none => (null, true, null),
      ResumeKind.resume => (decision.position, true, null),
      // Open paused at the saved position; the prompt decides.
      ResumeKind.offer => (decision.position, false, decision.position),
    };
  }

  Future<void> _loadMovieDetails(MovieRow row) async {
    try {
      final details = await deps.vod.movieDetails(playlistId, row.providerId);
      if (_disposed || details == null || _vodId != row.providerId) return;
      _media = PlayerMediaInfo(
        title: details.name,
        overview: details.plot,
        image: details.backdrop ?? details.poster ?? row.poster,
        durationHint: details.duration,
        technical: details.technical,
      );
      _notify();
    } catch (error) {
      debugPrint('Player: movie details failed: $error');
    }
  }

  /// "Resume from 12:34".
  Future<void> resumeFromPrompt() async {
    if (_resumeOffer == null) return;
    _resumeOffer = null;
    _notify();
    await engine.play();
  }

  /// "From the beginning" (prompt or info panel).
  Future<void> startOver() async {
    _resumeOffer = null;
    _nextOffer = null;
    _countdownTimer?.cancel();
    _notify();
    await engine.seek(Duration.zero);
    if (!_state.playing) await engine.play();
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    if (kind != PlayerKind.vod) return;
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state.playing) unawaited(saveProgress());
    });
  }

  /// Stores the resume position (every 5 s while playing and on exit).
  Future<void> saveProgress({bool force = false}) async {
    final type = _vodType;
    final id = _vodId;
    if (kind != PlayerKind.vod || type == null || id == null) return;
    if (_resumeOffer != null) return;
    final d = _state.duration;
    if (d <= Duration.zero) return;
    final p = _state.completed ? d : position;
    if (!force &&
        _lastSaved != null &&
        (p - _lastSaved!).abs() < const Duration(seconds: 1)) {
      return;
    }
    _lastSaved = p;
    try {
      await deps.watchState.save(
        playlistId,
        type,
        id,
        p,
        d,
        seriesId: _seriesId,
      );
    } catch (error) {
      debugPrint('Player: saving the position failed: $error');
    }
  }

  // -------------------------------------------------------------------------
  // Next episode

  bool get _autoplayNext => deps.settings.get(
    PlaylistSettings.autoplayNextEpisode,
    playlistId: playlistId,
  );

  void _updateNextOffer() {
    final next = _nextEpisode;
    if (kind != PlayerKind.vod || next == null || _nextDismissed) return;
    if (_resumeOffer != null) return;
    final d = _state.duration;
    if (d <= const Duration(minutes: 1)) return;
    final credits = creditsStart(_chapters);
    final due =
        d - _state.position <= const Duration(seconds: 30) ||
        (credits != null && _state.position >= credits);
    if (due && _nextOffer == null) {
      _nextOffer = NextEpisodeOffer(
        episode: next,
        countdown: _autoplayNext ? 10 : null,
      );
      if (_autoplayNext) _startCountdown();
    } else if (!due && _nextOffer != null) {
      // Seeked back before the end.
      _nextOffer = null;
      _countdownTimer?.cancel();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final offer = _nextOffer;
      if (offer == null || offer.countdown == null) {
        _countdownTimer?.cancel();
        return;
      }
      if (!_state.playing) return;
      final left = offer.countdown! - 1;
      if (left <= 0) {
        _countdownTimer?.cancel();
        unawaited(playNextEpisode());
        return;
      }
      _nextOffer = NextEpisodeOffer(episode: offer.episode, countdown: left);
      _notify();
    });
  }

  /// Hides the Next episode card for this episode.
  void dismissNextEpisode() {
    _nextDismissed = true;
    _nextOffer = null;
    _countdownTimer?.cancel();
    _notify();
  }

  /// Plays the next episode (card, info panel, N key).
  Future<void> playNextEpisode() async {
    final next = _nextEpisode;
    if (next == null || _disposed) return;
    _countdownTimer?.cancel();
    await saveProgress(force: true);
    final request = VodPlayRequest(
      playlistId: playlistId,
      type: ItemType.episode,
      providerId: next.providerId,
      seriesId: next.seriesId,
      resume: true,
    );
    _request = request;
    await engine.stop();
    await _startVod(request);
  }

  Future<void> _readChapters() async {
    if (_chaptersRead || kind != PlayerKind.vod) return;
    _chaptersRead = true;
    final raw = await engine.getProperty('chapter-list');
    if (_disposed) return;
    _chapters = parseChapterList(raw, _state.duration);
    if (_chapters.isNotEmpty) _notify();
  }

  /// Skip intro: jumps to the end of the intro chapter.
  Future<void> skipIntro() async {
    final intro = introChapter;
    if (intro == null) return;
    await engine.seek(intro.end);
  }

  // -------------------------------------------------------------------------
  // Live

  Future<void> _startLive(LivePlayRequest r) async {
    _setResolving(true);
    final channel = await deps.live.channel(playlistId, r.channelId);
    if (_disposed) return;
    if (channel == null) {
      return _fail(const PlayerFailure(PlayerFailureKind.notFound));
    }
    _zapIds = r.zapChannelIds;
    _categoryId = r.categoryId ?? channel.row.categoryId;
    _views[channel.providerId] = channel;
    _channel = channel;
    _notify();
    unawaited(_loadZapList());
    await _tune(channel);
  }

  Future<void> _loadZapList() async {
    if (_zapIds != null) return;
    final category = _categoryId == null
        ? const AllCategory()
        : ProviderCategory(_categoryId!);
    try {
      final list = await deps.live.channels(playlistId, category);
      if (_disposed) return;
      _zapList = list;
      for (final c in list) {
        _views[c.providerId] = c;
      }
    } catch (error) {
      debugPrint('Player: loading the zap list failed: $error');
    }
  }

  Future<void> _tune(ChannelView channel) async {
    _tuneTimer?.cancel();
    _channel = channel;
    _resolveFailure = null;
    _setResolving(true);
    _tunedChannelId = channel.providerId;
    try {
      final resolved = await deps.resolver.live(playlistId, channel.row);
      if (_disposed || _tunedChannelId != channel.providerId) return;
      _setResolving(false);
      await engine.open(_source(resolved, channel.displayName));
      if (_disposed) return;
      unawaited(
        deps.live
            .addLastWatched(playlistId, channel.providerId)
            .catchError((Object e) => debugPrint('Player: last watched: $e')),
      );
    } on StreamResolveException catch (e) {
      if (!_disposed) _fail(PlayerFailure.fromResolve(e.error));
    }
    unawaited(_loadNowNext(channel));
  }

  Future<void> _loadNowNext(ChannelView channel) async {
    _nowNextTimer?.cancel();
    try {
      final now = deps.clock();
      final nn = await deps.epg.nowNextForChannel(playlistId, channel, at: now);
      if (_disposed || _channel?.providerId != channel.providerId) return;
      _nowNext = nn;
      _notify();
      // Refresh when the programme on air ends.
      final end = nn.now?.stop ?? nn.next?.start;
      if (end != null) {
        final wait = end.difference(deps.clock().toUtc());
        if (wait > Duration.zero && wait < const Duration(hours: 12)) {
          _nowNextTimer = Timer(wait + const Duration(seconds: 1), () {
            final c = _channel;
            if (c != null) unawaited(_loadNowNext(c));
          });
        }
      }
    } catch (error) {
      debugPrint('Player: now/next failed: $error');
    }
  }

  /// The channel [delta] steps away in the zap list (wrapping around).
  Future<ChannelView?> _neighbor(int delta) async {
    final current = _channel;
    if (current == null) return null;
    final ids = _zapIds ?? _zapList?.map((c) => c.providerId).toList();
    if (ids == null) {
      final n = await deps.live.neighbors(
        playlistId,
        _categoryId == null
            ? const AllCategory()
            : ProviderCategory(_categoryId!),
        current.providerId,
      );
      return delta < 0 ? n.previous : n.next;
    }
    if (ids.length < 2) return null;
    var index = ids.indexOf(current.providerId);
    if (index < 0) index = delta > 0 ? -1 : 0;
    final target = ids[(index + delta) % ids.length];
    return _view(target);
  }

  Future<ChannelView?> _view(String id) async {
    final cached = _views[id];
    if (cached != null) return cached;
    final view = await deps.live.channel(playlistId, id);
    if (view != null) _views[id] = view;
    return view;
  }

  /// ↑/↓ zapping: the OSD shows [delta]'s channel at once; the stream opens
  /// after a short pause so fast key repeats only open the last channel.
  Future<void> zap(int delta) async {
    if (kind != PlayerKind.live) return;
    final next = await _neighbor(delta);
    if (_disposed || next == null || next.providerId == _channel?.providerId) {
      return;
    }
    if (next.locked && unlockChannel != null) {
      final ok = await unlockChannel!(next.providerId);
      if (!ok || _disposed) return;
    }
    _switchTo(next, debounce: true);
  }

  /// A zap opens at once; zaps that follow within [_zapBurst] (a held key)
  /// wait [_zapSettle] so only the channel the user stops on opens.
  static const Duration _zapBurst = Duration(milliseconds: 400);
  static const Duration _zapSettle = Duration(milliseconds: 150);

  /// Runs for [_zapBurst] after each zap (a timer, so tests' fake time and
  /// the real clock behave the same).
  Timer? _burstTimer;

  void _switchTo(ChannelView next, {bool debounce = false}) {
    final playing = _tunedChannelId;
    if (playing != null && playing != next.providerId) {
      _previousChannelId = playing;
    }
    _channel = next;
    _nowNext = NowNext.empty;
    _zapSerial++;
    _notify();
    _tuneTimer?.cancel();
    final burst = debounce && (_burstTimer?.isActive ?? false);
    _burstTimer?.cancel();
    _burstTimer = debounce ? Timer(_zapBurst, () {}) : null;
    if (burst) {
      _tuneTimer = Timer(_zapSettle, () {
        if (!_disposed && _channel?.providerId == next.providerId) {
          unawaited(_tune(next));
        }
      });
    } else {
      unawaited(_tune(next));
    }
  }

  /// Tunes [channelId] (guides, number zapping).
  Future<bool> tuneChannel(String channelId) async {
    if (kind != PlayerKind.live) return false;
    if (channelId == _channel?.providerId) return true;
    final view = await _view(channelId);
    if (_disposed || view == null) return false;
    if (view.locked && unlockChannel != null) {
      final ok = await unlockChannel!(view.providerId);
      if (!ok || _disposed) return false;
    }
    _switchTo(view);
    return true;
  }

  /// Backspace: back to the channel watched before the last switch.
  Future<bool> previousChannel() async {
    final id = _previousChannelId;
    if (kind != PlayerKind.live || id == null) return false;
    return tuneChannel(id);
  }

  /// Number zapping: the channel with number [number].
  Future<bool> tuneNumber(int number) async {
    if (kind != PlayerKind.live) return false;
    final view = await deps.live.channelByNumber(playlistId, number);
    if (_disposed || view == null) return false;
    _views[view.providerId] = view;
    return tuneChannel(view.providerId);
  }

  // -------------------------------------------------------------------------
  // Catch-up

  Future<void> _startCatchup(CatchupPlayRequest r) async {
    _setResolving(true);
    _programmeStart = r.startUtc.toUtc();
    _programmeEnd = r.endUtc.toUtc();
    final channel = await deps.live.channel(playlistId, r.channelId);
    if (_disposed) return;
    if (channel == null) {
      return _fail(const PlayerFailure(PlayerFailureKind.notFound));
    }
    _channel = channel;
    _media = PlayerMediaInfo(
      title: r.title,
      subtitle: channel.displayName,
      image: channel.logo,
      durationHint: programmeDuration,
    );
    _notify();
    unawaited(_loadProgramme(channel, r));
    try {
      final resolved = await deps.resolver.catchup(
        playlistId,
        channel.row,
        r.startUtc,
        r.endUtc,
      );
      if (_disposed) return;
      _setResolving(false);
      await engine.open(_source(resolved, r.title));
    } on StreamResolveException catch (e) {
      if (!_disposed) _fail(PlayerFailure.fromResolve(e.error));
    }
  }

  Future<void> _loadProgramme(ChannelView channel, CatchupPlayRequest r) async {
    final key = channel.epgKey;
    if (key == null) return;
    try {
      final list = await deps.epg.programmes(
        playlistId,
        key,
        r.startUtc,
        r.endUtc,
      );
      if (_disposed) return;
      final match = list
          .where((p) => p.start == r.startUtc.toUtc())
          .firstOrNull;
      _programmeDescription = match?.description;
      if (match?.description != null) {
        _media = _media?.copyWith(overview: match!.description);
      }
      _notify();
    } catch (error) {
      debugPrint('Player: programme lookup failed: $error');
    }
  }

  /// Xtream `timeshift.php` alternative after the archive URL failed.
  Future<bool> _tryCatchupFallback() async {
    final r = _request;
    final channel = _channel;
    if (r is! CatchupPlayRequest || channel == null) return false;
    if (_triedCatchupFallback) return false;
    _triedCatchupFallback = true;
    try {
      final fallback = await deps.resolver.catchupFallback(
        playlistId,
        channel.row,
        r.startUtc,
        r.endUtc,
      );
      if (fallback == null || _disposed) return false;
      await engine.open(_source(fallback, r.title));
      return true;
    } catch (error) {
      debugPrint('Player: catch-up fallback failed: $error');
      return false;
    }
  }

  // =========================================================================
  // Engine events

  void _onState(EngineState s) {
    if (_disposed) return;
    final previous = _state;
    _state = s;
    _stats = engine.stats;
    if (s.error != null && previous.error == null) {
      if (kind == PlayerKind.catchup &&
          !_triedCatchupFallback &&
          s.error!.kind != EngineErrorKind.codec) {
        unawaited(_tryCatchupFallback());
      }
    }
    if (kind == PlayerKind.vod) {
      if (s.duration > Duration.zero && !_chaptersRead && s.hasVideo) {
        unawaited(_readChapters());
      }
      _updateNextOffer();
      if (s.completed && !previous.completed) {
        unawaited(saveProgress(force: true));
        if (_nextEpisode != null && !_nextDismissed && _autoplayNext) {
          unawaited(playNextEpisode());
        }
      }
    }
    _notify();
  }

  void _onStats(EngineStats s) {
    if (_disposed) return;
    _stats = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // =========================================================================
  // Commands

  /// Retry from the error overlay.
  Future<void> retry() async {
    if (_resolveFailure != null) {
      _resolveFailure = null;
      _notify();
      final channel = _channel;
      if (kind == PlayerKind.live && channel != null) {
        await _tune(channel);
      } else {
        _triedCatchupFallback = false;
        await _startRequest(_request);
      }
      return;
    }
    _triedCatchupFallback = false;
    await engine.play();
  }

  Future<void> togglePlay() async {
    if (_resumeOffer != null) return resumeFromPrompt();
    if (_state.completed) {
      await engine.seek(Duration.zero);
      return engine.play();
    }
    await engine.playOrPause();
  }

  /// Seeks to [target] inside the bar range.
  Future<void> seekTo(Duration target) async {
    if (kind == PlayerKind.live) return;
    final d = duration;
    var t = target < Duration.zero ? Duration.zero : target;
    if (d > Duration.zero && t > d) t = d;
    await engine.seek(t);
  }

  Future<void> seekBy(Duration delta) => seekTo(position + delta);

  /// 0–9 → 0–90 %.
  Future<void> seekPercent(int digit) async {
    final d = duration;
    if (d <= Duration.zero) return;
    await seekTo(d * (digit.clamp(0, 9) / 10));
  }

  Future<void> setVolume(double value) async {
    final v = value.clamp(0.0, 100.0).toDouble();
    playerSessionVolume = v;
    if (_state.muted && v > 0) await engine.setMuted(false);
    await engine.setVolume(v);
  }

  Future<void> changeVolume(double delta) => setVolume(_state.volume + delta);

  Future<void> toggleMute() => engine.setMuted(!_state.muted);

  Future<void> switchProfile(EngineProfile p) async {
    await engine.switchProfile(p);
    _notify();
  }

  Future<void> selectAudio(EngineTrack t) => engine.selectAudio(t);

  Future<void> selectSubtitle(EngineTrack? t) => engine.selectSubtitle(t);

  Future<void> addExternalSubtitle(String path) =>
      engine.addExternalSubtitle(path);

  static Duration _clampDelay(Duration d) {
    const limit = Duration(seconds: 5);
    if (d > limit) return limit;
    if (d < -limit) return -limit;
    // Keep 0.1 s steps exact.
    return Duration(milliseconds: (d.inMilliseconds / 100).round() * 100);
  }

  Future<void> setAudioDelay(Duration d) async {
    _audioDelay = _clampDelay(d);
    _notify();
    await engine.setAudioDelay(_audioDelay);
  }

  Future<void> stepAudioDelay(int tenths) =>
      setAudioDelay(_audioDelay + Duration(milliseconds: 100 * tenths));

  Future<void> setSubtitleDelay(Duration d) async {
    _subtitleDelay = _clampDelay(d);
    _notify();
    await engine.setSubtitleDelay(_subtitleDelay);
  }

  Future<void> stepSubtitleDelay(int tenths) =>
      setSubtitleDelay(_subtitleDelay + Duration(milliseconds: 100 * tenths));

  Future<void> setSubtitleSize(SubtitleSize size) async {
    _subtitleSize = size;
    _notify();
    await engine.setSubtitleScale(size.scale);
  }

  Future<void> setAspect(AspectMode mode) async {
    _aspect = mode;
    _notify();
    await engine.setAspect(mode);
  }

  Future<void> setDeinterlace(DeinterlaceMode mode) async {
    _deinterlace = mode;
    _notify();
    await engine.setDeinterlace(mode);
  }

  Future<void> setRate(double rate) => engine.setRate(rate);

  // =========================================================================

  @override
  void dispose() {
    if (_disposed) return;
    unawaited(saveProgress(force: true));
    _disposed = true;
    _saveTimer?.cancel();
    _countdownTimer?.cancel();
    _tuneTimer?.cancel();
    _burstTimer?.cancel();
    _nowNextTimer?.cancel();
    unawaited(_stateSub?.cancel());
    unawaited(_statsSub?.cancel());
    unawaited(engine.dispose());
    super.dispose();
  }
}
