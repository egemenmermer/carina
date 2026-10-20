import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/category_repository.dart';
import 'package:carina/data/repositories/favorites_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/parental_service.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/features/downloads/downloads_screen.dart';
import 'package:carina/features/favorites/favorites_api.dart';
import 'package:carina/features/parental/parental_api.dart';
import 'package:carina/features/parental/parental_pin_flows.dart';
import 'package:carina/features/search/search_screen.dart';
import 'package:carina/features/settings/settings_screen.dart';

import '../../support/screenshot.dart';
import 'library_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(
    WidgetTester tester,
    MockImportFixture fx,
    Widget child,
    String name, {
    String location = '/p/1/settings',
    bool shell = true,
    Future<void> Function()? before,
  }) async {
    await pumpScreen(
      tester,
      shell ? inShell(fx, location, child) : child,
      overrides: libraryOverrides(fx),
    );
    await settleDrift(tester, rounds: 14);
    if (before != null) {
      await before();
      await settleDrift(tester, rounds: 8);
    }
    await settle(tester);
    await saveScreen(tester, name);
  }

  testWidgets('search results (sicak)', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await shot(
      tester,
      fx,
      SearchScreen(playlistId: pid, initialQuery: 'sicak'),
      'library_search_results',
      location: '/p/$pid/search',
    );
    expect(find.text('Sıcak Kafa'), findsWidgets);
    await disposeFixture(tester, fx);
  });

  testWidgets('search by actor', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await shot(
      tester,
      fx,
      SearchScreen(playlistId: pid, initialPerson: MockFixtures.sharedActor),
      'library_search_people',
      location: '/p/$pid/search',
    );
    expect(find.text('Sıcak Kafa'), findsWidgets);
    await disposeFixture(tester, fx);
  });

  testWidgets('search live filter', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await shot(
      tester,
      fx,
      SearchScreen(playlistId: pid, initialQuery: 'haber'),
      'library_search_live',
      location: '/p/$pid/search',
      before: () async {
        await tester.tap(find.byKey(const ValueKey('search-filter-live')));
        await settleDrift(tester);
      },
    );
    expect(find.byKey(const ValueKey('section-channels')), findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('search empty', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await shot(
      tester,
      fx,
      SearchScreen(playlistId: pid, initialQuery: 'zqxw'),
      'library_search_empty',
      location: '/p/$pid/search',
    );
    expect(find.text('No results for "zqxw"'), findsOneWidget);
    await disposeFixture(tester, fx);
  });

  for (final (section, name) in const [
    ('general', 'library_settings_general'),
    ('player', 'library_settings_player'),
    ('live', 'library_settings_live'),
  ]) {
    testWidgets('settings $section', (tester) async {
      final fx = await importFixture(tester);
      final pid = fx.playlistId;
      await shot(
        tester,
        fx,
        SettingsScreen(playlistId: pid, section: section),
        name,
        location: '/p/$pid/settings/$section',
      );
      await disposeFixture(tester, fx);
    });
  }

  testWidgets('settings in Turkish', (tester) async {
    await tester.runAsync(() => initializeDateFormatting('tr'));
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await pumpScreen(
      tester,
      inShell(
        fx,
        '/p/$pid/settings/player',
        SettingsScreen(playlistId: pid, section: 'player'),
      ),
      overrides: libraryOverrides(fx),
      locale: const Locale('tr'),
    );
    await settleDrift(tester, rounds: 14);
    await saveScreen(tester, 'library_settings_player_tr');
    expect(find.text('Oynatıcı'), findsWidgets);
    await disposeFixture(tester, fx);
  });

  testWidgets('settings chooser', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await shot(
      tester,
      fx,
      SettingsScreen(playlistId: pid, section: 'player'),
      'library_settings_chooser',
      location: '/p/$pid/settings/player',
      before: () async {
        await tester.tap(find.text('Aspect ratio'));
        await settle(tester);
      },
    );
    await disposeFixture(tester, fx);
  });

  testWidgets('settings parental', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await tester.runAsync(() async {
      final parental = ParentalService(
        fx.db,
        fx.secrets,
        LiveRepository(fx.db, fx.settings),
        CategoryRepository(fx.db, fx.settings),
      );
      await parental.lockChannel(pid, '${MockFixtures.cocukKilitli}', true);
      await parental.lockChannel(pid, '${MockFixtures.kanalDSd}', true);
      final cats = await CategoryRepository(
        fx.db,
        fx.settings,
      ).categories(pid, SectionKind.live);
      final cocuk = cats.firstWhere(
        (c) => c.providerName == MockFixtures.cocukCategoryName,
      );
      await parental.lockCategory(
        pid,
        SectionKind.live,
        cocuk.providerId!,
        true,
      );
    });
    await shot(
      tester,
      fx,
      SettingsScreen(playlistId: pid, section: 'parental'),
      'library_settings_parental',
      location: '/p/$pid/settings/parental',
    );
    expect(find.text('Çocuk Kilitli'), findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('settings hidden items', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await tester.runAsync(() async {
      final live = LiveRepository(fx.db, fx.settings);
      await live.setHidden(pid, '${MockFixtures.kanalDSd}', true);
      await live.setHidden(pid, '1009', true);
      final vod = VodRepository(
        db: fx.db,
        settings: fx.settings,
        secrets: fx.secrets,
      );
      await vod.setHidden(
        pid,
        SectionKind.movie,
        '${MockFixtures.kisUykusu}',
        true,
      );
      await vod.setHidden(
        pid,
        SectionKind.series,
        '${MockFixtures.maviKapi}',
        true,
      );
      final categories = CategoryRepository(fx.db, fx.settings);
      final movieCats = await categories.categories(pid, SectionKind.movie);
      final first = movieCats.firstWhere((c) => c.providerId != null);
      await categories.setHidden(
        pid,
        SectionKind.movie,
        first.providerId!,
        true,
      );
      vod.dispose();
    });
    await shot(
      tester,
      fx,
      SettingsScreen(playlistId: pid, section: 'management'),
      'library_settings_hidden_items',
      location: '/p/$pid/settings/management',
      before: () async {
        await tester.tap(find.byKey(const ValueKey('row:hidden')));
        await settle(tester);
      },
    );
    expect(find.text('Kış Uykusu'), findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('settings about with TMDb key', (tester) async {
    final fx = await importFixture(tester);
    await tester.runAsync(
      () => fx.secrets.write(SecretStore.tmdbKey, 'test-key-123'),
    );
    await shot(
      tester,
      fx,
      SettingsScreen(playlistId: fx.playlistId, section: 'about'),
      'library_settings_about',
      location: '/p/${fx.playlistId}/settings/about',
    );
    expect(
      find.text(
        'This product uses the TMDB API but is not endorsed or certified '
        'by TMDB.',
      ),
      findsOneWidget,
    );
    await disposeFixture(tester, fx);
  });

  testWidgets('favorite tags sheet', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final movieId = '${MockFixtures.kisUykusu}';
    await tester.runAsync(() async {
      final repo = FavoritesRepository(db: fx.db, settings: fx.settings);
      final weekend = await repo.createTag(pid, 'Hafta sonu');
      await repo.createTag(pid, 'Çocuklar');
      await repo.createTag(pid, 'Klasikler');
      await repo.setTags(pid, ItemType.movie, movieId, {weekend});
    });
    await shot(
      tester,
      fx,
      SettingsScreen(playlistId: pid, section: 'playlist'),
      'library_favorite_tags_sheet',
      location: '/p/$pid/settings',
      before: () async {
        unawaited(
          showFavoriteTagsSheet(
            tester.element(find.byType(SettingsScreen)),
            playlistId: pid,
            type: ItemType.movie,
            providerId: movieId,
            title: MockFixtures.kisUykusuName,
          ),
        );
        await settleDrift(tester);
        await tester.enterText(
          find.byType(EditableText).last,
          'Gece izlenecek',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);
      },
    );
    expect(find.text('Gece izlenecek'), findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('parental pin pad', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await tester.runAsync(() async {
      final parental = ParentalService(
        fx.db,
        fx.secrets,
        LiveRepository(fx.db, fx.settings),
        CategoryRepository(fx.db, fx.settings),
      );
      await parental.setPin(pid, '1234');
      await parental.lockChannel(pid, '${MockFixtures.cocukKilitli}', true);
    });
    await shot(
      tester,
      fx,
      SettingsScreen(playlistId: pid, section: 'playlist'),
      'library_parental_pin',
      location: '/p/$pid/settings',
      before: () async {
        unawaited(
          ensureChannelUnlocked(
            tester.element(find.byType(SettingsScreen)),
            playlistId: pid,
            channelId: '${MockFixtures.cocukKilitli}',
          ),
        );
        await settleDrift(tester);
        await settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
        await settle(tester);
      },
    );
    expect(find.text('Çocuk Kilitli is locked'), findsOneWidget);
    expect(parentalSettingsAccessProvider, isNotNull);
    await disposeFixture(tester, fx);
  });

  testWidgets('downloads empty', (tester) async {
    final fx = await importFixture(tester);
    await shot(
      tester,
      fx,
      const DownloadsScreen(),
      'library_downloads_empty',
      shell: false,
    );
    expect(find.text('No downloads'), findsOneWidget);
    await disposeFixture(tester, fx);
  });
}
