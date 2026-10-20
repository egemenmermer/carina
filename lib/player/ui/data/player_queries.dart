/// Row lookups the player needs but the shared repositories do not expose
/// (`StreamUrlResolver.movie/episode` take drift rows; `VodRepository` only
/// returns view models). Read-only.
library;

import 'package:drift/drift.dart';

import '../../../data/db/database.dart';

/// Single-row queries for the player.
class PlayerQueries {
  const PlayerQueries(this._db);

  final AppDatabase _db;

  /// The stored movie [providerId] of [playlistId] (hidden ones included).
  Future<MovieRow?> movieRow(int playlistId, String providerId) =>
      (_db.select(_db.movies)
            ..where(
              (m) =>
                  m.playlistId.equals(playlistId) &
                  m.providerId.equals(providerId),
            )
            ..limit(1))
          .getSingleOrNull();

  /// The stored episode [providerId] of [playlistId].
  Future<EpisodeRow?> episodeRow(int playlistId, String providerId) =>
      (_db.select(_db.episodes)
            ..where(
              (e) =>
                  e.playlistId.equals(playlistId) &
                  e.providerId.equals(providerId),
            )
            ..limit(1))
          .getSingleOrNull();
}
