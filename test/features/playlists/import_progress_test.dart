import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/sources/source_exception.dart';

import '../../support/drift_widgets.dart';
import '../../support/screenshot.dart';
import 'support/playlists_harness.dart';

class _Env {
  _Env(this.db, this.settings, this.paths, this.imports, this.playlistId);

  final AppDatabase db;
  final SettingsStore settings;
  final AppPaths paths;
  final FakeImportService imports;
  final int playlistId;

  List<Override> get overrides => [
    appDatabaseProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(paths),
    settingsStoreProvider.overrideWithValue(settings),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    importServiceProvider.overrideWithValue(imports),
  ];
}

Future<_Env> _createEnv({DateTime? lastReloadAt}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = SettingsStore(db);
  await settings.load();
  final paths = await tempAppPaths();
  final secrets = MemorySecretStore();
  final pid = await db
      .into(db.playlists)
      .insert(
        PlaylistsCompanion.insert(
          name: 'Kanal Demo',
          type: PlaylistType.xtream,
          server: const Value('http://iptv.example.com:8080'),
          username: const Value('kanal'),
          avatarId: const Value('animal-fox'),
          reloadFrequencyHours: const Value(0),
          lastReloadAt: Value(lastReloadAt),
          createdAt: DateTime(2026, 10, 17),
        ),
      );
  return _Env(
    db,
    settings,
    paths,
    FakeImportService(
      db: db,
      paths: paths,
      secrets: secrets,
      settings: settings,
    ),
    pid,
  );
}

