/// Xtream Codes API DTOs.
///
/// Every parser accepts any JSON value: wrong types, `null`, `""`, `"null"`
/// and PHP empty arrays (`[]` where an object is expected) are normalized
/// and never throw. Row parsers (`fromJson` returning a nullable value)
/// return null for rows that cannot be used — not a map, or without their id
/// — and `listFromJson` skips them.
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'json_utils.dart';

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

/// Account statuses that make [XtreamAccount.isActive] false.
const Set<String> xtreamInactiveStatuses = {
  'expired',
  'banned',
  'disabled',
  'inactive',
  'suspended',
  'blocked',
};

/// `user_info` of the account call.
class XtreamUserInfo {
  const XtreamUserInfo({
    this.auth = false,
    this.username,
    this.status,
    this.expDate,
    this.isTrial = false,
    this.activeCons,
    this.maxConnections,
    this.allowedOutputFormats = const [],
    this.createdAt,
    this.message,
  });

  factory XtreamUserInfo.fromJson(Object? json) {
    final j = asMap(json);
    final status = asString(j['status']);
    return XtreamUserInfo(
      // A panel that omits `auth` but reports a status did authenticate.
      auth: asBool(j['auth']) ?? status != null,
      username: asString(j['username']),
      status: status,
      expDate: asDateFromEpoch(j['exp_date']),
      isTrial: asBool(j['is_trial']) ?? false,
      activeCons: asInt(j['active_cons']),
      maxConnections: asInt(j['max_connections']),
      allowedOutputFormats: List.unmodifiable(
        asStringList(j['allowed_output_formats'])
            .map((f) => f.toLowerCase())
            .toSet(),
      ),
      createdAt: asDateFromEpoch(j['created_at']),
      message: asString(j['message']),
    );
  }

  final bool auth;
  final String? username;

  /// As delivered: `Active`, `Expired`, `Banned`, `Disabled`…
  final String? status;

  /// Null = never expires.
  final DateTime? expDate;
  final bool isTrial;
  final int? activeCons;
  final int? maxConnections;

  /// Lowercased, e.g. `[m3u8, ts, rtmp]`.
  final List<String> allowedOutputFormats;
  final DateTime? createdAt;

  /// Panel message of the day.
  final String? message;

  /// JSON in the provider's shape, without the password (safe to store).
  Map<String, Object?> toJson() => {
    'auth': auth ? 1 : 0,
    'username': username,
    'status': status,
    'exp_date': _epochSeconds(expDate),
    'is_trial': isTrial ? '1' : '0',
    'active_cons': activeCons,
    'max_connections': maxConnections,
    'allowed_output_formats': allowedOutputFormats,
    'created_at': _epochSeconds(createdAt),
    'message': message,
  };
}

/// `server_info` of the account call.
class XtreamServerInfo {
  const XtreamServerInfo({
    this.url,
    this.port,
    this.httpsPort,
    this.serverProtocol,
    this.rtmpPort,
    this.timezone,
    this.timestampNow,
    this.timeNow,
  });

  factory XtreamServerInfo.fromJson(Object? json) {
    final j = asMap(json);
    var timestamp = asInt(j['timestamp_now']);
    if (timestamp != null && timestamp >= 100000000000) {
      timestamp ~/= 1000; // milliseconds
    }
    return XtreamServerInfo(
      url: asString(j['url']),
      port: asInt(j['port']),
      httpsPort: asInt(j['https_port']),
      serverProtocol: asString(j['server_protocol'])?.toLowerCase(),
      rtmpPort: asInt(j['rtmp_port']),
      timezone: asString(j['timezone']),
      timestampNow: timestamp,
      timeNow: asString(j['time_now']),
    );
  }

  final String? url;
  final int? port;
  final int? httpsPort;

  /// `http` or `https`.
  final String? serverProtocol;
  final int? rtmpPort;

  /// IANA name as reported, e.g. `Europe/Istanbul` (informational only).
  final String? timezone;

  /// Server clock as Unix seconds (UTC).
  final int? timestampNow;

  /// Server wall clock, `YYYY-MM-DD HH:MM:SS` in the server timezone.
  final String? timeNow;

  Map<String, Object?> toJson() => {
    'url': url,
    'port': port,
    'https_port': httpsPort,
    'server_protocol': serverProtocol,
    'rtmp_port': rtmpPort,
    'timezone': timezone,
    'timestamp_now': timestampNow,
    'time_now': timeNow,
  };
}

