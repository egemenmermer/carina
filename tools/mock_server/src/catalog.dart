/// Deterministic catalog for the Carina mock IPTV server.
///
/// `MockCatalog.generate(scale)` always produces the same channels, movies,
/// series and guide channels for a given scale. Only timestamps (`added`,
/// `last_modified`) are relative to the generation day, so "recently added"
/// rows stay meaningful.
library;

import 'rng.dart';
import 'text_pools.dart';

/// Catalog size.
enum MockScale {
  /// 300 live channels, 2,000 movies, 200 series.
  small(liveCount: 300, movieCount: 2000, seriesCount: 200),

  /// 20,000 live channels, 60,000 movies, 8,000 series.
  large(liveCount: 20000, movieCount: 60000, seriesCount: 8000);

  const MockScale({
    required this.liveCount,
    required this.movieCount,
    required this.seriesCount,
  });

  final int liveCount;
  final int movieCount;
  final int seriesCount;
}

/// Media file names (in the media directory) and image paths (on the server).
abstract final class MockMedia {
  static const h264Aac1080p25 = 'h264_aac_1080p25.ts';
  static const h264Ac351080p25 = 'h264_ac3_51_1080p25.ts';
  static const hevcEac32160p25 = 'hevc_eac3_2160p25.ts';
  static const mpeg2Mp2576i25 = 'mpeg2_mp2_576i25.ts';
  static const h264Aac720p50Mp4 = 'h264_aac_720p50.mp4';
  static const vodTracksMkv = 'vod_tracks.mkv';

  static const liveTsFiles = <String>[
    h264Aac1080p25,
    h264Ac351080p25,
    hevcEac32160p25,
    mpeg2Mp2576i25,
  ];

  static const allFiles = <String>[
    ...liveTsFiles,
    h264Aac720p50Mp4,
    vodTracksMkv,
  ];

  static const posterCount = 40;
  static const backdropCount = 20;
  static const logoCount = 30;
  static const stillCount = 20;

  static String posterPath(int i) => '/img/poster_${_two(i % posterCount)}.jpg';
  static String backdropPath(int i) =>
      '/img/backdrop_${_two(i % backdropCount)}.jpg';
  static String logoPath(int i) => '/img/logo_${_two(i % logoCount)}.png';
  static String stillPath(int i) => '/img/still_${_two(i % stillCount)}.jpg';

  /// A logo URL that deliberately 404s (broken provider logo).
  static const brokenLogoPath = '/img/logo_missing.png';

  /// Media file served for a VOD container extension.
  static String vodFileFor(String containerExtension) =>
      containerExtension.toLowerCase() == 'mp4'
      ? h264Aac720p50Mp4
      : vodTracksMkv;
}

String _two(int v) => v < 10 ? '0$v' : '$v';

/// Known fixtures with stable ids (docs/ARCHITECTURE.md section 4).
abstract final class MockFixtures {
  static const username = 'carina';
  static const password = 'test123';
  static const expiredUsername = 'expired';
  static const expiredPassword = 'test123';

  /// `TRT 1 HD`: H.264/AAC TS, 3 days of archive, category `TR | Ulusal`.
  static const trt1Hd = 1001;

  /// `Show TV FHD`: H.264/AC-3 5.1 TS.
  static const showTvFhd = 1002;

  /// `UHD Test 4K`: HEVC/E-AC-3 2160p TS.
  static const uhdTest4k = 1003;

  /// `Kanal D SD`: MPEG-2/MP2 576i TS.
  static const kanalDSd = 1004;

  /// `Haber Canlı HLS`: the live HLS source.
  static const haberCanliHls = 1005;

  /// `Çocuk Kilitli`: intended parental-lock test channel.
  static const cocukKilitli = 1006;

  /// Live stream that drops after 10 seconds.
  static const dropAfter10s = 1007;

  /// Live streams listed in the catalog whose stream URL returns 404.
  static const notFoundLiveIds = <int>[1008, 1009];

  /// `TRT Haber HD`: 7 days of archive; its epg_channel_id differs from the
  /// XMLTV id only in letter case.
  static const trtHaberHd = 1010;

  /// Other qualities of the Show TV channel (same EPG channel as 1002).
  static const showTvHd = 1011;

  /// SD variant whose epg_channel_id is empty (matchable by name only).
  static const showTvSd = 1012;

  static const liveNames = <int, String>{
    1001: 'TRT 1 HD',
    1002: 'Show TV FHD',
    1003: 'UHD Test 4K',
    1004: 'Kanal D SD',
    1005: 'Haber Canlı HLS',
    1006: 'Çocuk Kilitli',
    1007: 'Kopan Yayın Testi',
    1008: 'Kapalı Kanal 404',
    1009: 'Offline Channel 404',
    1010: 'TRT Haber HD',
    1011: 'Show TV HD',
    1012: 'Show TV SD',
  };

  /// Fixture channels with archive (channel id → days).
  static const archiveDays = <int, int>{1001: 3, 1010: 7};

  static const ulusalCategoryId = '1';
  static const ulusalCategoryName = 'TR | Ulusal';
  static const cocukCategoryName = 'TR | Çocuk';

  /// `Kış Uykusu`: vod_tracks.mkv (2 audio + 2 subtitle tracks).
  static const kisUykusu = 3001;
  static const kisUykusuName = 'Kış Uykusu';

  /// `Sıcak Kafa`: 2 seasons, episodes keyed by season (map shape).
  static const sicakKafa = 5001;
  static const sicakKafaName = 'Sıcak Kafa';

  /// `Gece Yarısı Dosyaları`: episodes delivered as a list, season 0 specials.
  static const geceYarisi = 5002;
  static const geceYarisiName = 'Gece Yarısı Dosyaları';

  /// `Mavi Kapı`: `seasons: []` although episodes exist.
  static const maviKapi = 5003;
  static const maviKapiName = 'Mavi Kapı';

  static const fixtureSeriesIds = <int>[5001, 5002, 5003];

  /// Episode ids of the fixture series: `seriesId * 1000 + season * 100 + n`
  /// (`5001101` is S01E01 of `Sıcak Kafa`).
  static int episodeId(int seriesId, int season, int episode) =>
      seriesId * 1000 + season * 100 + episode;

  /// Actor credited in 3001, 5001 and several generated titles.
  static const sharedActor = 'Nehir Aydın';

  /// Server time zone (fixed +03:00, no DST).
  static const timezone = 'Europe/Istanbul';
  static const utcOffset = Duration(hours: 3);

  /// Account expiry of `carina` (2027-03-01 00:00 UTC).
  static final expiresAt = DateTime.utc(2027, 3, 1);

  /// Expiry of the `expired` account (in the past).
  static final expiredAt = DateTime.utc(2026, 9, 1);
}

enum MockSection { live, movie, series }

/// What a live channel streams.
enum LiveVariant {
  h264Aac1080p25(MockMedia.h264Aac1080p25),
  h264Ac351080p25(MockMedia.h264Ac351080p25),
  hevcEac32160p25(MockMedia.hevcEac32160p25),
  mpeg2Mp2576i25(MockMedia.mpeg2Mp2576i25),
  hls(null);

  const LiveVariant(this.tsFile);

  /// TS file looped for `.ts` requests; null for the HLS channel.
  final String? tsFile;

  /// File served for catch-up of this channel.
  String get archiveFile => tsFile ?? MockMedia.h264Aac1080p25;
}

/// Special stream behaviour.
enum LiveBehavior { normal, notFound, dropAfter }

/// How a stream's `epg_channel_id` relates to the XMLTV channel ids.
enum EpgMatchKind {
  /// epg_channel_id equals the XMLTV id.
  exact,

  /// Same id, different letter case.
  caseInsensitive,

  /// Empty or wrong id; only the normalized display name matches.
  nameOnly,

  /// No guide for this channel at all.
  none,
}

/// Shape of `episodes` in `get_series_info`.
enum EpisodesShape {
  /// `{"1": [...], "2": [...]}`.
  map,

  /// `[[...], [...]]` (what PHP emits for keys 0..n-1).
  list,
}

/// Bit flags for odd field types in live entries.
abstract final class ChannelQuirk {
  static const numAsString = 1 << 0;
  static const idAsString = 1 << 1;
  static const logoNull = 1 << 2;
  static const addedAsInt = 1 << 3;
  static const addedEmpty = 1 << 4;
  static const archiveAsString = 1 << 5;
  static const noCategoryIds = 1 << 6;
  static const customSid = 1 << 7;
  static const adultAsString = 1 << 8;
  static const separator = 1 << 9;
}

/// Bit flags for odd field types in movie entries.
abstract final class MovieQuirk {
  static const ratingAsNumber = 1 << 0;
  static const ratingEmpty = 1 << 1;
  static const ratingNull = 1 << 2;
  static const ratingNA = 1 << 3;
  static const yearAsInt = 1 << 4;
  static const yearMissing = 1 << 5;
  static const tmdbAsInt = 1 << 6;
  static const tmdbIdKey = 1 << 7;
  static const posterNull = 1 << 8;
  static const infoEmpty = 1 << 9;
  static const rating5AsString = 1 << 10;
  static const numAsString = 1 << 11;
}

/// Bit flags for odd field types in series entries.
abstract final class SeriesQuirk {
  static const ratingAsNumber = 1 << 0;
  static const ratingEmpty = 1 << 1;
  static const backdropAsString = 1 << 2;
  static const backdropNull = 1 << 3;
  static const coverNull = 1 << 4;
  static const plotEmpty = 1 << 5;
  static const runTimeAsInt = 1 << 6;
  static const seasonsEmpty = 1 << 7;
  static const seasonsExtra = 1 << 8;
}

final class MockCategory {
  const MockCategory({
    required this.id,
    required this.name,
    required this.section,
    this.parentId = 0,
  });

  final String id;
  final String name;
  final MockSection section;
  final int parentId;
}

final class MockChannel {
  const MockChannel({
    required this.streamId,
    required this.num,
    required this.name,
    required this.baseName,
    required this.categoryId,
    required this.logoPath,
    required this.epgChannelId,
    required this.xmltvId,
    required this.epgMatch,
    required this.archiveDays,
    required this.variant,
    required this.behavior,
    required this.added,
    required this.streamType,
    required this.countryCode,
    this.directSourcePath,
    this.catchupMode,
    this.quirks = 0,
  });

  final int streamId;

  /// Position in the provider list (1-based).
  final int num;
  final String name;

  /// Channel identity without prefix and quality (`Show TV`).
  final String baseName;
  final String? categoryId;

  /// Server path of the logo; null when the logo is missing.
  final String? logoPath;

  /// Value delivered as `epg_channel_id` (may be empty or null).
  final String? epgChannelId;

  /// XMLTV channel that carries this channel's guide, if any.
  final String? xmltvId;
  final EpgMatchKind epgMatch;

  /// Catch-up window in days (0 = no archive).
  final int archiveDays;
  final LiveVariant variant;
  final LiveBehavior behavior;
  final DateTime added;

  /// `live` or `radio_streams`.
  final String streamType;
  final String countryCode;
  final String? directSourcePath;

  /// Catch-up mode used in `/playlist.m3u` (default/append/shift/flussonic/xc).
  final String? catchupMode;
  final int quirks;

