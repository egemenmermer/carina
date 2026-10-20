import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// The single local database. Opened once at startup (see
/// `appDatabaseProvider`); tests use [AppDatabase.forTesting] with
/// `NativeDatabase.memory()`.
@DriftDatabase(
  tables: [
    Playlists,
    Categories,
    Channels,
    Movies,
    Series,
    Seasons,
    Episodes,
    EpgChannels,
    Programmes,
    Favorites,
    FavoriteTags,
    FavoriteTagLinks,
    WatchStates,
    LastWatchedLive,
    Reminders,
    Downloads,
    Recordings,
    TmdbCache,
    Settings,
  ],
  include: {'search.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens `kanal.sqlite` in [directory] (the app data folder) on a
  /// background isolate. The file keeps the app's former name so existing
  /// installs open their data.
  factory AppDatabase.open(String directory) => AppDatabase(
    driftDatabase(
      name: 'kanal',
      native: DriftNativeOptions(
        databaseDirectory: () async => directory,
        shareAcrossIsolates: true,
      ),
    ),
  );

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      // 64 MB page cache: bulk EPG writes are ~20% faster.
      await customStatement('PRAGMA cache_size = -65536');
    },
  );
}
