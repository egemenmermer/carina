/// M3U / M3U8 content import.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:path/path.dart' as p;

import '../db/database.dart';
import '../net/dio_factory.dart';
import '../net/mask.dart';
import '../sources/m3u/m3u.dart';
import '../sources/source_exception.dart';
import '../text/normalize.dart';
import 'content_writer.dart';
import 'import_job.dart';
import 'import_progress.dart';
import 'import_rows.dart';
import 'xtream_importer.dart' show ContentCounts;

/// Everything an M3U import writes, built from a parse result (on a
/// background isolate, see [parseM3uContentFile]).
final class M3uContent {
  const M3uContent({
    required this.header,
    required this.entryCount,
    required this.duplicates,
    required this.liveCategories,
    required this.movieCategories,
    required this.seriesCategories,
    required this.channels,
    required this.movies,
    required this.series,
    required this.seasons,
    required this.episodes,
  });

  final M3uHeader header;

  /// Entries in the file (before removing duplicates).
  final int entryCount;

  /// Entries dropped because an earlier entry had the same `m3uEntryId`.
  final int duplicates;
  final List<CategoryData> liveCategories;
  final List<CategoryData> movieCategories;
  final List<CategoryData> seriesCategories;
  final List<ChannelData> channels;
  final List<MovieData> movies;
  final List<SeriesData> series;
  final List<SeasonData> seasons;
  final List<EpisodeData> episodes;

  Set<String> get episodeIds => {for (final e in episodes) e.providerId};

  /// `"<seriesId>/<season>"` keys of [seasons].
  Set<String> get seasonKeys => {
    for (final s in seasons) '${s.seriesId}/${s.seasonNumber}',
  };
}

/// Archive window of an entry: `catchup-days` (header defaults included by
/// the parser), 7 when catch-up is declared without days, 0 without
/// catch-up.
int m3uArchiveDays(M3uEntry entry) {
  if (entry.catchup == null) return 0;
  final days = entry.catchupDays;
  return days != null && days > 0 ? days : 7;
}

/// Provider id of the series an episode belongs to: the first 16 hex
/// characters of `sha1(normalizeForSearch(seriesName))`.
String m3uSeriesId(String seriesName) {
  final normalized = normalizeForSearch(seriesName);
  final key = normalized.isEmpty ? seriesName.trim().toLowerCase() : normalized;
  return sha1.convert(utf8.encode(key)).toString().substring(0, 16);
}

