import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/time_format.dart';
import 'package:carina/data/repositories/epg_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';
import 'package:carina/player/ui/player_screen.dart';

import 'player_test_support.dart';

void main() {
  late MockImportFixture fx;
  late List<ChannelView> ulusal;
  late ProgrammeView pastProgramme;
  late NowNext trtNowNext;

  setUpAll(() async {
    await loadAppFonts();
    fx = await importPlayerFixture();
    final live = LiveRepository(fx.db, fx.settings);
    ulusal = await live.channels(
      fx.playlistId,
      const ProviderCategory(MockFixtures.ulusalCategoryId),
    );
    final trt = ulusal.firstWhere(
      (c) => c.providerId == '${MockFixtures.trt1Hd}',
    );
    final epg = EpgRepository(
      fx.db,
      PlaylistRepository(fx.db, fx.secrets, fx.settings),
    );
    trtNowNext = (await epg.nowNext(fx.playlistId, [
      trt.epgKey!,
    ], at: testNow))[trt.epgKey!]!;
    final past = await epg.programmes(
      fx.playlistId,
      trt.epgKey!,
      testNow.subtract(const Duration(hours: 8)),
      testNow.subtract(const Duration(hours: 2)),
    );
    pastProgramme = past.firstWhere(
      (p) => p.stop.isBefore(testNow.subtract(const Duration(hours: 2))),
    );
    epg.dispose();
    await live.dispose();
  });
  tearDownAll(() => fx.dispose());

  String id(int i) => ulusal[i].providerId;
  String name(int i) => ulusal[i].displayName;

  LivePlayRequest channel(
    String channelId, {
    List<String>? zap,
    PlayerInitialOverlay overlay = PlayerInitialOverlay.none,
  }) => LivePlayRequest(
    playlistId: fx.playlistId,
    channelId: channelId,
    zapChannelIds: zap,
    categoryId: MockFixtures.ulusalCategoryId,
    initialOverlay: overlay,
  );

  /// Lets a zap resolve: the neighbor lookup, the 150 ms debounce, the URL.
  Future<void> settleZap(WidgetTester tester) async {
    await settleDrift(tester, rounds: 3);
    await tester.pump(const Duration(milliseconds: 200));
    await settleDrift(tester, rounds: 4);
  }

  List<String?> titles(WidgetTester tester, FakeEngineFactory f) =>
      f.last.openedSources.map((s) => s.title).toList();

  testWidgets('↑/↓ zap through zapChannelIds (wrapping), the OSD shows the '
      'new channel, Backspace returns to the previous one', (tester) async {
    final factory = manualFactory();
    final zap = [id(0), id(1), id(4), id(5)];
    await pumpPlayer(tester, fx, channel(id(1), zap: zap), factory: factory);
    expect(titles(tester, factory), [name(1)]);
    expect(factory.last.openedSources.single.isLive, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleDrift(tester, rounds: 3);
    // The OSD shows the new channel before the stream opens.
    expect(find.byKey(const ValueKey('player-zap-osd')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('player-zap-osd')),
        matching: find.text(name(4)),
      ),
      findsOneWidget,
    );
    await settleZap(tester);
    expect(titles(tester, factory).last, name(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settleZap(tester);
    expect(titles(tester, factory).last, name(5));
    // Wraps around to the first channel.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleZap(tester);
    expect(titles(tester, factory).last, name(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settleZap(tester);
    expect(titles(tester, factory).last, name(5));

    // Backspace: back to the channel before the last switch.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await settleZap(tester);
    expect(titles(tester, factory).last, name(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await settleZap(tester);
    expect(titles(tester, factory).last, name(5));

    // One engine for every channel; the OSD hides after 3 s.
    expect(factory.created, hasLength(1));
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('player-zap-osd')), findsNothing);
    await closePlayer(tester);
  });

  testWidgets('without zapChannelIds the category order is used; the first '
      'zap opens at once, a held key only opens where it stops; tunes go to '
      'Last watched', (tester) async {
    await tester.runAsync(
      () => LiveRepository(fx.db, fx.settings).clearLastWatched(fx.playlistId),
    );
    final factory = manualFactory();
    await pumpPlayer(tester, fx, channel(id(0)), factory: factory);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleDrift(tester, rounds: 1);
    // The first zap opens without waiting.
    expect(titles(tester, factory), [name(0), name(1)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleZap(tester);
    // Within the burst id(2) was only shown; id(3) opened.
    expect(titles(tester, factory), [name(0), name(1), name(3)]);

    final recent = await tester.runAsync(
      () => LiveRepository(
        fx.db,
        fx.settings,
      ).channels(fx.playlistId, const LastWatchedCategory()),
    );
    expect(recent!.first.providerId, id(3));
    expect(recent.map((c) => c.providerId), contains(id(0)));
    expect(recent.map((c) => c.providerId), isNot(contains(id(2))));
    await closePlayer(tester);
  });

  testWidgets('mouse wheel zaps when the setting is on', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, channel(id(0)), factory: factory);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(700, 400)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await settleZap(tester);
    expect(titles(tester, factory).last, name(1));
    await closePlayer(tester);
  });

  testWidgets('live overlay: logo, name, LIVE, programme, progress and Next', (
    tester,
  ) async {
    final factory = manualFactory();
    await pumpPlayer(
      tester,
      fx,
      channel(id(0), overlay: PlayerInitialOverlay.controls),
      factory: factory,
    );
    await settlePlayer(tester);
    expect(find.byKey(const ValueKey('player-live-header')), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('FHD'), findsOneWidget);
    expect(find.text('25 FPS'), findsOneWidget);
    expect(find.text(trtNowNext.now!.title), findsOneWidget);
    expect(find.textContaining(trtNowNext.next!.title), findsOneWidget);
    expect(find.textContaining('Next:'), findsOneWidget);
    // Desktop has Backspace: no on-screen previous-channel button.
    expect(
      find.byKey(const ValueKey('player-previous-channel')),
      findsNothing,
    );
    await closePlayer(tester);
  });

  testWidgets('Enter opens the action sheet; Mini TV Guide tunes with ↓ + '
      'Enter; G and Shift+G toggle the guides', (tester) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, channel(id(0)), factory: factory);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-action-sheet')), findsOneWidget);
    expect(find.text('What do you need to do?'), findsOneWidget);
    expect(find.text('Full TV Guide (change channel)'), findsOneWidget);
    expect(find.text('Add channel (multi-channel)'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Mini TV Guide (change channel)'));
    await settle(tester, maxFrames: 8);
    await settleDrift(tester, rounds: 4);
    expect(find.byKey(const ValueKey('player-mini-guide')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleZap(tester);
    expect(find.byKey(const ValueKey('player-mini-guide')), findsNothing);
    expect(titles(tester, factory).last, name(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await settlePlayer(tester);
    expect(find.byKey(const ValueKey('player-mini-guide')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('player-mini-guide')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('player-full-guide')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('player-full-guide')), findsNothing);

    // Cancel closes the sheet without doing anything.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, maxFrames: 8);
    await tester.tap(find.text('Cancel'));
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-action-sheet')), findsNothing);
    await closePlayer(tester);
  });

  testWidgets('number zapping tunes the typed number after 1.5 s', (
    tester,
  ) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, channel(id(0)), factory: factory);
    final target = ulusal.firstWhere((c) => c.number == 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(find.byKey(const ValueKey('player-number-osd')), findsOneWidget);
    expect(titles(tester, factory), hasLength(1));
    await tester.pump(const Duration(milliseconds: 1600));
    await settleZap(tester);
    expect(titles(tester, factory).last, target.displayName);
    expect(find.byKey(const ValueKey('player-number-osd')), findsNothing);

    for (final key in [
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.digit9,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pump(const Duration(milliseconds: 1600));
    await settleZap(tester);
    expect(find.text('No channel with number 9999'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await closePlayer(tester);
  });

  testWidgets('live reconnects show progress; a final error offers Retry', (
    tester,
  ) async {
    final factory = manualFactory();
    await pumpPlayer(tester, fx, channel(id(0)), factory: factory);
    final engine = factory.last;
    engine.simulateReconnect(2);
    await pumpUi(tester);
    expect(find.text('Reconnecting… (2/3)'), findsOneWidget);
    engine.simulateError(
      const EngineError(kind: EngineErrorKind.ended, message: 'ended'),
    );
    await pumpUi(tester);
    expect(find.text('The stream ended.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await pumpUi(tester);
    expect(find.text('The stream ended.'), findsNothing);
    expect(engine.calls.where((c) => c.startsWith('open')), hasLength(2));

    // A dead channel does not trap the user: ↓ still zaps.
    engine.simulateError(
      const EngineError(
        kind: EngineErrorKind.http,
        statusCode: 404,
        message: 'nf',
      ),
    );
    await pumpUi(tester);
    expect(find.text('Stream not found (HTTP 404).'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleZap(tester);
    expect(titles(tester, factory).last, name(1));
    expect(find.text('Stream not found (HTTP 404).'), findsNothing);
    await closePlayer(tester);
  });

  testWidgets('catch-up: the bar spans the programme, ←/→ jump 30 s and '
      'Shift+→ 5 min', (tester) async {
    final factory = manualFactory(vodDuration: const Duration(hours: 4));
    await pumpPlayer(
      tester,
      fx,
      CatchupPlayRequest(
        playlistId: fx.playlistId,
        channelId: '${MockFixtures.trt1Hd}',
        startUtc: pastProgramme.start,
        endUtc: pastProgramme.stop,
        title: pastProgramme.title,
        initialOverlay: PlayerInitialOverlay.controls,
      ),
      factory: factory,
    );
    final player = tester.state<PlayerScreenState>(find.byType(PlayerScreen));
    final engine = factory.last;
    final source = engine.openedSources.single;
    expect(source.isLive, isFalse);
    expect(source.url, contains('/timeshift/'));
    expect(player.controller.duration, pastProgramme.duration);

    final format = CarinaTimeFormat(locale: 'en', use24h: false);
    expect(find.text(format.time(pastProgramme.start)), findsOneWidget);
    expect(find.text(format.time(pastProgramme.stop)), findsOneWidget);
    expect(find.text(pastProgramme.title), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(engine.state.position, const Duration(seconds: 30));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(engine.state.position, const Duration(minutes: 5, seconds: 30));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await pumpUi(tester);
    expect(engine.state.playing, isFalse);
    // Seeking past the programme end stops at the end.
    await player.controller.seekTo(const Duration(hours: 9));
    expect(engine.state.position, pastProgramme.duration);
    await closePlayer(tester);
  });
}