/// Result of `player_api.php` without an action.
class XtreamAccount {
  XtreamAccount({required this.userInfo, required this.serverInfo})
    : serverUtcOffset = xtreamServerUtcOffset(
        timestampNow: serverInfo.timestampNow,
        timeNow: serverInfo.timeNow,
      );

  factory XtreamAccount.fromJson(Object? json) {
    final j = asMap(json);
    return XtreamAccount(
      userInfo: XtreamUserInfo.fromJson(j['user_info']),
      serverInfo: XtreamServerInfo.fromJson(j['server_info']),
    );
  }

  final XtreamUserInfo userInfo;
  final XtreamServerInfo serverInfo;

  /// Offset of the server's wall clock from UTC: `time_now − timestamp_now`
  /// rounded to the nearest 15 minutes (zero when unknown). Used to build
  /// catch-up URLs and to read EPG times without timestamps.
  final Duration serverUtcOffset;

  /// `auth` is set and the status is not Expired/Banned/Disabled (see
  /// [xtreamInactiveStatuses]). A missing status counts as active.
  bool get isActive =>
      userInfo.auth &&
      !xtreamInactiveStatuses.contains(userInfo.status?.toLowerCase());

  String? get status => userInfo.status;
  DateTime? get expDate => userInfo.expDate;
  int? get maxConnections => userInfo.maxConnections;
  int? get activeCons => userInfo.activeCons;
  List<String> get allowedOutputFormats => userInfo.allowedOutputFormats;

  /// Provider-shaped JSON without the password; [XtreamAccount.fromJson]
  /// reads it back.
  Map<String, Object?> toJson() => {
    'user_info': userInfo.toJson(),
    'server_info': serverInfo.toJson(),
  };
}

const int _quarterHourSeconds = 15 * 60;
const int _maxOffsetSeconds = 14 * 3600;

/// `time_now` (server wall clock) minus `timestamp_now` (UTC), rounded to
/// the nearest 15 minutes. Zero when either value is missing or unparseable,
/// or when the result is beyond ±14 h (a broken clock).
Duration xtreamServerUtcOffset({int? timestampNow, String? timeNow}) {
  if (timestampNow == null || timestampNow <= 0 || timeNow == null) {
    return Duration.zero;
  }
  final wallClock = asDate(timeNow);
  if (wallClock == null) return Duration.zero;
  final utc = DateTime.fromMillisecondsSinceEpoch(
    timestampNow * 1000,
    isUtc: true,
  );
  final seconds = wallClock.difference(utc).inSeconds;
  final rounded = (seconds / _quarterHourSeconds).round() * _quarterHourSeconds;
  if (rounded.abs() > _maxOffsetSeconds) return Duration.zero;
  return Duration(seconds: rounded);
}

// ---------------------------------------------------------------------------
// Categories and catalog rows
// ---------------------------------------------------------------------------

/// `get_live_categories` / `get_vod_categories` / `get_series_categories`.
class XtreamCategory {
  const XtreamCategory({
    required this.categoryId,
    required this.categoryName,
    this.parentId,
  });

  /// Null without `category_id`. A missing name falls back to the id; a
  /// `parent_id` of 0 becomes null.
  static XtreamCategory? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = asId(json['category_id']);
    if (id == null) return null;
    final parent = asId(json['parent_id']);
    return XtreamCategory(
      categoryId: id,
      categoryName: asString(json['category_name']) ?? id,
      parentId: parent == '0' ? null : parent,
    );
  }

  static List<XtreamCategory> listFromJson(Object? json) =>
      _rows(json, fromJson);

  final String categoryId;
  final String categoryName;
  final String? parentId;
}

/// `get_live_streams` row.
class XtreamLiveStream {
  const XtreamLiveStream({
    required this.streamId,
    required this.name,
    this.num,
    this.streamType,
    this.streamIcon,
    this.epgChannelId,
    this.added,
    this.categoryId,
    this.categoryIds = const [],
    this.tvArchive = false,
    this.tvArchiveDuration = 0,
    this.directSource,
    this.customSid,
    this.isAdult = false,
  });