ImportProgress _snapshot(
  int pid,
  ImportStep step, {
  Map<ImportStep, int> counts = const {},
  int? received,
  int? total,
  SourceException? error,
  SourceException? epgError,
  ImportStep? failedStep,
  List<ImportWarning> warnings = const [],
  ImportScope scope = ImportScope.all,
}) => ImportProgress(
  playlistId: pid,
  scope: scope,
  step: step,
  counts: counts,
  receivedBytes: received,
  totalBytes: total,
  error: error,
  epgError: epgError,
  failedStep: failedStep,
  warnings: warnings,
  done: step.isTerminal,
  plannedSteps: scope == ImportScope.epg
      ? const [...ImportStep.epgSteps, ImportStep.completed]
      : allSteps,
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('stepper mid-way, then completed: the playlist opens', (
    tester,
  ) async {
    final env = (await tester.runAsync(_createEnv))!;
    final pid = env.playlistId;
    final router = playlistsTestRouter(
      initialLocation: '/playlists/$pid/import',
    );
    await pumpScreen(tester, routerHost(router), overrides: env.overrides);
    await pumpUntil(tester, () => env.imports.started.isNotEmpty);
    expect(env.imports.started.single, (pid, ImportScope.all));
    expect(find.text('Importing Kanal Demo'), findsOneWidget);
    expect(find.text('http://ipt***:8080'), findsOneWidget);

    env.imports.emit(
      _snapshot(
        pid,
        ImportStep.movies,
        counts: {
          ImportStep.liveCategories: 24,
          ImportStep.liveChannels: 12480,
          ImportStep.movies: 3150,
        },
      ),
    );
    // Tickers start on the first frame after the change; give the footer
    // rule time to grow.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    for (final label in [
      'Connecting',
      'Live categories',
      'Live channels',
      'Movies',
      'Series',
      'EPG: Cleaning programs',
      'EPG: Downloading',
      'EPG: Parsing',
      'Completed',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('12,480'), findsOneWidget);
    expect(find.text('3,150'), findsOneWidget);
    expect(find.text('38%'), findsOneWidget);
    expect(find.text('Press Esc to cancel'), findsOneWidget);
    await saveScreen(tester, 'playlists_import_progress');

    // Guide download with byte progress.
    env.imports.emit(
      _snapshot(
        pid,
        ImportStep.epgDownloading,
        counts: {
          ImportStep.liveCategories: 24,
          ImportStep.liveChannels: 12480,
          ImportStep.movies: 3150,
          ImportStep.series: 640,
          ImportStep.epgCleaning: 1200,
        },
        received: 12 * 1024 * 1024,
        total: 40 * 1024 * 1024,
      ),
    );
    await tester.pump();
    expect(find.text('12.0 MB of 40.0 MB'), findsOneWidget);
    expect(find.text('1,200 removed'), findsOneWidget);

    env.imports.emit(
      _snapshot(
        pid,
        ImportStep.completed,
        counts: {ImportStep.epgParsing: 123456},
      ),
    );
    await pumpUntil(
      tester,
      () => router.state.uri.toString() == '/p/$pid/live',
    );
    expect(find.text('Playlist ready'), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('failure: the error dialog, then the Manager', (
    tester,
  ) async {
    final env = (await tester.runAsync(_createEnv))!;
    final pid = env.playlistId;
    final router = playlistsTestRouter(
      initialLocation: '/playlists/$pid/import',
    );
    await pumpScreen(tester, routerHost(router), overrides: env.overrides);
    await pumpUntil(tester, () => env.imports.started.isNotEmpty);
    env.imports.emit(
      _snapshot(
        pid,
        ImportStep.failed,
        failedStep: ImportStep.connecting,
        error: const SourceException(SourceErrorKind.unreachable),
      ),
    );
    await settle(tester);
    expect(find.text('The playlist could not be imported'), findsOneWidget);
    expect(find.textContaining("couldn't reach the server"), findsOneWidget);
    expect(find.textContaining('green check'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget, reason: 'step marked');
    await saveScreen(tester, 'playlists_import_error');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // Ok
    await settleDrift(tester);
    expect(router.state.uri.toString(), '/');
    await unmountAndFlush(tester);
  });

  testWidgets('guide failure and empty sections are reported, content kept', (
    tester,
  ) async {
    final env = (await tester.runAsync(
      () => _createEnv(lastReloadAt: DateTime(2026, 10, 10)),
    ))!;
    final pid = env.playlistId;
    final router = playlistsTestRouter(
      initialLocation: '/playlists/$pid/import',
    );
    await pumpScreen(tester, routerHost(router), overrides: env.overrides);
    await pumpUntil(tester, () => env.imports.started.isNotEmpty);
    expect(find.text('Updating Kanal Demo'), findsOneWidget);
    env.imports.emit(
      _snapshot(
        pid,
        ImportStep.completed,
        failedStep: ImportStep.epgDownloading,
        epgError: const SourceException(SourceErrorKind.unparseable),
        warnings: const [
          ImportWarning(SourceErrorKind.sectionEmpty, SectionKind.series),
        ],
      ),
    );
    await settle(tester);
    expect(find.text('The guide could not be loaded'), findsOneWidget);
    expect(find.textContaining('were imported and are ready'), findsOneWidget);
    expect(find.text('Guide failed'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('Imported, but some sections are empty'), findsOneWidget);
    expect(find.textContaining('Nothing was found in: Series'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpUntil(
      tester,
      () => find.text('Playlist updated').evaluate().isNotEmpty,
    );
    await pumpUntil(
      tester,
      () => router.state.uri.toString() == '/p/$pid/live',
    );
    await unmountAndFlush(tester);
  });

  testWidgets('Esc cancels and returns to the Manager', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final pid = env.playlistId;
    final router = playlistsTestRouter(
      initialLocation: '/playlists/$pid/import?scope=epg',
    );
    await pumpScreen(tester, routerHost(router), overrides: env.overrides);
    await pumpUntil(tester, () => env.imports.started.isNotEmpty);
    expect(env.imports.started.single, (pid, ImportScope.epg));
    expect(find.text('Updating the guide of Kanal Demo'), findsOneWidget);
    env.imports.emit(
      _snapshot(pid, ImportStep.epgParsing, scope: ImportScope.epg),
    );
    await tester.pump();
    expect(find.text('Connecting'), findsNothing, reason: 'EPG steps only');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(env.imports.cancelled, [pid]);
    expect(find.text('Cancelling…'), findsOneWidget);
    env.imports.emit(
      _snapshot(
        pid,
        ImportStep.cancelled,
        failedStep: ImportStep.epgParsing,
        scope: ImportScope.epg,
      ),
    );
    await settleDrift(tester);
    expect(router.state.uri.toString(), '/');
    expect(find.text('Import cancelled'), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('a guide-only failure shows the guide reason', (tester) async {
    final env = (await tester.runAsync(_createEnv))!;
    final pid = env.playlistId;
    final router = playlistsTestRouter(
      initialLocation: '/playlists/$pid/import?scope=epg',
    );
    await pumpScreen(tester, routerHost(router), overrides: env.overrides);
    await pumpUntil(tester, () => env.imports.started.isNotEmpty);
    env.imports.emit(
      _snapshot(
        pid,
        ImportStep.failed,
        scope: ImportScope.epg,
        failedStep: ImportStep.epgDownloading,
        error: const SourceException(SourceErrorKind.emptyBody),
      ),
    );
    await settle(tester);
    expect(find.text('The guide could not be loaded'), findsOneWidget);
    expect(find.text('The guide file was empty.'), findsOneWidget);
    // "Edit playlist" goes to the edit form.
    await tester.tap(find.text('Edit playlist'));
    await settleDrift(tester);
    expect(router.state.uri.toString(), '/playlists/$pid/edit');
    await unmountAndFlush(tester);
  });
}
