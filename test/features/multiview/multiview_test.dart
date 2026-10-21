import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/features/multiview/multiview_api.dart';
import 'package:carina/features/multiview/multiview_layout.dart';
import 'package:carina/features/multiview/multiview_screen.dart';
import 'package:carina/features/multiview/multiview_state.dart';
import 'package:carina/core/core.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';
import 'package:carina/player/ui/player_screen.dart';

import '../../player/ui/player_test_support.dart';

void main() {
  group('layout geometry', () {
    const area = Size(1392, 800);

    void expect16x9(Rect r) =>
        expect(r.width / r.height, closeTo(16 / 9, 0.01));

    test('every layout keeps 16:9 tiles inside the area', () {
      for (final layout in MultiviewLayout.values) {
        final rects = multiviewRects(layout, area, gap: 10);
        expect(rects, hasLength(layout.slots));
        for (final r in rects) {
          expect16x9(r);
          expect(r.left, greaterThanOrEqualTo(-0.01));
          expect(r.top, greaterThanOrEqualTo(-0.01));
          expect(r.right, lessThanOrEqualTo(area.width + 0.01));
          expect(r.bottom, lessThanOrEqualTo(area.height + 0.01));
        }
        // No overlaps.
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(
              rects[i].intersect(rects[j]).isEmpty ||
                  rects[i].intersect(rects[j]).width <= 0 ||
                  rects[i].intersect(rects[j]).height <= 0,
              isTrue,
            );
          }
        }
      }
    });

    test('1 + 3: three small tiles are as tall as the big one', () {
      final r = multiviewRects(MultiviewLayout.onePlusThree, area, gap: 10);
      expect(r[0].width, greaterThan(r[1].width * 2.5));
      expect(r[3].bottom, closeTo(r[0].bottom, 0.01));
      expect(r[1].top, closeTo(r[0].top, 0.01));
    });

    test('arrow focus moves to the nearest tile in that direction', () {
      final r = multiviewRects(MultiviewLayout.grid2x2, area);
      expect(neighborTile(r, 0, TraversalDirection.right), 1);
      expect(neighborTile(r, 0, TraversalDirection.down), 2);
      expect(neighborTile(r, 3, TraversalDirection.up), 1);
      expect(neighborTile(r, 3, TraversalDirection.left), 2);
      expect(neighborTile(r, 0, TraversalDirection.left), 0);
      final p = multiviewRects(MultiviewLayout.onePlusThree, area);
      expect(neighborTile(p, 0, TraversalDirection.right), 2);
      expect(neighborTile(p, 1, TraversalDirection.down), 2);
      expect(neighborTile(p, 3, TraversalDirection.left), 0);
    });
  });

  group('session', () {
    late ProviderContainer container;
    MultiviewSessionNotifier notifier() =>
        container.read(multiviewSessionProvider(1).notifier);
    MultiviewSession session() => container.read(multiviewSessionProvider(1));

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('adds up to four, focuses the new tile, grows the layout', () {
      expect(notifier().add('a'), isTrue);
      expect(notifier().add('b'), isTrue);
      expect(session().layout, MultiviewLayout.sideBySide);
      expect(notifier().add('c'), isTrue);
      expect(session().layout, MultiviewLayout.grid2x2);
      expect(session().focused, 2);
      expect(notifier().add('d'), isTrue);
      expect(notifier().add('e'), isFalse);
      expect(session().tiles.map((t) => t.channelId), ['a', 'b', 'c', 'd']);
      // An open channel is focused, not duplicated.
      expect(notifier().add('b'), isTrue);
      expect(session().focused, 1);
      expect(session().tiles, hasLength(4));
    });

    test('close, change channel and swap with main keep ids and focus', () {
      notifier().replace(['a', 'b', 'c']);
      final ids = session().tiles.map((t) => t.id).toList();
      notifier().focus(2);
      notifier().swapWithMain(2);
      expect(session().tiles.map((t) => t.channelId), ['c', 'b', 'a']);
      expect(session().focused, 0);
      expect(session().tiles.first.id, ids[2]);
      notifier().changeChannel(1, 'x');
      expect(session().tiles[1].channelId, 'x');
      expect(session().tiles[1].id, ids[1]);
      expect(session().focused, 1);
      notifier().close(0);
      expect(session().tiles.map((t) => t.channelId), ['x', 'a']);
      expect(session().focused, 0);
      // 1 + 1 cannot hold three tiles.
      notifier().replace(['a', 'b', 'c'], layout: MultiviewLayout.onePlusThree);
      notifier().setLayout(MultiviewLayout.sideBySide);
      expect(session().layout, MultiviewLayout.onePlusThree);
    });
  });

  group('session on a TV', () {
    late ProviderContainer container;
    MultiviewSessionNotifier notifier() =>
        container.read(multiviewSessionProvider(1).notifier);
    MultiviewSession session() => container.read(multiviewSessionProvider(1));

    setUp(
      () => container = ProviderContainer(
        overrides: [formFactorProvider.overrideWithValue(FormFactor.tv)],
      ),
    );
    tearDown(() => container.dispose());

    test('holds two tiles in 1 + 1 only', () {
      expect(session().maxTiles, 2);
      expect(session().layouts, [MultiviewLayout.sideBySide]);
      expect(notifier().add('a'), isTrue);
      expect(notifier().add('b'), isTrue);
      expect(session().isFull, isTrue);
      expect(notifier().add('c'), isFalse);
      expect(session().tiles, hasLength(2));
      expect(session().layout, MultiviewLayout.sideBySide);
    });

    test('replace and setLayout stay inside the cap', () {
      notifier().replace(['a', 'b', 'c', 'd'], layout: MultiviewLayout.grid2x2);
      expect(session().tiles.map((t) => t.channelId), ['a', 'b']);
      expect(session().layout, MultiviewLayout.sideBySide);
      notifier().setLayout(MultiviewLayout.grid2x2);
      expect(session().layout, MultiviewLayout.sideBySide);
      notifier().clear();
      expect(session().maxTiles, 2);
    });
  });

  test('desktop keeps all layouts and four tiles', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final s = container.read(multiviewSessionProvider(1));
    expect(s.maxTiles, 4);
    expect(s.layouts, MultiviewLayout.values);
    expect(
      MultiviewLayout.fitting(3, MultiviewLayout.sideBySide),
      MultiviewLayout.grid2x2,
    );
    expect(
      MultiviewLayout.fitting(2, MultiviewLayout.onePlusThree),
      MultiviewLayout.onePlusThree,
    );
  });

  group('screen', () {
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

    List<bool> mutedFlags(FakeEngineFactory f) => [
      for (final e in f.created) e.state.muted,
    ];

    testWidgets('only the focused tile has sound; click, arrows, Enter and '
        'Esc', (tester) async {
      final factory = manualFactory();
      await pumpScreen(
        tester,
        MultiviewScreen(
          playlistId: fx.playlistId,
          initialLayout: MultiviewLayout.grid2x2,
          initialChannelIds: ulusal.take(4).toList(),
        ),
        overrides: playerOverrides(fx, factory: factory),
      );
      await settleDrift(tester, rounds: 12);
      expect(factory.created, hasLength(4));
      for (final e in factory.created) {
        expect(e.options.profile, EngineProfile.lowLatency);
        expect(e.openedSources.single.isLive, isTrue);
      }
      expect(mutedFlags(factory), [false, true, true, true]);
      expect(find.byKey(const ValueKey('multiview-audio')), findsOneWidget);

      // Click the bottom-right tile.
      final tiles = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('multiview-tile-'),
      );
      expect(tiles, findsNWidgets(4));
      await tester.tap(tiles.at(3));
      await tester.pump(const Duration(milliseconds: 400));
      await pumpUi(tester);
      expect(mutedFlags(factory), [true, true, true, false]);

      // Arrow keys move the focus (and the sound).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await pumpUi(tester);
      expect(mutedFlags(factory), [true, false, true, true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await pumpUi(tester);
      expect(mutedFlags(factory), [false, true, true, true]);

      // Enter: the focused tile full screen; Esc: back to the grid.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpUi(tester);
      expect(tiles, findsOneWidget);
      expect(find.text('Esc to return to all channels'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpUi(tester);
      expect(tiles, findsNWidgets(4));

      // The layout picker switches to 1 + 3; 1 + 1 is off with 4 tiles.
      await tester.tap(
        find.byKey(const ValueKey('multiview-layout-onePlusThree')),
      );
      await pumpUi(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MultiviewScreen)),
      );
      expect(
        container.read(multiviewSessionProvider(fx.playlistId)).layout,
        MultiviewLayout.onePlusThree,
      );
      await tester.tap(
        find.byKey(const ValueKey('multiview-layout-sideBySide')),
      );
      await pumpUi(tester);
      expect(
        container.read(multiviewSessionProvider(fx.playlistId)).layout,
        MultiviewLayout.onePlusThree,
      );

      // Closing a tile disposes its engine.
      container.read(multiviewSessionProvider(fx.playlistId).notifier).close(3);
      await pumpUi(tester);
      expect(factory.created[3].isDisposed, isTrue);
      expect(tiles, findsNWidgets(3));
      await tester.pump(const Duration(seconds: 3));
      await closePlayer(tester);
      for (final e in factory.created) {
        expect(e.isDisposed, isTrue);
      }
    });

    testWidgets('addToMultiview: no warning for two streams, the connection '
        'warning (max_connections) before the 3rd and 4th, at most four', (
      tester,
    ) async {
      final factory = manualFactory();
      late BuildContext host;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
        overrides: playerOverrides(fx, factory: factory),
      );

      Future<void> add(String channelId) async {
        unawaited(
          addToMultiview(host, playlistId: fx.playlistId, channelId: channelId),
        );
        await settleDrift(tester, rounds: 6);
        await settle(tester, maxFrames: 8);
      }

      await add(ulusal[0]);
      expect(find.byType(MultiviewScreen), findsOneWidget);
      await add(ulusal[1]);
      expect(find.text('Open another stream?'), findsNothing);
      expect(factory.created, hasLength(2));

      await add(ulusal[2]);
      expect(find.text('Open another stream?'), findsOneWidget);
      expect(
        find.text(
          'Most IPTV accounts allow only 1–2 connections at the same time. '
          'Your account allows 2.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Open anyway'));
      await settleDrift(tester, rounds: 6);
      await settle(tester, maxFrames: 8);
      expect(factory.created, hasLength(3));

      // Cancel keeps three.
      await add(ulusal[4]);
      expect(find.text('Open another stream?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester, maxFrames: 8);
      expect(factory.created, hasLength(3));

      await add(ulusal[4]);
      await tester.tap(find.text('Open anyway'));
      await settleDrift(tester, rounds: 6);
      await settle(tester, maxFrames: 8);
      expect(factory.created, hasLength(4));

      // A fifth stream is refused with a toast.
      await add(ulusal[5]);
      expect(find.text('Open another stream?'), findsNothing);
      expect(find.text('Multi-channel shows up to 4 channels'), findsOneWidget);
      expect(factory.created, hasLength(4));
      await tester.pump(const Duration(seconds: 3));
      await closePlayer(tester);
    });

    testWidgets('on a TV: two tiles, no layout picker, adding is capped', (
      tester,
    ) async {
      final factory = manualFactory();
      await pumpScreen(
        tester,
        MultiviewScreen(
          playlistId: fx.playlistId,
          initialLayout: MultiviewLayout.grid2x2,
          initialChannelIds: ulusal.take(4).toList(),
        ),
        overrides: [
          ...playerOverrides(fx, factory: factory),
          formFactorProvider.overrideWithValue(FormFactor.tv),
        ],
      );
      await settleDrift(tester, rounds: 12);
      expect(factory.created, hasLength(2));
      final tiles = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('multiview-tile-'),
      );
      expect(tiles, findsNWidgets(2));
      for (final layout in MultiviewLayout.values) {
        expect(
          find.byKey(ValueKey('multiview-layout-${layout.name}')),
          findsNothing,
        );
      }
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MultiviewScreen)),
      );
      final context = tester.element(find.byType(MultiviewScreen));
      unawaited(
        addToMultiview(
          context,
          playlistId: fx.playlistId,
          channelId: ulusal[5],
        ),
      );
      await settleDrift(tester, rounds: 6);
      expect(find.text('Multi-channel shows up to 2 channels'), findsOneWidget);
      expect(
        container.read(multiviewSessionProvider(fx.playlistId)).tiles,
        hasLength(2),
      );
      await tester.pump(const Duration(seconds: 3));
      await closePlayer(tester);
    });

    testWidgets('live player Add channel opens multi-channel with the '
        'channel picker', (tester) async {
      final factory = manualFactory();
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Center(
            child: KButton(
              label: 'Open',
              onPressed: () => openPlayer(
                context,
                LivePlayRequest(
                  playlistId: fx.playlistId,
                  channelId: ulusal[0],
                ),
              ),
            ),
          ),
        ),
        overrides: playerOverrides(fx, factory: factory),
      );
      await tester.tap(find.text('Open'));
      await settle(tester, maxFrames: 10);
      await settleDrift(tester, rounds: 10);
      expect(find.byType(PlayerScreen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester, maxFrames: 8);
      await tester.tap(find.text('Add channel (multi-channel)'));
      await settle(tester, maxFrames: 10);
      await settleDrift(tester, rounds: 8);
      await settle(tester, maxFrames: 10);
      await settleDrift(tester, rounds: 6);
      expect(find.byType(PlayerScreen), findsNothing);
      expect(factory.created.first.isDisposed, isTrue);
      expect(find.byType(MultiviewScreen), findsOneWidget);
      expect(find.text('Choose a channel'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'kanal d');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, maxFrames: 10);
      await settleDrift(tester, rounds: 6);
      expect(find.text('Choose a channel'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MultiviewScreen)),
      );
      final tiles = container
          .read(multiviewSessionProvider(fx.playlistId))
          .tiles
          .map((t) => t.channelId)
          .toList();
      expect(tiles, hasLength(2));
      expect(tiles.first, ulusal[0]);
      await tester.pump(const Duration(seconds: 3));
      await closePlayer(tester);
    });

    testWidgets('addToMultiview with a layout fills it from the category', (
      tester,
    ) async {
      final factory = manualFactory();
      late BuildContext host;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
        overrides: playerOverrides(fx, factory: factory),
      );
      unawaited(
        addToMultiview(
          host,
          playlistId: fx.playlistId,
          channelId: ulusal[0],
          layout: MultiviewLayout.grid2x2,
        ),
      );
      await settleDrift(tester, rounds: 8);
      await settle(tester, maxFrames: 8);
      await settleDrift(tester, rounds: 6);
      expect(find.text('Open another stream?'), findsNothing);
      expect(factory.created, hasLength(4));
      expect(factory.created.first.openedSources.single.title, isNotEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MultiviewScreen)),
      );
      final s = container.read(multiviewSessionProvider(fx.playlistId));
      expect(s.layout, MultiviewLayout.grid2x2);
      expect(s.tiles.first.channelId, ulusal[0]);
      expect(s.tiles.map((t) => t.channelId).toSet(), hasLength(4));
      await closePlayer(tester);
    });

    group('on a TV remote', () {
      bool inside(String label) =>
          FocusManager.instance.primaryFocus?.ancestors.any(
            (n) => (n.debugLabel ?? '').startsWith(label),
          ) ??
          false;
      String? primary() => FocusManager.instance.primaryFocus?.debugLabel;

      Future<FakeEngineFactory> pumpTv(
        WidgetTester tester, {
        required int channels,
      }) async {
        final factory = manualFactory();
        await pumpScreen(
          tester,
          MultiviewScreen(
            playlistId: fx.playlistId,
            initialChannelIds: ulusal.take(channels).toList(),
          ),
          overrides: [
            ...playerOverrides(fx, factory: factory),
            formFactorProvider.overrideWithValue(FormFactor.tv),
          ],
        );
        await settleDrift(tester, rounds: 12);
        return factory;
      }

      Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
        await tester.sendKeyEvent(k);
        await pumpUi(tester);
      }

      testWidgets('OK toggles the tile once, even while the key repeats', (
        tester,
      ) async {
        await pumpTv(tester, channels: 2);
        final hint = find.text('Esc to return to all channels');
        expect(hint, findsNothing);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await pumpUi(tester);
        expect(hint, findsOneWidget);
        await key(tester, LogicalKeyboardKey.enter);
        expect(hint, findsNothing);
        await tester.pump(const Duration(seconds: 3));
        await closePlayer(tester);
      });

      testWidgets('arrows reach the empty slot, the top bar and the tile '
          'toolbar, and come back', (tester) async {
        await pumpTv(tester, channels: 1);
        expect(primary(), 'multiview');

        await key(tester, LogicalKeyboardKey.arrowRight);
        expect(primary(), 'multiview slot 1');
        await key(tester, LogicalKeyboardKey.arrowLeft);
        expect(primary(), 'multiview');

        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(inside('multiview bar'), isTrue);
        await key(tester, LogicalKeyboardKey.arrowDown);
        expect(primary(), 'multiview');

        await key(tester, LogicalKeyboardKey.arrowDown);
        expect(inside('multiview toolbar'), isTrue);
        // Change channel, full tile, close.
        await key(tester, LogicalKeyboardKey.arrowRight);
        await key(tester, LogicalKeyboardKey.arrowLeft);
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(primary(), 'multiview');

        // OK on the toolbar's full-tile button.
        await key(tester, LogicalKeyboardKey.arrowDown);
        await key(tester, LogicalKeyboardKey.arrowRight);
        await key(tester, LogicalKeyboardKey.enter);
        expect(find.text('Esc to return to all channels'), findsOneWidget);
        expect(primary(), 'multiview');
        await key(tester, LogicalKeyboardKey.escape);
        await tester.pump(const Duration(seconds: 3));
        await closePlayer(tester);
      });

      testWidgets('OK on the empty slot opens the picker; OK on a row picks',
          (tester) async {
        await pumpTv(tester, channels: 1);
        await key(tester, LogicalKeyboardKey.arrowRight);
        await key(tester, LogicalKeyboardKey.enter);
        await settleDrift(tester, rounds: 6);
        expect(find.text('Choose a channel'), findsOneWidget);
        // The list has focus: no keyboard for the search field yet.
        expect(primary(), 'picker list');

        // Up from the first row goes to the field, Down comes back.
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(primary(), 'picker search');
        await key(tester, LogicalKeyboardKey.arrowDown);
        expect(primary(), 'picker list');

        await key(tester, LogicalKeyboardKey.arrowDown);
        await key(tester, LogicalKeyboardKey.enter);
        await settleDrift(tester, rounds: 6);
        expect(find.text('Choose a channel'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MultiviewScreen)),
        );
        final ids = container
            .read(multiviewSessionProvider(fx.playlistId))
            .tiles
            .map((t) => t.channelId)
            .toList();
        expect(ids, hasLength(2));
        expect(ids.first, ulusal.first);
        await tester.pump(const Duration(seconds: 3));
        await closePlayer(tester);
      });
    });
  });
}