  /// Null without `stream_id`.
  static XtreamLiveStream? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = asId(json['stream_id']);
    if (id == null) return null;
    final categoryId = asId(json['category_id']);
    return XtreamLiveStream(
      streamId: id,
      name: asString(json['name']) ?? '',
      num: asInt(json['num']),
      streamType: asString(json['stream_type']),
      streamIcon: asString(json['stream_icon']),
      epgChannelId: asString(json['epg_channel_id']),
      added: asDateFromEpoch(json['added']),
      categoryId: categoryId,
      categoryIds: _categoryIds(json['category_ids'], categoryId),
      tvArchive: asBool(json['tv_archive']) ?? false,
      tvArchiveDuration: math.max(0, asInt(json['tv_archive_duration']) ?? 0),
      directSource: asString(json['direct_source']),
      customSid: asString(json['custom_sid']),
      isAdult: asBool(json['is_adult']) ?? false,
    );
  }

  static List<XtreamLiveStream> listFromJson(Object? json) =>
      _rows(json, fromJson);

  final String streamId;

  /// As delivered (quality tokens included); `''` when missing.
  final String name;
  final int? num;

  /// `live`, `radio_streams`, `created_live`…
  final String? streamType;
  final String? streamIcon;
  final String? epgChannelId;
  final DateTime? added;
  final String? categoryId;

  /// `category_ids`, always containing [categoryId] first when it is set.
  final List<String> categoryIds;
  final bool tvArchive;

  /// Archive window in days as delivered.
  final int tvArchiveDuration;
  final String? directSource;
  final String? customSid;
  final bool isAdult;

  /// Catch-up window in days: [tvArchiveDuration] when [tvArchive], else 0.
  int get archiveDays => tvArchive ? tvArchiveDuration : 0;

  XtreamLiveStream copyWith({List<String>? categoryIds}) => XtreamLiveStream(
    streamId: streamId,
    name: name,
    num: num,
    streamType: streamType,
    streamIcon: streamIcon,
    epgChannelId: epgChannelId,
    added: added,
    categoryId: categoryId,
    categoryIds: categoryIds ?? this.categoryIds,
    tvArchive: tvArchive,
    tvArchiveDuration: tvArchiveDuration,
    directSource: directSource,
    customSid: customSid,
    isAdult: isAdult,
  );
}

/// `get_vod_streams` row.
class XtreamVodStream {
  const XtreamVodStream({
    required this.streamId,
    required this.name,
    this.num,
    this.streamIcon,
    this.rating,
    this.rating5Based,
    this.added,
    this.categoryId,
    this.categoryIds = const [],
    this.containerExtension,
    this.tmdbId,
    this.year,
    this.directSource,
    this.customSid,
    this.isAdult = false,
  });

  /// Null without `stream_id`.
  static XtreamVodStream? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = asId(json['stream_id']);
    if (id == null) return null;
    final categoryId = asId(json['category_id']);
    final rating5 = _rating(json['rating_5based'], max: 5);
    return XtreamVodStream(
      streamId: id,
      name: asString(json['name']) ?? asString(json['title']) ?? '',
      num: asInt(json['num']),
      streamIcon: asString(json['stream_icon']),
      rating: _rating(json['rating']) ?? (rating5 == null ? null : rating5 * 2),
      rating5Based: rating5,
      added: asDateFromEpoch(json['added']),
      categoryId: categoryId,
      categoryIds: _categoryIds(json['category_ids'], categoryId),
      containerExtension: _extension(json['container_extension']),
      tmdbId: asPositiveInt(json['tmdb']) ?? asPositiveInt(json['tmdb_id']),
      year:
          asYear(json['year']) ??
          asYear(
            json['releaseDate'] ?? json['releasedate'] ?? json['release_date'],
          ),
      directSource: asString(json['direct_source']),
      customSid: asString(json['custom_sid']),
      isAdult: asBool(json['is_adult']) ?? false,
    );
  }

  static List<XtreamVodStream> listFromJson(Object? json) =>
      _rows(json, fromJson);

  final String streamId;
  final String name;
  final int? num;
  final String? streamIcon;

  /// 0–10; derived from [rating5Based] when `rating` is missing. Zero and
  /// out-of-range values (meaning "unknown") are null.
  final double? rating;
  final double? rating5Based;
  final DateTime? added;
  final String? categoryId;
  final List<String> categoryIds;

  /// Without a leading dot, e.g. `mkv`.
  final String? containerExtension;
  final int? tmdbId;
  final int? year;
  final String? directSource;
  final String? customSid;
  final bool isAdult;
}

