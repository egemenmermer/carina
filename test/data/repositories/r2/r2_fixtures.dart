import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/text/normalize.dart';

/// In-memory database, settings, secrets and a controllable clock for the
/// R2 repository tests. Rows are seeded directly (no import pipeline).
class R2Env {
  R2Env._(this.db, this.settings, this.secrets, this.now);

  static Future<R2Env> create({DateTime? now}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    await settings.load();
    return R2Env._(
      db,
      settings,
      MemorySecretStore(),
      now ?? DateTime(2026, 10, 17, 12),
    );
  }

  final AppDatabase db;
  final SettingsStore settings;
  final MemorySecretStore secrets;

  /// The clock handed to repositories (advance it in tests).
  DateTime now;

  DateTime clock() => now;

  Future<void> close() => db.close();

  Future<int> playlist({
    PlaylistType type = PlaylistType.xtream,
    String? server,
    String username = 'kanal',
    String? password = 'test123',
    String name = 'Test',
  }) async {
    final id = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: name,
            type: type,
            server: Value(server),
            username: Value(type == PlaylistType.xtream ? username : null),
            createdAt: DateTime(2026),
          ),
        );
    if (password != null && type == PlaylistType.xtream) {
      await secrets.write(SecretStore.playlistPassword(id), password);
    }
    return id;
  }

  Future<int> category(
    int playlistId,
    SectionKind kind,
    String providerId,
    String name, {
    int sortIndex = 0,
    int? customIndex,
    String? localName,
    bool hidden = false,
    bool locked = false,
  }) => db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          playlistId: playlistId,
          kind: kind,
          providerId: providerId,
          name: name,
          sortIndex: Value(sortIndex),
          customIndex: Value(customIndex),
          localName: Value(localName),
          hidden: Value(hidden),
          locked: Value(locked),
        ),
      );

  Future<int> movie(
    int playlistId,
    String providerId,
    String name, {
    String? categoryId,
    String? poster,
    double? rating,
    DateTime? added,
    int? year,
    int sortIndex = 0,
    bool hidden = false,
    int? tmdbId,
    String? infoJson,
    DateTime? infoFetchedAt,
    String? containerExt,
  }) => db
      .into(db.movies)
      .insert(
        MoviesCompanion.insert(
          playlistId: playlistId,
          providerId: providerId,
          name: name,
          categoryId: Value(categoryId),
          poster: Value(poster),
          rating: Value(rating),
          added: Value(added),
          year: Value(year),
          sortIndex: Value(sortIndex),
          hidden: Value(hidden),
          tmdbId: Value(tmdbId),
          infoJson: Value(infoJson),
          infoFetchedAt: Value(infoFetchedAt),
          containerExt: Value(containerExt),
        ),
      );

  Future<int> series(
    int playlistId,
    String providerId,
    String name, {
    String? categoryId,
    String? cover,
    String? cast,
    String? plot,
    String? genre,
    double? rating,
    DateTime? lastModified,
    int? year,
    int sortIndex = 0,
    bool hidden = false,
    List<String>? backdrops,
    int? tmdbId,
  }) => db
      .into(db.series)
      .insert(
        SeriesCompanion.insert(
          playlistId: playlistId,
          providerId: providerId,
          name: name,
          categoryId: Value(categoryId),
          cover: Value(cover),
          cast: Value(cast),
          plot: Value(plot),
          genre: Value(genre),
          rating: Value(rating),
          lastModified: Value(lastModified),
          year: Value(year),
          sortIndex: Value(sortIndex),
          hidden: Value(hidden),
          backdropsJson: Value(
            backdrops == null ? null : jsonEncode(backdrops),
          ),
          tmdbId: Value(tmdbId),
        ),
      );

  Future<int> episode(
    int playlistId,
    String seriesId,
    String providerId,
    int season,
    int episode, {
    String title = '',
    int? durationSecs,
    String? streamUrl,
  }) => db
      .into(db.episodes)
      .insert(
        EpisodesCompanion.insert(
          playlistId: playlistId,
          providerId: providerId,
          seriesId: seriesId,
          season: season,
          episodeNum: episode,
          title: title,
          durationSecs: Value(durationSecs),
          streamUrl: Value(streamUrl),
        ),
      );

  Future<int> channel(
    int playlistId,
    String providerId,
    String name, {
    String? displayName,
    String? epgId,
    String? matchedEpgId,
    String? customEpgId,
    String? categoryId,
    bool hidden = false,
    int? num,
    String? quality,
    int sortIndex = 0,
  }) => db
      .into(db.channels)
      .insert(
        ChannelsCompanion.insert(
          playlistId: playlistId,
          providerId: providerId,
          name: name,
          displayName: displayName ?? name,
          epgId: Value(epgId),
          matchedEpgId: Value(matchedEpgId),
          customEpgId: Value(customEpgId),
          categoryId: Value(categoryId),
          hidden: Value(hidden),
          num: Value(num),
          quality: Value(quality),
          sortIndex: Value(sortIndex),
        ),
      );

  Future<int> programme(
    int playlistId,
    String epgChannelId,
    DateTime start,
    DateTime stop,
    String title,
  ) => db
      .into(db.programmes)
      .insert(
        ProgrammesCompanion.insert(
          playlistId: playlistId,
          epgChannelId: epgChannelId,
          start: start.toUtc().millisecondsSinceEpoch,
          stop: stop.toUtc().millisecondsSinceEpoch,
          title: title,
        ),
      );

  /// A `search_index` row; `normalized` comes from [normalizeForSearch].
  /// [asInt] stores `playlist_id` as an integer (both forms must work).
  Future<void> index(
    int playlistId,
    String kind,
    String refId,
    String title, {
    bool asInt = false,
  }) => db.customInsert(
    'INSERT INTO search_index(normalized, title, kind, ref_id, playlist_id) '
    'VALUES (?, ?, ?, ?, ?)',
    variables: [
      Variable.withString(normalizeForSearch(title)),
      Variable.withString(title),
      Variable.withString(kind),
      Variable.withString(refId),
      asInt ? Variable.withInt(playlistId) : Variable.withString('$playlistId'),
    ],
    updates: {db.searchIndex},
  );

  Future<void> indexProgramme(int playlistId, int programmeId, String title) =>
      db.customInsert(
        'INSERT INTO programme_search(normalized, programme_id, playlist_id) '
        'VALUES (?, ?, ?)',
        variables: [
          Variable.withString(normalizeForSearch(title)),
          Variable.withInt(programmeId),
          Variable.withInt(playlistId),
        ],
        updates: {db.programmeSearch},
      );
}

/// Collects a stream's values so a test can wait for the next emission
/// that matches a condition (one subscription for the whole test).
class Emissions<T> {
  Emissions(Stream<T> stream) {
    _sub = stream.listen(
      (v) {
        values.add(v);
        _changed.add(null);
      },
      onError: (Object e, StackTrace st) {
        errors.add(e);
        _changed.add(null);
      },
    );
  }

  final List<T> values = [];
  final List<Object> errors = [];
  final StreamController<void> _changed = StreamController<void>.broadcast();
  late final StreamSubscription<T> _sub;
  int _cursor = 0;

  /// The next not-yet-consumed value matching [test] (5 s timeout).
  Future<T> next([bool Function(T value)? test]) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      if (errors.isNotEmpty) throw errors.first;
      while (_cursor < values.length) {
        final v = values[_cursor++];
        if (test == null || test(v)) return v;
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('No matching emission', remaining);
      }
      await _changed.stream.first.timeout(remaining, onTimeout: () {});
    }
  }

  Future<void> cancel() async {
    await _sub.cancel();
    await _changed.close();
  }
}
