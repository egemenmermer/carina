/// A real import of the in-process mock server, for widget, screenshot and
/// integration tests that need a populated database.
///
/// ```dart
/// late MockImportFixture fx;
/// setUpAll(() async => fx = await importMockPlaylist());
/// tearDownAll(() => fx.dispose());
///
/// testWidgets('live grid', (tester) async {
///   await tester.pumpWidget(carinaTestApp(LiveScreen(playlistId: fx.playlistId),
///       overrides: fx.providerOverrides));
/// });
/// ```
///
/// Inside a `testWidgets` body (fake async), wrap the calls:
/// `fx = (await tester.runAsync(importMockPlaylist))!;` and
/// `await tester.runAsync(fx.dispose);`. HTTP goes through a real
/// `HttpClient` even when the Flutter test binding mocks `HttpClient`.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../../tools/mock_server/src/server.dart';

export '../../tools/mock_server/src/server.dart' show MockScale, MockFixtures;

/// The result of [importMockPlaylist].
class MockImportFixture {
  MockImportFixture._({
    required this.server,
    required this.db,
    required this.paths,
    required this.settings,
    required this.secrets,
    required this.importService,
    required this.playlistId,
    required this.importResult,
    required this.tempDir,
  });

  /// The running mock server (`server.baseUrl`, `server.catalog`,
  /// `server.requestLog`).
  final MockServer server;

  /// In-memory database with the imported playlist.
  final AppDatabase db;

  /// Temporary app folders.
  final AppPaths paths;
  final SettingsStore settings;

  /// Holds the playlist password (`test123`).
  final MemorySecretStore secrets;

  /// The service that ran the import (reuse it to reload).
  final ImportService importService;

  /// The Xtream playlist "Kanal Demo" (server = mock base URL, user
  /// `kanal`, `epgUrl` null = the default `{server}/xmltv.php`).
  final int playlistId;

  /// The terminal progress of the import.
  final ImportProgress importResult;
  final Directory tempDir;

  /// Overrides for `ProviderScope(overrides: …)` / `ProviderContainer`:
  /// database, paths, settings, secrets and the import service.
  List<Override> get providerOverrides => [
    appDatabaseProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(paths),
    settingsStoreProvider.overrideWithValue(settings),
    secretStoreProvider.overrideWithValue(secrets),
    importServiceProvider.overrideWithValue(importService),
  ];

  /// Runs another import of the playlist (through a real `HttpClient`, see
  /// the library documentation).
  Future<ImportProgress> reload({ImportScope scope = ImportScope.all}) =>
      HttpOverrides.runWithHttpOverrides(
        () => importService.run(playlistId, scope: scope),
        _RealHttpOverrides(),
      );

  /// Stops the server, closes the database and deletes the temp folder.
  Future<void> dispose() async {
    await importService.dispose();
    await server.stop();
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Best effort (Windows may still hold a handle for a moment).
    }
  }
}

/// Starts the mock server (ephemeral port), creates an in-memory database,
/// a [MemorySecretStore], a loaded [SettingsStore] and temporary
/// [AppPaths], adds the Xtream playlist "Kanal Demo" and runs the real
/// import (with the mock XMLTV guide unless [withEpg] is false).
///
/// Throws a [StateError] when the import does not complete. The small
/// catalog imports in about a second; [MockScale.large] takes longer.
Future<MockImportFixture> importMockPlaylist({
  MockScale scale = MockScale.small,
  bool withEpg = true,
}) => HttpOverrides.runWithHttpOverrides(
  () => _importMockPlaylist(scale: scale, withEpg: withEpg),
  _RealHttpOverrides(),
);

Future<MockImportFixture> _importMockPlaylist({
  required MockScale scale,
  required bool withEpg,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final tempDir = await Directory.systemTemp.createTemp('carina_mock_import_');
  final mediaDir = Directory('${tempDir.path}${Platform.pathSeparator}media');
  final liveDir = Directory('${tempDir.path}${Platform.pathSeparator}live');
  await mediaDir.create(recursive: true);
  await liveDir.create(recursive: true);

  final server = await MockServer.start(
    port: 0,
    scale: scale,
    mediaDir: mediaDir.path,
    liveDir: liveDir.path,
  );
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final paths = await AppPaths.resolve(
    override: '${tempDir.path}${Platform.pathSeparator}data',
  );
  final settings = SettingsStore(db);
  await settings.load();
  final secrets = MemorySecretStore();
  final service = ImportService(
    db: db,
    paths: paths,
    secrets: secrets,
    settings: settings,
    config: const ImportConfig(retries: 1),
  );

  try {
    final base = server.baseUrl;
    const user = MockFixtures.username;
    const pass = MockFixtures.password;
    final playlistId = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Kanal Demo',
            type: PlaylistType.xtream,
            server: Value(base),
            username: const Value(user),
            // null = the default XMLTV ({server}/xmltv.php, built from the
            // stored credentials); '' = guide switched off.
            epgUrl: Value(withEpg ? null : ''),
            createdAt: DateTime.now(),
          ),
        );
    await secrets.write(SecretStore.playlistPassword(playlistId), pass);

    final result = await service.run(playlistId);
    if (!result.succeeded) {
      throw StateError('Mock import did not complete: $result');
    }
    return MockImportFixture._(
      server: server,
      db: db,
      paths: paths,
      settings: settings,
      secrets: secrets,
      importService: service,
      playlistId: playlistId,
      importResult: result,
      tempDir: tempDir,
    );
  } on Object {
    await service.dispose();
    await server.stop();
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Best effort.
    }
    rethrow;
  }
}

/// Creates real `HttpClient`s even when the Flutter test binding installed
/// its mock `HttpOverrides` (which answers every request with HTTP 400).
class _RealHttpOverrides extends HttpOverrides {}
