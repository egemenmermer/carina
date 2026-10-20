import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/repositories/search_repository.dart';
import 'package:carina/features/search/search_api.dart';
import 'package:carina/features/search/search_screen.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

import '../../support/screenshot.dart';
import 'library_harness.dart';

/// Counts the queries that reach the repository.
class CountingSearchRepository extends SearchRepository {
  CountingSearchRepository(MockImportFixture fx) : super(db: fx.db);

  final List<(String, SearchFilter)> calls = [];

  @override
  Future<SearchResults> search(
    int playlistId,
    String query, {
    SearchFilter filter = SearchFilter.all,
    int limitPerSection = 30,
    bool excludeLocked = false,
  }) {
    calls.add((query, filter));
    return super.search(
      playlistId,
      query,
      filter: filter,
      limitPerSection: limitPerSection,
      excludeLocked: excludeLocked,
    );
  }
}

Finder get field => find.descendant(
  of: find.byKey(const ValueKey('search-field')),
  matching: find.byType(EditableText),
);

Future<CountingSearchRepository> pumpSearch(
  WidgetTester tester,
  MockImportFixture fx, {
  String? query,
  String? person,
}) async {
  final repo = CountingSearchRepository(fx);
  await pumpScreen(
    tester,
    SearchScreen(
      playlistId: fx.playlistId,
      initialQuery: query,
      initialPerson: person,
    ),
    overrides: libraryOverrides(
      fx,
      extra: [searchRepositoryProvider.overrideWithValue(repo)],
    ),
  );
  await settleDrift(tester);
  return repo;
}

/// The "Sıcak Kafa" poster in the Shows section.
Finder get sicakKafa => find.descendant(
  of: find.byKey(const ValueKey('section-shows')),
  matching: find.byKey(const ValueKey('vod-series-${MockFixtures.sicakKafa}')),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('typing is debounced: one query after 150 ms of quiet', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final repo = await pumpSearch(tester, fx);
    expect(find.text('Search your library'), findsOneWidget);
    for (final text in ['s', 'si', 'sic', 'sica', 'sicak']) {
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(repo.calls, isEmpty, reason: 'still typing');
    await tester.pump(const Duration(milliseconds: 160));
    await settleDrift(tester);
    expect(repo.calls, [('sicak', SearchFilter.all)]);
    expect(sicakKafa, findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('Turkish normalization: case and diacritics are ignored', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    for (final query in ['sicak kafa', 'SICAK KAFA', 'Sıcak', 'sıc ka']) {
      await pumpSearch(tester, fx, query: query);
      expect(sicakKafa, findsOneWidget, reason: query);
    }
    // Quality tokens are dropped: "trt 1 hd" finds TRT 1.
    await pumpSearch(tester, fx, query: 'trt 1 hd');
    expect(find.byKey(const ValueKey('channel-1001')), findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('filters choose the sections', (tester) async {
    final fx = await importFixture(tester);
    final repo = await pumpSearch(tester, fx, query: 'haber');
    expect(find.byKey(const ValueKey('section-channels')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-filter-movies')));
    await settleDrift(tester);
    expect(repo.calls.last, ('haber', SearchFilter.movies));
    expect(find.byKey(const ValueKey('section-channels')), findsNothing);
    expect(find.byKey(const ValueKey('section-programmes')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('search-filter-live')));
    await settleDrift(tester);
    expect(repo.calls.last, ('haber', SearchFilter.live));
    expect(find.byKey(const ValueKey('section-channels')), findsOneWidget);
    expect(find.byKey(const ValueKey('section-programmes')), findsOneWidget);
    expect(find.byKey(const ValueKey('section-movies')), findsNothing);
    // Channel cards show the programme on air.
    final card = find.byKey(const ValueKey('channel-1005'));
    expect(
      find.descendant(of: card, matching: find.byType(KProgressBar)),
      findsOneWidget,
    );
    await disposeFixture(tester, fx);
  });

  testWidgets('people: a person lists their titles (search by actor)', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    await pumpSearch(tester, fx, query: 'nehir');
    await tester.tap(find.byKey(const ValueKey('search-filter-people')));
    await settleDrift(tester);
    final person = find.byKey(
      const ValueKey('person-${MockFixtures.sharedActor}'),
    );
    expect(person, findsOneWidget);
    await tester.tap(
      find.descendant(of: person, matching: find.byType(FocusableCard)),
    );
    await settleDrift(tester);
    expect(find.text('SEARCH BY ACTOR'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('person-shows')),
        matching: find.byKey(const ValueKey('vod-series-5001')),
      ),
      findsOneWidget,
    );
    // Back returns to the results.
    await tester.tap(find.byKey(const ValueKey('person-back')));
    await settleDrift(tester);
    expect(find.text('SEARCH BY ACTOR'), findsNothing);
    expect(person, findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('initialPerson opens the titles view', (tester) async {
    final fx = await importFixture(tester);
    await pumpSearch(tester, fx, person: MockFixtures.sharedActor);
    expect(find.text(MockFixtures.sharedActor), findsWidgets);
    expect(find.text(MockFixtures.sicakKafaName), findsWidgets);
    await disposeFixture(tester, fx);
  });

  testWidgets('no results: message and Clear; Esc clears the field', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    await pumpSearch(tester, fx, query: 'zqxw');
    expect(find.text('No results for "zqxw"'), findsOneWidget);
    await tester.tap(find.text('Clear').last);
    await settle(tester);
    expect(find.text('Search your library'), findsOneWidget);
    expect(tester.widget<EditableText>(field).controller.text, isEmpty);

    await tester.enterText(field, 'trt');
    await tester.pump(const Duration(milliseconds: 200));
    await settleDrift(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(tester.widget<EditableText>(field).controller.text, isEmpty);
    await disposeFixture(tester, fx);
  });

  testWidgets('openPersonSearch closes sheets and navigates with ?person=', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final router = GoRouter(
      initialLocation: '/p/$pid/movies',
      routes: [
        GoRoute(
          path: '/p/:pid/movies',
          builder: (c, s) => const Material(child: Text('movies')),
        ),
        GoRoute(
          path: '/p/:pid/search',
          builder: (c, s) => SearchScreen(
            playlistId: pid,
            initialPerson: s.uri.queryParameters['person'],
          ),
        ),
      ],
    );
    await tester.runAsync(loadAppFonts);
    await tester.pumpWidget(
      ProviderScope(
        overrides: libraryOverrides(fx),
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildCarinaTheme(),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          builder: (context, child) => KToastHost(child: child!),
        ),
      ),
    );
    await settleDrift(tester);
    final context = tester.element(find.text('movies'));
    unawaited(showKSheet<void>(context, child: const Text('details sheet')));
    await settle(tester);
    expect(find.text('details sheet'), findsOneWidget);
    openPersonSearch(
      tester.element(find.text('details sheet')),
      playlistId: pid,
      person: MockFixtures.sharedActor,
    );
    await settleDrift(tester);
    expect(find.text('details sheet'), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.queryParameters['person'],
      MockFixtures.sharedActor,
    );
    expect(find.text(MockFixtures.sicakKafaName), findsWidgets);
    await disposeFixture(tester, fx);
  });
}
