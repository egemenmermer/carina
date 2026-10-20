import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/tables.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/repositories/watch_state_repository.dart';
import 'package:carina/features/multiview/multiview_layout.dart';
import 'package:carina/features/multiview/multiview_screen.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';

import 'player_test_support.dart';

void main() {
  late MockImportFixture fx;
  late List<String> ulusal;

  setUpAll(() async {
    await loadAppFonts();
    fx = await importPlayerFixture();
    final live = LiveRepository(fx.db, fx.settings);
    ulusal = [
      for (final c in await live.channels(
        fx.playlistId,
        const ProviderCategory(MockFixtures.ulusalCategoryId),
      ))
        c.providerId,
    ];
    await live.dispose();
  });
  tearDownAll(() => fx.dispose());

  VodPlayRequest movie({
    PlayerInitialOverlay overlay = PlayerInitialOverlay.controls,
    bool? resume = false,
  }) => VodPlayRequest(
    playlistId: fx.playlistId,
    type: ItemType.movie,
    providerId: '${MockFixtures.kisUykusu}',
    resume: resume,
    initialOverlay: overlay,
  );

  LivePlayRequest channel({
    PlayerInitialOverlay overlay = PlayerInitialOverlay.none,
  }) => LivePlayRequest(
    playlistId: fx.playlistId,
    channelId: '${MockFixtures.trt1Hd}',
    categoryId: MockFixtures.ulusalCategoryId,
    initialOverlay: overlay,
  );

  Future<void> vodShot(
    WidgetTester tester,
    String name,
    PlayerInitialOverlay overlay,
  ) async {
    final factory = manualFactory(
      vodDuration: const Duration(minutes: 2, seconds: 59),
    );
    await pumpPlayer(tester, fx, movie(overlay: overlay), factory: factory);
    factory.last.advance(const Duration(seconds: 13));
    await settlePlayer(tester);
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, name);
    await closePlayer(tester);
  }

  testWidgets('player_vod_controls', (tester) async {
    await vodShot(tester, 'player_vod_controls', PlayerInitialOverlay.controls);
  });

  testWidgets('player_vod_audio_menu', (tester) async {
    await vodShot(
      tester,
      'player_vod_audio_menu',
      PlayerInitialOverlay.audioMenu,
    );
  });

  testWidgets('player_vod_switch_player', (tester) async {
    await vodShot(
      tester,
      'player_vod_switch_player',
      PlayerInitialOverlay.switchPlayerMenu,
    );
  });

  testWidgets('player_vod_subtitles_menu', (tester) async {
    await vodShot(
      tester,
      'player_vod_subtitles_menu',
      PlayerInitialOverlay.subtitlesMenu,
    );
  });

  testWidgets('player_vod_info_panel', (tester) async {
    await vodShot(
      tester,
      'player_vod_info_panel',
      PlayerInitialOverlay.infoPanel,
    );
  });

  testWidgets('player_stats', (tester) async {
    await vodShot(tester, 'player_stats', PlayerInitialOverlay.stats);
  });

  testWidgets('player_resume_prompt', (tester) async {
    await tester.runAsync(
      () => WatchStateRepository(db: fx.db).save(
        fx.playlistId,
        ItemType.movie,
        '${MockFixtures.kisUykusu}',
        const Duration(minutes: 12, seconds: 34),
        const Duration(minutes: 42, seconds: 17),
      ),
    );
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      movie(overlay: PlayerInitialOverlay.none, resume: null),
      factory: factory,
    );
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'player_resume_prompt');
    await closePlayer(tester);
    await tester.runAsync(
      () => WatchStateRepository(db: fx.db)
          .clear(fx.playlistId, ItemType.movie, '${MockFixtures.kisUykusu}'),
    );
  });

  testWidgets('player_next_episode', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      VodPlayRequest(
        playlistId: fx.playlistId,
        type: ItemType.episode,
        providerId: '${MockFixtures.episodeId(MockFixtures.sicakKafa, 1, 1)}',
        seriesId: '${MockFixtures.sicakKafa}',
        resume: false,
      ),
      factory: factory,
    );
    final engine = factory.last;
    await engine.seek(engine.state.duration - const Duration(seconds: 27));
    engine.advance(const Duration(seconds: 1));
    await settlePlayer(tester);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'player_next_episode');
    await closePlayer(tester);
  });

  testWidgets('player_error', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, movie(), factory: factory);
    factory.last.simulateError(
      const EngineError(
        kind: EngineErrorKind.http,
        statusCode: 404,
        message: 'Stream not found (HTTP 404).',
      ),
    );
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'player_error');
    await closePlayer(tester);
  });

  testWidgets('player_live_controls', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      channel(overlay: PlayerInitialOverlay.controls),
      factory: factory,
    );
    await settlePlayer(tester);
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'player_live_controls');
    await closePlayer(tester);
  });

  testWidgets('player_live_osd', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, channel(), factory: factory);
    await tester.pump(const Duration(seconds: 4));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settlePlayer(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await settlePlayer(tester);
    await saveScreen(tester, 'player_live_osd');
    await closePlayer(tester);
  });

  testWidgets('player_live_action_sheet', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      channel(overlay: PlayerInitialOverlay.actionSheet),
      factory: factory,
    );
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'player_live_action_sheet');
    await closePlayer(tester);
  });

  testWidgets('player_live_mini_guide', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      channel(overlay: PlayerInitialOverlay.miniGuide),
      factory: factory,
    );
    await settlePlayer(tester, frames: 8);
    await saveScreen(tester, 'player_live_mini_guide');
    await closePlayer(tester);
  });

  testWidgets('player_tr_controls (Turkish)', (tester) async {
    final factory = manualFactory(
      vodDuration: const Duration(minutes: 2, seconds: 59),
    );
    await pumpPlayer(
      tester,
      fx,
      movie(overlay: PlayerInitialOverlay.subtitlesMenu),
      factory: factory,
      locale: const Locale('tr'),
    );
    factory.last.advance(const Duration(seconds: 13));
    await settlePlayer(tester);
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'player_tr_subtitles_menu');
    await closePlayer(tester);
  });

  testWidgets('player_tr_live (Turkish)', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      channel(overlay: PlayerInitialOverlay.actionSheet),
      factory: factory,
      locale: const Locale('tr'),
    );
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, 'player_tr_live_action_sheet');
    await closePlayer(tester);
  });

  Future<void> multiviewShot(
    WidgetTester tester,
    String name,
    MultiviewLayout layout,
  ) async {
    final factory = manualFactory();
    await pumpScreen(
      tester,
      MultiviewScreen(
        playlistId: fx.playlistId,
        initialLayout: layout,
        initialChannelIds: ulusal.take(4).toList(),
      ),
      overrides: playerOverrides(fx, factory: factory),
    );
    await settleDrift(tester, rounds: 12);
    // Hover the second tile to show its toolbar.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MultiviewScreen)),
    );
    expect(container, isNotNull);
    await settle(tester, maxFrames: 10);
    await saveScreen(tester, name);
    await closePlayer(tester);
  }

  testWidgets('multiview_2x2', (tester) async {
    await multiviewShot(tester, 'multiview_2x2', MultiviewLayout.grid2x2);
  });

  testWidgets('multiview_1plus3', (tester) async {
    await multiviewShot(
      tester,
      'multiview_1plus3',
      MultiviewLayout.onePlusThree,
    );
  });
}
