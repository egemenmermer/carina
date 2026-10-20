import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/import/import.dart';

import '../../support/mock_import.dart';

void main() {
  testWidgets('importMockPlaylist inside testWidgets (runAsync)', (
    tester,
  ) async {
    final fx = (await tester.runAsync(importMockPlaylist))!;
    try {
      expect(fx.importResult.succeeded, isTrue, reason: '${fx.importResult}');
      expect(fx.importResult.epgError, isNull);
      final playlist = await tester.runAsync(
        () => (fx.db.select(
          fx.db.playlists,
        )..where((p) => p.id.equals(fx.playlistId))).getSingle(),
      );
      expect(playlist!.name, 'Kanal Demo');
      expect(playlist.liveCount, fx.server.catalog.channels.length);
      expect(playlist.programmeCount, greaterThan(0));
      // The default XMLTV: never stored with the credentials.
      expect(playlist.epgUrl, isNull);
      expect(
        await fx.secrets.read('playlist.${fx.playlistId}.password'),
        MockFixtures.password,
      );

      // The overrides wire a ProviderScope.
      late ImportService fromScope;
      late AppDatabaseHolder holder;
      await tester.pumpWidget(
        ProviderScope(
          overrides: fx.providerOverrides,
          child: Consumer(
            builder: (context, ref, _) {
              fromScope = ref.watch(importServiceProvider);
              holder = AppDatabaseHolder(ref.watch(appDatabaseProvider));
              return const SizedBox();
            },
          ),
        ),
      );
      expect(fromScope, same(fx.importService));
      expect(holder.db, same(fx.db));

      // A reload through the fixture uses real HTTP as well.
      final reload = (await tester.runAsync(
        () => fx.reload(scope: ImportScope.content),
      ))!;
      expect(reload.succeeded, isTrue, reason: '$reload');
      await tester.pumpWidget(const SizedBox());
    } finally {
      await tester.runAsync(fx.dispose);
    }
  });

  test('importMockPlaylist without the guide', () async {
    final fx = await importMockPlaylist(withEpg: false);
    addTearDown(fx.dispose);
    expect(fx.importResult.succeeded, isTrue);
    expect(fx.importResult.skippedSteps, containsAll(ImportStep.epgSteps));
    final count = await fx.db.select(fx.db.programmes).get();
    expect(count, isEmpty);
    final playlist = await fx.db.select(fx.db.playlists).getSingle();
    expect(playlist.epgUrl, '');
  });
}

class AppDatabaseHolder {
  AppDatabaseHolder(this.db);
  final Object db;
}
