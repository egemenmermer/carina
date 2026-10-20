/// Xtream Codes `player_api.php` payloads for the mock catalog.
///
/// Large lists are encoded once per origin and cached as UTF-8 bytes, so a
/// 60,000-movie `get_vod_streams` is served straight from memory.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'catalog.dart';
import 'epg.dart';
import 'rng.dart';

/// State of a username/password pair.
enum MockAccount { active, expired, invalid }

MockAccount accountFor(String? username, String? password) {
  if (username == MockFixtures.username && password == MockFixtures.password) {
    return MockAccount.active;
  }
  if (username == MockFixtures.expiredUsername &&
      password == MockFixtures.expiredPassword) {
    return MockAccount.expired;
  }
  return MockAccount.invalid;
}

/// A `player_api.php` response.
final class ApiResponse {
  const ApiResponse(this.status, this.body, {this.html = false});

  final int status;
  final Uint8List body;

  /// Served as `text/html; charset=UTF-8` (as some real panels do).
  final bool html;
}

/// Actions answered with a `text/html` content type.
const htmlActions = <String>{
  'get_live_categories',
  'get_series_categories',
  'get_series',
  'get_vod_info',
  'get_short_epg',
};

final _unauthorized = Uint8List.fromList(
  utf8.encode('{"user_info":{"auth":0}}'),
);
final _emptyList = Uint8List.fromList(utf8.encode('[]'));

/// Encodes a JSON array in batches, so a 60k-item list never needs one
/// giant intermediate `List<Map>`.
Uint8List encodeJsonList<T>(
  Iterable<T> items,
  Map<String, Object?> Function(T item) toJson, {
  int batch = 1000,
}) {
  final encoder = jsonUtf8;
  final out = BytesBuilder(copy: false)..addByte(0x5B);
  var first = true;
  var pending = <Map<String, Object?>>[];
  void flush() {
    if (pending.isEmpty) return;
    final bytes = encoder.convert(pending);
    if (!first) out.addByte(0x2C);
    first = false;
    out.add(Uint8List.sublistView(_asBytes(bytes), 1, bytes.length - 1));
    pending = <Map<String, Object?>>[];
  }

  for (final item in items) {
    pending.add(toJson(item));
    if (pending.length >= batch) flush();
  }
  flush();
  out.addByte(0x5D);
  return out.takeBytes();
}

/// Shared JSON → UTF-8 encoder.
final jsonUtf8 = JsonUtf8Encoder();

Uint8List _asBytes(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

Uint8List _encode(Object? value) => _asBytes(jsonUtf8.convert(value));

String _hms(int seconds) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${two(seconds ~/ 3600)}:${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)}';
}

int _epochSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

/// ffprobe-like stream info for the two VOD files.
Map<String, Object?> _videoInfo(String file) {
  final mp4 = file == MockMedia.h264Aac720p50Mp4;
  return {
    'index': 0,
    'codec_name': 'h264',
    'codec_long_name': 'H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10',
    'profile': 'High',
    'codec_type': 'video',
    'codec_tag_string': mp4 ? 'avc1' : '[0][0][0][0]',
    'width': 1280,
    'height': 720,
    'coded_width': 1280,
    'coded_height': 720,
    'display_aspect_ratio': '16:9',
    'pix_fmt': 'yuv420p',
    'level': mp4 ? 32 : 31,
    'field_order': 'progressive',
    'r_frame_rate': mp4 ? '50/1' : '25/1',
    'avg_frame_rate': mp4 ? '50/1' : '25/1',
    'time_base': mp4 ? '1/12800' : '1/1000',
    'disposition': {'default': 1, 'forced': 0},
    'tags': {'language': 'eng'},
  };
}