/// `get_series` row, also used for `get_series_info.info`.
class XtreamSeries {
  const XtreamSeries({
    required this.seriesId,
    required this.name,
    this.num,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.year,
    this.lastModified,
    this.rating,
    this.rating5Based,
    this.backdrops = const [],
    this.youtubeTrailer,
    this.episodeRunTime,
    this.tmdbId,
    this.categoryId,
    this.categoryIds = const [],
  });

  /// Null when neither `series_id` nor [fallbackId] is available.
  static XtreamSeries? fromJson(Object? json, {String? fallbackId}) {
    if (json is! Map) return null;
    final id = asId(json['series_id']) ?? fallbackId;
    if (id == null) return null;
    final categoryId = asId(json['category_id']);
    final rating5 = _rating(json['rating_5based'], max: 5);
    final releaseDate = asString(
      json['releaseDate'] ?? json['release_date'] ?? json['releasedate'],
    );
    return XtreamSeries(
      seriesId: id,
      name: asString(json['name']) ?? asString(json['title']) ?? '',
      num: asInt(json['num']),
      cover: asString(json['cover']) ?? asString(json['cover_big']),
      plot: asString(json['plot']) ?? asString(json['description']),
      cast: asString(json['cast']) ?? asString(json['actors']),
      director: asString(json['director']),
      genre: asString(json['genre']),
      releaseDate: releaseDate,
      year: asYear(json['year']) ?? asYear(releaseDate),
      lastModified: asDateFromEpoch(json['last_modified']),
      rating: _rating(json['rating']) ?? (rating5 == null ? null : rating5 * 2),
      rating5Based: rating5,
      backdrops: _backdrops(json['backdrop_path']),
      youtubeTrailer: asString(json['youtube_trailer']),
      episodeRunTime: asPositiveInt(json['episode_run_time']),
      tmdbId: asPositiveInt(json['tmdb']) ?? asPositiveInt(json['tmdb_id']),
      categoryId: categoryId,
      categoryIds: _categoryIds(json['category_ids'], categoryId),
    );
  }

  static List<XtreamSeries> listFromJson(Object? json) => _rows(json, fromJson);

  final String seriesId;
  final String name;
  final int? num;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;

  /// Raw release date text (`2008-01-20`, `2008`…); see [releaseDateParsed].
  final String? releaseDate;
  final int? year;
  final DateTime? lastModified;

  /// 0–10 (see [XtreamVodStream.rating]).
  final double? rating;
  final double? rating5Based;
  final List<String> backdrops;
  final String? youtubeTrailer;

  /// Minutes.
  final int? episodeRunTime;
  final int? tmdbId;
  final String? categoryId;
  final List<String> categoryIds;

  DateTime? get releaseDateParsed => asDate(releaseDate);
}

// ---------------------------------------------------------------------------
// VOD info
// ---------------------------------------------------------------------------

/// ffprobe-style `video` block of `get_vod_info` / episode info.
class XtreamVideoInfo {
  const XtreamVideoInfo({
    this.codecName,
    this.codecLongName,
    this.profile,
    this.width,
    this.height,
    this.displayAspectRatio,
    this.pixFmt,
    this.fieldOrder,
    this.colorTransfer,
    this.frameRate,
    this.bitRate,
    this.language,
  });

  /// Null when the block is missing or empty.
  static XtreamVideoInfo? fromJson(Object? json) {
    if (json is! Map || json.isEmpty) return null;
    final tags = asMap(json['tags']);
    return XtreamVideoInfo(
      codecName: asString(json['codec_name']),
      codecLongName: asString(json['codec_long_name']),
      profile: asString(json['profile']),
      width: asPositiveInt(json['width']),
      height: asPositiveInt(json['height']),
      displayAspectRatio: asString(json['display_aspect_ratio']),
      pixFmt: asString(json['pix_fmt']),
      fieldOrder: asString(json['field_order']),
      colorTransfer: asString(json['color_transfer']),
      frameRate:
          _fraction(json['avg_frame_rate']) ?? _fraction(json['r_frame_rate']),
      bitRate:
          asPositiveInt(json['bit_rate']) ??
          asPositiveInt(tags['BPS']) ??
          asPositiveInt(tags['BPS-eng']),
      language: asString(tags['language']),
    );
  }

  final String? codecName;
  final String? codecLongName;
  final String? profile;
  final int? width;
  final int? height;
  final String? displayAspectRatio;
  final String? pixFmt;

  /// `progressive`, `tt`, `bb`…
  final String? fieldOrder;