/// Maps a parse result to rows: categories from the first group of each
/// entry (per section), live channels, movies, and series built from the
/// episode entries (seasons and episodes included). Entries with the same
/// `m3uEntryId` are kept once (the first). [added] stamps new rows (null on
/// a first import).
M3uContent m3uContentFromResult(M3uParseResult result, {DateTime? added}) {
  final ids = <String>{};
  var duplicates = 0;
  final liveGroups = <String, CategoryData>{};
  final movieGroups = <String, CategoryData>{};
  final seriesGroups = <String, CategoryData>{};
  final channels = <ChannelData>[];
  final movies = <MovieData>[];
  final seriesById = <String, SeriesData>{};
  final episodes = <EpisodeData>[];
  final seasonSizes = <String, Map<int, int>>{};

  String? groupOf(
    M3uEntry e,
    Map<String, CategoryData> groups,
    SectionKind kind,
  ) {
    final all = e.groups;
    if (all.isEmpty) return null;
    final group = all.first;
    groups.putIfAbsent(
      group,
      () => CategoryData(
        kind: kind,
        providerId: group,
        name: group,
        sortIndex: groups.length,
      ),
    );
    return group;
  }

  String? headersOf(M3uEntry e) =>
      e.headers.isEmpty ? null : jsonEncode(e.headers);

  for (final e in result.entries) {
    final id = m3uEntryId(e);
    if (!ids.add(id)) {
      duplicates++;
      continue;
    }
    switch (e.kind) {
      case M3uKind.live:
        final display = channelDisplayName(e.name, fallback: id);
        final catchup = e.catchup;
        channels.add(
          ChannelData(
            providerId: id,
            num: e.tvgChno,
            name: e.name,
            displayName: display.displayName,
            quality: display.quality,
            logo: e.tvgLogo,
            categoryId: groupOf(e, liveGroups, SectionKind.live),
            epgId: e.tvgId,
            archiveDays: m3uArchiveDays(e),
            catchupType: catchup,
            catchupSource: catchup == null ? null : e.catchupSource,
            streamUrl: e.url,
            headersJson: headersOf(e),
            unsupported: e.unsupported,
            added: added,
            sortIndex: channels.length,
          ),
        );
      case M3uKind.movie:
        movies.add(
          MovieData(
            providerId: id,
            name: nonBlankName(e.name, fallback: id),
            categoryId: groupOf(e, movieGroups, SectionKind.movie),
            poster: e.tvgLogo,
            added: added,
            containerExt: urlExtension(e.url),
            year: yearFromTitle(e.name),
            streamUrl: e.url,
            headersJson: headersOf(e),
            sortIndex: movies.length,
          ),
        );
      case M3uKind.episode:
        final category = groupOf(e, seriesGroups, SectionKind.series);
        var seriesName = (e.seriesName ?? e.name).trim();
        // "S01E02" alone: the group usually names the series.
        if (category != null && isSeriesMarkerOnly(seriesName)) {
          seriesName = category;
        }
        seriesName = nonBlankName(seriesName, fallback: id);
        final seriesId = m3uSeriesId(seriesName);
        seriesById.putIfAbsent(
          seriesId,
          () => SeriesData(
            providerId: seriesId,
            name: seriesName,
            categoryId: category,
            cover: e.tvgLogo,
            year: yearFromTitle(seriesName),
            sortIndex: seriesById.length,
          ),
        );
        final season = e.season ?? 1;
        final sizes = seasonSizes.putIfAbsent(seriesId, () => {});
        final position = (sizes[season] ?? 0) + 1;
        sizes[season] = position;
        episodes.add(
          EpisodeData(
            providerId: id,
            seriesId: seriesId,
            season: season,
            episodeNum: e.episode ?? position,
            title: e.episodeTitle ?? e.name,
            containerExt: urlExtension(e.url),
            durationSecs: e.duration > 0 ? e.duration : null,
            image: e.tvgLogo,
            streamUrl: e.url,
            added: added,
          ),
        );
    }
  }

  final seasons = <SeasonData>[];
  seasonSizes.forEach((seriesId, sizes) {
    final cover = seriesById[seriesId]?.cover;
    for (final number in sizes.keys.toList()..sort()) {
      seasons.add(
        SeasonData(
          seriesId: seriesId,
          seasonNumber: number,
          cover: cover,
          episodeCount: sizes[number],
        ),
      );
    }
  });

  return M3uContent(
    header: result.header,
    entryCount: result.entries.length,
    duplicates: duplicates,
    liveCategories: liveGroups.values.toList(),
    movieCategories: movieGroups.values.toList(),
    seriesCategories: seriesGroups.values.toList(),
    channels: channels,
    movies: movies,
    series: seriesById.values.toList(),
    seasons: seasons,
    episodes: episodes,
  );
}

/// Streams the M3U file at [path] through the parser and maps it with
/// [m3uContentFromResult]. Meant to run on a background isolate.
Future<M3uContent> parseM3uContentFile(String path, {DateTime? added}) async {
  final result = await parseM3uStream(File(path).openRead()).toResult();
  return m3uContentFromResult(result, added: added);
}

// A top-level factory so the closure sent to the isolate captures only the
// path and the date (never the importer).
Future<M3uContent> Function() _parseTask(String path, DateTime? added) =>
    () => parseM3uContentFile(path, added: added);

/// Whether [name] is only a season/episode marker (`S01E02`, `S01 E02`,
/// `1x02`) without a series name.
bool isSeriesMarkerOnly(String name) {
  final marker = parseSeriesMarker(name);
  return marker != null &&
      marker.episodeTitle == null &&
      marker.seriesName == name.trim();
}