  bool hasQuirk(int flag) => quirks & flag != 0;
  bool get hasArchive => archiveDays > 0;
}

final class MockMovie {
  const MockMovie({
    required this.streamId,
    required this.num,
    required this.name,
    required this.originalName,
    required this.categoryId,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.year,
    required this.containerExtension,
    required this.tmdbId,
    required this.added,
    required this.lang,
    required this.genre,
    required this.cast,
    required this.director,
    required this.durationSecs,
    required this.country,
    required this.age,
    required this.seed,
    this.directSourcePath,
    this.quirks = 0,
  });

  final int streamId;
  final int num;
  final String name;
  final String originalName;
  final String? categoryId;
  final String? posterPath;
  final String? backdropPath;

  /// Rating on a 0–10 scale; null when unrated.
  final double? rating;
  final int? year;
  final String containerExtension;
  final int? tmdbId;
  final DateTime added;
  final String lang;
  final String genre;
  final List<String> cast;
  final String director;
  final int durationSecs;
  final String country;
  final String age;
  final int seed;
  final String? directSourcePath;
  final int quirks;

  bool hasQuirk(int flag) => quirks & flag != 0;

  /// Media file served for this movie.
  String get mediaFile => MockMedia.vodFileFor(containerExtension);
}

final class MockSeason {
  const MockSeason(this.number, this.episodeCount, this.airDate);

  final int number;
  final int episodeCount;

  /// `YYYY-MM-DD`.
  final String airDate;
}

final class MockSeries {
  const MockSeries({
    required this.seriesId,
    required this.num,
    required this.name,
    required this.categoryId,
    required this.coverPath,
    required this.backdropPaths,
    required this.rating,
    required this.year,
    required this.releaseDate,
    required this.lastModified,
    required this.lang,
    required this.genre,
    required this.cast,
    required this.director,
    required this.plot,
    required this.seasons,
    required this.firstEpisodeId,
    required this.shape,
    required this.tmdbId,
    required this.episodeRunTime,
    required this.seed,
    this.quirks = 0,
  });

  final int seriesId;
  final int num;
  final String name;
  final String? categoryId;
  final String? coverPath;
  final List<String> backdropPaths;
  final double? rating;
  final int year;
  final String releaseDate;
  final DateTime lastModified;
  final String lang;
  final String genre;
  final List<String> cast;
  final String director;
  final String plot;

  /// Seasons in ascending order (season 0 = specials).
  final List<MockSeason> seasons;

  /// First episode id of a generated series; 0 for fixture series (their
  /// ids follow [MockFixtures.episodeId]).
  final int firstEpisodeId;
  final EpisodesShape shape;
  final int? tmdbId;

  /// Minutes.
  final int episodeRunTime;
  final int seed;
  final int quirks;

  bool hasQuirk(int flag) => quirks & flag != 0;
  bool get fixtureIds => firstEpisodeId == 0;

  int get episodeTotal {
    var n = 0;
    for (final s in seasons) {
      n += s.episodeCount;
    }
    return n;
  }
}

final class MockEpisode {
  const MockEpisode({
    required this.id,
    required this.series,
    required this.season,
    required this.episode,
    required this.containerExtension,
  });

  final int id;
  final MockSeries series;
  final int season;
  final int episode;
  final String containerExtension;

  String get mediaFile => MockMedia.vodFileFor(containerExtension);

  /// `S01E02`.
  String get code => 'S${_two(season)}E${_two(episode)}';
}

/// A `<channel>` of the generated XMLTV guide.
final class MockEpgChannel {
  const MockEpgChannel({
    required this.id,
    required this.displayNames,
    required this.iconPath,
    required this.lang,
    required this.genre,
    required this.utcOffsetMinutes,
    required this.seed,
    this.declared = true,
    this.usedByStreams = true,
  });

  final String id;
  final List<String> displayNames;
  final String? iconPath;

  /// Programme language (`tr`, `en`, `it`, `de`).
  final String lang;

  /// Programme genre key (news, general, sports, docs, kids, movies, music,
  /// local).
  final String genre;

  /// Offset used in the programme timestamps (`+0300` → 180).
  final int utcOffsetMinutes;
  final int seed;

  /// False for guide entries that reference a channel id without a
  /// `<channel>` element.
  final bool declared;

  /// False for guide channels that no stream uses (Custom EPG candidates).
  final bool usedByStreams;
}

/// The generated catalog.
final class MockCatalog {
  MockCatalog._({
    required this.scale,
    required this.generatedAt,
    required this.liveCategories,
    required this.vodCategories,
    required this.seriesCategories,
    required this.channels,
    required this.movies,
    required this.series,
    required this.epgChannels,
  }) : _channelsById = {for (final c in channels) c.streamId: c},
       _moviesById = {for (final m in movies) m.streamId: m},
       _seriesById = {for (final s in series) s.seriesId: s},
       _epgById = {for (final e in epgChannels) e.id: e},
       _generatedSeries = [
         for (final s in series)
           if (!s.fixtureIds) s,
       ]..sort((a, b) => a.firstEpisodeId.compareTo(b.firstEpisodeId));

  /// Builds the deterministic catalog for [scale]. [now] only anchors the
  /// `added` / `last_modified` timestamps (to the start of its UTC day).
  static MockCatalog generate(MockScale scale, {DateTime? now}) =>
      _Builder(scale, (now ?? DateTime.now()).toUtc()).build();

  final MockScale scale;
  final DateTime generatedAt;
  final List<MockCategory> liveCategories;
  final List<MockCategory> vodCategories;
  final List<MockCategory> seriesCategories;
  final List<MockChannel> channels;
  final List<MockMovie> movies;
  final List<MockSeries> series;
  final List<MockEpgChannel> epgChannels;

  final Map<int, MockChannel> _channelsById;
  final Map<int, MockMovie> _moviesById;
  final Map<int, MockSeries> _seriesById;
  final Map<String, MockEpgChannel> _epgById;
  final List<MockSeries> _generatedSeries;

  MockChannel? channelById(int id) => _channelsById[id];
  MockMovie? movieById(int id) => _moviesById[id];
  MockSeries? seriesById(int id) => _seriesById[id];
  MockEpgChannel? epgChannelById(String id) => _epgById[id];

  int get episodeCount {
    var n = 0;
    for (final s in series) {
      n += s.episodeTotal;
    }
    return n;
  }

  /// All episodes of [s] in season order.
  List<MockEpisode> episodesOf(MockSeries s) {
    final out = <MockEpisode>[];
    var running = 0;
    for (final season in s.seasons) {
      for (var e = 1; e <= season.episodeCount; e++) {
        final id = s.fixtureIds
            ? MockFixtures.episodeId(s.seriesId, season.number, e)
            : s.firstEpisodeId + running;
        out.add(
          MockEpisode(
            id: id,
            series: s,
            season: season.number,
            episode: e,
            containerExtension: _episodeExtension(s, season.number, e, id),
          ),
        );
        running++;
      }
    }
    return out;
  }

  /// Looks up an episode by its stream id.
  MockEpisode? episodeById(int id) {
    final fixture = _seriesById[id ~/ 1000];
    if (fixture != null && fixture.fixtureIds) {
      final season = (id % 1000) ~/ 100;
      final number = id % 100;
      for (final s in fixture.seasons) {
        if (s.number == season && number >= 1 && number <= s.episodeCount) {
          return MockEpisode(
            id: id,
            series: fixture,
            season: season,
            episode: number,
            containerExtension: _episodeExtension(fixture, season, number, id),
          );
        }
      }
      return null;
    }
    var lo = 0;
    var hi = _generatedSeries.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final s = _generatedSeries[mid];
      if (id < s.firstEpisodeId) {
        hi = mid - 1;
      } else if (id >= s.firstEpisodeId + s.episodeTotal) {
        lo = mid + 1;
      } else {
        var index = id - s.firstEpisodeId;
        for (final season in s.seasons) {
          if (index < season.episodeCount) {
            return MockEpisode(
              id: id,
              series: s,
              season: season.number,
              episode: index + 1,
              containerExtension: _episodeExtension(
                s,
                season.number,
                index + 1,
                id,
              ),
            );
          }
          index -= season.episodeCount;
        }
        return null;
      }
    }
    return null;
  }

  static String _episodeExtension(
    MockSeries s,
    int season,
    int episode,
    int id,
  ) {
    if (s.seriesId == MockFixtures.sicakKafa && season == 1 && episode <= 3) {
      return 'mkv';
    }
    return id.isEven ? 'mkv' : 'mp4';
  }

  /// Plot of a movie (generated on demand from its seed).
  String moviePlot(MockMovie m) =>
      _fixturePlots[m.streamId] ??
      _plot(
        MockRandom(m.seed ^ 0x51ED),
        m.lang,
        m.cast.isEmpty ? null : m.cast.first,
      );

  /// Episode title as delivered by the provider.
  String episodeTitle(MockEpisode e) {
    final s = e.series;
    if (s.seriesId == MockFixtures.sicakKafa) return '${s.name} - ${e.code}';
    final r = MockRandom(mixHash(s.seed, e.season, e.episode));
    final word = episodeWord[s.lang] ?? 'Episode';
    if (e.season == 0) {
      return s.lang == 'tr'
          ? '${s.name} - Özel Bölüm ${e.episode}'
          : '${s.name} - Special ${e.episode}';
    }
    switch (r.nextInt(4)) {
      case 0:
        return '${s.name} - ${e.code}';
      case 1:
        return '${s.name} S${_two(e.season)} E${_two(e.episode)}';
      case 2:
        return '$word ${e.episode}';
      default:
        return s.lang == 'tr'
            ? '${e.episode}. Bölüm'
            : '${s.name} - ${e.code} - $word ${e.episode}';
    }
  }

  String episodePlot(MockEpisode e) {
    final r = MockRandom(mixHash(e.series.seed, e.season * 31 + e.episode));
    return _plot(
      r,
      e.series.lang,
      e.series.cast.isEmpty ? null : r.pick(e.series.cast),
    );
  }

  String episodeStillPath(MockEpisode e) =>
      MockMedia.stillPath(mixHash(e.id, e.series.seriesId));

  int episodeDurationSecs(MockEpisode e) {
    final r = MockRandom(mixHash(e.series.seed, e.id));
    return e.series.episodeRunTime * 60 + r.range(-180, 240);
  }

  /// `YYYY-MM-DD`.
  String episodeAirDate(MockEpisode e) {
    final base = DateTime.parse(e.series.releaseDate);
    final d = base.add(
      Duration(
        days: (e.season <= 0 ? 0 : e.season - 1) * 365 + (e.episode - 1) * 7,
      ),
    );
    return _date(d);
  }

  double episodeRating(MockEpisode e) {
    final r = MockRandom(mixHash(e.series.seed, e.id, 7));
    return (r.range(55, 92)) / 10.0;
  }
}

