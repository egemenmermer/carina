import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/tables.dart';
import 'package:carina/data/repositories/watch_state_repository.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';
import 'package:carina/player/ui/player_controller.dart'
    show playerSessionVolume;
import 'package:carina/player/ui/player_screen.dart';

import 'player_test_support.dart';

void main() {
  late MockImportFixture fx;

  setUpAll(() async {
    await loadAppFonts();
    fx = await importPlayerFixture();
  });
  tearDownAll(() => fx.dispose());

  final movieId = '${MockFixtures.kisUykusu}';
  final episode1 = '${MockFixtures.episodeId(MockFixtures.sicakKafa, 1, 1)}';
  final episode2 = '${MockFixtures.episodeId(MockFixtures.sicakKafa, 1, 2)}';

  VodPlayRequest movie({
    bool? resume = false,
    PlayerInitialOverlay overlay = PlayerInitialOverlay.none,
  }) => VodPlayRequest(
    playlistId: fx.playlistId,
    type: ItemType.movie,
    providerId: movieId,
    resume: resume,
    initialOverlay: overlay,
  );

  Future<TestGesture> hover(WidgetTester tester, Offset at) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: at);
    await gesture.moveTo(at + const Offset(4, 0));
    await tester.pump();
    return gesture;
  }

  Future<WatchState?> savedState(WidgetTester tester, String id, ItemType t) =>
      tester
          .runAsync(
            () => WatchStateRepository(db: fx.db).get(fx.playlistId, t, id),
          )
          .then((v) => v);

  Future<void> clearState(WidgetTester tester, String id, ItemType t) =>
      tester.runAsync(
        () => WatchStateRepository(db: fx.db).clear(fx.playlistId, t, id),
      );

  testWidgets('engine options come from the playlist Player settings', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final s = fx.settings;
      final pid = fx.playlistId;
      await s.set(PlaylistSettings.playerVod, 'software', playlistId: pid);
      await s.set(PlaylistSettings.aspect, 'r4x3', playlistId: pid);
      await s.set(PlaylistSettings.audioDelayMs, 300, playlistId: pid);
      await s.set(PlaylistSettings.subtitleSize, 'large', playlistId: pid);
      await s.set(
        PlaylistSettings.subtitleLanguage,
        'disabled',
        playlistId: pid,
      );
      await s.set(PlaylistSettings.audioLanguage, 'tur', playlistId: pid);
    });
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    final o = optionsOf(factory);
    expect(o.profile, EngineProfile.software);
    expect(o.aspect, AspectMode.r4x3);
    expect(o.audioDelay, const Duration(milliseconds: 300));
    expect(o.subtitleScale, 1.3);
    expect(o.subtitlesDisabled, isTrue);
    expect(o.preferredAudioLanguage, 'tur');
    // The preferred Turkish track was picked by the engine.
    expect(factory.last.state.selectedAudioId, '2');
    await closePlayer(tester);
    await tester.runAsync(() async {
      for (final key in [
        PlaylistSettings.playerVod,
        PlaylistSettings.aspect,
        PlaylistSettings.audioDelayMs,
        PlaylistSettings.subtitleSize,
        PlaylistSettings.subtitleLanguage,
        PlaylistSettings.audioLanguage,
      ]) {
        await fx.settings.reset(key, playlistId: fx.playlistId);
      }
    });
  });

  testWidgets('controls appear on mouse move and hide after 3 s, not while '
      'a menu is open', (tester) async {
    final factory = manualFactory();
    final player = await pumpPlayer(tester, fx, movie(), factory: factory);
    expect(factory.last.state.playing, isTrue);

    final gesture = await hover(tester, const Offset(700, 400));
    expect(player.controlsVisible, isTrue);
    expect(find.text('Kış Uykusu'), findsOneWidget);
    // Space plays / pauses on desktop: no on-screen Play / Pause button.
    expect(find.byKey(const ValueKey('player-play-pause')), findsNothing);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(player.controlsVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(player.controlsVisible, isFalse);
    // The cursor hides with the controls.
    final region = tester.widget<MouseRegion>(
      find.byKey(const ValueKey('player-cursor')),
    );
    expect(region.cursor, SystemMouseCursors.none);

    // Any key brings them back.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();
    expect(player.controlsVisible, isTrue);

    // A menu keeps them on screen.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await settle(tester, maxFrames: 8);
    expect(find.text('AUDIO'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(player.controlsVisible, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, maxFrames: 8);
    expect(find.text('AUDIO'), findsNothing);
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    expect(player.controlsVisible, isFalse);
    await gesture.removePointer();
    await closePlayer(tester);
  });

  testWidgets('SWITCH PLAYER switches the profile in place and keeps the '
      'position', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    final engine = factory.last;
    engine.advance(const Duration(minutes: 3, seconds: 20));
    await tester.pump();

    await hover(tester, const Offset(700, 400));
    await tester.tap(find.byTooltip('Switch player'));
    await settle(tester, maxFrames: 8);
    expect(find.text('SWITCH PLAYER'), findsOneWidget);
    expect(find.text('MPV · Hardware (D3D11)'), findsOneWidget);
    await tester.tap(find.text('MPV · Software'));
    await settle(tester, maxFrames: 8);

    expect(engine.calls, contains('switchProfile software'));
    expect(engine.profile, EngineProfile.software);
    expect(engine.state.position, const Duration(minutes: 3, seconds: 20));
    expect(find.text('Player: MPV · Software'), findsOneWidget);
    // Still the same player (no reopen of the route / engine).
    expect(factory.created, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    await closePlayer(tester);
  });

  testWidgets('AUDIO menu selects a track and steps the audio delay; [ and ] '
      'too', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    final engine = factory.last;

    await hover(tester, const Offset(700, 400));
    await tester.tap(find.byTooltip('Audio'));
    await settle(tester, maxFrames: 8);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('AAC stereo'), findsOneWidget);
    expect(find.text('AC3 5.1'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(PhosphorIconsBold.plus));
      await pumpUi(tester);
    }
    expect(engine.audioDelay, const Duration(milliseconds: 300));
    expect(find.text('+0.3 s'), findsOneWidget);

    await tester.tap(find.text('Türkçe'));
    await settle(tester, maxFrames: 8);
    expect(engine.calls, contains('selectAudio 2'));
    expect(engine.state.selectedAudioId, '2');
    expect(find.text('AUDIO'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    await tester.pump();
    expect(engine.audioDelay, const Duration(milliseconds: 200));
    expect(find.text('Audio delay: +0.2 s'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.pump();
    expect(engine.audioDelay, const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await closePlayer(tester);
  });

  testWidgets('SUBTITLES: off, internal track, external file, delay and size', (
    tester,
  ) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    // The picker is injected through the test overrides below.
    final engine = factory.last;
    await hover(tester, const Offset(700, 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await settle(tester, maxFrames: 8);
    expect(find.text('SUBTITLES'), findsOneWidget);
    expect(find.text('EXTERNAL SUBTITLES'), findsOneWidget);
    expect(find.text('Load from file…'), findsOneWidget);

    await tester.tap(find.text('Large'));
    await tester.pump();
    expect(engine.subtitleScale, 1.3);
    await tester.tap(find.text('Türkçe'));
    await settle(tester, maxFrames: 8);
    expect(engine.state.selectedSubtitleId, '2');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await settle(tester, maxFrames: 8);
    await tester.tap(find.text('Disabled'));
    await settle(tester, maxFrames: 8);
    expect(engine.calls, contains('selectSubtitle off'));
    expect(engine.state.selectedSubtitleId, isNull);
    await closePlayer(tester);
  });

  testWidgets('external subtitle file is added to the engine', (tester) async {
    final factory = manualFactory();
    await pumpScreen(
      tester,
      PlayerScreen(request: movie()),
      overrides: playerOverrides(
        fx,
        factory: factory,
        picker: () async => '/tmp/movie.tr.srt',
      ),
    );
    await settleDrift(tester, rounds: 12);
    final engine = factory.last;
    await hover(tester, const Offset(700, 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await settle(tester, maxFrames: 8);
    await tester.tap(find.text('Load from file…'));
    await settle(tester, maxFrames: 8);
    expect(engine.calls, contains('addExternalSubtitle /tmp/movie.tr.srt'));
    expect(engine.state.selectedSubtitleTrack?.isExternal, isTrue);
    expect(find.text('Subtitle loaded'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await closePlayer(tester);
  });

  testWidgets('PICTURE sets aspect and deinterlace', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    final engine = factory.last;
    await hover(tester, const Offset(700, 400));
    await tester.tap(find.byTooltip('Picture'));
    await settle(tester, maxFrames: 8);
    expect(find.text('ASPECT RATIO'), findsOneWidget);
    expect(find.text('DEINTERLACE'), findsOneWidget);
    await tester.tap(find.text('Crop'));
    await tester.pump();
    expect(engine.aspect, AspectMode.crop);
    await tester.tap(find.text('16:9'));
    await tester.pump();
    expect(engine.aspect, AspectMode.r16x9);
    await tester.tap(find.text('On'));
    await tester.pump();
    expect(engine.deinterlace, DeinterlaceMode.on);
    await closePlayer(tester);
  });

  testWidgets('resume prompt: Resume from 12:34 plays from there, positions '
      'are saved every 5 s and on exit', (tester) async {
    await tester.runAsync(
      () => WatchStateRepository(db: fx.db).save(
        fx.playlistId,
        ItemType.movie,
        movieId,
        const Duration(minutes: 12, seconds: 34),
        const Duration(minutes: 42, seconds: 17),
      ),
    );
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(resume: null), factory: factory);
    final engine = factory.last;
    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Resume from 12:34'), findsOneWidget);
    expect(engine.state.playing, isFalse);
    expect(engine.state.position, const Duration(minutes: 12, seconds: 34));

    // Enter activates the focused "Resume from" pill.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, maxFrames: 4);
    expect(find.text('Continue watching'), findsNothing);
    expect(engine.state.playing, isTrue);

    engine.advance(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 5));
    await settleDrift(tester, rounds: 4);
    final saved = await savedState(tester, movieId, ItemType.movie);
    expect(saved!.position, const Duration(minutes: 12, seconds: 40));

    engine.advance(const Duration(seconds: 3));
    await closePlayer(tester);
    final onExit = await savedState(tester, movieId, ItemType.movie);
    expect(onExit!.position, const Duration(minutes: 12, seconds: 43));
    await clearState(tester, movieId, ItemType.movie);
  });

  testWidgets('resume prompt: From the beginning seeks to 0; always-resume '
      'skips the prompt', (tester) async {
    Future<void> seed() => tester.runAsync(
      () => WatchStateRepository(db: fx.db).save(
        fx.playlistId,
        ItemType.movie,
        movieId,
        const Duration(minutes: 10),
        const Duration(minutes: 42, seconds: 17),
      ),
    );
    await seed();
    var factory = manualFactory();
    await pumpPlayer(tester, fx, movie(resume: null), factory: factory);
    await tester.tap(find.text('From the beginning'));
    await settle(tester, maxFrames: 4);
    expect(factory.last.state.position, Duration.zero);
    expect(factory.last.state.playing, isTrue);
    await closePlayer(tester);

    await seed();
    await tester.runAsync(
      () => fx.settings.set(
        PlaylistSettings.alwaysResume,
        true,
        playlistId: fx.playlistId,
      ),
    );
    factory = manualFactory();
    await pumpPlayer(tester, fx, movie(resume: null), factory: factory);
    expect(find.text('Continue watching'), findsNothing);
    expect(factory.last.state.position, const Duration(minutes: 10));
    expect(factory.last.state.playing, isTrue);
    await closePlayer(tester);
    await tester.runAsync(
      () => fx.settings.reset(
        PlaylistSettings.alwaysResume,
        playlistId: fx.playlistId,
      ),
    );
    await clearState(tester, movieId, ItemType.movie);
  });

  testWidgets('watching past 95% marks the movie watched', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    final engine = factory.last;
    await engine.seek(engine.state.duration - const Duration(seconds: 30));
    engine.simulateCompleted();
    await pumpUi(tester);
    await settleDrift(tester, rounds: 4);
    final saved = await savedState(tester, movieId, ItemType.movie);
    expect(saved!.watched, isTrue);
    await closePlayer(tester);
    await clearState(tester, movieId, ItemType.movie);
  });

  testWidgets('Next episode card counts down from 10 and plays the next '
      'episode', (tester) async {
    final factory = manualFactory();
    final player = await pumpPlayer(
      tester,
      fx,
      VodPlayRequest(
        playlistId: fx.playlistId,
        type: ItemType.episode,
        providerId: episode1,
        seriesId: '${MockFixtures.sicakKafa}',
        resume: false,
      ),
      factory: factory,
    );
    final engine = factory.last;
    expect(player.controller.nextEpisode?.providerId, episode2);
    expect(find.byKey(const ValueKey('player-next-episode')), findsNothing);

    await engine.seek(engine.state.duration - const Duration(seconds: 31));
    engine.advance(const Duration(seconds: 2));
    await pumpUi(tester);
    expect(find.byKey(const ValueKey('player-next-episode')), findsOneWidget);
    expect(find.text('Playing in 10'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Playing in 6'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await settlePlayer(tester, frames: 6);

    expect(player.controller.request, isA<VodPlayRequest>());
    expect((player.controller.request as VodPlayRequest).providerId, episode2);
    expect(engine.openedSources, hasLength(2));
    expect(find.byKey(const ValueKey('player-next-episode')), findsNothing);
    final first = await savedState(tester, episode1, ItemType.episode);
    expect(first!.watched, isTrue);
    await closePlayer(tester);
    await clearState(tester, episode1, ItemType.episode);
    await clearState(tester, episode2, ItemType.episode);
  });

  testWidgets('Next episode card: × dismisses it, autoplay off shows Play '
      'now without a countdown', (tester) async {
    await tester.runAsync(
      () => fx.settings.set(
        PlaylistSettings.autoplayNextEpisode,
        false,
        playlistId: fx.playlistId,
      ),
    );
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      VodPlayRequest(
        playlistId: fx.playlistId,
        type: ItemType.episode,
        providerId: episode1,
        resume: false,
      ),
      factory: factory,
    );
    final engine = factory.last;
    await engine.seek(engine.state.duration - const Duration(seconds: 20));
    engine.advance(const Duration(seconds: 1));
    await pumpUi(tester);
    expect(find.text('Play now'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(engine.openedSources, hasLength(1));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('player-next-episode')), findsNothing);
    await closePlayer(tester);
    await tester.runAsync(
      () => fx.settings.reset(
        PlaylistSettings.autoplayNextEpisode,
        playlistId: fx.playlistId,
      ),
    );
    await clearState(tester, episode1, ItemType.episode);
  });

  testWidgets('error overlay shows a readable message; Retry reopens', (
    tester,
  ) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    final engine = factory.last;
    engine.simulateError(
      const EngineError(
        kind: EngineErrorKind.http,
        statusCode: 403,
        message: 'forbidden',
      ),
    );
    await pumpUi(tester);
    expect(find.text("Can't play this stream"), findsOneWidget);
    expect(find.textContaining('Access forbidden (HTTP 403)'), findsOneWidget);
    expect(find.text('Switch player'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await pumpUi(tester);
    expect(engine.calls.where((c) => c.startsWith('open')), hasLength(2));
    expect(find.text("Can't play this stream"), findsNothing);

    engine.simulateError(
      const EngineError(kind: EngineErrorKind.codec, message: 'codec'),
    );
    await pumpUi(tester);
    expect(find.text('This video format is not supported.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Switch player'));
    await settle(tester, maxFrames: 8);
    expect(find.text('SWITCH PLAYER'), findsOneWidget);
    await tester.tap(find.text('MPV · Software'));
    await settle(tester, maxFrames: 8);
    expect(engine.calls, contains('switchProfile software'));
    // The reopened stream plays and the overlay is gone.
    expect(find.text("Can't play this stream"), findsNothing);
    expect(engine.state.playing, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await closePlayer(tester);
  });

  testWidgets('the ⓘ hint opens the info panel; Next episode in the panel', (
    tester,
  ) async {
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      VodPlayRequest(
        playlistId: fx.playlistId,
        type: ItemType.episode,
        providerId: episode1,
        resume: false,
      ),
      factory: factory,
    );
    await hover(tester, const Offset(700, 400));
    await tester.tap(find.byKey(const ValueKey('player-info-hint')));
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-info-panel')), findsOneWidget);
    expect(find.text('Next episode'), findsOneWidget);
    await tester.tap(find.text('Next episode'));
    await settlePlayer(tester, frames: 6);
    expect(factory.last.openedSources, hasLength(2));
    expect(find.byKey(const ValueKey('player-info-panel')), findsNothing);
    await closePlayer(tester);
    await clearState(tester, episode1, ItemType.episode);
    await clearState(tester, episode2, ItemType.episode);
  });

  testWidgets('keyboard: Space, ←/→, Shift+→, digits, M, ↑, Ctrl+Shift+D, '
      'Down opens the info panel', (tester) async {
    final factory = manualFactory();
    final player = await pumpPlayer(tester, fx, movie(), factory: factory);
    final engine = factory.last;
    await engine.seek(const Duration(minutes: 5));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(engine.state.playing, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(engine.state.playing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(engine.state.position, const Duration(minutes: 5, seconds: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    expect(engine.state.position, const Duration(minutes: 5));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(engine.state.position, const Duration(minutes: 6));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    expect(engine.state.position, engine.state.duration * 0.5);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(engine.state.muted, isTrue);
    expect(find.byKey(const ValueKey('player-volume-osd')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('player-mute-indicator')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(engine.state.muted, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('player-stats')), findsOneWidget);
    expect(find.text('d3d11va'), findsOneWidget);

    // Controls are visible (keys showed them): Down opens the info panel.
    expect(player.controlsVisible, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-info-panel')), findsOneWidget);
    expect(find.text('From the beginning'), findsOneWidget);
    expect(find.text('FHD'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-info-panel')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await closePlayer(tester);
  });

  testWidgets('the volume carries over to the next player', (tester) async {
    var factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await pumpUi(tester);
    expect(factory.last.state.volume, 90);
    await closePlayer(tester);
    factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    expect(factory.last.state.volume, 90);
    expect(factory.last.state.muted, isFalse);
    await tester.pump(const Duration(seconds: 2));
    await closePlayer(tester);
    playerSessionVolume = null;
  });

  testWidgets('double-click toggles full screen; Esc leaves full screen, then '
      'closes the player', (tester) async {
    final window = FakePlayerWindow();
    final factory = manualFactory();
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Center(
          child: KButton(
            label: 'Open',
            onPressed: () => openPlayer(context, movie()),
          ),
        ),
      ),
      overrides: playerOverrides(fx, factory: factory, window: window),
    );
    await tester.tap(find.text('Open'));
    await settle(tester, maxFrames: 10);
    await settleDrift(tester, rounds: 12);
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.tap(find.byType(PlayerScreen), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byType(PlayerScreen), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(window.toggles, 1);
    expect(window.fullscreen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, maxFrames: 6);
    expect(window.fullscreen, isFalse);
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, maxFrames: 10);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(factory.last.isDisposed, isTrue);
    await closePlayer(tester);
  });
}