final RegExp _yearInTitle = RegExp(r'[(\[]\s*((?:19|20)\d{2})\s*[)\]]');

/// `Kış Uykusu (2014)` → 2014.
int? yearFromTitle(String title) {
  final m = _yearInTitle.firstMatch(title);
  return m == null ? null : int.parse(m[1]!);
}

/// Lower-case file extension of a URL path (`…/1.mkv?x=1` → `mkv`), or null.
String? urlExtension(String url) {
  var end = url.length;
  final q = url.indexOf('?');
  if (q >= 0) end = q;
  final h = url.indexOf('#');
  if (h >= 0 && h < end) end = h;
  final path = url.substring(0, end);
  final slash = path.lastIndexOf('/');
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot < slash || dot == path.length - 1) return null;
  final ext = path.substring(dot + 1).toLowerCase();
  if (ext.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(ext)) return null;
  return ext;
}

final RegExp _windowsPath = RegExp(r'^[A-Za-z]:[\\/]');

/// The local file path of [source] (`file://` URI or an absolute path), or
/// null for a remote URL.
String? localPathOf(String source) {
  final s = source.trim();
  if (s.toLowerCase().startsWith('file://')) {
    try {
      return Uri.parse(s).toFilePath();
    } on Object {
      return null;
    }
  }
  if (s.startsWith('/') || _windowsPath.hasMatch(s) || s.startsWith(r'\\')) {
    return s;
  }
  return null;
}

/// Downloads (`PlaylistType.m3u`) or reads (`PlaylistType.m3uFile`) the
/// playlist, parses and maps it on a background isolate, stores the header
/// (`m3uHeaderJson`; `epgUrl` from `url-tvg` when it is null — not when it
/// is `''`, which switches the guide off),
/// then upserts the sections step by step.
final class M3uImporter {
  M3uImporter(this.job, this.writer);

  final ImportJob job;
  final ContentWriter writer;
  M3uContent? _content;

  ProgressReporter get _progress => job.progress;

  Future<ContentCounts> run() async {
    _progress.enter(ImportStep.connecting);
    final source = job.playlist.m3uUrl?.trim() ?? '';
    if (source.isEmpty) {
      throw const SourceException(
        SourceErrorKind.notFound,
        message: 'The playlist has no M3U URL or file',
      );
    }
    final local = job.playlist.type == PlaylistType.m3uFile
        ? (localPathOf(source) ?? source)
        : localPathOf(source);
    final String path;
    if (local != null) {
      path = local;
      if (!await File(path).exists()) {
        throw const SourceException(
          SourceErrorKind.notFound,
          message: 'The M3U file does not exist',
        );
      }
    } else {
      path = p.join(
        job.paths.tmp,
        'playlist_${job.playlistId}_${DateTime.now().microsecondsSinceEpoch}.m3u',
      );
      job.log('downloading ${maskUrl(source)}');
      await downloadToFile(
        job.dio,
        source,
        path,
        onProgress: (received, total) => _progress.bytes(received, total),
        cancelToken: job.cancelToken,
      );
    }

    final M3uContent content;
    try {
      job.throwIfCancelled();
      await _checkLooksLikeM3u(path, source);
      final added = await _hasContent() ? job.now() : null;
      content = await runCancellableIsolate(
        job,
        _parseTask(path, added),
        debugName: 'carina-m3u-import',
      );
    } finally {
      if (local == null) await _deleteQuietly(path);
    }
    job.throwIfCancelled();
    _content = content;
    job.log(
      'parsed ${content.entryCount} entries '
      '(${content.duplicates} duplicates): ${content.channels.length} live, '
      '${content.movies.length} movies, ${content.series.length} series',
    );
    if (content.entryCount == 0) {
      throw SourceException(
        SourceErrorKind.emptyBody,
        message: 'The playlist has no entries',
        url: local == null ? maskUrl(source) : null,
      );
    }
    await _saveHeader(content.header);

    _progress.enter(ImportStep.liveCategories);
    await writer.upsertCategories(SectionKind.live, content.liveCategories);
    _progress.count(
      ImportStep.liveCategories,
      content.liveCategories.length,
      force: true,
    );

    _progress.enter(ImportStep.liveChannels);
    await writer.upsertChannels(
      content.channels,
      onProgress: (n) => _progress.count(ImportStep.liveChannels, n),
    );
    _progress.count(
      ImportStep.liveChannels,
      content.channels.length,
      force: true,
    );

    _progress.enter(ImportStep.movies);
    await writer.upsertCategories(SectionKind.movie, content.movieCategories);
    await writer.upsertMovies(
      content.movies,
      onProgress: (n) => _progress.count(ImportStep.movies, n),
    );
    _progress.count(ImportStep.movies, content.movies.length, force: true);

    _progress.enter(ImportStep.series);
    await writer.upsertCategories(SectionKind.series, content.seriesCategories);
    await writer.upsertSeries(
      content.series,
      onProgress: (n) => _progress.count(ImportStep.series, n),
    );
    await writer.upsertSeasonsAndEpisodes(content.seasons, content.episodes);
    _progress.count(ImportStep.series, content.series.length, force: true);

    return (
      live: content.channels.length,
      movies: content.movies.length,
      series: content.series.length,
    );
  }