  /// `smpte2084` (PQ) / `arib-std-b67` (HLG) mean HDR.
  final String? colorTransfer;

  /// Frames per second from `avg_frame_rate` / `r_frame_rate` (`25/1`).
  final double? frameRate;

  /// Bits per second.
  final int? bitRate;
  final String? language;
}

/// ffprobe-style `audio` block of `get_vod_info` / episode info.
class XtreamAudioInfo {
  const XtreamAudioInfo({
    this.codecName,
    this.codecLongName,
    this.profile,
    this.channels,
    this.channelLayout,
    this.sampleRate,
    this.bitRate,
    this.language,
  });

  /// Null when the block is missing or empty.
  static XtreamAudioInfo? fromJson(Object? json) {
    if (json is! Map || json.isEmpty) return null;
    final tags = asMap(json['tags']);
    return XtreamAudioInfo(
      codecName: asString(json['codec_name']),
      codecLongName: asString(json['codec_long_name']),
      profile: asString(json['profile']),
      channels: asPositiveInt(json['channels']),
      channelLayout: asString(json['channel_layout']),
      sampleRate: asPositiveInt(json['sample_rate']),
      bitRate:
          asPositiveInt(json['bit_rate']) ??
          asPositiveInt(tags['BPS']) ??
          asPositiveInt(tags['BPS-eng']),
      language: asString(tags['language']),
    );
  }

  final String? codecName;
  final String? codecLongName;
  final String? profile;
  final int? channels;

  /// `stereo`, `5.1(side)`…
  final String? channelLayout;
  final int? sampleRate;

  /// Bits per second.
  final int? bitRate;
  final String? language;
}

/// `get_vod_info&vod_id=` (`info` + `movie_data`).
class XtreamVodInfo {
  const XtreamVodInfo({
    this.streamId,
    this.tmdbId,
    this.name,
    this.originalName,
    this.coverBig,
    this.movieImage,
    this.backdrops = const [],
    this.releaseDate,
    this.year,
    this.youtubeTrailer,
    this.director,
    this.actors,
    this.cast,
    this.description,
    this.plot,
    this.genre,
    this.age,
    this.mpaaRating,
    this.country,
    this.durationSecs,
    this.duration,
    this.rating,
    this.video,
    this.audio,
    this.bitrate,
    this.containerExtension,
    this.added,
    this.categoryId,
    this.categoryIds = const [],
    this.directSource,
    this.customSid,
  });

  /// Never throws; [vodId] is used when `movie_data.stream_id` is missing.
  factory XtreamVodInfo.fromJson(Object? json, {String? vodId}) {
    final root = asMap(json);
    final info = asMap(root['info']);
    final data = asMap(root['movie_data']);
    final categoryId = asId(data['category_id']);
    final releaseDate = asString(
      info['releasedate'] ?? info['release_date'] ?? info['releaseDate'],
    );
    final rating5 = _rating(info['rating_5based'], max: 5);
    return XtreamVodInfo(
      streamId: asId(data['stream_id']) ?? vodId,
      tmdbId: asPositiveInt(info['tmdb_id']) ?? asPositiveInt(info['tmdb']),
      name: asString(info['name']) ?? asString(data['name']),
      originalName: asString(info['o_name']),
      coverBig: asString(info['cover_big']),
      movieImage: asString(info['movie_image']),
      backdrops: _backdrops(info['backdrop_path']),
      releaseDate: releaseDate,
      year: asYear(info['year']) ?? asYear(releaseDate),
      youtubeTrailer: asString(info['youtube_trailer']),
      director: asString(info['director']),
      actors: asString(info['actors']),
      cast: asString(info['cast']),
      description: asString(info['description']),
      plot: asString(info['plot']),
      genre: asString(info['genre']),
      age: asString(info['age']),
      mpaaRating: asString(info['mpaa_rating']) ?? asString(info['mpaa']),
      country: asString(info['country']),
      durationSecs:
          asDurationSecs(info['duration_secs']) ??
          asDurationSecs(info['duration']),
      duration: asString(info['duration']),
      rating: _rating(info['rating']) ?? (rating5 == null ? null : rating5 * 2),
      video: XtreamVideoInfo.fromJson(info['video']),
      audio: XtreamAudioInfo.fromJson(info['audio']),
      bitrate: asPositiveInt(info['bitrate']),
      containerExtension: _extension(data['container_extension']),
      added: asDateFromEpoch(data['added']),
      categoryId: categoryId,
      categoryIds: _categoryIds(data['category_ids'], categoryId),
      directSource: asString(data['direct_source']),
      customSid: asString(data['custom_sid']),
    );
  }

