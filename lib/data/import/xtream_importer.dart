/// Xtream Codes content import.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../db/database.dart';
import '../net/mask.dart';
import '../sources/source_exception.dart';
import '../sources/xtream/xtream.dart';
import 'content_writer.dart';
import 'import_job.dart';
import 'import_progress.dart';
import 'import_rows.dart';

/// Item counts of a finished content import.
typedef ContentCounts = ({int live, int movies, int series});

/// Fetches an Xtream account's catalog and upserts it step by step:
/// connecting (authenticate, store `accountJson`) → live categories → live
/// channels (bulk, falling back to one request per category) → movie
/// categories + movies → series categories + series.
final class XtreamImporter {
  XtreamImporter(this.job, this.writer);

  final ImportJob job;
  final ContentWriter writer;

  ProgressReporter get _progress => job.progress;

  Future<ContentCounts> run() async {
    final playlist = job.playlist;
    final server = playlist.server?.trim() ?? '';
    final username = playlist.username?.trim() ?? '';
    final password = job.password ?? '';

    _progress.enter(ImportStep.connecting);
    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      throw SourceException(
        SourceErrorKind.unauthorized,
        message: 'Missing server, username or password',
        url: server.isEmpty ? null : maskServer(server),
      );
    }
    final client = XtreamClient(
      job.dio,
      XtreamCredentials(server, username, password),
      bulkReceiveTimeout: job.config.bulkReceiveTimeout,
      retries: job.config.retries,
    );
    job.log('connecting to ${maskServer(server)}');
    final account = await client.authenticate(cancelToken: job.cancelToken);
    job.throwIfCancelled();
    await (job.db.update(
      job.db.playlists,
    )..where((p) => p.id.equals(job.playlistId))).write(
      PlaylistsCompanion(accountJson: Value(jsonEncode(account.toJson()))),
    );

    // Live categories.
    _progress.enter(ImportStep.liveCategories);
    final liveCategories = await client.liveCategories(
      cancelToken: job.cancelToken,
    );
    job.throwIfCancelled();
    await writer.upsertCategories(
      SectionKind.live,
      categoriesFromXtream(liveCategories, SectionKind.live),
    );
    _progress.count(
      ImportStep.liveCategories,
      liveCategories.length,
      force: true,
    );

    // Live channels.
    _progress.enter(ImportStep.liveChannels);
    final streams = await _fetchWithFallback(
      'live',
      liveCategories,
      () => client.liveStreams(cancelToken: job.cancelToken),
      (ids) => client.liveStreamsPerCategory(
        ids,
        concurrency: job.config.categoryConcurrency,
        cancelToken: job.cancelToken,
      ),
    );
    job.throwIfCancelled();
    final seenChannels = <String>{};
    final channels = await mapInSlices(
      streams,
      (slice, done) =>
          channelsFromXtream(slice, seen: seenChannels, offset: done),
    );
    await writer.upsertChannels(
      channels,
      onProgress: (n) => _progress.count(ImportStep.liveChannels, n),
    );
    _progress.count(ImportStep.liveChannels, channels.length, force: true);

    // Movies.
    _progress.enter(ImportStep.movies);
    final vodCategories = await client.vodCategories(
      cancelToken: job.cancelToken,
    );
    final vod = await _fetchWithFallback(
      'movies',
      vodCategories,
      () => client.vodStreams(cancelToken: job.cancelToken),
      (ids) => client.vodStreamsPerCategory(
        ids,
        concurrency: job.config.categoryConcurrency,
        cancelToken: job.cancelToken,
      ),
    );
    job.throwIfCancelled();
    await writer.upsertCategories(
      SectionKind.movie,
      categoriesFromXtream(vodCategories, SectionKind.movie),
    );
    final seenMovies = <String>{};
    final movies = await mapInSlices(
      vod,
      (slice, done) => moviesFromXtream(slice, seen: seenMovies, offset: done),
    );
    await writer.upsertMovies(
      movies,
      onProgress: (n) => _progress.count(ImportStep.movies, n),
    );
    _progress.count(ImportStep.movies, movies.length, force: true);

    // Series.
    _progress.enter(ImportStep.series);
    final seriesCategories = await client.seriesCategories(
      cancelToken: job.cancelToken,
    );
    final list = await _fetchWithFallback(
      'series',
      seriesCategories,
      () => client.seriesList(cancelToken: job.cancelToken),
      (ids) => client.seriesListPerCategory(
        ids,
        concurrency: job.config.categoryConcurrency,
        cancelToken: job.cancelToken,
      ),
    );
    job.throwIfCancelled();
    await writer.upsertCategories(
      SectionKind.series,
      categoriesFromXtream(seriesCategories, SectionKind.series),
    );
    final seenSeries = <String>{};
    final series = await mapInSlices(
      list,
      (slice, done) => seriesFromXtream(slice, seen: seenSeries, offset: done),
    );
    await writer.upsertSeries(
      series,
      onProgress: (n) => _progress.count(ImportStep.series, n),
    );
    _progress.count(ImportStep.series, series.length, force: true);