Map<String, Object?> _audioInfo(String file) {
  final mp4 = file == MockMedia.h264Aac720p50Mp4;
  return {
    'index': 1,
    'codec_name': 'aac',
    'codec_long_name': 'AAC (Advanced Audio Coding)',
    'profile': 'LC',
    'codec_type': 'audio',
    'sample_fmt': 'fltp',
    'sample_rate': '48000',
    'channels': 2,
    'channel_layout': 'stereo',
    'bits_per_sample': 0,
    'disposition': {'default': 1, 'forced': 0},
    'tags': {'language': mp4 ? 'und' : 'eng'},
  };
}

/// kbit/s of the generated files (about 3.1 / 3.0 Mbit/s).
int _bitrate(String file) => file == MockMedia.h264Aac720p50Mp4 ? 3143 : 3025;

/// Builds and caches the `player_api.php` responses.
final class XtreamApi {
  XtreamApi(this.catalog);

  final MockCatalog catalog;
  final _cache = <String, Uint8List>{};

  /// Drops cached bytes (e.g. when they grow past a few origins).
  void clearCache() => _cache.clear();

  Uint8List _cached(String key, Uint8List Function() build) {
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 48) _cache.clear();
    return _cache[key] = build();
  }

  /// Pre-encodes the big lists for [origin].
  void warmUp(String origin) {
    liveStreams(origin, null);
    vodStreams(origin, null);
    seriesList(origin, null);
  }

  ApiResponse handle({
    required MockAccount account,
    required String username,
    required String password,
    required String? action,
    required Map<String, String> params,
    required String origin,
    required Uri requestedUri,
    required DateTime now,
    bool emptySections = false,
  }) {
    if (account == MockAccount.invalid) return ApiResponse(401, _unauthorized);
    final html = action != null && htmlActions.contains(action);
    if (action == null || action.isEmpty) {
      return ApiResponse(
        200,
        _encode(accountJson(account, username, password, requestedUri, now)),
      );
    }
    if (account == MockAccount.expired) {
      return ApiResponse(200, _emptyList, html: html);
    }
    final categoryId = params['category_id'];
    final Uint8List body;
    switch (action) {
      case 'get_live_categories':
        body = emptySections
            ? _emptyList
            : _categories(catalog.liveCategories, 'live');
      case 'get_vod_categories':
        body = emptySections
            ? _emptyList
            : _categories(catalog.vodCategories, 'vod');
      case 'get_series_categories':
        body = emptySections
            ? _emptyList
            : _categories(catalog.seriesCategories, 'series');
      case 'get_live_streams':
        body = emptySections ? _emptyList : liveStreams(origin, categoryId);
      case 'get_vod_streams':
        body = emptySections ? _emptyList : vodStreams(origin, categoryId);
      case 'get_series':
        body = emptySections ? _emptyList : seriesList(origin, categoryId);
      case 'get_vod_info':
        body = _encode(vodInfo(origin, int.tryParse(params['vod_id'] ?? '')));
      case 'get_series_info':
        body = _encode(
          seriesInfo(origin, int.tryParse(params['series_id'] ?? '')),
        );
      case 'get_short_epg':
        final channel = catalog.channelById(
          int.tryParse(params['stream_id'] ?? '') ?? -1,
        );
        final limit = int.tryParse(params['limit'] ?? '') ?? 4;
        body = _encode(
          channel == null
              ? {'epg_listings': <Object?>[]}
              : shortEpgJson(catalog, channel, now: now, limit: limit),
        );
      case 'get_simple_data_table':
        final channel = catalog.channelById(
          int.tryParse(params['stream_id'] ?? '') ?? -1,
        );
        body = _encode(
          channel == null
              ? {'epg_listings': <Object?>[]}
              : simpleDataTableJson(catalog, channel, now: now),
        );
      default:
        body = _emptyList;
    }
    return ApiResponse(200, body, html: html);
  }

  // ---------------------------------------------------------------- account

  Map<String, Object?> accountJson(
    MockAccount account,
    String username,
    String password,
    Uri requestedUri,
    DateTime now,
  ) {
    final active = account == MockAccount.active;
    final expiry = active ? MockFixtures.expiresAt : MockFixtures.expiredAt;
    final nowMs = now.millisecondsSinceEpoch;
    return {
      'user_info': {
        'username': username,
        'password': password,
        'message': active
            ? 'Carina mock server: test account'
            : 'Your subscription has expired.',
        'auth': 1,
        'status': active ? 'Active' : 'Expired',
        'exp_date': '${_epochSeconds(expiry)}',
        'is_trial': '0',
        'active_cons': '0',
        'created_at': '${_epochSeconds(DateTime.utc(2025, 1, 1))}',
        'max_connections': '2',
        'allowed_output_formats': ['m3u8', 'ts'],
      },
      'server_info': {
        'xui': true,
        'version': '1.5.12',
        'revision': 2,
        'url': requestedUri.host,
        'port': '${requestedUri.port}',
        'https_port': '8443',
        'server_protocol': 'http',
        'rtmp_port': '8880',
        'timezone': MockFixtures.timezone,
        'timestamp_now': nowMs ~/ 1000,
        'time_now': serverTimeString(nowMs),
        'process': true,
      },
    };
  }

  // ------------------------------------------------------------- categories

  Uint8List _categories(List<MockCategory> categories, String kind) =>
      _cached('categories/$kind', () {
        return encodeJsonList<MockCategory>(
          categories,
          (c) => {
            'category_id': c.id,
            'category_name': c.name,
            'parent_id': c.parentId,
          },
        );
      });

  // ------------------------------------------------------------------- live

  Uint8List liveStreams(String origin, String? categoryId) => _cached(
    'live|$origin|${categoryId ?? '*'}',
    () {
      final items = categoryId == null
          ? catalog.channels
          : catalog.channels.where((c) => c.categoryId == categoryId);
      return encodeJsonList<MockChannel>(items, (c) => channelJson(c, origin));
    },
  );

  Map<String, Object?> channelJson(MockChannel c, String origin) {
    final Object? icon = c.logoPath == null
        ? (c.hasQuirk(ChannelQuirk.logoNull) ? null : '')
        : '$origin${c.logoPath}';
    final seconds = _epochSeconds(c.added);
    final Object added = c.hasQuirk(ChannelQuirk.addedAsInt)
        ? seconds
        : (c.hasQuirk(ChannelQuirk.addedEmpty) ? '' : '$seconds');
    final archive = c.archiveDays > 0 ? 1 : 0;
    final archiveAsString = c.hasQuirk(ChannelQuirk.archiveAsString);
    final categoryNumber = c.categoryId == null
        ? null
        : int.tryParse(c.categoryId!);
    return {
      'num': c.hasQuirk(ChannelQuirk.numAsString) ? '${c.num}' : c.num,
      'name': c.name,
      'stream_type': c.streamType,
      'stream_id': c.hasQuirk(ChannelQuirk.idAsString)
          ? '${c.streamId}'
          : c.streamId,
      'stream_icon': icon,
      'epg_channel_id': c.epgChannelId,
      'added': added,
      'is_adult': c.hasQuirk(ChannelQuirk.adultAsString) ? '0' : 0,
      'category_id': c.categoryId,
      if (!c.hasQuirk(ChannelQuirk.noCategoryIds))
        'category_ids': [?categoryNumber],
      'custom_sid': c.hasQuirk(ChannelQuirk.customSid)
          ? '1:0:19:${(c.streamId * 7919 % 0xFFFF).toRadixString(16).toUpperCase()}:7DC:1A:11A0000:0:0:0:'
          : (c.streamId.isEven ? '' : null),
      'tv_archive': archiveAsString ? '$archive' : archive,
      'direct_source': c.directSourcePath == null
          ? ''
          : '$origin${c.directSourcePath}',
      'tv_archive_duration': archiveAsString
          ? '${c.archiveDays}'
          : c.archiveDays,
      'thumbnail': '',
    };
  }

  // ----------------------------------------------------------------- movies

  Uint8List vodStreams(String origin, String? categoryId) =>
      _cached('vod|$origin|${categoryId ?? '*'}', () {
        final items = categoryId == null
            ? catalog.movies
            : catalog.movies.where((m) => m.categoryId == categoryId);
        return encodeJsonList<MockMovie>(items, (m) => movieJson(m, origin));
      });

  Object? _movieRating(MockMovie m) {
    if (m.hasQuirk(MovieQuirk.ratingNull)) return null;
    if (m.hasQuirk(MovieQuirk.ratingEmpty)) return '';
    if (m.hasQuirk(MovieQuirk.ratingNA)) return 'N/A';
    final rating = m.rating ?? 0;
    if (m.hasQuirk(MovieQuirk.ratingAsNumber)) {
      return rating == rating.roundToDouble() ? rating.round() : rating;
    }
    return rating.toStringAsFixed(1);
  }

  Object _rating5(double? rating, bool asString) {
    if (rating == null) return 0;
    final v = double.parse((rating / 2).toStringAsFixed(2));
    return asString ? v.toStringAsFixed(1) : v;
  }

  Map<String, Object?> movieJson(MockMovie m, String origin) {
    final Object? poster = m.posterPath == null
        ? (m.hasQuirk(MovieQuirk.posterNull) ? null : '')
        : '$origin${m.posterPath}';
    final categoryNumber = m.categoryId == null
        ? null
        : int.tryParse(m.categoryId!);
    return {
      'num': m.hasQuirk(MovieQuirk.numAsString) ? '${m.num}' : m.num,
      'name': m.name,
      'title': m.originalName,
      if (!m.hasQuirk(MovieQuirk.yearMissing))
        'year': m.hasQuirk(MovieQuirk.yearAsInt) ? m.year : '${m.year}',
      'stream_type': 'movie',
      'stream_id': m.streamId,
      'stream_icon': poster,
      'rating': _movieRating(m),
      'rating_5based': _rating5(
        m.rating,
        m.hasQuirk(MovieQuirk.rating5AsString),
      ),
      'added': '${_epochSeconds(m.added)}',
      'is_adult': 0,
      'category_id': m.categoryId,
      'category_ids': [?categoryNumber],
      'container_extension': m.containerExtension,
      'custom_sid': '',
      'direct_source': m.directSourcePath == null
          ? ''
          : '$origin${m.directSourcePath}',
      if (m.tmdbId != null)
        (m.hasQuirk(MovieQuirk.tmdbIdKey) ? 'tmdb_id' : 'tmdb'):
            m.hasQuirk(MovieQuirk.tmdbAsInt) ? m.tmdbId : '${m.tmdbId}'
      else
        'tmdb': '',
      'trailer': '',
    };
  }

  Map<String, Object?> vodInfo(String origin, int? id) {
    final m = id == null ? null : catalog.movieById(id);
    if (m == null) return {'info': <Object?>[], 'movie_data': <Object?>[]};
    final categoryNumber = m.categoryId == null
        ? null
        : int.tryParse(m.categoryId!);
    final movieData = {
      'stream_id': m.streamId,
      'name': m.name,
      'title': m.originalName,
      'year': '${m.year}',
      'added': '${_epochSeconds(m.added)}',
      'category_id': m.categoryId,
      'category_ids': [?categoryNumber],
      'container_extension': m.containerExtension,
      'custom_sid': '',
      'direct_source': m.directSourcePath == null
          ? ''
          : '$origin${m.directSourcePath}',
    };
    if (m.hasQuirk(MovieQuirk.infoEmpty)) {
      return {'info': <Object?>[], 'movie_data': movieData};
    }
    final r = MockRandom(m.seed);
    final poster = m.posterPath == null ? '' : '$origin${m.posterPath}';
    final plot = catalog.moviePlot(m);
    final release = DateTime.utc(
      m.year ?? 2020,
      r.range(1, 12),
      r.range(1, 28),
    );
    final file = m.mediaFile;
    final rating = m.rating;
    return {
      'info': {
        'kinopoisk_url': '',
        'tmdb_id': m.tmdbId ?? '',
        'name': m.name.isEmpty ? m.originalName : m.name,
        'o_name': m.originalName,
        'cover_big': poster,
        'movie_image': poster,
        'releasedate':
            '${release.year}-${release.month.toString().padLeft(2, '0')}-${release.day.toString().padLeft(2, '0')}',
        'episode_run_time': '${m.durationSecs ~/ 60}',
        'youtube_trailer': r.chance(0.3)
            ? 'mock${m.streamId.toRadixString(36)}'
            : '',
        'director': m.director,
        'actors': m.cast.join(', '),
        'cast': m.cast.join(', '),
        'description': plot,
        'plot': plot,
        'age': m.age,
        'mpaa_rating': switch (m.age) {
          '18+' => 'R',
          '16+' => 'R',
          '13+' => 'PG-13',
          '7+' => 'PG',
          _ => 'G',
        },
        'rating_count_kinopoisk': 0,
        'country': m.country,
        'genre': m.genre,
        'backdrop_path': [
          if (m.backdropPath != null) '$origin${m.backdropPath}',
        ],
        'duration_secs': m.durationSecs,
        'duration': _hms(m.durationSecs),
        'video': _videoInfo(file),
        'audio': _audioInfo(file),
        'bitrate': _bitrate(file),
        'rating': rating == null ? '' : rating.toStringAsFixed(1),
        'status': 'Released',
        'runtime': m.durationSecs ~/ 60,
      },
      'movie_data': movieData,
    };
  }

  // ----------------------------------------------------------------- series

  Uint8List seriesList(String origin, String? categoryId) =>
      _cached('series|$origin|${categoryId ?? '*'}', () {
        final items = categoryId == null
            ? catalog.series
            : catalog.series.where((s) => s.categoryId == categoryId);
        return encodeJsonList<MockSeries>(items, (s) => seriesJson(s, origin));
      });

  Map<String, Object?> seriesJson(
    MockSeries s,
    String origin, {
    bool forInfo = false,
  }) {
    final Object? cover = s.coverPath == null
        ? (s.hasQuirk(SeriesQuirk.coverNull) ? null : '')
        : '$origin${s.coverPath}';
    final Object? backdrops = s.hasQuirk(SeriesQuirk.backdropAsString)
        ? ''
        : s.hasQuirk(SeriesQuirk.backdropNull)
        ? null
        : [for (final b in s.backdropPaths) '$origin$b'];
    final rating = s.rating;
    final Object? ratingValue = s.hasQuirk(SeriesQuirk.ratingEmpty)
        ? ''
        : s.hasQuirk(SeriesQuirk.ratingAsNumber)
        ? rating
        : rating?.toStringAsFixed(1);
    final categoryNumber = s.categoryId == null
        ? null
        : int.tryParse(s.categoryId!);
    return {
      if (!forInfo) 'num': s.num,
      'name': s.name,
      'title': s.name,
      'year': '${s.year}',
      if (!forInfo) 'stream_type': 'series',
      if (!forInfo) 'series_id': s.seriesId,
      'cover': cover,
      'plot': s.hasQuirk(SeriesQuirk.plotEmpty) ? '' : s.plot,
      'cast': s.cast.join(', '),
      'director': s.director,
      'genre': s.genre,
      'release_date': s.releaseDate,
      'releaseDate': s.releaseDate,
      'last_modified': '${_epochSeconds(s.lastModified)}',
      'rating': ratingValue,
      'rating_5based': s.hasQuirk(SeriesQuirk.ratingEmpty)
          ? 0
          : _rating5(rating, false),
      'backdrop_path': backdrops,
      'youtube_trailer': '',
      'episode_run_time': s.hasQuirk(SeriesQuirk.runTimeAsInt)
          ? s.episodeRunTime
          : '${s.episodeRunTime}',
      'category_id': s.categoryId,
      'category_ids': [?categoryNumber],
      'tmdb': s.tmdbId == null ? '' : '${s.tmdbId}',
    };
  }

  Map<String, Object?> seriesInfo(String origin, int? id) {
    final s = id == null ? null : catalog.seriesById(id);
    if (s == null) {
      return {
        'seasons': <Object?>[],
        'info': <Object?>[],
        'episodes': <Object?>[],
      };
    }
    final cover = s.coverPath == null ? '' : '$origin${s.coverPath}';
    final tr = s.lang == 'tr';
    final seasons = <Map<String, Object?>>[];
    if (!s.hasQuirk(SeriesQuirk.seasonsEmpty)) {
      for (final season in s.seasons) {
        seasons.add({
          'air_date': season.airDate,
          'episode_count': season.episodeCount,
          'id': mixHash(s.seriesId, season.number) & 0xFFFFF,
          'name': season.number == 0
              ? (tr ? 'Özel Bölümler' : 'Specials')
              : (tr ? 'Sezon ${season.number}' : 'Season ${season.number}'),
          'overview': '',
          'season_number': season.number,
          'vote_average': 0,
          'cover': cover,
          'cover_big': cover,
        });
      }
      if (s.hasQuirk(SeriesQuirk.seasonsExtra)) {
        final next = s.seasons.last.number + 1;
        seasons.add({
          'air_date': '${DateTime.now().year + 1}-01-01',
          'episode_count': 8,
          'id': mixHash(s.seriesId, next) & 0xFFFFF,
          'name': tr ? 'Sezon $next' : 'Season $next',
          'overview': '',
          'season_number': next,
          'vote_average': 0,
          'cover': cover,
          'cover_big': cover,
        });
      }
    }
    final bySeason = <int, List<Map<String, Object?>>>{};
    final episodes = catalog.episodesOf(s);
    final episodeNumAsString = s.seed.isOdd;
    for (var i = 0; i < episodes.length; i++) {
      final e = episodes[i];
      final title = catalog.episodeTitle(e);
      final secs = catalog.episodeDurationSecs(e);
      final added = s.lastModified.subtract(
        Duration(days: (episodes.length - 1 - i) * 7),
      );
      (bySeason[e.season] ??= []).add({
        'id': '${e.id}',
        'episode_num': episodeNumAsString ? '${e.episode}' : e.episode,
        'title': title,
        'container_extension': e.containerExtension,
        'info': {
          'tmdb_id': s.tmdbId == null ? '' : s.tmdbId! * 10 + i,
          'releasedate': catalog.episodeAirDate(e),
          'plot': catalog.episodePlot(e),
          'duration_secs': secs,
          'duration': _hms(secs),
          'movie_image': '$origin${catalog.episodeStillPath(e)}',
          'bitrate': _bitrate(e.mediaFile),
          'rating': catalog.episodeRating(e),
          'season': '${e.season}',
          'name': title,
          'video': _videoInfo(e.mediaFile),
          'audio': _audioInfo(e.mediaFile),
        },
        'custom_sid': '',
        'added': '${_epochSeconds(added)}',
        'season': e.season,
        'direct_source': '',
      });
    }
    final Object episodesValue;
    if (s.shape == EpisodesShape.map) {
      episodesValue = {
        for (final entry in bySeason.entries) '${entry.key}': entry.value,
      };
    } else {
      final keys = bySeason.keys.toList()..sort();
      episodesValue = [for (final k in keys) bySeason[k]!];
    }
    return {
      'seasons': seasons,
      'info': seriesJson(s, origin, forInfo: true),
      'episodes': episodesValue,
    };
  }
}