  /// `movie_data.stream_id` (or the requested id).
  final String? streamId;
  final int? tmdbId;
  final String? name;

  /// `o_name`.
  final String? originalName;
  final String? coverBig;
  final String? movieImage;
  final List<String> backdrops;

  /// Raw `releasedate` text.
  final String? releaseDate;
  final int? year;
  final String? youtubeTrailer;
  final String? director;
  final String? actors;
  final String? cast;
  final String? description;
  final String? plot;
  final String? genre;
  final String? age;
  final String? mpaaRating;
  final String? country;
  final int? durationSecs;

  /// Raw `duration` text, e.g. `01:52:30`.
  final String? duration;

  /// 0–10 (see [XtreamVodStream.rating]).
  final double? rating;
  final XtreamVideoInfo? video;
  final XtreamAudioInfo? audio;

  /// kbit/s as delivered.
  final int? bitrate;
  final String? containerExtension;
  final DateTime? added;
  final String? categoryId;
  final List<String> categoryIds;
  final String? directSource;
  final String? customSid;

  /// `description`, else `plot`.
  String? get overview => description ?? plot;

  /// `actors`, else `cast`.
  String? get castText => actors ?? cast;

  /// `mpaa_rating`, else `age`.
  String? get ageRating => mpaaRating ?? age;

  DateTime? get releaseDateParsed => asDate(releaseDate);

  /// True when the panel returned nothing useful (unknown id).
  bool get isEmpty =>
      name == null &&
      containerExtension == null &&
      overview == null &&
      coverBig == null &&
      movieImage == null;
}

// ---------------------------------------------------------------------------
// Series info
// ---------------------------------------------------------------------------

/// `get_series_info.seasons[]`.
class XtreamSeason {
  const XtreamSeason({
    required this.seasonNumber,
    this.id,
    this.name,
    this.cover,
    this.coverBig,
    this.airDate,
    this.episodeCount,
    this.overview,
    this.voteAverage,
  });

  /// Null without `season_number`.
  static XtreamSeason? fromJson(Object? json) {
    if (json is! Map) return null;
    final number = asInt(json['season_number']);
    if (number == null) return null;
    return XtreamSeason(
      seasonNumber: number,
      id: asId(json['id']),
      name: asString(json['name']),
      cover: asString(json['cover']) ?? asString(json['cover_big']),
      coverBig: asString(json['cover_big']),
      airDate: asString(json['air_date']),
      episodeCount: asInt(json['episode_count']),
      overview: asString(json['overview']),
      voteAverage: asDouble(json['vote_average']),
    );
  }

  final int seasonNumber;
  final String? id;
  final String? name;
  final String? cover;
  final String? coverBig;

  /// Raw `air_date` text.
  final String? airDate;
  final int? episodeCount;
  final String? overview;
  final double? voteAverage;
}

/// `get_series_info.episodes[season][]`.
class XtreamEpisode {
  const XtreamEpisode({
    required this.id,
    required this.episodeNum,
    required this.season,
    required this.title,
    this.seriesId,
    this.containerExtension,
    this.added,
    this.customSid,
    this.directSource,
    this.movieImage,
    this.plot,
    this.durationSecs,
    this.duration,
    this.releaseDate,
    this.rating,
    this.bitrate,
    this.tmdbId,
    this.video,
    this.audio,
  });