  /// After a successful import: drops seasons and episodes that are no
  /// longer in the playlist.
  Future<void> finish() async {
    final content = _content;
    if (content == null) return;
    final stale = await writer.deleteStaleEpisodes(
      content.episodeIds,
      content.seasonKeys,
    );
    if (stale > 0) job.log('removed $stale episodes');
  }

  Future<bool> _hasContent() async {
    final pid = Variable.withInt(job.playlistId);
    final row = await job.db
        .customSelect(
          'SELECT EXISTS(SELECT 1 FROM "channels" WHERE "playlist_id" = ?) '
          'OR EXISTS(SELECT 1 FROM "movies" WHERE "playlist_id" = ?) '
          'OR EXISTS(SELECT 1 FROM "series" WHERE "playlist_id" = ?) AS "any"',
          variables: [pid, pid, pid],
        )
        .getSingle();
    return row.read<int>('any') != 0;
  }

  Future<void> _checkLooksLikeM3u(String path, String source) async {
    final file = await File(path).open();
    final List<int> head;
    try {
      head = await file.read(64 * 1024);
    } finally {
      await file.close();
    }
    final text = utf8.decode(head, allowMalformed: true);
    final masked = localPathOf(source) == null ? maskUrl(source) : null;
    if (text.trim().isEmpty) {
      throw SourceException(
        SourceErrorKind.emptyBody,
        message: 'The playlist is empty',
        url: masked,
      );
    }
    if (!looksLikeM3u(text)) {
      throw SourceException(
        SourceErrorKind.unparseable,
        message: 'Not an M3U playlist',
        url: masked,
      );
    }
  }

  /// Stores the header; fills `epgUrl` from `url-tvg` only when it is null
  /// (the default) — never when it is `''` (EPG switched off) or custom.
  Future<void> _saveHeader(M3uHeader header) async {
    final epgUrl = job.playlist.epgUrl == null && header.tvgUrls.isNotEmpty
        ? header.tvgUrls.first
        : null;
    await (job.db.update(
      job.db.playlists,
    )..where((p) => p.id.equals(job.playlistId))).write(
      PlaylistsCompanion(
        m3uHeaderJson: Value(jsonEncode(header.toJson())),
        epgUrl: epgUrl == null ? const Value.absent() : Value(epgUrl),
      ),
    );
    if (epgUrl != null) {
      job.log('EPG URL taken from the playlist header: ${maskUrl(epgUrl)}');
    }
    job.playlist = await (job.db.select(
      job.db.playlists,
    )..where((p) => p.id.equals(job.playlistId))).getSingle();
  }
}

Future<void> _deleteQuietly(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Best effort.
  }
}
