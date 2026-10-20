import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/mpv_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';

const _vod = PlaybackSource(url: 'http://h/movie/1.mkv', title: 'Kış Uykusu');
const _live = PlaybackSource(
  url: 'http://h/live/1001.ts',
  isLive: true,
  title: 'TRT 1 HD',
);

void main() {
  group('FakeEngine', () {
    late FakeEngine engine;

    setUp(() => engine = FakeEngine(autoTick: false));
    tearDown(() => engine.dispose());

    test('open → playing with video, tracks and stats', () async {
      final states = <EngineState>[];
      final sub = engine.stateStream.listen(states.add);
      await engine.open(_vod);
      await Future<void>.delayed(Duration.zero);
      expect(states.first.buffering, isTrue);
      expect(states.first.hasVideo, isFalse);
      final s = engine.state;
      expect(s.playing, isTrue);
      expect(s.buffering, isFalse);
      expect(s.width, 1920);
      expect(s.height, 1080);
      expect(s.duration, const Duration(minutes: 42, seconds: 17));
      expect(engine.audioTracks, hasLength(2));
      expect(engine.subtitleTracks, hasLength(2));
      expect(s.selectedAudioId, '1');
      expect(s.selectedSubtitleId, isNull);
      expect(engine.calls, ['open Kış Uykusu']);
      final stats = engine.stats;
      expect(stats.width, 1920);
      expect(stats.height, 1080);
      expect(stats.fps, 25);
      expect(stats.videoCodec, 'h264');
      expect(stats.audioCodec, 'aac');
      expect(stats.qualityLabel, 'FHD');
      expect(stats.sizeLabel, '1920×1080');
      await sub.cancel();
    });

    test('position ticks and VOD completes', () async {
      await engine.open(_vod);
      engine.advance(const Duration(seconds: 2));
      expect(engine.state.position, const Duration(seconds: 2));
      await engine.setRate(2);
      engine.advance(const Duration(seconds: 1));
      expect(engine.state.position, const Duration(seconds: 4));
      engine.advance(const Duration(hours: 1));
      expect(engine.state.completed, isTrue);
      expect(engine.state.playing, isFalse);
      expect(engine.state.position, engine.state.duration);
    });

    test('live never completes and has no duration', () async {
      await engine.open(_live);
      engine.advance(const Duration(hours: 3));
      expect(engine.state.completed, isFalse);
      expect(engine.state.isLive, isTrue);
      expect(engine.state.duration, Duration.zero);
    });

    test('auto tick uses timers', () async {
      final ticking = FakeEngine(
        tickInterval: const Duration(milliseconds: 10),
      );
      await ticking.open(_vod);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ticking.state.position, greaterThan(Duration.zero));
      await ticking.pause();
      final paused = ticking.state.position;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(ticking.state.position, paused);
      await ticking.dispose();
    });

    test('transport and settings calls are recorded', () async {
      await engine.open(_vod);
      await engine.pause();
      await engine.playOrPause();
      await engine.seek(const Duration(minutes: 1));
      await engine.setVolume(140);
      await engine.setMuted(true);
      await engine.selectAudio(engine.audioTracks[1]);
      await engine.selectSubtitle(engine.subtitleTracks[1]);
      await engine.selectSubtitle(null);
      await engine.setAudioDelay(const Duration(milliseconds: -300));
      await engine.setSubtitleDelay(const Duration(seconds: 1));
      await engine.setSubtitleScale(1.3);
      await engine.setAspect(AspectMode.crop);
      await engine.setDeinterlace(DeinterlaceMode.on);
      expect(engine.calls, [
        'open Kış Uykusu',
        'pause',
        'play',
        'seek 0:01:00.000000',
        'setVolume 100',
        'setMuted true',
        'selectAudio 2',
        'selectSubtitle 2',
        'selectSubtitle off',
        'setAudioDelay -0.300',
        'setSubtitleDelay 1.000',
        'setSubtitleScale 1.30',
        'setAspect crop',
        'setDeinterlace on',
      ]);
      expect(engine.state.position, const Duration(minutes: 1));
      expect(engine.state.volume, 100);
      expect(engine.state.muted, isTrue);
      expect(engine.state.selectedAudioId, '2');
      expect(engine.state.selectedSubtitleId, isNull);
      expect(engine.aspect, AspectMode.crop);
      expect(engine.deinterlace, DeinterlaceMode.on);
      expect(engine.stats.audioCodec, 'ac3');
      expect(engine.stats.audioChannels, 6);
    });

    test('external subtitles are appended and selected', () async {
      await engine.open(_vod);
      await engine.addExternalSubtitle('/subs/film.tr.srt');
      final added = engine.subtitleTracks.last;
      expect(engine.subtitleTracks, hasLength(3));
      expect(added.isExternal, isTrue);
      expect(added.title, 'film.tr.srt');
      expect(engine.state.selectedSubtitleId, added.id);
    });

    test('switchProfile keeps position and tracks', () async {
      await engine.open(_vod);
      engine.advance(const Duration(seconds: 90));
      await engine.selectAudio(engine.audioTracks[1]);
      await engine.switchProfile(EngineProfile.software);
      expect(engine.profile, EngineProfile.software);
      expect(engine.state.position, const Duration(seconds: 90));
      expect(engine.state.selectedAudioId, '2');
      expect(engine.state.hasVideo, isTrue);
      expect(engine.stats.hwdec, 'no');
      expect(engine.stats.profile, EngineProfile.software);
      expect(engine.calls.last, 'switchProfile software');
    });

    test('preferred languages pick the Turkish tracks', () async {
      final tr = FakeEngine(
        autoTick: false,
        options: const EngineOptions(
          preferredAudioLanguage: 'tr',
          preferredSubtitleLanguage: 'Türkçe',
        ),
      );
      await tr.open(_vod);
      expect(tr.state.selectedAudioTrack?.language, 'tur');
      expect(tr.state.selectedSubtitleTrack?.language, 'tur');
      await tr.dispose();
      final off = FakeEngine(
        autoTick: false,
        options: const EngineOptions(
          preferredSubtitleLanguage: kSubtitlesDisabled,
        ),
      );
      await off.open(_vod);
      expect(off.state.selectedSubtitleId, isNull);
      await off.dispose();
    });

    test('simulated error, buffering, reconnect and retry', () async {
      await engine.open(_live);
      engine.simulateBuffering(43);
      expect(engine.state.buffering, isTrue);
      expect(engine.state.bufferingPercent, 43);
      engine.simulateReconnect(2);
      expect(engine.state.reconnecting, isTrue);
      expect(engine.state.reconnectAttempt, 2);
      const error = EngineError(
        kind: EngineErrorKind.http,
        statusCode: 404,
        message: 'Stream not found (HTTP 404).',
      );
      engine.simulateError(error);
      expect(engine.state.error, error);
      expect(engine.state.reconnecting, isFalse);
      // play() from the error overlay reopens the source.
      await engine.play();
      expect(engine.state.error, isNull);
      expect(engine.openedSources, [_live, _live]);
    });

    test('getProperty fakes mpv values', () async {
      expect(await engine.getProperty('audio-codec-name'), isNull);
      await engine.open(_vod);
      expect(await engine.getProperty('audio-codec-name'), 'aac');
      expect(await engine.getProperty('video-params/w'), '1920');
      expect(await engine.getProperty('audio-params/channel-count'), '2');
      expect(await engine.getProperty('unknown-property'), isNull);
    });

    test('stop resets the state', () async {
      await engine.open(_vod);
      await engine.setVolume(30);
      await engine.stop();
      expect(engine.state.source, isNull);
      expect(engine.state.playing, isFalse);
      expect(engine.state.volume, 30);
    });

    test('dispose is idempotent and later calls are no-ops', () async {
      await engine.open(_vod);
      final done = expectLater(engine.stateStream, emitsDone);
      await engine.dispose();
      await engine.dispose();
      await done;
      expect(engine.isDisposed, isTrue);
      await engine.play();
      await engine.seek(Duration.zero);
      expect(await engine.getProperty('audio-codec-name'), isNull);
      expect(engine.calls.where((c) => c == 'dispose'), hasLength(1));
      expect(engine.calls.last, 'dispose');
    });
  });

  group('preview engines', () {
    test('muted and low latency', () {
      final factory = FakeEngineFactory(autoTick: false);
      final preview = factory.create(
        options: const EngineOptions(profile: EngineProfile.hardware),
        preview: true,
      );
      expect(preview.preview, isTrue);
      expect(preview.state.muted, isTrue);
      expect(preview.profile, EngineProfile.lowLatency);
      final main = factory.create(options: const EngineOptions());
      expect(main.state.muted, isFalse);
      expect(main.profile, EngineProfile.auto);
      expect(factory.created, [preview, main]);
      expect(factory.last, main);
    });
  });

  group('provider', () {
    test('defaults to MpvEngineFactory', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(playbackEngineFactoryProvider),
        isA<MpvEngineFactory>(),
      );
    });

    test('can be overridden with FakeEngineFactory', () {
      final fake = FakeEngineFactory(autoTick: false);
      final container = ProviderContainer(
        overrides: [playbackEngineFactoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final engine = container
          .read(playbackEngineFactoryProvider)
          .create(options: const EngineOptions());
      expect(engine, isA<FakeEngine>());
      expect(fake.created.single, same(engine));
    });
  });

  testWidgets('buildVideo paints the fake frame', (tester) async {
    final engine = FakeEngine(autoTick: false);
    await tester.pumpWidget(
      SizedBox(
        width: 320,
        height: 180,
        child: engine.buildVideo(key: const ValueKey('video')),
      ),
    );
    expect(find.byKey(const ValueKey('video')), findsOneWidget);
    expect(find.text('VIDEO'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsOneWidget);
    await engine.dispose();
  });

  testWidgets('open delay goes through buffering on the fake clock', (
    tester,
  ) async {
    final engine = FakeEngine(
      autoTick: false,
      openDelay: const Duration(milliseconds: 300),
    );
    await engine.open(_vod);
    expect(engine.state.buffering, isTrue);
    await tester.pump(const Duration(milliseconds: 299));
    expect(engine.state.hasVideo, isFalse);
    await tester.pump(const Duration(milliseconds: 2));
    expect(engine.state.hasVideo, isTrue);
    await engine.dispose();
  });
}