  /// Null without `id`.
  ///
  /// [season] (the key the episode was grouped under) wins over the
  /// episode's own `season`; [fallbackSeason] is used when neither exists.
  /// [fallbackEpisodeNum] (the position in its list) replaces a missing
  /// `episode_num`.
  static XtreamEpisode? fromJson(
    Object? json, {
    int? season,
    int fallbackSeason = 1,
    int? fallbackEpisodeNum,
    String? seriesId,
  }) {
    if (json is! Map) return null;
    final id = asId(json['id']) ?? asId(json['stream_id']);
    if (id == null) return null;
    final info = asMap(json['info']);
    return XtreamEpisode(
      id: id,
      seriesId: seriesId,
      episodeNum: asInt(json['episode_num']) ?? fallbackEpisodeNum ?? 0,
      season: season ?? asInt(json['season']) ?? fallbackSeason,
      title: asString(json['title']) ?? asString(info['name']) ?? '',
      containerExtension: _extension(json['container_extension']),
      added: asDateFromEpoch(json['added']),
      customSid: asString(json['custom_sid']),
      directSource: asString(json['direct_source']),
      movieImage: asString(info['movie_image']) ?? asString(info['cover_big']),
      plot: asString(info['plot']) ?? asString(info['description']),
      durationSecs:
          asDurationSecs(info['duration_secs']) ??
          asDurationSecs(info['duration']),
      duration: asString(info['duration']),
      releaseDate: asString(
        info['releasedate'] ?? info['release_date'] ?? info['air_date'],
      ),
      rating: _rating(info['rating']),
      bitrate: asPositiveInt(info['bitrate']),
      tmdbId: asPositiveInt(info['tmdb_id']),
      video: XtreamVideoInfo.fromJson(info['video']),
      audio: XtreamAudioInfo.fromJson(info['audio']),
    );
  }

  final String id;

  /// Set by [XtreamSeriesInfo.fromJson] from the requested series id.
  final String? seriesId;
  final int episodeNum;
  final int season;

  /// `''` when missing.
  final String title;
  final String? containerExtension;
  final DateTime? added;
  final String? customSid;
  final String? directSource;
  final String? movieImage;
  final String? plot;
  final int? durationSecs;
  final String? duration;

  /// Raw release date text.
  final String? releaseDate;

  /// 0–10.
  final double? rating;
  final int? bitrate;
  final int? tmdbId;
  final XtreamVideoInfo? video;
  final XtreamAudioInfo? audio;
}

/// `get_series_info&series_id=`.
class XtreamSeriesInfo {
  const XtreamSeriesInfo({
    this.seasons = const [],
    this.info,
    this.episodes = const {},
  });

  /// Never throws. `episodes` may be a map keyed by season (`{"1": [...]}`),
  /// a list of per-season lists, or a flat list of episodes with a `season`
  /// field; all three produce the same [episodes] map.
  factory XtreamSeriesInfo.fromJson(Object? json, {String? seriesId}) {
    final root = asMap(json);
    final seasons = _rows(root['seasons'], XtreamSeason.fromJson)
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    return XtreamSeriesInfo(
      seasons: List.unmodifiable(seasons),
      info: XtreamSeries.fromJson(root['info'], fallbackId: seriesId ?? ''),
      episodes: _parseEpisodes(root['episodes'], seriesId),
    );
  }

  /// Sorted by season number.
  final List<XtreamSeason> seasons;
  final XtreamSeries? info;

  /// Season number → episodes, seasons ascending, episodes by number.
  final Map<int, List<XtreamEpisode>> episodes;

  /// Season numbers present in [seasons] or [episodes], ascending.
  List<int> get seasonNumbers =>
      {...seasons.map((s) => s.seasonNumber), ...episodes.keys}.toList()
        ..sort();

  static Map<int, List<XtreamEpisode>> _parseEpisodes(
    Object? raw,
    String? seriesId,
  ) {
    final groups = <int, List<XtreamEpisode>>{};

    void addRows(Iterable<Object?> rows, {int? season, int fallback = 1}) {
      var position = 0;
      for (final row in rows) {
        position++;
        final episode = XtreamEpisode.fromJson(
          row,
          season: season,
          fallbackSeason: fallback,
          fallbackEpisodeNum: position,
          seriesId: seriesId,
        );
        if (episode != null) (groups[episode.season] ??= []).add(episode);
      }
    }

    bool isContainer(Object? v) =>
        v is List ||
        (v is Map &&
            !v.containsKey('id') &&
            v.isNotEmpty &&
            v.values.every((e) => e is Map));

    if (raw is Map) {
      raw.forEach((key, value) {
        final season = asInt(key);
        addRows(asList(value), season: season, fallback: season ?? 1);
      });
    } else if (raw is List) {
      final flat = <Object?>[];
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (isContainer(item)) {
          addRows(asList(item), fallback: i + 1);
        } else {
          flat.add(item);
        }
      }
      addRows(flat);
    }

    final result = <int, List<XtreamEpisode>>{};
    for (final season in groups.keys.toList()..sort()) {
      final list = groups[season]!;
      mergeSort(list, compare: (a, b) => a.episodeNum.compareTo(b.episodeNum));
      result[season] = List.unmodifiable(list);
    }
    return Map.unmodifiable(result);
  }
}