/// Hand-written plots of the fixture titles (ids are unique across movies
/// and series).
const _fixturePlots = <int, String>{
  MockFixtures.kisUykusu:
      'Kapadokya\'da küçük bir otel işleten emekli bir oyuncu, kış bastırıp '
      'misafirler azalınca ailesiyle ve kendisiyle yüzleşmek zorunda kalır.',
  MockFixtures.sicakKafa:
      'İstanbul\'da insanları en saçma iddialara inandıran bir salgın '
      'yayılırken, hastalığa bağışık tek kişi olan genç bir çevirmen '
      'gerçeğin peşine düşer.',
  MockFixtures.geceYarisi:
      'Gece vardiyasındaki iki dedektif şehrin kapanmış dosyalarını yeniden '
      'açar; her bölümde yeni bir sır, her sezonda daha büyük bir komplo.',
  MockFixtures.maviKapi:
      'Mavi kapılı eski bir apartmanda yaşayan komşuların komik ve sıcak '
      'hikâyeleri.',
};

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String _plot(MockRandom r, String lang, String? name) {
  final who = name ?? 'O';
  switch (lang) {
    case 'tr':
      final city = r.pick(trCities);
      switch (r.nextInt(3)) {
        case 0:
          return '$city şehrinde yaşayan ${r.pick(trRoles)} $who, ${r.pick(trEvents)}. ${r.pick(trTwists)}';
        case 1:
          return '$who, ${r.pick(trEvents)} ve $city sokaklarında kendini tehlikeli bir oyunun içinde bulur. ${r.pick(trTwists)}';
        default:
          return 'Yıllar sonra memleketine dönen ${r.pick(trRoles)}, $city sokaklarında ${r.pick(trEvents)}. ${r.pick(trTwists)}';
      }
    case 'it':
      return r.pick(itPlots);
    case 'de':
      return r.pick(dePlots);
    default:
      final city = r.pick(ukTowns);
      return 'In $city, ${r.pick(enRoles)} ${r.pick(enEvents)}. ${r.pick(enTwists)}';
  }
}

// ---------------------------------------------------------------------------
// Text helpers shared with the guide generator
// ---------------------------------------------------------------------------

const _foldMap = <String, String>{
  'ş': 's', 'ç': 'c', 'ğ': 'g', 'ö': 'o', 'ü': 'u', 'ı': 'i', 'é': 'e', //
  'è': 'e', 'ê': 'e', 'ë': 'e', 'â': 'a', 'à': 'a', 'á': 'a', 'ä': 'a',
  'ã': 'a', 'å': 'a', 'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', 'ô': 'o',
  'ò': 'o', 'ó': 'o', 'õ': 'o', 'ø': 'o', 'û': 'u', 'ù': 'u', 'ú': 'u',
  'ñ': 'n', 'ł': 'l', 'ś': 's', 'ź': 'z', 'ż': 'z', 'ć': 'c', 'ń': 'n',
  'ą': 'a', 'ę': 'e', 'ő': 'o', 'ű': 'u', 'ə': 'e', 'ß': 'ss', 'č': 'c',
  'š': 's', 'ž': 'z', 'đ': 'd',
};

/// Turkish-aware lowercase.
String trLower(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Turkish-aware uppercase.
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Lowercases (Turkish-aware, dotless ı → i) and folds diacritics.
String foldText(String s) {
  final lower = s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .toLowerCase();
  final b = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    b.write(_foldMap[ch] ?? ch);
  }
  return b.toString();
}

/// Drops diacritics but keeps the letter case (`Habertürk` → `Haberturk`).
String stripDiacritics(String s) {
  final b = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == 'İ') {
      b.write('I');
      continue;
    }
    if (ch == 'ı') {
      b.write('i');
      continue;
    }
    final lower = ch.toLowerCase();
    final folded = _foldMap[lower];
    if (folded == null) {
      b.write(ch);
    } else {
      b.write(ch != lower ? folded.toUpperCase() : folded);
    }
  }
  return b.toString();
}

final _qualityWord = RegExp(
  r'(^|\s)(sd|hd|fhd|uhd|4k|8k|h265|h\.265|hevc|50fps|60fps|hdr)(?=\s|$)',
);
final _prefixPattern = RegExp(
  r'^\s*(\|[a-z]{2,4}\||\[[a-z]{2,4}\]|[a-z]{2,4}\s*[:|\-]|[a-z]{2}\.\s)\s*',
);
final _punctuation = RegExp(r'[^\p{L}\p{N}.]+', unicode: true);
final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Approximation of the app's `normalizeChannelName` (diacritics, quality
/// tokens and country prefixes stripped, then only letters and digits).
/// Used to keep channel identities unambiguous for name-based EPG matching.
String channelKey(String name) {
  var s = foldText(name).trim();
  s = s.replaceFirst(_prefixPattern, '');
  s = ' ${s.replaceAll(_punctuation, ' ')} ';
  s = s.replaceAll(_qualityWord, ' ');
  return s.replaceAll(_nonWord, '');
}

