import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/details/details_api.dart';
import 'package:carina/features/home_movies/category_grid_screen.dart';
import 'package:carina/features/home_movies/movies_home_screen.dart';
import 'package:carina/features/home_shows/shows_home_screen.dart';

import '../../support/drift_widgets.dart';
import '../../support/screenshot.dart';
import 'vod_test_support.dart';

/// Screenshots of the Movies & Shows feature on the real mock catalog
/// (`build/screens/vod_*.png`, 1440×900), with the mock artwork.
void main() {
  setUpAll(loadAppFonts);

  Widget shell(int pid, String location, Widget child) =>
      PlaylistShell(playlistId: pid, location: location, child: child);

  Future<MockImportFixture> importAndSeed(WidgetTester tester) async {
    final fx = (await tester.runAsync(importMockPlaylist))!;
    await tester.runAsync(() => seedVodLibrary(fx));
    return fx;
  }

  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(target));
    return gesture;
  }

  testWidgets('vod_movies_home', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        shell(pid, '/p/$pid/movies', MoviesHomeScreen(playlistId: pid)),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 30);
      // tvOS-style: hovering the first Continue watching card puts it in
      // the hero (as the focused card in the Apple TV reference).
      await hover(tester, find.text('Kış Uykusu').first);
      await settleDrift(tester, rounds: 40);
      await saveScreen(tester, 'vod_movies_home');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_shows_home', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        shell(pid, '/p/$pid/shows', ShowsHomeScreen(playlistId: pid)),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 30);
      await hover(tester, find.text('Sıcak Kafa').first);
      await settleDrift(tester, rounds: 40);
      await saveScreen(tester, 'vod_shows_home');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_movie_details', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        shell(pid, '/p/$pid/movies', MoviesHomeScreen(playlistId: pid)),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      showMovieDetails(
        tester.element(find.byType(MoviesHomeScreen)),
        playlistId: pid,
        movieId: '${MockFixtures.kisUykusu}',
      );
      await settleDrift(tester, rounds: 40);
      await saveScreen(tester, 'vod_movie_details');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_movie_details_tr', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        shell(pid, '/p/$pid/movies', MoviesHomeScreen(playlistId: pid)),
        overrides: vodOverrides(fx),
        locale: const Locale('tr'),
      );
      await settleDrift(tester, rounds: 20);
      showMovieDetails(
        tester.element(find.byType(MoviesHomeScreen)),
        playlistId: pid,
        movieId: '${MockFixtures.kisUykusu}',
      );
      await settleDrift(tester, rounds: 40);
      await saveScreen(tester, 'vod_movie_details_tr');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  Future<void> openSeriesSheet(
    WidgetTester tester,
    MockImportFixture fx,
  ) async {
    final pid = fx.playlistId;
    await pumpScreen(
      tester,
      shell(pid, '/p/$pid/shows', ShowsHomeScreen(playlistId: pid)),
      overrides: vodOverrides(fx),
    );
    await settleDrift(tester, rounds: 20);
    showSeriesDetails(
      tester.element(find.byType(ShowsHomeScreen)),
      playlistId: pid,
      seriesId: '${MockFixtures.sicakKafa}',
    );
    await settleDrift(tester, rounds: 40);
  }

  testWidgets('vod_series_details', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      await openSeriesSheet(tester, fx);
      await saveScreen(tester, 'vod_series_details');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_series_details_season2', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      await openSeriesSheet(tester, fx);
      await tester.tap(find.text('Season 2').first);
      await settleDrift(tester, rounds: 10);
      // Scroll the episodes into view with the wheel (the tabs stay
      // pinned).
      FocusManager.instance.primaryFocus?.unfocus();
      final wheel = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await wheel.addPointer(location: const Offset(720, 600));
      await wheel.moveTo(const Offset(720, 600));
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(720, 600),
          kind: PointerDeviceKind.mouse,
          scrollDelta: Offset(0, 560),
        ),
      );
      await settleDrift(tester, rounds: 30);
      await wheel.removePointer();
      await saveScreen(tester, 'vod_series_details_season2');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_see_all', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        shell(
          pid,
          '/p/$pid/movies/category/p:1002',
          CategoryGridScreen(
            playlistId: pid,
            section: 'movies',
            categoryId: 'p:1002',
          ),
        ),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 40);
      await saveScreen(tester, 'vod_see_all');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_card_menu', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        shell(pid, '/p/$pid/movies', MoviesHomeScreen(playlistId: pid)),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 30);
      // Right-click the second Continue watching card.
      final target = find.text('Şeker Bayramı').evaluate().isEmpty
          ? find.text('Kış Uykusu').first
          : find.text('Şeker Bayramı').first;
      await tester.tap(target, buttons: kSecondaryButton);
      await settleDrift(tester, rounds: 30);
      await saveScreen(tester, 'vod_card_menu');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_category_grid_from_sidebar', (tester) async {
    useMockArtwork();
    final fx = await importAndSeed(tester);
    try {
      final pid = fx.playlistId;
      await pumpScreen(
        tester,
        shell(pid, '/p/$pid/movies', MoviesHomeScreen(playlistId: pid)),
        overrides: vodOverrides(fx),
      );
      await settleDrift(tester, rounds: 20);
      await tester.tap(find.byTooltip('Categories'));
      await settleDrift(tester, rounds: 20);
      await tester.tap(find.text('Aksiyon').last);
      await settleDrift(tester, rounds: 40);
      await saveScreen(tester, 'vod_category_grid_from_sidebar');
      await unmountAndFlush(tester);
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  testWidgets('vod_empty', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    late int pid;
    await tester.runAsync(() async {
      await settings.load();
      pid = await db
          .into(db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Boş Liste',
              type: PlaylistType.xtream,
              createdAt: DateTime(2026, 10, 17),
              lastReloadAt: Value(DateTime(2026, 10, 17)),
            ),
          );
    });
    await pumpScreen(
      tester,
      shell(pid, '/p/$pid/movies', MoviesHomeScreen(playlistId: pid)),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(settings),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        minuteClockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 10, 17, 21, 30)),
        ),
      ],
    );
    await settleDrift(tester, rounds: 20);
    await saveScreen(tester, 'vod_empty');
    expect(find.text('No movies yet'), findsOneWidget);
    await unmountAndFlush(tester);
  });
}