// ---------------------------------------------------------------------------
// EPG
// ---------------------------------------------------------------------------

/// `get_short_epg` / `get_simple_data_table` listing.
class XtreamEpgListing {
  const XtreamEpgListing({
    required this.start,
    required this.stop,
    required this.title,
    this.id,
    this.epgId,
    this.description,
    this.lang,
    this.channelId,
    this.streamId,
    this.nowPlaying = false,
    this.hasArchive = false,
  });

  /// Null without a usable start/stop (or when stop is not after start).
  ///
  /// Times come from `start_timestamp` / `stop_timestamp` (UTC). When those
  /// are missing, `start` / `end` (server wall clock) are converted with
  /// [serverOffset]. `title` and `description` are base64 on most panels;
  /// plain text is kept as it is.
  static XtreamEpgListing? fromJson(
    Object? json, {
    Duration serverOffset = Duration.zero,
  }) {
    if (json is! Map) return null;
    final start =
        asDateFromEpoch(json['start_timestamp']) ??
        asDate(json['start'])?.subtract(serverOffset);
    final stop =
        asDateFromEpoch(json['stop_timestamp'] ?? json['end_timestamp']) ??
        asDate(json['end'] ?? json['stop'])?.subtract(serverOffset);
    if (start == null || stop == null || !stop.isAfter(start)) return null;
    return XtreamEpgListing(
      start: start,
      stop: stop,
      title: decodeMaybeBase64(asString(json['title'])) ?? '',
      description: _nonEmpty(decodeMaybeBase64(asString(json['description']))),
      id: asId(json['id']),
      epgId: asId(json['epg_id']),
      lang: asString(json['lang']),
      channelId: asString(json['channel_id']),
      streamId: asId(json['stream_id']),
      nowPlaying: asBool(json['now_playing']) ?? false,
      hasArchive: asBool(json['has_archive']) ?? false,
    );
  }

  /// Accepts `{"epg_listings": [...]}` or a bare list; sorted by start.
  static List<XtreamEpgListing> listFromJson(
    Object? json, {
    Duration serverOffset = Duration.zero,
  }) {
    final rows = json is Map && json.containsKey('epg_listings')
        ? json['epg_listings']
        : json;
    final listings = _rows(
      rows,
      (row) => fromJson(row, serverOffset: serverOffset),
    );
    mergeSort(listings, compare: (a, b) => a.start.compareTo(b.start));
    return listings;
  }

  /// UTC.
  final DateTime start;

  /// UTC.
  final DateTime stop;
  final String title;
  final String? description;
  final String? id;
  final String? epgId;
  final String? lang;
  final String? channelId;
  final String? streamId;
  final bool nowPlaying;
  final bool hasArchive;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<T> _rows<T>(Object? json, T? Function(Object? row) parse) {
  final out = <T>[];
  for (final row in asList(json)) {
    final value = parse(row);
    if (value != null) out.add(value);
  }
  return out;
}

List<String> _categoryIds(Object? raw, String? primary) {
  final ids = <String>[?primary];
  final values = raw is String ? raw.split(',') : asList(raw);
  for (final value in values) {
    final id = asId(value);
    if (id != null && !ids.contains(id)) ids.add(id);
  }
  return List.unmodifiable(ids);
}

double? _rating(Object? v, {double max = 10}) {
  final d = asDouble(v);
  if (d == null || d <= 0 || d > max) return null;
  return d;
}

String? _extension(Object? v) {
  final raw = asString(v);
  if (raw == null) return null;
  var s = raw;
  while (s.startsWith('.')) {
    s = s.substring(1);
  }
  return s.isEmpty ? null : s;
}

List<String> _backdrops(Object? v) =>
    List.unmodifiable(asStringList(v, splitCommas: false));

double? _fraction(Object? v) {
  final s = asString(v);
  if (s == null) return null;
  final slash = s.indexOf('/');
  if (slash < 0) {
    final d = asDouble(s);
    return (d == null || d <= 0) ? null : d;
  }
  final a = double.tryParse(s.substring(0, slash));
  final b = double.tryParse(s.substring(slash + 1));
  if (a == null || b == null || a <= 0 || b <= 0) return null;
  return a / b;
}

String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

Object? _epochSeconds(DateTime? d) =>
    d == null ? null : '${d.millisecondsSinceEpoch ~/ 1000}';
