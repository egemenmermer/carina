import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/tables.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/player/player_api.dart';
import 'package:carina/player/ui/player_menus.dart';
import 'package:carina/player/ui/player_screen.dart';

import 'player_test_support.dart';

/// The player with a remote: D-pad focus traversal between the controls,
/// OK, Back, the focusable seek bar and focus after overlays.
void main() {
  late MockImportFixture fx;
  late List<ChannelView> ulusal;

  setUpAll(() async {
    await loadAppFonts();
    fx = await importPlayerFixture();
    final live = LiveRepository(fx.db, fx.settings);
    ulusal = await live.channels(
      fx.playlistId,
      const ProviderCategory(MockFixtures.ulusalCategoryId),
    );
    await live.dispose();
  });
  tearDownAll(() => fx.dispose());

  final movieId = '${MockFixtures.kisUykusu}';
  final episode1 = '${MockFixtures.episodeId(MockFixtures.sicakKafa, 1, 1)}';

  VodPlayRequest movie() => VodPlayRequest(
    playlistId: fx.playlistId,
    type: ItemType.movie,
    providerId: movieId,
    resume: false,
  );

  VodPlayRequest episode() => VodPlayRequest(
    playlistId: fx.playlistId,
    type: ItemType.episode,
    providerId: episode1,
    resume: false,
  );

  LivePlayRequest channel(
    int i, {
    PlayerInitialOverlay overlay = PlayerInitialOverlay.none,
  }) => LivePlayRequest(
    playlistId: fx.playlistId,
    channelId: ulusal[i].providerId,
    categoryId: MockFixtures.ulusalCategoryId,
    initialOverlay: overlay,
  );

  /// The player on TV, pushed over a launcher so Back can leave it.
  Future<PlayerScreenState> openTv(
    WidgetTester tester,
    PlayRequest request,
    FakeEngineFactory factory,
  ) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Center(
          child: KButton(
            label: 'Open',
            onPressed: () => openPlayer(context, request),
          ),
        ),
      ),
      overrides: playerOverrides(
        fx,
        factory: factory,
        formFactor: FormFactor.tv,
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester, maxFrames: 10);
    await settleDrift(tester, rounds: 12);
    return tester.state<PlayerScreenState>(find.byType(PlayerScreen));
  }

  String? focusLabel() => FocusManager.instance.primaryFocus?.debugLabel;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await pumpUi(tester);
  }

  /// Lets the controls time out.
  Future<void> hideControls(WidgetTester tester, PlayerScreenState p) async {
    await tester.pump(const Duration(seconds: 4));
    expect(p.controlsVisible, isFalse);
  }

  testWidgets('VOD, controls hidden: ←/→ seek and bring the controls with '
      'focus on the seek bar', (tester) async {
    final factory = manualFactory();
    final player = await openTv(tester, movie(), factory);
    final engine = factory.last;
    await engine.seek(const Duration(minutes: 5));
    await hideControls(tester, player);
    expect(focusLabel(), 'player');

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(engine.state.position, const Duration(minutes: 5, seconds: 10));
    expect(player.controlsVisible, isTrue);
    expect(focusLabel(), 'player seek bar');

    // Hidden again: ← seeks back and shows them again.
    await hideControls(tester, player);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(engine.state.position, const Duration(minutes: 5));
    expect(focusLabel(), 'player seek bar');
    await closePlayer(tester);
  });

  testWidgets('VOD: OK pauses with the controls hidden and plays again from '
      'the seek bar', (tester) async {
    final factory = manualFactory();
    final player = await openTv(tester, movie(), factory);
    final engine = factory.last;
    await hideControls(tester, player);
    expect(engine.state.playing, isTrue);

    await press(tester, LogicalKeyboardKey.select);
    expect(engine.state.playing, isFalse);
    expect(player.controlsVisible, isTrue);
    expect(focusLabel(), 'player seek bar');

    await press(tester, LogicalKeyboardKey.select);
    expect(engine.state.playing, isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(engine.state.playing, isFalse);
    await closePlayer(tester);
  });

  testWidgets('controls shown: the D-pad moves between them, OK activates, '
      'Back hides them first and then leaves', (tester) async {
    final factory = manualFactory();
    final player = await openTv(tester, movie(), factory);
    final engine = factory.last;
    await engine.seek(const Duration(minutes: 5));
    await hideControls(tester, player);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(player.controlsVisible, isTrue);
    expect(focusLabel(), 'player seek bar');
    // Down: the info hint; OK opens the panel.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusLabel(), 'player hint');
    expect(engine.state.position, const Duration(minutes: 5));
    await press(tester, LogicalKeyboardKey.select);
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-info-panel')), findsOneWidget);
    // Back closes the panel and focus returns to the hint.
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-info-panel')), findsNothing);
    expect(focusLabel(), 'player hint');
    expect(player.controlsVisible, isTrue);

    // Up from the seek bar reaches a button; ←/→ keep moving between them.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusLabel(), endsWith(' button'));
    final first = FocusManager.instance.primaryFocus;
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(FocusManager.instance.primaryFocus, isNot(same(first)));
    expect(engine.state.position, const Duration(minutes: 5));

    // First Back hides the controls, the second one leaves the player.
    await press(tester, LogicalKeyboardKey.escape);
    expect(player.controlsVisible, isFalse);
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(focusLabel(), 'player');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, maxFrames: 10);
    expect(find.byType(PlayerScreen), findsNothing);
    await closePlayer(tester);
  });

  testWidgets('auto-hide hands focus back to the player: ← / → still seek', (
    tester,
  ) async {
    final factory = manualFactory();
    final player = await openTv(tester, movie(), factory);
    final engine = factory.last;
    await engine.seek(const Duration(minutes: 5));
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusLabel(), endsWith(' button'));

    await hideControls(tester, player);
    await pumpUi(tester);
    expect(focusLabel(), 'player');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(engine.state.position, const Duration(minutes: 5, seconds: 10));
    await closePlayer(tester);
  });

  testWidgets('seek bar: ←/→ scrub in steps that grow while the key repeats, '
      'the seek lands when the key rests', (tester) async {
    final factory = manualFactory();
    final player = await openTv(tester, movie(), factory);
    final engine = factory.last;
    await engine.seek(const Duration(minutes: 5));
    await hideControls(tester, player);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusLabel(), 'player seek bar');

    // One press: +10 s once the key rests; the target shows meanwhile.
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(engine.state.position, const Duration(minutes: 5));
    expect(find.text('5:10'), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.state.position, const Duration(minutes: 5, seconds: 10));

    // Held: 10 s a step, then 30 s, with a single seek at the end.
    await tester.pump(const Duration(seconds: 1));
    final seeks = engine.state.position;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.state.position, seeks);
    await tester.pump(const Duration(milliseconds: 400));
    // 10 + 3 × 10 + 3 × 30 s.
    expect(engine.state.position, seeks + const Duration(seconds: 130));

    // ← steps back, never below 0.
    await engine.seek(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.state.position, Duration.zero);
    await closePlayer(tester);
  });

  testWidgets('a menu opened from a button returns focus to that button', (
    tester,
  ) async {
    final factory = manualFactory();
    final player = await openTv(tester, movie(), factory);
    await hideControls(tester, player);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusLabel(), endsWith(' button'));
    final button = FocusManager.instance.primaryFocus;

    await press(tester, LogicalKeyboardKey.select);
    await settle(tester, maxFrames: 8);
    expect(player.controlsVisible, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester, maxFrames: 8);
    await pumpUi(tester);
    expect(FocusManager.instance.primaryFocus, same(button));
    await closePlayer(tester);
  });

  testWidgets('More on TV: Muted, no Full screen', (tester) async {
    final factory = manualFactory();
    final player = await openTv(tester, movie(), factory);
    final engine = factory.last;
    unawaited(player.openMenu(PlayerMenu.more));
    await settle(tester, maxFrames: 8);
    expect(find.text('Full screen'), findsNothing);
    expect(find.text('Statistics'), findsOneWidget);
    await tester.tap(find.text('Muted'));
    await settle(tester, maxFrames: 8);
    expect(engine.state.muted, isTrue);
    await closePlayer(tester);
  });

  testWidgets('info panel: ↑/↓ move between its buttons instead of volume', (
    tester,
  ) async {
    final factory = manualFactory();
    final player = await openTv(tester, episode(), factory);
    final engine = factory.last;
    await engine.seek(const Duration(minutes: 5));
    await hideControls(tester, player);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    await settle(tester, maxFrames: 8);
    expect(find.text('Next episode'), findsOneWidget);
    final first = FocusManager.instance.primaryFocus;
    final volume = engine.state.volume;
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus, isNot(same(first)));
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus, same(first));
    expect(find.byKey(const ValueKey('player-info-panel')), findsOneWidget);
    expect(engine.state.volume, volume);
    await closePlayer(tester);
  });

  testWidgets('live: ←/→ bring the controls with focus, ↑/↓ zap, Back '
      'hides the controls and then leaves', (tester) async {
    final factory = manualFactory();
    final player = await openTv(tester, channel(0), factory);
    await hideControls(tester, player);
    expect(focusLabel(), 'player');

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(player.controlsVisible, isTrue);
    expect(focusLabel(), 'player hint');
    // Up: the buttons; OK opens one of the menus.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusLabel(), endsWith(' button'));

    await press(tester, LogicalKeyboardKey.escape);
    expect(player.controlsVisible, isFalse);
    expect(focusLabel(), 'player');
    // Hidden: ↓ zaps as on desktop.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await settleDrift(tester, rounds: 3);
    await tester.pump(const Duration(milliseconds: 200));
    await settleDrift(tester, rounds: 4);
    expect(factory.last.openedSources.last.title, ulusal[1].displayName);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, maxFrames: 10);
    expect(find.byType(PlayerScreen), findsNothing);
    await closePlayer(tester);
  });

  testWidgets('live: the action sheet is reached with OK; the mini guide '
      'moves with ↓ and tunes with OK', (tester) async {
    final factory = manualFactory();
    await openTv(tester, channel(0), factory);
    await press(tester, LogicalKeyboardKey.select);
    await settle(tester, maxFrames: 8);
    expect(find.byKey(const ValueKey('player-action-sheet')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    await settle(tester, maxFrames: 8);
    await settleDrift(tester, rounds: 4);
    expect(find.byKey(const ValueKey('player-mini-guide')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    await settleDrift(tester, rounds: 3);
    await tester.pump(const Duration(milliseconds: 200));
    await settleDrift(tester, rounds: 4);
    expect(find.byKey(const ValueKey('player-mini-guide')), findsNothing);
    expect(factory.last.openedSources.last.title, ulusal[1].displayName);
    // Focus is back on the player: ↓ keeps zapping.
    expect(focusLabel(), 'player');
    await closePlayer(tester);
  });
}