/// ASCII slug for XMLTV ids (`Show TV` → `showtv`).
String slugify(String name) {
  final folded = foldText(name);
  final b = StringBuffer();
  for (final c in folded.codeUnits) {
    if ((c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39)) {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

final class _Identity {
  _Identity({
    required this.baseName,
    required this.cc,
    required this.genre,
    required this.lang,
    required this.slug,
    required this.hasEpg,
    required this.logoIndex,
    required this.utcOffsetMinutes,
    required this.seed,
  });

  final String baseName;
  final String cc;
  final String genre;
  final String lang;
  final String slug;
  final bool hasEpg;
  final int logoIndex;
  final int utcOffsetMinutes;
  final int seed;
  bool used = false;
  int firstUse = 1 << 30;

  String get xmltvId => '$slug.${cc.toLowerCase()}';
}

enum _Qualities { normal, sports, uhd, hevc, fhd, raw, backup, sd, none }

final class _LiveSpec {
  const _LiveSpec(
    this.name,
    this.cc,
    this.genre,
    this.small, {
    required this.prefix,
    this.standardPrefix = true,
    this.qualities = _Qualities.normal,
    this.largeCount,
  });

  final String name;
  final String cc;

  /// Pool key: general, sports, news, docs, kids, movies, music, local,
  /// radio, allday, ppv, mixed (all genres of a country), test, empty.
  final String genre;

  /// Number of streams in the small catalog.
  final int small;

  /// Prefix put in front of the channel name (`TR: `).
  final String prefix;

  /// Whether the app's normalizer can strip [prefix] (name matching works).
  final bool standardPrefix;
  final _Qualities qualities;

  /// Explicit stream count in the large catalog (PPV only); otherwise every
  /// channel of the pool is listed once.
  final int? largeCount;
}

/// Categories of the small catalog. The large catalog starts with the same
/// list (so category ids match across scales) and appends packages.
const _baseSpecs = <_LiveSpec>[
  _LiveSpec('TR | Ulusal', 'TR', 'general', 30, prefix: 'TR: '),
  _LiveSpec(
    'TR | Spor',
    'TR',
    'sports',
    30,
    prefix: 'TR | ',
    qualities: _Qualities.sports,
  ),
  _LiveSpec('TR | Haber', 'TR', 'news', 20, prefix: '|TR| '),
  _LiveSpec('TR | Belgesel', 'TR', 'docs', 15, prefix: 'TR: '),
  _LiveSpec('TR | Çocuk', 'TR', 'kids', 15, prefix: 'TR - '),
  _LiveSpec('TR | Sinema', 'TR', 'movies', 15, prefix: '[TR] '),
  _LiveSpec('TR | Müzik', 'TR', 'music', 10, prefix: 'TR: '),
  _LiveSpec('TR | Yerel', 'TR', 'local', 20, prefix: 'TR | '),
  _LiveSpec(
    'TR | 4K UHD',
    'TR',
    'general',
    8,
    prefix: 'TR: ',
    qualities: _Qualities.uhd,
  ),
  _LiveSpec('TR | Test', 'TR', 'test', 0, prefix: ''),
  _LiveSpec(
    'TR | Radyo',
    'TR',
    'radio',
    5,
    prefix: 'TR: ',
    qualities: _Qualities.none,
  ),
  _LiveSpec(
    'TR | 7/24',
    'TR',
    'allday',
    10,
    prefix: 'TR: ',
    qualities: _Qualities.none,
  ),
  _LiveSpec('IT | Top Italia', 'IT', 'general', 20, prefix: 'IT | '),
  _LiveSpec(
    'IT | Sport',
    'IT',
    'sports',
    8,
    prefix: 'IT | ',
    qualities: _Qualities.sports,
  ),
  _LiveSpec('UK | Entertainment', 'UK', 'general', 20, prefix: 'UK: '),
  _LiveSpec(
    'UK | Sports',
    'UK',
    'sports',
    10,
    prefix: 'UK: ',
    qualities: _Qualities.sports,
  ),
  _LiveSpec('UK | News', 'UK', 'news', 8, prefix: '|UK| '),
  _LiveSpec('DE | Filme', 'DE', 'movies', 10, prefix: 'DE: '),
  _LiveSpec('DE | Unterhaltung', 'DE', 'general', 15, prefix: 'DE: '),
  _LiveSpec(
    'DE | Sport',
    'DE',
    'sports',
    8,
    prefix: 'DE: ',
    qualities: _Qualities.sports,
  ),
  _LiveSpec('AZ | Azərbaycan', 'AZ', 'mixed', 5, prefix: 'AZ: '),
  _LiveSpec(
    'PPV | Etkinlikler',
    'TR',
    'ppv',
    6,
    prefix: 'PPV ',
    qualities: _Qualities.none,
    largeCount: 300,
  ),
  _LiveSpec('TR | Boş Kategori', 'TR', 'empty', 0, prefix: ''),
];

/// Genre categories per country for the large catalog: (genre, label).
const _genreLabels = <String, List<(String, String)>>{
  'TR': [
    ('general', 'Ulusal'),
    ('sports', 'Spor'),
    ('news', 'Haber'),
    ('docs', 'Belgesel'),
    ('kids', 'Çocuk'),
    ('movies', 'Sinema'),
    ('music', 'Müzik'),
    ('local', 'Yerel'),
  ],
  'UK': [
    ('general', 'Entertainment'),
    ('sports', 'Sports'),
    ('news', 'News'),
    ('docs', 'Documentary'),
    ('kids', 'Kids'),
    ('movies', 'Movies'),
    ('music', 'Music'),
    ('local', 'Local'),
  ],
  'DE': [
    ('general', 'Unterhaltung'),
    ('sports', 'Sport'),
    ('news', 'Nachrichten'),
    ('docs', 'Doku'),
    ('kids', 'Kinder'),
    ('movies', 'Filme'),
    ('music', 'Musik'),
    ('local', 'Regional'),
  ],
  'IT': [
    ('general', 'Top Italia'),
    ('sports', 'Sport'),
    ('news', 'Notizie'),
    ('docs', 'Documentari'),
    ('kids', 'Bambini'),
    ('movies', 'Cinema'),
    ('music', 'Musica'),
    ('local', 'Locali'),
  ],
};

const _mixedLabels = <String, String>{
  'AZ': 'Azərbaycan', 'FR': 'Généraliste', 'NL': 'Algemeen', 'PL': 'Ogólne', //
  'ES': 'Generalistas', 'PT': 'Generalistas', 'GR': 'Ελληνικά', 'RU': 'Русские',
  'AR': 'قنوات عربية', 'ALB': 'Shqip', 'EXYU': 'Ex-Yu Kanali',
  'US': 'Entertainment', 'IN': 'Hindi', 'KU': 'Kurdî',
};

/// Provider "packages" that re-list the same channels: (key, prefix, qualities).
/// `{cc}` is replaced by the country code.
const _packages = <(String, String, _Qualities)>[
  ('VIP', '{cc} VIP | ', _Qualities.normal),
  ('FHD', '{cc} FHD: ', _Qualities.fhd),
  ('YEDEK', '{cc} YEDEK | ', _Qualities.backup),
  ('RAW', '{cc} RAW: ', _Qualities.raw),
  ('HEVC', '{cc} HEVC | ', _Qualities.hevc),
  ('PLUS', '{cc}+ | ', _Qualities.normal),
  ('4K', '{cc} 4K | ', _Qualities.uhd),
  ('SD', '{cc} SD: ', _Qualities.sd),
  ('GOLD', '{cc} GOLD | ', _Qualities.normal),
  ('EXTRA', '{cc} EXTRA: ', _Qualities.normal),
  ('BACKUP', '{cc} BACKUP: ', _Qualities.backup),
];

/// Packages that also re-list local channels.
const _localPackages = <String>{'YEDEK', 'PLUS', 'GOLD', 'EXTRA'};

/// Number of packages per country in the large catalog.
const _packageCount = <String, int>{
  'TR': 11, 'UK': 6, 'DE': 6, 'IT': 5, 'AZ': 3, 'FR': 4, 'NL': 4, 'PL': 4, //
  'ES': 4, 'PT': 4, 'GR': 4, 'RU': 4, 'AR': 4, 'ALB': 4, 'EXYU': 4, 'US': 4,
  'IN': 4, 'KU': 4,
};

const _alternatePrefixes = <String>['{cc}: ', '{cc} | ', '|{cc}| ', '[{cc}] '];

const _countryLang = <String, String>{
  'TR': 'tr',
  'AZ': 'tr',
  'UK': 'en',
  'US': 'en',
  'IT': 'it',
  'DE': 'de',
};

/// Countries whose names the app can match by normalized display name.
const _nameMatchCountries = <String>{'TR', 'UK', 'DE', 'IT', 'AZ'};

const _qualitySets = <_Qualities, List<List<String>>>{
  _Qualities.normal: [
    [''], ['HD'], ['FHD'], ['SD'], ['HD', 'FHD'], ['SD', 'HD', 'FHD'], //
    ['FHD', '4K'], ['HD 50FPS'], ['H265'], ['HEVC'], ['FHD H265'],
    ['HD', 'HD (Yedek)'], ['HD+'], ['ᴴᴰ'], ['HDTV'], ['UHD'],
  ],
  _Qualities.sports: [
    ['HD'], ['FHD'], ['FHD 50FPS'], ['HD 50FPS'], ['SD', 'HD', 'FHD'], //
    ['FHD', '4K'], ['4K 50FPS'], ['H265'], ['FHD HEVC'], [''],
    ['HD', 'HD (Yedek)'],
  ],
  _Qualities.uhd: [
    ['4K'], ['UHD'], ['4K HEVC'], ['4K H265'], ['4K 50FPS'], //
  ],
  _Qualities.hevc: [
    ['HEVC'], ['H265'], ['FHD HEVC'], ['4K H265'], //
  ],
  _Qualities.fhd: [
    ['FHD'], ['FHD 50FPS'], ['FHD H265'], //
  ],
  _Qualities.raw: [
    ['RAW'], ['HD RAW'], ['FHD RAW'], //
  ],
  _Qualities.backup: [
    ['HD (Yedek)'], ['Yedek'], ['FHD Yedek'], ['HD Backup'], //
  ],
  _Qualities.sd: [
    ['SD'],
  ],
  _Qualities.none: [
    [''],
  ],
};

const _qualityWeights = <_Qualities, List<int>>{
  _Qualities.normal: [15, 25, 10, 5, 8, 8, 3, 3, 3, 2, 2, 3, 1, 1, 1, 1],
  _Qualities.sports: [20, 15, 15, 10, 8, 5, 3, 3, 3, 10, 5],
  _Qualities.uhd: [40, 15, 20, 15, 10],
  _Qualities.hevc: [35, 35, 20, 10],
  _Qualities.fhd: [70, 20, 10],
  _Qualities.raw: [50, 30, 20],
  _Qualities.backup: [40, 30, 20, 10],
  _Qualities.sd: [1],
  _Qualities.none: [1],
};

/// Quality tokens that the app's normalizer strips (name matching works).
const _cleanQualities = <String>{
  '', 'HD', 'FHD', 'SD', '4K', 'UHD', 'H265', 'HEVC', 'HD 50FPS', //
  'FHD 50FPS', 'FHD H265', 'FHD HEVC', '4K HEVC', '4K H265', '4K 50FPS',
};

const _catchupModes = <String>['default', 'append', 'shift', 'flussonic', 'xc'];

/// Approximate number of guide channels in the large catalog (≈ 1,000,000
/// programmes over the 14-day window).
const _largeEpgChannelTarget = 2700;

final class _LiveResult {
  _LiveResult(this.categories, this.channels, this.epgChannels);
  final List<MockCategory> categories;
  final List<MockChannel> channels;
  final List<MockEpgChannel> epgChannels;
}

final class _Builder {
  _Builder(this.scale, this.now)
    : anchorDay = DateTime.utc(now.year, now.month, now.day),
      rng = MockRandom(scale == MockScale.small ? 0x4B414E01 : 0x4B414E02);

  final MockScale scale;
  final DateTime now;
  final DateTime anchorDay;
  final MockRandom rng;

  bool get large => scale == MockScale.large;

  final _actors = <String, List<String>>{};
  final _directors = <String, List<String>>{};
  final _identityByKey = <String, _Identity>{};
  final _identities = <_Identity>[];
  final _pools = <String, List<_Identity>>{};
  final _slugs = <String>{};
  final _titleCounters = <String, int>{};

  MockCatalog build() {
    _buildPeople();
    final live = _buildLive();
    final vodCategories = _vodCategories();
    final movies = _buildMovies(vodCategories);
    final seriesCategories = _seriesCategories();
    final series = _buildSeries(seriesCategories);
    return MockCatalog._(
      scale: scale,
      generatedAt: now,
      liveCategories: live.categories,
      vodCategories: vodCategories,
      seriesCategories: seriesCategories,
      channels: live.channels,
      movies: movies,
      series: series,
      epgChannels: live.epgChannels,
    );
  }

  // ---------------------------------------------------------------- people

  void _buildPeople() {
    final r = MockRandom(0x9E0F1E);
    final taken = <String>{MockFixtures.sharedActor};
    List<String> people(List<String> first, List<String> last, int count) {
      final out = <String>[];
      var guard = 0;
      while (out.length < count && guard++ < count * 50) {
        final n = '${r.pick(first)} ${r.pick(last)}';
        if (taken.add(n)) out.add(n);
      }
      return out;
    }

    _actors['tr'] = [
      MockFixtures.sharedActor,
      ...people(trFirstNames, trLastNames, 79),
    ];
    _actors['en'] = people(enFirstNames, enLastNames, 30);
    _actors['it'] = people(itFirstNames, itLastNames, 14);
    _actors['de'] = people(deFirstNames, deLastNames, 14);
    _directors['tr'] = people(trFirstNames, trLastNames, 20);
    _directors['en'] = people(enFirstNames, enLastNames, 10);
    _directors['it'] = people(itFirstNames, itLastNames, 6);
    _directors['de'] = people(deFirstNames, deLastNames, 6);
  }

  List<String> _castFor(MockRandom r, String lang) {
    final own = _actors[lang] ?? _actors['en']!;
    final count = r.range(3, 5);
    final out = <String>[];
    var guard = 0;
    while (out.length < count && guard++ < 40) {
      final pool = r.chance(0.8)
          ? own
          : _actors[r.pick(const ['tr', 'en', 'it', 'de'])]!;
      var name = r.pick(pool);
      // The shared fixture actor stays rare so "search by actor" returns
      // several titles, not hundreds.
      if (name == MockFixtures.sharedActor && !r.chance(0.04)) {
        name = _actors['tr']![1 + r.nextInt(_actors['tr']!.length - 1)];
      }
      if (!out.contains(name)) out.add(name);
    }
    return out;
  }

  String _directorFor(MockRandom r, String lang) =>
      r.pick(_directors[lang] ?? _directors['en']!);

  /// Spread over the last 60 days, ~5 % within the last 7 days.
  DateTime _addedAt(MockRandom r) {
    final recent = r.chance(0.05);
    final seconds = recent
        ? r.range(3600, 6 * 86400)
        : r.range(8 * 86400, 59 * 86400);
    return anchorDay.subtract(Duration(seconds: seconds));
  }

  // ------------------------------------------------------------- identities

  _Identity _identity(
    String baseName,
    String cc,
    String genre, {
    bool? forceEpg,
  }) {
    var name = baseName;
    var key = channelKey(name);
    final existing = _identityByKey[key];
    if (existing != null) {
      if (existing.cc == cc) return existing;
      name = '$baseName $cc';
      key = channelKey(name);
      final again = _identityByKey[key];
      if (again != null) return again;
    }
    final seq = _identities.length;
    var slug = slugify(name);
    if (slug.isEmpty) slug = 'ch${seq + 1}';
    final ccLower = cc.toLowerCase();
    var unique = slug;
    var n = 2;
    while (!_slugs.add('$unique.$ccLower')) {
      unique = '$slug$n';
      n++;
    }
    final noGuide = const {'radio', 'allday', 'ppv', 'test'}.contains(genre);
    final r = MockRandom(mixHash(hashString(name), 0x1D));
    final hasEpg =
        forceEpg ??
        (!noGuide && (genre == 'local' ? r.chance(0.8) : r.chance(0.97)));
    final identity = _Identity(
      baseName: name,
      cc: cc,
      genre: genre,
      lang: _countryLang[cc] ?? 'en',
      slug: unique,
      hasEpg: hasEpg,
      logoIndex: seq,
      utcOffsetMinutes: cc == 'UK' ? 0 : 180,
      seed: mixHash(hashString(name), seq),
    );
    _identityByKey[key] = identity;
    _identities.add(identity);
    return identity;
  }

  List<_Identity> _pool(String cc, String genre) {
    final cacheKey = '$cc/$genre';
    final cached = _pools[cacheKey];
    if (cached != null) return cached;
    final out = <_Identity>[];
    final seen = <_Identity>{};
    void add(String name, String g) {
      final id = _identity(name, cc, g);
      if (seen.add(id)) out.add(id);
    }

    final byGenre = channelNames[cc] ?? const <String, List<String>>{};
    if (genre == 'mixed') {
      for (final entry in byGenre.entries) {
        for (final n in entry.value) {
          add(n, entry.key);
        }
      }
    } else {
      if (cc == 'TR' && genre == 'general') {
        for (final n in const ['TRT 1', 'Show TV', 'Kanal D']) {
          add(n, 'general');
        }
      }
      for (final n in byGenre[genre] ?? const <String>[]) {
        add(n, genre);
      }
      if (large && cc == 'TR' && genre == 'allday') {
        for (final t in [...trSeriesTitles, ...trMovieTitles.take(40)]) {
          add('7/24 $t', 'allday');
        }
      }
    }
    if (large && (genre == 'local' || genre == 'mixed')) {
      final cities = switch (cc) {
        'TR' => trCities,
        'UK' => ukTowns,
        'DE' => deCities,
        'IT' => itCities,
        _ => otherCities[cc] ?? const <String>[],
      };
      final suffixes = localSuffixes[cc] ?? localSuffixes['other']!;
      for (final suffix in suffixes) {
        for (final city in cities) {
          final name = switch (suffix) {
            'Tele' => 'Tele$city',
            'Canale' => 'Canale $city',
            'Kanal' => 'Kanal $city',
            _ => '$city $suffix',
          };
          add(name, 'local');
        }
      }
    }
    _pools[cacheKey] = out;
    return out;
  }

  // ------------------------------------------------------------------- live

  List<_LiveSpec> _liveSpecList() {
    if (!large) return _baseSpecs;
    final specs = <_LiveSpec>[..._baseSpecs];
    final names = {for (final s in specs) s.name};
    void add(_LiveSpec s) {
      if (names.add(s.name)) specs.add(s);
    }

    const countries = [
      'TR', 'UK', 'DE', 'IT', 'AZ', 'FR', 'NL', 'PL', 'ES', 'PT', 'GR', 'RU', //
      'AR', 'ALB', 'EXYU', 'US', 'IN', 'KU',
    ];
    // Round 0: the remaining base categories of every country.
    for (final cc in countries) {
      final genres = _genreLabels[cc];
      if (genres == null) {
        add(
          _LiveSpec(
            '$cc | ${_mixedLabels[cc]}',
            cc,
            'mixed',
            0,
            prefix: '$cc: ',
          ),
        );
        continue;
      }
      for (final (genre, label) in genres) {
        add(
          _LiveSpec(
            '$cc | $label',
            cc,
            genre,
            0,
            prefix: '$cc: ',
            qualities: genre == 'sports'
                ? _Qualities.sports
                : _Qualities.normal,
          ),
        );
      }
    }
    add(
      const _LiveSpec(
        'UK | PPV Events',
        'UK',
        'ppv',
        0,
        prefix: 'UK: ',
        qualities: _Qualities.none,
        largeCount: 200,
      ),
    );
    // Then one package at a time across all countries, so trimming to the
    // exact target drops the least important packages.
    for (var p = 0; p < _packages.length; p++) {
      final (key, prefixTemplate, qualities) = _packages[p];
      for (final cc in countries) {
        if (p >= (_packageCount[cc] ?? 0)) continue;
        final prefix = prefixTemplate.replaceAll('{cc}', cc);
        final packageName = prefix.replaceAll(RegExp(r'[:|]\s*$'), '').trim();
        final genres = _genreLabels[cc];
        if (genres == null) {
          add(
            _LiveSpec(
              '$packageName | ${_mixedLabels[cc]}',
              cc,
              'mixed',
              0,
              prefix: prefix,
              standardPrefix: false,
              qualities: qualities,
            ),
          );
          continue;
        }
        for (final (genre, label) in genres) {
          if (genre == 'local' && !_localPackages.contains(key)) continue;
          add(
            _LiveSpec(
              '$packageName | $label',
              cc,
              genre,
              0,
              prefix: prefix,
              standardPrefix: false,
              qualities: qualities,
            ),
          );
        }
      }
    }
    return specs;
  }

  _LiveResult _buildLive() {
    final specs = _liveSpecList();
    final catIdByName = <String, String>{
      for (var i = 0; i < specs.length; i++) specs[i].name: '${i + 1}',
    };

    final target = scale.liveCount;
    final fixtures = _liveFixtures(catIdByName);
    final fixtureNames = {for (final f in fixtures) f.name};
    final channels = <MockChannel>[...fixtures];
    var nextId = 10001;
    var genIndex = 0;
    var archiveIndex = 2; // 1001 uses "default" and 1010 uses "xc".
    final r = MockRandom(mixHash(rng.nextUint32(), 0x11FE));
    final nameOnlyChance = large ? 0.3 : 0.11;

    void advanceId() => nextId += 1 + (r.chance(0.03) ? r.range(1, 3) : 0);

    for (final spec in specs) {
      if (channels.length >= target) break;
      if (spec.genre == 'test' || spec.genre == 'empty') continue;
      final catId = catIdByName[spec.name]!;
      final names = <String>{};
      final pool = spec.genre == 'ppv'
          ? const <_Identity>[]
          : _pool(spec.cc, spec.genre);
      // Small: explicit count. Large: every channel of the pool once.
      final limit = large ? (spec.largeCount ?? 1 << 30) : spec.small;
      if (limit <= 0) continue;
      var emitted = 0;
      bool full() => emitted >= limit || channels.length >= target;

      // A separator entry at the top of some categories ("━━━ TR SPOR ━━━").
      final separator = large
          ? r.chance(0.2)
          : (spec.name == 'TR | Spor' || spec.name == 'UK | Entertainment');
      if (separator && limit > 3) {
        final label = spec.name
            .replaceAll('|', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .toUpperCase();
        channels.add(
          _channel(
            r: r,
            id: nextId,
            name: r.chance(0.5) ? '━━━━━ $label ━━━━━' : '##### $label #####',
            baseName: label,
            spec: spec,
            categoryId: catId,
            identity: null,
            quality: '',
            standard: false,
            genIndex: genIndex,
            behavior: LiveBehavior.notFound,
            extraQuirks: ChannelQuirk.separator,
          ),
        );
        advanceId();
        genIndex++;
        emitted++;
      }

      if (spec.genre == 'ppv') {
        final teams = teamNames[spec.cc == 'UK' ? 'en' : 'tr']!;
        for (var n = 1; !full(); n++) {
          final a = teams[(n * 7) % teams.length];
          final b = teams[(n * 7 + 1 + n % (teams.length - 1)) % teams.length];
          final hh = _two(12 + n % 11);
          final mm = const ['00', '15', '30', '45'][n % 4];
          final name = spec.cc == 'UK'
              ? 'UK: EPL ${_two(n)} | $a v $b $hh:$mm'
              : (n.isEven
                    ? 'PPV ${_two(n)} | Etkinlik'
                    : 'PPV ${_two(n)}: $a - $b $hh:$mm');
          channels.add(
            _channel(
              r: r,
              id: nextId,
              name: name,
              baseName: name,
              spec: spec,
              categoryId: catId,
              identity: null,
              quality: '',
              standard: false,
              genIndex: genIndex,
            ),
          );
          advanceId();
          genIndex++;
          emitted++;
        }
        continue;
      }

      final rounds = large ? 1 : 1 << 30;
      for (var i = 0; i < pool.length * rounds && !full(); i++) {
        final identity = pool[i % pool.length];
        if (!large && i >= pool.length * 8) break;
        final qualities = r.weighted(
          _qualitySets[spec.qualities]!,
          _qualityWeights[spec.qualities]!,
        );
        for (final q in qualities) {
          if (full()) break;
          final useAlternate = spec.standardPrefix && r.chance(0.1);
          final noPrefix =
              spec.standardPrefix && !useAlternate && r.chance(0.05);
          final prefix = noPrefix
              ? ''
              : useAlternate
              ? r.pick(_alternatePrefixes).replaceAll('{cc}', spec.cc)
              : spec.prefix;
          var name = '$prefix${identity.baseName}${q.isEmpty ? '' : ' $q'}';
          if (spec.cc == 'TR' && r.chance(0.03)) name = trUpper(name);
          if (fixtureNames.contains(name) || !names.add(name)) continue;
          identity.used = true;
          if (identity.firstUse > channels.length) {
            identity.firstUse = channels.length;
          }
          final archive = _archiveFor(r, spec);
          channels.add(
            _channel(
              r: r,
              id: nextId,
              name: name,
              baseName: identity.baseName,
              spec: spec,
              categoryId: catId,
              identity: identity,
              quality: q,
              standard: spec.standardPrefix,
              genIndex: genIndex,
              behavior: genIndex % 61 == 60
                  ? LiveBehavior.notFound
                  : LiveBehavior.normal,
              archiveDays: archive,
              catchupMode: archive > 0
                  ? _catchupModes[archiveIndex++ % _catchupModes.length]
                  : null,
              nameOnlyChance: nameOnlyChance,
            ),
          );
          advanceId();
          genIndex++;
          emitted++;
        }
      }
    }

    // Pad to the exact target if the pools ran dry.
    final ulusal = _pool('TR', 'general');
    for (var k = 0; channels.length < target; k++) {
      final identity = ulusal[k % ulusal.length];
      channels.add(
        _channel(
          r: r,
          id: nextId,
          name: 'TR: ${identity.baseName} Yedek ${k + 2}',
          baseName: identity.baseName,
          spec: specs.first,
          categoryId: catIdByName[specs.first.name],
          identity: identity,
          quality: 'Yedek',
          standard: false,
          genIndex: genIndex++,
        ),
      );
      advanceId();
    }

    final numbered = _applyBrokenEntriesAndNumbers(channels);
    // Keep categories that have streams, plus the deliberately empty one.
    final usedCategories = {for (final c in numbered) c.categoryId};
    final categories = <MockCategory>[
      for (final s in specs)
        if (usedCategories.contains(catIdByName[s.name]) || s.genre == 'empty')
          MockCategory(
            id: catIdByName[s.name]!,
            name: s.name,
            section: MockSection.live,
          ),
    ];
    final epg = _epgChannels();
    return _LiveResult(categories, numbered, epg);
  }

  int _archiveFor(MockRandom r, _LiveSpec spec) {
    final popular =
        (spec.cc == 'TR' || spec.cc == 'UK') &&
        (spec.genre == 'general' ||
            spec.genre == 'news' ||
            spec.genre == 'sports');
    if (!r.chance(popular ? 0.12 : 0.02)) return 0;
    return r.chance(0.6) ? 3 : 7;
  }

  MockChannel _channel({
    required MockRandom r,
    required int id,
    required String name,
    required String baseName,
    required _LiveSpec spec,
    required String? categoryId,
    required _Identity? identity,
    required String quality,
    required bool standard,
    required int genIndex,
    LiveBehavior behavior = LiveBehavior.normal,
    int archiveDays = 0,
    String? catchupMode,
    int extraQuirks = 0,
    double nameOnlyChance = 0.11,
  }) {
    var quirks = extraQuirks;
    // Logos: ~15 % missing (null or ""), ~2 % broken URLs.
    String? logo;
    final logoRoll = r.nextDouble();
    if (extraQuirks & ChannelQuirk.separator != 0 || logoRoll < 0.15) {
      logo = null;
      if (r.chance(0.35)) quirks |= ChannelQuirk.logoNull;
    } else if (logoRoll < 0.17) {
      logo = MockMedia.brokenLogoPath;
    } else {
      logo = MockMedia.logoPath(identity?.logoIndex ?? genIndex);
    }

    String? epgId;
    String? xmltvId;
    var match = EpgMatchKind.none;
    if (identity != null && identity.hasEpg) {
      xmltvId = identity.xmltvId;
      final roll = r.nextDouble();
      final nameOk =
          standard &&
          _cleanQualities.contains(quality) &&
          _nameMatchCountries.contains(identity.cc);
      if (nameOk && roll < nameOnlyChance) {
        match = EpgMatchKind.nameOnly;
        final how = r.nextInt(3);
        epgId = how == 0
            ? ''
            : (how == 1
                  ? null
                  : '${identity.slug}-alt.${identity.cc.toLowerCase()}');
      } else if (r.chance(0.03)) {
        match = EpgMatchKind.caseInsensitive;
        epgId = _caseVariant(xmltvId);
      } else {
        match = EpgMatchKind.exact;
        epgId = xmltvId;
      }
    } else {
      final how = r.nextInt(3);
      epgId = how == 0 ? '' : (how == 1 ? null : '${slugify(baseName)}.noepg');
    }

    if (r.chance(0.02)) quirks |= ChannelQuirk.numAsString;
    if (r.chance(0.02)) quirks |= ChannelQuirk.idAsString;
    final addedRoll = r.nextDouble();
    if (addedRoll < 0.02) {
      quirks |= ChannelQuirk.addedAsInt;
    } else if (addedRoll < 0.03) {
      quirks |= ChannelQuirk.addedEmpty;
    }
    if (archiveDays > 0 && r.chance(0.3)) {
      quirks |= ChannelQuirk.archiveAsString;
    }
    if (r.chance(0.05)) quirks |= ChannelQuirk.noCategoryIds;
    if (r.chance(0.03)) quirks |= ChannelQuirk.customSid;
    if (r.chance(0.5)) quirks |= ChannelQuirk.adultAsString;

    final directSource =
        (genIndex == 5 || genIndex == 120) && behavior == LiveBehavior.normal
        ? '/direct/live/$id.ts'
        : null;
    return MockChannel(
      streamId: id,
      num: 0,
      name: name,
      baseName: baseName,
      categoryId: categoryId,
      logoPath: logo,
      epgChannelId: epgId,
      xmltvId: xmltvId,
      epgMatch: match,
      archiveDays: archiveDays,
      variant: LiveVariant.values[genIndex % LiveVariant.values.length],
      behavior: behavior,
      added: _addedAt(r),
      streamType: spec.genre == 'radio' ? 'radio_streams' : 'live',
      countryCode: spec.cc,
      directSourcePath: directSource,
      catchupMode: catchupMode,
      quirks: quirks,
    );
  }

  static String _caseVariant(String id) {
    final dot = id.lastIndexOf('.');
    final slug = id.substring(0, dot);
    final cc = id.substring(dot + 1).toUpperCase();
    final head = slug.isEmpty ? '' : slug[0].toUpperCase() + slug.substring(1);
    var variant = '$head.$cc';
    if (variant == id) variant = id.toUpperCase();
    return variant;
  }

  List<MockChannel> _liveFixtures(Map<String, String> cat) {
    final ulusal = cat[MockFixtures.ulusalCategoryName]!;
    final trt1 = _identity('TRT 1', 'TR', 'general', forceEpg: true);
    final show = _identity('Show TV', 'TR', 'general', forceEpg: true);
    final kanalD = _identity('Kanal D', 'TR', 'general', forceEpg: true);
    final trtHaber = _identity('TRT Haber', 'TR', 'news', forceEpg: true);
    final uhd = _identity('UHD Test', 'TR', 'general', forceEpg: true);
    final haber = _identity('Haber Canlı', 'TR', 'news', forceEpg: true);
    final cocuk = _identity('Çocuk Kilitli', 'TR', 'kids', forceEpg: true);
    final kopan = _identity(
      'Kopan Yayın Testi',
      'TR',
      'general',
      forceEpg: true,
    );
    for (final i in [trt1, show, kanalD, trtHaber, uhd, haber, cocuk, kopan]) {
      i.used = true;
      i.firstUse = 0;
    }

    MockChannel fx(
      int id,
      _Identity? identity,
      String categoryId, {
      required LiveVariant variant,
      required EpgMatchKind match,
      String? epgId,
      int archive = 0,
      String? catchup,
      LiveBehavior behavior = LiveBehavior.normal,
      required int logo,
      required int addedDaysAgo,
    }) {
      return MockChannel(
        streamId: id,
        num: 0,
        name: MockFixtures.liveNames[id]!,
        baseName: identity?.baseName ?? MockFixtures.liveNames[id]!,
        categoryId: categoryId,
        logoPath: MockMedia.logoPath(logo),
        epgChannelId: epgId ?? identity?.xmltvId,
        xmltvId: identity?.xmltvId,
        epgMatch: match,
        archiveDays: archive,
        variant: variant,
        behavior: behavior,
        added: anchorDay.subtract(Duration(days: addedDaysAgo, hours: 2)),
        streamType: 'live',
        countryCode: 'TR',
        catchupMode: catchup,
      );
    }

    final test = cat['TR | Test']!;
    // Order = provider order (num): the Show TV qualities sit together.
    return [
      fx(
        1001,
        trt1,
        ulusal,
        variant: LiveVariant.h264Aac1080p25,
        match: EpgMatchKind.exact,
        archive: 3,
        catchup: 'default',
        logo: 0,
        addedDaysAgo: 40,
      ),
      fx(
        1002,
        show,
        ulusal,
        variant: LiveVariant.h264Ac351080p25,
        match: EpgMatchKind.exact,
        logo: 1,
        addedDaysAgo: 40,
      ),
      fx(
        1011,
        show,
        ulusal,
        variant: LiveVariant.h264Aac1080p25,
        match: EpgMatchKind.exact,
        logo: 1,
        addedDaysAgo: 39,
      ),
      fx(
        1012,
        show,
        ulusal,
        variant: LiveVariant.mpeg2Mp2576i25,
        match: EpgMatchKind.nameOnly,
        epgId: '',
        logo: 1,
        addedDaysAgo: 39,
      ),
      fx(
        1003,
        uhd,
        ulusal,
        variant: LiveVariant.hevcEac32160p25,
        match: EpgMatchKind.exact,
        logo: 2,
        addedDaysAgo: 3,
      ),
      fx(
        1004,
        kanalD,
        ulusal,
        variant: LiveVariant.mpeg2Mp2576i25,
        match: EpgMatchKind.exact,
        logo: 3,
        addedDaysAgo: 30,
      ),
      fx(
        1005,
        haber,
        ulusal,
        variant: LiveVariant.hls,
        match: EpgMatchKind.exact,
        logo: 4,
        addedDaysAgo: 20,
      ),
      fx(
        1006,
        cocuk,
        cat[MockFixtures.cocukCategoryName]!,
        variant: LiveVariant.h264Aac1080p25,
        match: EpgMatchKind.exact,
        logo: 5,
        addedDaysAgo: 20,
      ),
      fx(
        1010,
        trtHaber,
        cat['TR | Haber']!,
        variant: LiveVariant.h264Ac351080p25,
        match: EpgMatchKind.caseInsensitive,
        epgId: 'TRTHaber.tr',
        archive: 7,
        catchup: 'xc',
        logo: 6,
        addedDaysAgo: 25,
      ),
      fx(
        1007,
        kopan,
        test,
        variant: LiveVariant.h264Aac1080p25,
        match: EpgMatchKind.exact,
        behavior: LiveBehavior.dropAfter,
        logo: 7,
        addedDaysAgo: 10,
      ),
      fx(
        1008,
        null,
        test,
        variant: LiveVariant.h264Aac1080p25,
        match: EpgMatchKind.none,
        epgId: '',
        behavior: LiveBehavior.notFound,
        logo: 8,
        addedDaysAgo: 10,
      ),
      fx(
        1009,
        null,
        test,
        variant: LiveVariant.h264Aac1080p25,
        match: EpgMatchKind.none,
        epgId: '',
        behavior: LiveBehavior.notFound,
        logo: 9,
        addedDaysAgo: 10,
      ),
    ];
  }

  List<MockChannel> _applyBrokenEntriesAndNumbers(List<MockChannel> input) {
    final out = <MockChannel>[];
    var k = 0;
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      var name = c.name;
      var categoryId = c.categoryId;
      var quirks = c.quirks;
      if (c.streamId >= 10000 && !c.hasQuirk(ChannelQuirk.separator)) {
        // Broken entries at fixed positions (and periodically in large).
        if (k == 20 || (large && k % 2711 == 1500)) name = '';
        if (k == 33 || (large && k % 1999 == 700)) name = '  $name  ';
        if (k == 47 || k == 160 || (large && k % 997 == 300)) {
          categoryId = null;
          quirks |= ChannelQuirk.noCategoryIds;
        }
        if (k == 77 || (large && k % 4999 == 2000)) categoryId = '9999';
        if (k == 91) name = name.replaceAll(' ', '  ');
        k++;
      }
      out.add(
        MockChannel(
          streamId: c.streamId,
          num: i + 1,
          name: name,
          baseName: c.baseName,
          categoryId: categoryId,
          logoPath: c.logoPath,
          epgChannelId: c.epgChannelId,
          xmltvId: c.xmltvId,
          epgMatch: c.epgMatch,
          archiveDays: c.archiveDays,
          variant: c.variant,
          behavior: c.behavior,
          added: c.added,
          streamType: c.streamType,
          countryCode: c.countryCode,
          directSourcePath: c.directSourcePath,
          catchupMode: c.catchupMode,
          quirks: quirks,
        ),
      );
    }
    return out;
  }

  List<MockEpgChannel> _epgChannels() {
    final used = _identities.where((i) => i.used && i.hasEpg).toList()
      ..sort((a, b) {
        final c = a.firstUse.compareTo(b.firstUse);
        return c != 0 ? c : a.logoIndex.compareTo(b.logoIndex);
      });
    final r = MockRandom(0xE96C);
    final out = <MockEpgChannel>[
      for (final i in used) _epgFor(i, r, usedByStreams: true),
    ];

    // Guide channels that no stream uses (Custom EPG candidates); the large
    // guide is topped up to about a million programmes.
    final targetTotal = large
        ? _largeEpgChannelTarget
        : out.length + (out.length * 0.08).ceil() + 4;
    if (out.length < targetTotal) {
      const genres = [
        'general',
        'news',
        'sports',
        'docs',
        'kids',
        'movies',
        'music',
        'local',
      ];
      for (final cc in const ['TR', 'UK', 'DE', 'IT']) {
        for (final g in genres) {
          _pool(cc, g);
        }
      }
      final seen = <String>{for (final e in out) e.id};
      for (final i in _identities) {
        if (out.length >= targetTotal) break;
        if (i.used || !i.hasEpg) continue;
        if (seen.add(i.xmltvId)) out.add(_epgFor(i, r, usedByStreams: false));
      }
    }
    // Programmes for a channel id that has no <channel> element.
    out.add(
      const MockEpgChannel(
        id: 'orphan.programmes.tr',
        displayNames: ['Orphan'],
        iconPath: null,
        lang: 'tr',
        genre: 'general',
        utcOffsetMinutes: 180,
        seed: 0x0F0F,
        declared: false,
        usedByStreams: false,
      ),
    );
    return out;
  }

  MockEpgChannel _epgFor(
    _Identity i,
    MockRandom r, {
    required bool usedByStreams,
  }) {
    final names = <String>[i.baseName];
    if (r.chance(0.4)) names.add('${i.baseName} HD');
    final plain = stripDiacritics(i.baseName);
    if (plain != i.baseName && r.chance(0.3)) names.add(plain);
    if (i.lang == 'tr' && r.chance(0.08)) names.add(trUpper(i.baseName));
    final genre = switch (i.genre) {
      'test' || 'radio' || 'allday' || 'ppv' || 'mixed' => 'general',
      _ => i.genre,
    };
    final lang = switch (i.lang) {
      'tr' || 'en' || 'it' || 'de' => i.lang,
      _ => 'en',
    };
    return MockEpgChannel(
      id: i.xmltvId,
      displayNames: names,
      iconPath: r.chance(0.85) ? MockMedia.logoPath(i.logoIndex) : null,
      lang: lang,
      genre: genre,
      utcOffsetMinutes: i.utcOffsetMinutes,
      seed: i.seed,
      usedByStreams: usedByStreams,
    );
  }

  // ----------------------------------------------------------------- movies

  static const _smallVodCategories = <String>[
    'Yerli Filmler', 'Aksiyon', 'Komedi', 'Dram', 'Bilim Kurgu', 'Belgesel', //
    'Korku', 'Gerilim', 'Romantik', 'Animasyon', 'Aile', 'Fantastik', 'Macera',
    'Suç', 'Tarih', 'Savaş', '4K UHD Filmler', 'Netflix Filmleri',
    'EN | Action', 'EN | Comedy', 'EN | Drama', 'IT | Film', 'DE | Filme',
    'DE | Komödie', 'Çocuk Filmleri', 'Yeşilçam Klasikleri',
    'Altyazılı Filmler', 'Boş Kategori',
  ];

  static const _largeVodCategories = <String>[
    'Koleksiyon | Polisiye', 'Koleksiyon | Western', 'Koleksiyon | Müzikal', //
    'Koleksiyon | Spor', 'Koleksiyon | Biyografi', 'EN | Thriller',
    'EN | Horror', 'EN | Sci-Fi', 'EN | Family', 'EN | Documentary',
    'IT | Commedia', 'IT | Azione', 'DE | Thriller', 'DE | Kinderfilme',
    'Disney+ Filmleri', 'Amazon Prime Filmleri', 'Apple TV+ Filmleri',
    'Oscar Ödüllü Filmler', 'Kült Filmler', 'Kısa Filmler',
    'Festival Filmleri', 'Dublaj Filmler',
  ];

  List<MockCategory> _vodCategories() {
    final names = <String>[
      ..._smallVodCategories,
      if (large) ...[
        for (var y = 2026; y >= 2015; y--) 'Filmler $y',
        ..._largeVodCategories,
      ],
    ];
    return [
      for (var i = 0; i < names.length; i++)
        MockCategory(
          id: '${1001 + i}',
          name: names[i],
          section: MockSection.movie,
        ),
    ];
  }

  /// Hand-written titles first (each once, shuffled), then combinations.
  String _title(
    MockRandom r,
    String key,
    List<String> handWritten,
    String Function() combine,
  ) {
    final n = _titleCounters[key] ?? 0;
    _titleCounters[key] = n + 1;
    if (n < handWritten.length) {
      final shuffled = MockRandom(hashString(key)).shuffled(handWritten);
      return shuffled[n];
    }
    return combine();
  }

  String _movieTitle(MockRandom r, String lang) {
    switch (lang) {
      case 'tr':
        return _title(r, 'movie/tr', trMovieTitles, () {
          var t = '${r.pick(trAdjectives)} ${r.pick(trNouns)}';
          if (r.chance(0.15)) t += r.pick(trTitleSuffixes);
          return t;
        });
      case 'it':
        return _title(r, 'movie/it', itMovieTitles, () {
          final adj = r.pick(itAdjectives);
          if (r.chance(0.5)) return 'Il ${r.pick(itMascNouns)} ${adj[0]}';
          final n = r.pick(itFemNouns);
          final article = n == 'Estate' || n == 'Isola' ? "L'" : 'La ';
          return '$article$n ${adj[1]}';
        });
      case 'de':
        return _title(r, 'movie/de', deMovieTitles, () {
          final adj = r.pick(deAdjectives);
          return switch (r.nextInt(3)) {
            0 => 'Der $adj ${r.pick(deMascNouns)}',
            1 => 'Die $adj ${r.pick(deFemNouns)}',
            _ => 'Das $adj ${r.pick(deNeutNouns)}',
          };
        });
      default:
        return _title(r, 'movie/en', enMovieTitles, () {
          final adj = r.pick(enAdjectives);
          final noun = r.pick(enNouns);
          var t = switch (r.nextInt(4)) {
            0 => 'The $adj $noun',
            1 => '$adj $noun',
            2 => '$noun of the ${r.pick(enNouns)}',
            _ => 'Beyond the $noun',
          };
          if (r.chance(0.12)) t += r.pick(enTitleSuffixes);
          return t;
        });
    }
  }

  List<MockMovie> _buildMovies(List<MockCategory> cats) {
    final byName = {for (final c in cats) c.name: c.id};
    final largeOnly = [
      for (final c in cats)
        if (!_smallVodCategories.contains(c.name)) c.id,
    ];
    final r = MockRandom(mixHash(rng.nextUint32(), 0x30F1E));
    final out = <MockMovie>[
      MockMovie(
        streamId: MockFixtures.kisUykusu,
        num: 1,
        name: MockFixtures.kisUykusuName,
        originalName: MockFixtures.kisUykusuName,
        categoryId: byName['Yerli Filmler'],
        posterPath: MockMedia.posterPath(0),
        backdropPath: MockMedia.backdropPath(0),
        rating: 8.1,
        year: 2014,
        containerExtension: 'mkv',
        tmdbId: 900001,
        added: anchorDay.subtract(const Duration(days: 2, hours: 5)),
        lang: 'tr',
        genre: 'Dram',
        cast: const [
          MockFixtures.sharedActor,
          'Tarık Ilgaz',
          'Hülya Sözer',
          'Cemal Uçar',
        ],
        director: 'Selim Ateş',
        durationSecs: 6720,
        country: 'Türkiye',
        age: '13+',
        seed: 0x3001,
      ),
    ];
    var nextId = 100001;
    for (var i = 1; i < scale.movieCount; i++) {
      final lang = r.weighted(
        const ['tr', 'en', 'it', 'de'],
        const [45, 35, 10, 10],
      );
      final title = _movieTitle(r, lang);
      final yearRoll = r.nextDouble();
      final year = yearRoll < 0.6
          ? r.range(2015, 2026)
          : yearRoll < 0.9
          ? r.range(1990, 2014)
          : r.range(1960, 1989);
      String? cat;
      final String genre;
      if (lang == 'tr') {
        genre = r.pick(trGenres);
        cat = r.chance(0.45)
            ? byName['Yerli Filmler']
            : (byName[genre] ?? byName['Dram']);
        if (year < 1985 && r.chance(0.5)) cat = byName['Yeşilçam Klasikleri'];
      } else if (lang == 'en') {
        genre = r.pick(enGenres);
        cat = switch (r.nextInt(5)) {
          0 => byName['EN | Action'],
          1 => byName['EN | Comedy'],
          2 => byName['EN | Drama'],
          _ => byName[r.pick(trGenres)] ?? byName['Aksiyon'],
        };
        if (r.chance(0.08)) cat = byName['Netflix Filmleri'];
        if (r.chance(0.05)) cat = byName['Altyazılı Filmler'];
      } else if (lang == 'it') {
        genre = r.pick(trGenres);
        cat = byName['IT | Film'];
      } else {
        genre = r.pick(trGenres);
        cat = r.chance(0.7) ? byName['DE | Filme'] : byName['DE | Komödie'];
      }
      if (genre == 'Animasyon' && r.chance(0.5)) cat = byName['Çocuk Filmleri'];
      if (large && year >= 2015 && r.chance(0.2)) {
        cat = byName['Filmler $year'] ?? cat;
      }
      if (large && largeOnly.isNotEmpty && r.chance(0.12)) {
        cat = r.pick(largeOnly);
      }
      var quality = '';
      if (r.chance(0.03)) {
        cat = byName['4K UHD Filmler'];
        quality = ' 4K';
      }
      if (cat == null || cat == byName['Boş Kategori']) cat = byName['Dram'];
      var name = title;
      final style = r.nextDouble();
      if (style < 0.15) {
        name = '$title ($year)';
      } else if (style < 0.18) {
        name = 'TR: $title';
      } else if (style < 0.20) {
        name = '[Altyazılı] $title';
      } else if (style < 0.21) {
        name = '4K | $title';
      }
      name = '$name$quality';
      if (i == 37 || (large && i % 9973 == 5000)) name = '';
      var quirks = 0;
      final ratingRoll = r.nextDouble();
      double? rating = r.range(40, 93) / 10.0;
      if (ratingRoll < 0.03) {
        rating = null;
        quirks |= MovieQuirk.ratingNull;
      } else if (ratingRoll < 0.08) {
        rating = null;
        quirks |= MovieQuirk.ratingEmpty;
      } else if (ratingRoll < 0.10) {
        rating = null;
        quirks |= MovieQuirk.ratingNA;
      } else if (ratingRoll < 0.40) {
        quirks |= MovieQuirk.ratingAsNumber;
      }
      if (r.chance(0.05)) quirks |= MovieQuirk.rating5AsString;
      final yearType = r.nextDouble();
      if (yearType < 0.1) {
        quirks |= MovieQuirk.yearAsInt;
      } else if (yearType < 0.15) {
        quirks |= MovieQuirk.yearMissing;
      }
      int? tmdb;
      if (r.chance(0.6)) {
        tmdb = 900000 + mixHash(i, 0x7D) % 99999;
        if (r.chance(0.2)) quirks |= MovieQuirk.tmdbAsInt;
        if (r.chance(0.15)) quirks |= MovieQuirk.tmdbIdKey;
      }
      String? poster = MockMedia.posterPath(i);
      if (r.chance(0.1)) {
        poster = null;
        if (r.chance(0.4)) quirks |= MovieQuirk.posterNull;
      }
      if (r.chance(0.02)) quirks |= MovieQuirk.infoEmpty;
      if (r.chance(0.02)) quirks |= MovieQuirk.numAsString;
      // Alternate the two VOD files; a few upper-case extensions.
      var ext = i.isEven ? 'mkv' : 'mp4';
      if (i == 12 || (large && i % 5003 == 12)) ext = 'MKV';
      out.add(
        MockMovie(
          streamId: nextId,
          num: i + 1,
          name: name,
          originalName: title,
          categoryId: cat,
          posterPath: poster,
          backdropPath: r.chance(0.85) ? MockMedia.backdropPath(i) : null,
          rating: rating,
          year: year,
          containerExtension: ext,
          tmdbId: tmdb,
          added: _addedAt(r),
          lang: lang,
          genre: genre,
          cast: _castFor(r, lang),
          director: _directorFor(r, lang),
          durationSecs: r.range(80, 180) * 60 + r.range(0, 59),
          country: switch (lang) {
            'tr' => r.pick(trCountries),
            'it' => 'Italia',
            'de' => 'Deutschland',
            _ => r.pick(enCountries),
          },
          age: r.pick(ageRatings),
          seed: mixHash(nextId, 0xF11),
          directSourcePath: r.chance(0.01)
              ? '/direct/movie/$nextId.$ext'
              : null,
          quirks: quirks,
        ),
      );
      nextId += 1 + (r.chance(0.03) ? r.range(1, 3) : 0);
    }
    return out;
  }

  // ----------------------------------------------------------------- series

  static const _smallSeriesCategories = <String>[
    'Yerli Diziler',
    'Netflix Series',
    'Netflix Dizileri',
    'Disney+ Dizileri', //
    'Amazon Prime Dizileri', 'BluTV Dizileri', 'Exxen Dizileri',
    'Yabancı Diziler', 'Belgesel Dizileri', 'Animasyon Dizileri',
    'Kore Dizileri', 'Anime', 'EN | TV Shows', 'IT | Serie TV', 'DE | Serien',
    'Çocuk Dizileri', 'Reality Show', 'Boş Kategori',
  ];

  static const _largeSeriesCategories = <String>[
    'Gain Dizileri',
    'TOD Dizileri',
    'HBO Max Dizileri',
    'Apple TV+ Dizileri', //
    'Mini Diziler', 'Polisiye Diziler', 'Tarihi Diziler', 'Komedi Dizileri',
    'Bilim Kurgu Dizileri', 'EN | Crime', 'EN | Comedy Series',
    'EN | Sci-Fi Series', 'DE | Krimiserien', 'IT | Fiction',
  ];

  List<MockCategory> _seriesCategories() {
    final names = [
      ..._smallSeriesCategories,
      if (large) ..._largeSeriesCategories,
    ];
    return [
      for (var i = 0; i < names.length; i++)
        MockCategory(
          id: '${2001 + i}',
          name: names[i],
          section: MockSection.series,
        ),
    ];
  }

  String _seriesTitle(MockRandom r, String lang) {
    switch (lang) {
      case 'tr':
        return _title(r, 'series/tr', trSeriesTitles, () {
          var t = '${r.pick(trAdjectives)} ${r.pick(trNouns)}';
          if (r.chance(0.3)) t += r.pick(trSeriesSuffixes);
          return t;
        });
      case 'it':
        return _title(
          r,
          'series/it',
          itSeriesTitles,
          () => _movieTitle(r, 'it'),
        );
      case 'de':
        return _title(
          r,
          'series/de',
          deSeriesTitles,
          () => _movieTitle(r, 'de'),
        );
      default:
        return _title(
          r,
          'series/en',
          enSeriesTitles,
          () =>
              '${r.chance(0.5) ? 'The ' : ''}${r.pick(enAdjectives)} ${r.pick(enNouns)}${r.pick(enSeriesSuffixes)}',
        );
    }
  }

  List<MockSeries> _buildSeries(List<MockCategory> cats) {
    final byName = {for (final c in cats) c.name: c.id};
    final largeOnly = [
      for (final c in cats)
        if (!_smallSeriesCategories.contains(c.name)) c.id,
    ];
    final r = MockRandom(mixHash(rng.nextUint32(), 0x5E41E5));

    MockSeries fixture({
      required int id,
      required String name,
      required int num,
      required List<MockSeason> seasons,
      required EpisodesShape shape,
      required int poster,
      required List<int> backdrops,
      required String release,
      required int modifiedDaysAgo,
      required String genre,
      required List<String> cast,
      int quirks = 0,
    }) {
      return MockSeries(
        seriesId: id,
        num: num,
        name: name,
        categoryId: byName['Yerli Diziler'],
        coverPath: MockMedia.posterPath(poster),
        backdropPaths: [for (final b in backdrops) MockMedia.backdropPath(b)],
        rating: 7.6,
        year: int.parse(release.substring(0, 4)),
        releaseDate: release,
        lastModified: anchorDay.subtract(
          Duration(days: modifiedDaysAgo, hours: 3),
        ),
        lang: 'tr',
        genre: genre,
        cast: cast,
        director: 'Ece Turan',
        plot: _fixturePlots[id] ?? _plot(MockRandom(id), 'tr', cast.first),
        seasons: seasons,
        firstEpisodeId: 0,
        shape: shape,
        tmdbId: 900000 + id,
        episodeRunTime: 45,
        seed: mixHash(id, 0x5E),
        quirks: quirks,
      );
    }

    final out = <MockSeries>[
      fixture(
        id: MockFixtures.sicakKafa,
        name: MockFixtures.sicakKafaName,
        num: 1,
        seasons: const [
          MockSeason(1, 8, '2022-02-04'),
          MockSeason(2, 6, '2023-03-10'),
        ],
        shape: EpisodesShape.map,
        poster: 1,
        backdrops: const [1, 2],
        release: '2022-02-04',
        modifiedDaysAgo: 1,
        genre: 'Bilim Kurgu, Dram',
        cast: const [
          MockFixtures.sharedActor,
          'Barış Kaya',
          'Defne Uysal',
          'Kerem Işık',
        ],
      ),
      fixture(
        id: MockFixtures.geceYarisi,
        name: MockFixtures.geceYarisiName,
        num: 2,
        seasons: const [
          MockSeason(0, 2, '2021-10-01'),
          MockSeason(1, 6, '2021-10-08'),
          MockSeason(2, 6, '2022-10-07'),
          MockSeason(3, 5, '2023-10-06'),
        ],
        shape: EpisodesShape.list,
        poster: 2,
        backdrops: const [3],
        release: '2021-10-08',
        modifiedDaysAgo: 12,
        genre: 'Gerilim, Suç',
        cast: const ['Can Doğan', 'Gizem Toprak', MockFixtures.sharedActor],
      ),
      fixture(
        id: MockFixtures.maviKapi,
        name: MockFixtures.maviKapiName,
        num: 3,
        seasons: const [
          MockSeason(1, 5, '2020-01-15'),
          MockSeason(2, 4, '2021-01-20'),
        ],
        shape: EpisodesShape.map,
        poster: 3,
        backdrops: const [],
        release: '2020-01-15',
        modifiedDaysAgo: 30,
        genre: 'Komedi, Aile',
        cast: const ['Oya Bulut', 'Tolga Esen', 'Pınar Çınar'],
        quirks: SeriesQuirk.seasonsEmpty,
      ),
    ];

    var nextId = 7001;
    var nextEpisode = 600001;
    for (var i = out.length; i < scale.seriesCount; i++) {
      final lang = r.weighted(
        const ['tr', 'en', 'it', 'de'],
        const [50, 38, 6, 6],
      );
      final title = _seriesTitle(r, lang);
      String? cat;
      if (lang == 'tr') {
        cat = r.weighted(
          [
            byName['Yerli Diziler'],
            byName['BluTV Dizileri'],
            byName['Exxen Dizileri'],
            byName['Netflix Dizileri'],
            byName['Çocuk Dizileri'],
          ],
          const [55, 12, 10, 15, 8],
        );
      } else if (lang == 'en') {
        cat = r.weighted(
          [
            byName['Netflix Series'],
            byName['Yabancı Diziler'],
            byName['EN | TV Shows'], //
            byName['Disney+ Dizileri'], byName['Amazon Prime Dizileri'],
            byName['Belgesel Dizileri'], byName['Animasyon Dizileri'],
            byName['Kore Dizileri'], byName['Anime'], byName['Reality Show'],
          ],
          const [25, 25, 15, 8, 8, 5, 5, 4, 3, 2],
        );
      } else if (lang == 'it') {
        cat = byName['IT | Serie TV'];
      } else {
        cat = byName['DE | Serien'];
      }
      if (large && largeOnly.isNotEmpty && r.chance(0.15)) {
        cat = r.pick(largeOnly);
      }
      final seasonCount = r.weighted(
        const [1, 2, 3, 4, 5],
        const [30, 28, 20, 12, 10],
      );
      final year = r.range(2005, 2026 - (seasonCount ~/ 2));
      final release = DateTime.utc(year, r.range(1, 12), r.range(1, 28));
      final seasons = <MockSeason>[];
      final hasSpecials = r.chance(0.1);
      if (hasSpecials) {
        seasons.add(MockSeason(0, r.range(1, 3), _date(release)));
      }
      for (var s = 1; s <= seasonCount; s++) {
        seasons.add(
          MockSeason(
            s,
            r.range(4, 10),
            _date(release.add(Duration(days: 365 * (s - 1)))),
          ),
        );
      }
      // PHP turns season keys 0..n-1 into a JSON list; some panels also
      // re-index (array_values), which yields a list for 1..n.
      final shape = hasSpecials || r.chance(0.08)
          ? EpisodesShape.list
          : EpisodesShape.map;
      var quirks = 0;
      if (r.chance(0.3)) quirks |= SeriesQuirk.ratingAsNumber;
      if (r.chance(0.05)) quirks |= SeriesQuirk.ratingEmpty;
      final backdropRoll = r.nextDouble();
      if (backdropRoll < 0.03) {
        quirks |= SeriesQuirk.backdropAsString;
      } else if (backdropRoll < 0.06) {
        quirks |= SeriesQuirk.backdropNull;
      }
      final hasCover = r.chance(0.9);
      if (!hasCover && r.chance(0.4)) quirks |= SeriesQuirk.coverNull;
      if (r.chance(0.04)) quirks |= SeriesQuirk.plotEmpty;
      if (r.chance(0.3)) quirks |= SeriesQuirk.runTimeAsInt;
      if (r.chance(0.05)) quirks |= SeriesQuirk.seasonsEmpty;
      if (r.chance(0.03)) quirks |= SeriesQuirk.seasonsExtra;
      final cast = _castFor(r, lang);
      final backdropCount = r.range(0, 3);
      final series = MockSeries(
        seriesId: nextId,
        num: i + 1,
        name: i == 57 ? '' : title,
        categoryId: i == 61 ? null : cat,
        coverPath: hasCover ? MockMedia.posterPath(i + 7) : null,
        backdropPaths: [
          for (var b = 0; b < backdropCount; b++)
            MockMedia.backdropPath(i + b * 7),
        ],
        rating: r.range(50, 92) / 10.0,
        year: year,
        releaseDate: _date(release),
        lastModified: _addedAt(r),
        lang: lang,
        genre: lang == 'tr' || r.chance(0.5)
            ? '${r.pick(trGenres)}, ${r.pick(trGenres)}'
            : '${r.pick(enGenres)}, ${r.pick(enGenres)}',
        cast: cast,
        director: _directorFor(r, lang),
        plot: _plot(
          MockRandom(mixHash(nextId, 0x9107)),
          lang,
          cast.isEmpty ? null : cast.first,
        ),
        seasons: seasons,
        firstEpisodeId: nextEpisode,
        shape: shape,
        tmdbId: r.chance(0.6) ? 800000 + mixHash(i, 0x7E) % 99999 : null,
        episodeRunTime: r.weighted(
          const [25, 30, 40, 45, 50, 60],
          const [10, 15, 15, 30, 15, 15],
        ),
        seed: mixHash(nextId, 0x5E),
        quirks: quirks,
      );
      out.add(series);
      nextEpisode += series.episodeTotal;
      nextId += 1 + (r.chance(0.03) ? r.range(1, 3) : 0);
    }
    return out;
  }
}