    return (
      live: channels.length,
      movies: movies.length,
      series: series.length,
    );
  }

  /// The bulk call, or one request per category when the bulk call fails
  /// (timeout, HTTP error, unreadable body…) or returns nothing although
  /// there are categories. Credential and cancellation errors are rethrown.
  Future<List<T>> _fetchWithFallback<T>(
    String section,
    List<XtreamCategory> categories,
    Future<List<T>> Function() bulk,
    Future<List<T>> Function(List<String> categoryIds) perCategory,
  ) async {
    try {
      final all = await bulk();
      if (all.isNotEmpty || categories.isEmpty) return all;
      job.log('bulk $section list is empty; trying each category');
    } on SourceException catch (e) {
      if (job.isCancelled || !_fallbackWorthy(e) || categories.isEmpty) {
        rethrow;
      }
      job.log(
        'bulk $section list failed (${e.kind.name}); '
        'falling back to ${categories.length} category requests',
      );
    }
    job.throwIfCancelled();
    return perCategory([for (final c in categories) c.categoryId]);
  }

  static bool _fallbackWorthy(SourceException e) => switch (e.kind) {
    SourceErrorKind.timeout ||
    SourceErrorKind.unreachable ||
    SourceErrorKind.http ||
    SourceErrorKind.notFound ||
    SourceErrorKind.emptyBody ||
    SourceErrorKind.unparseable => true,
    _ => false,
  };
}

/// Category rows in provider order.
List<CategoryData> categoriesFromXtream(
  List<XtreamCategory> categories,
  SectionKind kind,
) {
  final seen = <String>{};
  final out = <CategoryData>[];
  for (final c in categories) {
    if (!seen.add(c.categoryId)) continue;
    out.add(
      CategoryData(
        kind: kind,
        providerId: c.categoryId,
        name: nonBlankName(c.categoryName, fallback: c.categoryId),
        parentId: c.parentId,
        sortIndex: out.length,
      ),
    );
  }
  return out;
}

/// Channel rows in provider order (duplicate stream ids: first wins).
///
/// `displayName` / `quality` come from `parseQuality`, `archiveDays` is
/// `tv_archive_duration` when `tv_archive == 1`, `streamUrl` stays null
/// (built from the stream id) and only an absolute `direct_source` is kept.
///
/// [seen] and [offset] let a caller map a big list in slices (see
/// [mapInSlices]).
List<ChannelData> channelsFromXtream(
  List<XtreamLiveStream> streams, {
  Set<String>? seen,
  int offset = 0,
}) {
  seen ??= <String>{};
  final out = <ChannelData>[];
  for (final s in streams) {
    if (!seen.add(s.streamId)) continue;
    final display = channelDisplayName(s.name, fallback: s.streamId);
    out.add(
      ChannelData(
        providerId: s.streamId,
        num: s.num,
        name: s.name,
        displayName: display.displayName,
        quality: display.quality,
        logo: s.streamIcon,
        categoryId: s.categoryId,
        epgId: s.epgChannelId,
        archiveDays: s.archiveDays,
        directSource: usableDirectSource(s.directSource),
        added: s.added,
        sortIndex: offset + out.length,
      ),
    );
  }
  return out;
}

/// Movie rows in provider order (duplicate stream ids: first wins).
List<MovieData> moviesFromXtream(
  List<XtreamVodStream> streams, {
  Set<String>? seen,
  int offset = 0,
}) {
  seen ??= <String>{};
  final out = <MovieData>[];
  for (final s in streams) {
    if (!seen.add(s.streamId)) continue;
    out.add(
      MovieData(
        providerId: s.streamId,
        name: nonBlankName(s.name, fallback: s.streamId),
        categoryId: s.categoryId,
        poster: s.streamIcon,
        rating: s.rating,
        added: s.added,
        containerExt: s.containerExtension,
        tmdbId: s.tmdbId,
        year: s.year,
        directSource: usableDirectSource(s.directSource),
        sortIndex: offset + out.length,
      ),
    );
  }
  return out;
}

/// Series rows in provider order (duplicate series ids: first wins).
/// `backdropsJson` is a JSON list (null when there is none) and `year` comes
/// from `year` or the release date.
List<SeriesData> seriesFromXtream(
  List<XtreamSeries> list, {
  Set<String>? seen,
  int offset = 0,
}) {
  seen ??= <String>{};
  final out = <SeriesData>[];
  for (final s in list) {
    if (!seen.add(s.seriesId)) continue;
    out.add(
      SeriesData(
        providerId: s.seriesId,
        name: nonBlankName(s.name, fallback: s.seriesId),
        categoryId: s.categoryId,
        cover: s.cover,
        plot: s.plot,
        cast: s.cast,
        director: s.director,
        genre: s.genre,
        releaseDate: s.releaseDate,
        lastModified: s.lastModified,
        rating: s.rating,
        backdropsJson: s.backdrops.isEmpty ? null : jsonEncode(s.backdrops),
        youtubeTrailer: s.youtubeTrailer,
        tmdbId: s.tmdbId,
        year: s.year,
        sortIndex: offset + out.length,
      ),
    );
  }
  return out;
}
