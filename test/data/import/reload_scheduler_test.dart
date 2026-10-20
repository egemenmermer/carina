import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'import_harness.dart';

void main() {
  late ImportHarness h;

  setUpAll(() async => h = await ImportHarness.create());
  tearDownAll(() => h.dispose());

  group('ReloadScheduler.checkOnOpen', () {
    test('reloads in the background when the frequency elapsed', () async {
      final scheduler = ReloadScheduler(h.service);
      final old = DateTime.now().subtract(const Duration(hours: 100));
      final id = await h.addXtream(
        epg: false,
        reloadFrequencyHours: 72,
        lastReloadAt: old,
      );
      expect(await scheduler.checkOnOpen(id), isTrue);
      expect(h.service.isRunning(id), isTrue);
      // Opening again while it runs does not start a second import.
      expect(await scheduler.checkOnOpen(id), isFalse);
      final result = await h.service.start(id).last;
      expect(result.step, ImportStep.completed);
      expect(result.scope, ImportScope.all);
      final row = await h.playlist(id);
      expect(row.lastReloadAt!.isAfter(old), isTrue);
      // Fresh now.
      expect(await scheduler.checkOnOpen(id), isFalse);
    });

    test('never-imported playlists reload', () async {
      final id = await h.addXtream(epg: false);
      expect(await ReloadScheduler(h.service).checkOnOpen(id), isTrue);
      await h.service.start(id).last;
    });

    test('recent reloads, "Never" and unknown playlists do not', () async {
      final scheduler = ReloadScheduler(h.service);
      final recent = await h.addXtream(
        epg: false,
        lastReloadAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(await scheduler.checkOnOpen(recent), isFalse);
      final never = await h.addXtream(epg: false, reloadFrequencyHours: 0);
      expect(await scheduler.checkOnOpen(never), isFalse);
      expect(await scheduler.checkOnOpen(424242), isFalse);
      expect(h.service.isRunning(recent), isFalse);
      expect(h.service.isRunning(never), isFalse);
    });

    test('uses its clock', () async {
      final id = await h.addXtream(
        epg: false,
        reloadFrequencyHours: 12,
        lastReloadAt: DateTime(2026, 10, 17, 8),
      );
      final early = ReloadScheduler(
        h.service,
        clock: () => DateTime(2026, 10, 17, 19),
      );
      expect(await early.checkOnOpen(id), isFalse);
      final late = ReloadScheduler(
        h.service,
        clock: () => DateTime(2026, 10, 17, 21),
      );
      expect(await late.checkOnOpen(id), isTrue);
      await h.service.start(id).last;
    });
  });

  group('providers', () {
    test('importServiceProvider builds from the core providers', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(h.db),
          appPathsProvider.overrideWithValue(h.paths),
          settingsStoreProvider.overrideWithValue(h.settings),
          secretStoreProvider.overrideWithValue(h.secrets),
        ],
      );
      final service = container.read(importServiceProvider);
      expect(service.db, same(h.db));
      expect(container.read(reloadSchedulerProvider).service, same(service));
      final id = await h.addXtream(epg: false);
      final progress = container.listen(importProgressProvider(id), (_, _) {});
      await pumpEventQueue();
      expect(progress.read().value, isNull);
      final result = await service.run(id, scope: ImportScope.content);
      expect(result.succeeded, isTrue);
      container.dispose();
    });
  });
}
