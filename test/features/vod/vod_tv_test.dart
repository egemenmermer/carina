import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/features/home_movies/category_grid_screen.dart';
import 'package:carina/features/home_movies/movies_home_screen.dart';
import 'package:carina/features/home_movies/widgets/vod_cards.dart';
import 'package:carina/features/home_movies/widgets/vod_rows.dart';

import '../../support/drift_widgets.dart';
import '../../support/screenshot.dart';
import 'vod_test_support.dart';

void main() {
  setUpAll(loadAppFonts);

  /// The card (continue or poster) that holds primary focus, or null.
  Widget? focusedCard() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    return context.findAncestorWidgetOfExactType<VodContinueCard>() ??
        context.findAncestorWidgetOfExactType<VodPosterCard>();
  }

  /// Row title and provider id of the card that holds primary focus (a
  /// movie can sit in several rows).
  String? focusedId() {
    final c = focusedCard();
    final row = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<VodRowSection>();
    final id = switch (c) {
      VodContinueCard() => c.entry.item.providerId,
      VodPosterCard() => c.item.providerId,
      _ => null,
    };
    return '${row?.title}/$id';
  }

  testWidgets('TV: the D-pad walks across and down every row; OK opens', (
    tester,
  ) async {
    final fx = (await tester.runAsync(importMockPlaylist))!;
    await tester.runAsync(() => seedVodLibrary(fx));
    try {
      await pumpScreen(
        tester,
        MoviesHomeScreen(playlistId: fx.playlistId),
        overrides: [
          ...vodOverrides(fx),
          formFactorProvider.overrideWithValue(FormFactor.tv),
        ],
      );
      await settleDrift(tester, rounds: 20);

      // Start on the first Continue watching card.
      final first = find.byType(VodContinueCard).first;
      final node = FocusManager.instance.rootScope.traversalDescendants
          .firstWhere(
            (n) =>
                n.context != null &&
                n.context!.findAncestorWidgetOfExactType<VodContinueCard>() ==
                    tester.widget(first),
          );
      node.requestFocus();
      await tester.pump();
      expect(focusedCard(), isA<VodContinueCard>());

      // Right: the next card of the row, scrolled into view.
      final startCard = focusedCard();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleDrift(tester, rounds: 3);
      expect(focusedCard(), isA<VodContinueCard>());
      expect(focusedCard(), isNot(same(startCard)));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleDrift(tester, rounds: 3);

      // Down through more rows than fit on screen: every press moves on to
      // a new row (never stalls on an unbuilt one) and keeps it visible.
      final ids = <String?>[focusedId()];
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      for (var i = 0; i < 7; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await settleDrift(tester, rounds: 4);
        expect(focusedCard(), isNotNull, reason: 'Down #${i + 1} found a row');
        final id = focusedId();
        expect(ids, isNot(contains(id)), reason: 'Down #${i + 1} moved on');
        ids.add(id);
        final box =
            FocusManager.instance.primaryFocus!.context!.findRenderObject()!
                as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        expect(rect.bottom, lessThanOrEqualTo(screen.height + 1));
        expect(rect.top, greaterThanOrEqualTo(-1));
      }

      // And back up.
      for (var i = 0; i < 7; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await settleDrift(tester, rounds: 4);
        expect(focusedId(), ids[ids.length - 2 - i], reason: 'Up #${i + 1}');
      }
      expect(focusedCard(), isA<VodContinueCard>());
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('TV: a category grid focuses its first poster; the D-pad walks '
      'the grid', (tester) async {
    final fx = (await tester.runAsync(importMockPlaylist))!;
    try {
      await pumpScreen(
        tester,
        CategoryGridScreen(
          playlistId: fx.playlistId,
          section: 'movies',
          categoryId: 'p:1002',
        ),
        overrides: [
          ...vodOverrides(fx),
          formFactorProvider.overrideWithValue(FormFactor.tv),
        ],
      );
      await settleDrift(tester, rounds: 20);
      String? tile() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<VodPosterTile>()
          ?.item
          .providerId;
      final first = tile();
      expect(first, isNotNull, reason: 'no key needed to enter the grid');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleDrift(tester, rounds: 3);
      final second = tile();
      expect(second, isNot(first));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleDrift(tester, rounds: 3);
      final below = tile();
      expect(below, isNot(second));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleDrift(tester, rounds: 3);
      expect(tile(), second);
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('desktop: a category grid waits for a key before it focuses a '
      'poster', (tester) async {
    final fx = (await tester.runAsync(importMockPlaylist))!;
    try {
      await pumpScreen(
        tester,
        CategoryGridScreen(
          playlistId: fx.playlistId,
          section: 'movies',
          categoryId: 'p:1002',
        ),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<VodPosterTile>(),
        isNull,
      );
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });
}
