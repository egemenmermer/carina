import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/shell/category_selection.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/data/repositories/watch_state_repository.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/text/normalize.dart';
import 'package:carina/features/details/details_api.dart';
import 'package:carina/features/details/movie_details_sheet.dart';
import 'package:carina/features/details/series_details_sheet.dart';
import 'package:carina/features/home_movies/category_grid_screen.dart';
import 'package:carina/features/home_movies/movies_home_screen.dart';
import 'package:carina/features/home_movies/widgets/vod_cards.dart';
import 'package:carina/features/home_movies/widgets/vod_grid.dart';
import 'package:carina/features/home_movies/widgets/vod_hero.dart';
import 'package:carina/features/home_shows/shows_home_screen.dart';

import '../../support/drift_widgets.dart';
import '../../support/screenshot.dart';
import 'vod_test_support.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<(MockImportFixture, VodSeed)> importAndSeed(
    WidgetTester tester,
  ) async {
    final fx = (await tester.runAsync(importMockPlaylist))!;
    final seed = (await tester.runAsync(() => seedVodLibrary(fx)))!;
    return (fx, seed);
  }

  VodRepository repoOf(MockImportFixture fx) =>
      VodRepository(db: fx.db, settings: fx.settings, secrets: fx.secrets);

  Finder continueCard(String providerId) => find.byWidgetPredicate(
    (w) => w is VodContinueCard && w.entry.item.providerId == providerId,
  );

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(1, 1));
    addTearDown(gesture.removePointer);
    return gesture;
  }

  ProviderContainer containerOf(WidgetTester tester, Type screen) =>
      ProviderScope.containerOf(tester.element(find.byType(screen)));

  testWidgets('hero rotates every 10 s, follows hovered cards, holds while '
      'hovered', (tester) async {
    final (fx, _) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      final repo = repoOf(fx);
      final candidates = (await tester.runAsync(
        () => repo.heroCandidates(pid, SectionKind.movie),
      ))!;
      repo.dispose();
      expect(candidates.length, greaterThan(2));
      Finder hero(String id) => find.byKey(vodHeroKey(SectionKind.movie, id));

      await pumpScreen(
        tester,
        MoviesHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      expect(hero(candidates[0].providerId), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 500));
      expect(hero(candidates[1].providerId), findsOneWidget);
      expect(hero(candidates[0].providerId), findsNothing);

      // Hovering a card shows it in the hero after a short dwell.
      final cw = (await tester.runAsync(
        () => WatchStateRepository(
          db: fx.db,
          settings: fx.settings,
        ).continueWatchingMovies(pid),
      ))!;
      final target = cw.firstWhere(
        (e) => e.item.providerId != candidates[1].providerId,
      );
      final gesture = await mouse(tester);
      await gesture.moveTo(
        tester.getCenter(continueCard(target.item.providerId)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(hero(target.item.providerId), findsOneWidget);

      // The pointer on the hero pauses the rotation.
      await gesture.moveTo(const Offset(300, 200));
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 500));
      expect(hero(target.item.providerId), findsOneWidget);

      // Leaving it lets the rotation continue.
      await gesture.moveTo(const Offset(1400, 880));
      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 500));
      expect(hero(target.item.providerId), findsNothing);
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('Continue watching resumes directly or opens details per '
      'setting', (tester) async {
    final (fx, _) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      final launcher = RecordingLauncher();
      await pumpScreen(
        tester,
        MoviesHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx, launcher: launcher),
      );
      await settleDrift(tester, rounds: 20);
      const kis = '${MockFixtures.kisUykusu}';
      await tester.tap(continueCard(kis));
      await settleDrift(tester, rounds: 4);
      expect(launcher.requests, hasLength(1));
      final r = launcher.requests.single;
      expect(r.type, ItemType.movie);
      expect(r.providerId, kis);
      expect(r.resume, isTrue);
      expect(find.byType(MovieDetailsSheet), findsNothing);

      await tester.runAsync(
        () => fx.settings.set(
          PlaylistSettings.continueWatchingOpensPlayer,
          false,
          playlistId: pid,
        ),
      );
      await settleDrift(tester, rounds: 4);
      await tester.tap(continueCard(kis));
      await settleDrift(tester, rounds: 20);
      expect(find.byType(MovieDetailsSheet), findsOneWidget);
      expect(launcher.requests, hasLength(1));
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('Continue watching on Shows resumes the episode', (tester) async {
    final (fx, _) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      final launcher = RecordingLauncher();
      await pumpScreen(
        tester,
        ShowsHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx, launcher: launcher),
      );
      await settleDrift(tester, rounds: 20);
      await tester.tap(continueCard('${MockFixtures.sicakKafa}'));
      await settleDrift(tester, rounds: 4);
      final r = launcher.requests.single;
      expect(r.type, ItemType.episode);
      expect(r.seriesId, '${MockFixtures.sicakKafa}');
      expect(
        r.providerId,
        '${MockFixtures.episodeId(MockFixtures.sicakKafa, 1, 2)}',
      );
      expect(r.resume, isTrue);
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('movie details: Resume / From the beginning / Play and the '
      'favorites toggle with toasts', (tester) async {
    final (fx, seed) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      final launcher = RecordingLauncher();
      await pumpScreen(
        tester,
        MoviesHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx, launcher: launcher),
      );
      await settleDrift(tester, rounds: 10);
      final ctx = tester.element(find.byType(MoviesHomeScreen));
      showMovieDetails(
        ctx,
        playlistId: pid,
        movieId: '${MockFixtures.kisUykusu}',
      );
      await settleDrift(tester, rounds: 20);
      final sheet = find.byType(MovieDetailsSheet);
      Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);

      expect(inSheet(find.textContaining('Resume from')), findsOneWidget);
      await tester.tap(inSheet(find.textContaining('Resume from')));
      await tester.pump();
      expect(launcher.requests.last.resume, isTrue);
      await tester.tap(inSheet(find.text('From the beginning')));
      await tester.pump();
      expect(launcher.requests.last.resume, isFalse);
      expect(launcher.requests.last.providerId, '${MockFixtures.kisUykusu}');

      // Close; open a movie that was never played: only Play.
      Navigator.of(ctx, rootNavigator: true).pop();
      await settleDrift(tester, rounds: 6);
      final fresh = seed.favoriteMovies[2];
      await tester.runAsync(() => prefetchDetails(fx, movies: [fresh]));
      showMovieDetails(ctx, playlistId: pid, movieId: fresh);
      await settleDrift(tester, rounds: 20);
      expect(inSheet(find.textContaining('Resume from')), findsNothing);
      expect(inSheet(find.text('From the beginning')), findsNothing);
      await tester.tap(inSheet(find.text('Play')));
      await tester.pump();
      expect(launcher.requests.last.providerId, fresh);
      expect(launcher.requests.last.resume, isNull);

      // It is a favorite: remove, then add again.
      await tester.tap(inSheet(find.text('Remove from favorites')));
      await settleDrift(tester, rounds: 6);
      expect(find.text('Removed from favorites'), findsOneWidget);
      expect(inSheet(find.text('Add to favorites')), findsOneWidget);
      await tester.tap(inSheet(find.text('Add to favorites')));
      await settleDrift(tester, rounds: 6);
      expect(find.text('Added to favorites'), findsOneWidget);
      expect(inSheet(find.text('Remove from favorites')), findsOneWidget);
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('hero Favorites button toggles with a toast', (tester) async {
    final (fx, _) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        MoviesHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      final button = find.text('Favorites').first;
      await tester.tap(button);
      await settleDrift(tester, rounds: 6);
      final first = find.text('Added to favorites').evaluate().isNotEmpty;
      expect(
        first || find.text('Removed from favorites').evaluate().isNotEmpty,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(button);
      await settleDrift(tester, rounds: 6);
      expect(
        find.text(first ? 'Removed from favorites' : 'Added to favorites'),
        findsOneWidget,
      );
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('series details: mark watched / unwatched / all previous', (
    tester,
  ) async {
    final (fx, _) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      const sid = '${MockFixtures.sicakKafa}';
      String ep(int s, int n) =>
          '${MockFixtures.episodeId(MockFixtures.sicakKafa, s, n)}';
      await pumpScreen(
        tester,
        ShowsHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 10);
      showSeriesDetails(
        tester.element(find.byType(ShowsHomeScreen)),
        playlistId: pid,
        seriesId: sid,
      );
      await settleDrift(tester, rounds: 20);
      final scrollable = find
          .descendant(
            of: find.byType(SeriesDetailsSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> menuOn(String id, String action) async {
        final row = find.byKey(ValueKey(id));
        await tester.scrollUntilVisible(row, 150, scrollable: scrollable);
        await tester.pump();
        await tester.tap(row, buttons: kSecondaryButton);
        await settleDrift(tester, rounds: 6);
        await tester.tap(find.text(action));
        await settleDrift(tester, rounds: 8);
      }

      Future<Set<String>> watched() async => (await tester.runAsync(
        () => WatchStateRepository(
          db: fx.db,
          settings: fx.settings,
        ).watchedEpisodeIds(pid, sid),
      ))!;

      expect(await watched(), {ep(1, 1)});
      await menuOn(ep(1, 3), 'Mark all previous as watched');
      expect(find.text('2 episodes marked as watched'), findsOneWidget);
      expect(await watched(), containsAll([ep(1, 1), ep(1, 2)]));

      await menuOn(ep(1, 4), 'Mark as watched');
      expect(find.text('Marked as watched'), findsOneWidget);
      expect(await watched(), contains(ep(1, 4)));

      await menuOn(ep(1, 4), 'Mark as unwatched');
      expect(find.text('Marked as unwatched'), findsOneWidget);
      expect(await watched(), isNot(contains(ep(1, 4))));
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('See All: sort by name, filter, no results + Clear, keyboard', (
    tester,
  ) async {
    final (fx, _) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      final repo = repoOf(fx);
      final byName = (await tester.runAsync(
        () => repo
            .watchCategoryItems(
              pid,
              SectionKind.movie,
              const ProviderCategory('1002'),
              sort: VodSort.name,
            )
            .first,
      ))!;
      repo.dispose();
      await pumpScreen(
        tester,
        CategoryGridScreen(
          playlistId: pid,
          section: 'movies',
          categoryId: 'p:1002',
        ),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      List<VodItem> tiles() => [
        for (final t in tester.widgetList<VodPosterTile>(
          find.byType(VodPosterTile),
        ))
          t.item,
      ];

      await tester.tap(find.text('Default order'));
      await settleDrift(tester, rounds: 6);
      await tester.tap(find.text('Name').last);
      await settleDrift(tester, rounds: 10);
      expect(tiles().first.providerId, byName.first.providerId);
      expect(find.text('Name'), findsWidgets);

      // Filter by a word of one title.
      final word = normalizeForSearch(byName[3].name).split(' ').first;
      final expected = byName
          .where((i) => normalizeForSearch(i.name).contains(word))
          .length;
      await tester.enterText(find.byType(TextField), word);
      await tester.pump(const Duration(milliseconds: 200));
      await settleDrift(tester, rounds: 4);
      expect(
        find.text(expected == 1 ? '1 title' : '$expected titles'),
        findsOneWidget,
      );
      for (final item in tiles()) {
        expect(normalizeForSearch(item.name), contains(word));
      }

      await tester.enterText(find.byType(TextField), 'zzqxw');
      await tester.pump(const Duration(milliseconds: 200));
      await settleDrift(tester, rounds: 4);
      expect(find.text('No results for “zzqxw”'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await settleDrift(tester, rounds: 4);
      expect(tiles().first.providerId, byName.first.providerId);

      // Keyboard: the grid has focus; arrows walk the cells.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      tester
          .widget<Focus>(
            find
                .descendant(
                  of: find.byType(VodGridView),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      String? focused() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<VodPosterTile>()
          ?.item
          .providerId;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focused(), byName[0].providerId);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(focused(), byName[1].providerId);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final below = focused();
      expect(below, isNotNull);
      expect(below, isNot(byName[1].providerId));
      expect(byName.indexWhere((i) => i.providerId == below), greaterThan(1));
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('sidebar category shows its grid; Home chip and Esc return; '
      'a saved category resets to Home on first visit', (tester) async {
    final (fx, _) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await tester.runAsync(
        () => fx.settings.set(
          const SettingKey<String?>(
            'selectedCategory.movie',
            null,
            SettingScope.playlist,
          ),
          'p:1002',
          playlistId: pid,
        ),
      );
      await pumpScreen(
        tester,
        MoviesHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      final scope = (playlistId: pid, kind: SectionKind.movie);
      final c = containerOf(tester, MoviesHomeScreen);
      expect(find.byType(VodGridView), findsNothing);
      expect(find.text('Continue watching'), findsOneWidget);
      expect(c.read(selectedCategoryProvider(scope)), const AllCategory());

      c
          .read(selectedCategoryProvider(scope).notifier)
          .select(const ProviderCategory('1002'));
      await settleDrift(tester, rounds: 10);
      expect(find.byType(VodGridView), findsOneWidget);
      expect(find.text('Aksiyon'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await settleDrift(tester, rounds: 10);
      expect(find.byType(VodGridView), findsNothing);
      expect(c.read(selectedCategoryProvider(scope)), const AllCategory());

      // Picking the same category again works (the selection was reset).
      c
          .read(selectedCategoryProvider(scope).notifier)
          .select(const ProviderCategory('1002'));
      await settleDrift(tester, rounds: 10);
      expect(find.byType(VodGridView), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleDrift(tester, rounds: 10);
      expect(find.byType(VodGridView), findsNothing);
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('card context menu: Hide removes the card with a toast', (
    tester,
  ) async {
    final (fx, seed) = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      final target = seed.continueMovies.first;
      await pumpScreen(
        tester,
        MoviesHomeScreen(playlistId: pid),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      expect(continueCard(target), findsOneWidget);
      await tester.tap(continueCard(target), buttons: kSecondaryButton);
      await settleDrift(tester, rounds: 8);
      expect(find.text('Remove from Continue watching'), findsOneWidget);
      await tester.tap(find.text('Hide'));
      await settleDrift(tester, rounds: 10);
      expect(find.textContaining('Hidden.'), findsOneWidget);
      expect(continueCard(target), findsNothing);
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });
}
