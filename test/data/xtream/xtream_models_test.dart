import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/xtream/xtream_models.dart';

Map<String, Object?> _account({
  Object? auth = 1,
  Object? status = 'Active',
  Object? timestampNow = 1760700000,
  Object? timeNow = '2025-10-17 14:20:00',
}) => {
  'user_info': {
    'username': 'kanal',
    'password': 'test123',
    'message': 'Welcome',
    'auth': auth,
    'status': status,
    'exp_date': '1803859200',
    'is_trial': '0',
    'active_cons': '1',
    'created_at': 1700000000,
    'max_connections': '2',
    'allowed_output_formats': ['m3u8', 'TS', 'rtmp', 'ts'],
  },
  'server_info': {
    'url': 'panel.example.com',
    'port': '8080',
    'https_port': 8443,
    'server_protocol': 'HTTP',
    'rtmp_port': '',
    'timezone': 'Europe/Istanbul',
    'timestamp_now': timestampNow,
    'time_now': timeNow,
  },
};

void main() {
  group('XtreamAccount', () {
    test('parses user_info and server_info', () {
      final a = XtreamAccount.fromJson(_account());
      expect(a.userInfo.auth, isTrue);
      expect(a.userInfo.username, 'kanal');
      expect(a.status, 'Active');
      expect(a.expDate, DateTime.utc(2027, 3, 1));
      expect(a.userInfo.isTrial, isFalse);
      expect(a.activeCons, 1);
      expect(a.maxConnections, 2);
      expect(a.allowedOutputFormats, ['m3u8', 'ts', 'rtmp']);
      expect(a.userInfo.createdAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(a.userInfo.message, 'Welcome');
      expect(a.serverInfo.url, 'panel.example.com');
      expect(a.serverInfo.port, 8080);
      expect(a.serverInfo.httpsPort, 8443);
      expect(a.serverInfo.serverProtocol, 'http');
      expect(a.serverInfo.rtmpPort, isNull);
      expect(a.serverInfo.timezone, 'Europe/Istanbul');
      expect(a.serverInfo.timestampNow, 1760700000);
      expect(a.serverInfo.timeNow, '2025-10-17 14:20:00');
      expect(a.serverUtcOffset, const Duration(hours: 3));
      expect(a.isActive, isTrue);
    });

    test('isActive follows auth and status', () {
      expect(XtreamAccount.fromJson(_account(auth: 0)).isActive, isFalse);
      expect(XtreamAccount.fromJson(_account(auth: '0')).isActive, isFalse);
      for (final s in ['Expired', 'banned', 'DISABLED', 'Inactive']) {
        expect(
          XtreamAccount.fromJson(_account(status: s)).isActive,
          isFalse,
          reason: s,
        );
      }
      expect(XtreamAccount.fromJson(_account(status: null)).isActive, isTrue);
      expect(
        XtreamAccount.fromJson(_account(status: 'Trial')).isActive,
        isTrue,
      );
    });

    test('a missing auth counts as authenticated when a status is present', () {
      expect(
        XtreamAccount.fromJson(_account(auth: null)).userInfo.auth,
        isTrue,
      );
      expect(
        XtreamAccount.fromJson(_account(auth: null, status: null))
            .userInfo
            .auth,
        isFalse,
      );
    });

    test('unlimited expiry and missing blocks', () {
      final a = XtreamAccount.fromJson({
        'user_info': {'auth': 1, 'exp_date': null, 'max_connections': ''},
        'server_info': [],
      });
      expect(a.expDate, isNull);
      expect(a.maxConnections, isNull);
      expect(a.serverUtcOffset, Duration.zero);
      expect(a.serverInfo.url, isNull);
    });

    test('never throws on junk', () {
      for (final junk in [
        null,
        'x',
        42,
        [],
        {},
        {'user_info': 'nope'},
      ]) {
        expect(() => XtreamAccount.fromJson(junk), returnsNormally);
      }
      expect(XtreamAccount.fromJson(null).isActive, isFalse);
    });

    test('toJson drops the password and round-trips', () {
      final a = XtreamAccount.fromJson(_account());
      final json = a.toJson();
      expect(json.toString(), isNot(contains('test123')));
      final b = XtreamAccount.fromJson(json);
      expect(b.expDate, a.expDate);
      expect(b.maxConnections, 2);
      expect(b.allowedOutputFormats, a.allowedOutputFormats);
      expect(b.serverUtcOffset, a.serverUtcOffset);
      expect(b.isActive, isTrue);
    });
  });

  group('xtreamServerUtcOffset', () {
    Duration offset(int ts, String now) =>
        xtreamServerUtcOffset(timestampNow: ts, timeNow: now);

    // 1760700000 = 2025-10-17 11:20:00 UTC.
    test('whole hours', () {
      expect(
        offset(1760700000, '2025-10-17 14:20:00'),
        const Duration(hours: 3),
      );
      expect(offset(1760700000, '2025-10-17 11:20:00'), Duration.zero);
      expect(
        offset(1760700000, '2025-10-17 06:20:00'),
        const Duration(hours: -5),
      );
    });

    test('rounds a few seconds of skew away', () {
      expect(
        offset(1760700000, '2025-10-17 14:20:07'),
        const Duration(hours: 3),
      );
      expect(
        offset(1760700000, '2025-10-17 14:19:53'),
        const Duration(hours: 3),
      );
    });

    test('keeps half and quarter hour zones', () {
      expect(
        offset(1760700000, '2025-10-17 16:50:00'),
        const Duration(hours: 5, minutes: 30),
      );
      expect(
        offset(1760700000, '2025-10-17 17:05:00'),
        const Duration(hours: 5, minutes: 45),
      );
      expect(
        offset(1760700000, '2025-10-17 07:50:00'),
        const Duration(hours: -3, minutes: -30),
      );
    });

    test('crosses midnight', () {
      // 2025-10-17 22:00 UTC is 2025-10-18 01:00 at +3.
      expect(
        offset(1760738400, '2025-10-18 01:00:00'),
        const Duration(hours: 3),
      );
    });

    test('zero when unknown or absurd', () {
      expect(xtreamServerUtcOffset(), Duration.zero);
      expect(
        xtreamServerUtcOffset(timestampNow: 1760700000, timeNow: 'now'),
        Duration.zero,
      );
      expect(
        xtreamServerUtcOffset(timestampNow: 0, timeNow: '2025-10-17 14:20:00'),
        Duration.zero,
      );
      expect(offset(1760700000, '2025-10-19 14:20:00'), Duration.zero);
    });

    test('accepts timestamp_now as a string or in milliseconds', () {
      expect(
        XtreamAccount.fromJson(_account(timestampNow: '1760700000'))
            .serverUtcOffset,
        const Duration(hours: 3),
      );
      expect(
        XtreamAccount.fromJson(_account(timestampNow: 1760700000000))
            .serverUtcOffset,
        const Duration(hours: 3),
      );
    });
  });

  group('XtreamCategory', () {
    test('normalizes ids and names', () {
      final list = XtreamCategory.listFromJson([
        {'category_id': '1', 'category_name': 'TR | Ulusal', 'parent_id': 0},
        {'category_id': 2, 'category_name': ' Spor ', 'parent_id': '5'},
        {'category_id': 3.0, 'category_name': ''},
        {'category_id': '', 'category_name': 'No id'},
        {'category_name': 'Missing id'},
        'garbage',
        null,
        42,
      ]);
      expect(list.map((c) => c.categoryId), ['1', '2', '3']);
      expect(list[0].categoryName, 'TR | Ulusal');
      expect(list[0].parentId, isNull);
      expect(list[1].categoryName, 'Spor');
      expect(list[1].parentId, '5');
      expect(list[2].categoryName, '3', reason: 'falls back to the id');
    });

    test('accepts PHP objects instead of lists and junk roots', () {
      expect(
        XtreamCategory.listFromJson({
          '0': {'category_id': '9', 'category_name': 'A'},
        }).single.categoryId,
        '9',
      );
      expect(XtreamCategory.listFromJson(null), isEmpty);
      expect(XtreamCategory.listFromJson('[]'), isEmpty);
    });
  });

  group('XtreamLiveStream', () {
    test('normalizes a nasty row', () {
      final s = XtreamLiveStream.fromJson({
        'num': '7',
        'name': '  TRT 1 HD  ',
        'stream_type': 'live',
        'stream_id': '1001',
        'stream_icon': false,
        'epg_channel_id': '',
        'added': '1700000000',
        'category_id': 1,
        'category_ids': [1, '4', 4, null, ''],
        'tv_archive': '1',
        'tv_archive_duration': '3',
        'direct_source': '',
        'custom_sid': null,
        'is_adult': '0',
      })!;
      expect(s.streamId, '1001');
      expect(s.num, 7);
      expect(s.name, 'TRT 1 HD');
      expect(s.streamType, 'live');
      expect(s.streamIcon, isNull);
      expect(s.epgChannelId, isNull);
      expect(s.added, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(s.categoryId, '1');
      expect(s.categoryIds, ['1', '4']);
      expect(s.tvArchive, isTrue);
      expect(s.tvArchiveDuration, 3);
      expect(s.archiveDays, 3);
      expect(s.directSource, isNull);
      expect(s.customSid, isNull);
      expect(s.isAdult, isFalse);
    });

    test('ints, nulls and missing keys', () {
      final s = XtreamLiveStream.fromJson({
        'stream_id': 1002.0,
        'tv_archive': 0,
        'tv_archive_duration': 7,
        'category_id': null,
      })!;
      expect(s.streamId, '1002');
      expect(s.name, '');
      expect(s.num, isNull);
      expect(s.added, isNull);
      expect(s.categoryId, isNull);
      expect(s.categoryIds, isEmpty);
      expect(s.tvArchive, isFalse);
      expect(s.archiveDays, 0);
    });

    test('skips rows without stream_id', () {
      final list = XtreamLiveStream.listFromJson([
        {'stream_id': 1, 'name': 'A'},
        {'stream_id': '', 'name': 'B'},
        {'stream_id': null, 'name': 'C'},
        {'name': 'D'},
        {'stream_id': [], 'name': 'E'},
        ['not', 'a', 'map'],
        {'stream_id': '2', 'name': 'F', 'category_ids': '3,5'},
      ]);
      expect(list.map((s) => s.name), ['A', 'F']);
      expect(list[1].categoryIds, ['3', '5']);
    });

    test('negative archive duration becomes 0', () {
      final s = XtreamLiveStream.fromJson({
        'stream_id': 1,
        'tv_archive': true,
        'tv_archive_duration': '-2',
      })!;
      expect(s.tvArchiveDuration, 0);
    });
  });

  group('XtreamVodStream', () {
    test('ratings, tmdb, extension and year', () {
      final list = XtreamVodStream.listFromJson([
        {
          'stream_id': '3001',
          'name': 'Kış Uykusu',
          'rating': '8.1',
          'rating_5based': 4.05,
          'container_extension': '.mkv',
          'tmdb': '',
          'tmdb_id': '254320',
          'year': '2014',
          'added': 1700000000,
        },
        {
          'stream_id': 3002,
          'name': 'No rating',
          'rating': '0',
          'rating_5based': '3.5',
          'tmdb': 0,
          'releasedate': '2008-01-20',
          'container_extension': '',
        },
        {'stream_id': 3003, 'rating': 'N/A', 'rating_5based': ''},
        {'stream_id': 3004, 'rating': 11},
      ]);
      expect(list, hasLength(4));
      expect(list[0].rating, 8.1);
      expect(list[0].rating5Based, 4.05);
      expect(list[0].containerExtension, 'mkv');
      expect(list[0].tmdbId, 254320);
      expect(list[0].year, 2014);
      expect(list[1].rating, 7.0, reason: 'derived from rating_5based');
      expect(list[1].tmdbId, isNull);
      expect(list[1].year, 2008);
      expect(list[1].containerExtension, isNull);
      expect(list[2].rating, isNull);
      expect(list[2].name, '');
      expect(list[3].rating, isNull, reason: 'out of range');
    });
  });

  group('XtreamSeries', () {
    test('parses a list row', () {
      final s = XtreamSeries.listFromJson([
        {
          'num': 1,
          'name': 'Sıcak Kafa',
          'series_id': 5001,
          'cover': 'http://img/cover.jpg',
          'plot': 'Plot',
          'cast': 'A, B',
          'director': 'D',
          'genre': 'Drama',
          'releaseDate': '2022-03-04',
          'last_modified': '1700000000',
          'rating': '7',
          'rating_5based': 3.5,
          'backdrop_path': ['http://img/b1.jpg', '', 'http://img/b2.jpg'],
          'youtube_trailer': '',
          'episode_run_time': '45',
          'category_id': '20',
        },
        {'name': 'no id'},
      ]).single;
      expect(s.seriesId, '5001');
      expect(s.name, 'Sıcak Kafa');
      expect(s.releaseDate, '2022-03-04');
      expect(s.releaseDateParsed, DateTime.utc(2022, 3, 4));
      expect(s.year, 2022);
      expect(s.lastModified, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(s.rating, 7.0);
      expect(s.backdrops, ['http://img/b1.jpg', 'http://img/b2.jpg']);
      expect(s.youtubeTrailer, isNull);
      expect(s.episodeRunTime, 45);
      expect(s.categoryIds, ['20']);
    });

    test('a single backdrop string is not split on commas', () {
      final s = XtreamSeries.fromJson({
        'series_id': 1,
        'backdrop_path': 'http://img/a,b.jpg',
      })!;
      expect(s.backdrops, ['http://img/a,b.jpg']);
    });
  });

  group('XtreamVodInfo', () {
    test('parses info, technical details and movie_data', () {
      final info = XtreamVodInfo.fromJson({
        'info': {
          'tmdb_id': '254320',
          'name': 'Kış Uykusu',
          'o_name': 'Winter Sleep',
          'cover_big': 'http://img/big.jpg',
          'movie_image': 'http://img/poster.jpg',
          'releasedate': '2014-06-13',
          'youtube_trailer': 'abc123',
          'director': 'Nuri Bilge Ceylan',
          'actors': 'Haluk Bilginer',
          'cast': 'Haluk Bilginer, Melisa Sözen',
          'description': 'A hotel owner…',
          'plot': 'Plot text',
          'genre': 'Drama',
          'age': '13+',
          'mpaa_rating': 'PG-13',
          'country': 'Turkey',
          'backdrop_path': ['http://img/bd1.jpg'],
          'duration_secs': 11760,
          'duration': '03:16:00',
          'video': {
            'codec_name': 'h264',
            'profile': 'High',
            'width': 1920,
            'height': '1080',
            'display_aspect_ratio': '16:9',
            'pix_fmt': 'yuv420p',
            'field_order': 'progressive',
            'avg_frame_rate': '25/1',
            'tags': {'BPS': '4500000', 'language': 'tur'},
          },
          'audio': {
            'codec_name': 'ac3',
            'channels': '6',
            'channel_layout': '5.1(side)',
            'sample_rate': '48000',
            'bit_rate': 384000,
            'tags': {'language': 'tur'},
          },
          'bitrate': '4884',
          'rating': '8.1',
        },
        'movie_data': {
          'stream_id': 3001,
          'name': 'Kış Uykusu',
          'added': '1700000000',
          'category_id': '30',
          'container_extension': 'mkv',
          'custom_sid': '',
          'direct_source': '',
        },
      });
      expect(info.streamId, '3001');
      expect(info.tmdbId, 254320);
      expect(info.name, 'Kış Uykusu');
      expect(info.originalName, 'Winter Sleep');
      expect(info.year, 2014);
      expect(info.releaseDateParsed, DateTime.utc(2014, 6, 13));
      expect(info.overview, 'A hotel owner…');
      expect(info.castText, 'Haluk Bilginer');
      expect(info.ageRating, 'PG-13');
      expect(info.durationSecs, 11760);
      expect(info.backdrops, ['http://img/bd1.jpg']);
      expect(info.rating, 8.1);
      expect(info.bitrate, 4884);
      expect(info.video!.codecName, 'h264');
      expect(info.video!.width, 1920);
      expect(info.video!.height, 1080);
      expect(info.video!.frameRate, 25.0);
      expect(info.video!.bitRate, 4500000);
      expect(info.video!.language, 'tur');
      expect(info.audio!.codecName, 'ac3');
      expect(info.audio!.channels, 6);
      expect(info.audio!.channelLayout, '5.1(side)');
      expect(info.audio!.sampleRate, 48000);
      expect(info.audio!.bitRate, 384000);
      expect(info.containerExtension, 'mkv');
      expect(info.added, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(info.categoryId, '30');
      expect(info.directSource, isNull);
      expect(info.isEmpty, isFalse);
    });

    test('PHP empty arrays and fallbacks', () {
      final info = XtreamVodInfo.fromJson({
        'info': {
          'duration': '01:52:30',
          'plot': 'Only plot',
          'cast': 'Cast only',
          'age': '18+',
          'video': [],
          'audio': [],
          'backdrop_path': 'http://img/single.jpg',
          'tmdb_id': '0',
          'rating': '',
          'video_frame': null,
        },
        'movie_data': [],
      }, vodId: '77');
      expect(info.streamId, '77');
      expect(info.durationSecs, 6750);
      expect(info.overview, 'Only plot');
      expect(info.castText, 'Cast only');
      expect(info.ageRating, '18+');
      expect(info.video, isNull);
      expect(info.audio, isNull);
      expect(info.backdrops, ['http://img/single.jpg']);
      expect(info.tmdbId, isNull);
      expect(info.rating, isNull);
    });

    test('empty responses never throw', () {
      for (final junk in [
        null,
        [],
        {},
        'x',
        {'info': [], 'movie_data': []},
      ]) {
        final info = XtreamVodInfo.fromJson(junk);
        expect(info.isEmpty, isTrue, reason: '$junk');
      }
    });

    test('frame rate fractions', () {
      final v = XtreamVideoInfo.fromJson({
        'r_frame_rate': '30000/1001',
        'avg_frame_rate': '0/0',
      })!;
      expect(v.frameRate, closeTo(29.97, 0.01));
    });
  });

  group('XtreamSeriesInfo', () {
    Map<String, Object?> episode(Object? id, Object? num, {Object? season}) => {
      'id': id,
      'episode_num': num,
      'title': 'Episode $num',
      'container_extension': 'mp4',
      'season': ?season,
      'info': {
        'movie_image': 'http://img/e$num.jpg',
        'plot': 'Plot $num',
        'duration_secs': '2700',
        'releasedate': '2022-03-04',
        'rating': '7.5',
      },
    };

    final seasons = [
      {'season_number': 2, 'name': 'Season 2', 'episode_count': '1'},
      {
        'season_number': '1',
        'name': 'Season 1',
        'cover': '',
        'cover_big': 'http://img/s1.jpg',
        'air_date': '2022-03-04',
        'episode_count': 2,
      },
      {'name': 'no number'},
    ];

    void expectSameShape(XtreamSeriesInfo info) {
      expect(info.episodes.keys, [1, 2]);
      expect(info.episodes[1]!.map((e) => e.id), ['101', '102']);
      expect(info.episodes[1]!.map((e) => e.episodeNum), [1, 2]);
      expect(info.episodes[2]!.single.id, '201');
      expect(info.episodes[2]!.single.season, 2);
      expect(info.episodes[1]!.first.seriesId, '5001');
      expect(info.episodes[1]!.first.durationSecs, 2700);
      expect(info.episodes[1]!.first.rating, 7.5);
      expect(info.episodes[1]!.first.movieImage, 'http://img/e1.jpg');
      expect(info.episodes[1]!.first.containerExtension, 'mp4');
    }

    test('episodes as a map keyed by season', () {
      final info = XtreamSeriesInfo.fromJson({
        'seasons': seasons,
        'info': {'name': 'Sıcak Kafa', 'backdrop_path': []},
        'episodes': {
          '2': [episode('201', 1, season: 2)],
          '1': [
            episode('102', '2', season: '1'),
            episode(101, 1, season: 1),
            episode(null, 3),
          ],
        },
      }, seriesId: '5001');
      expectSameShape(info);
      expect(info.seasons.map((s) => s.seasonNumber), [1, 2]);
      expect(info.seasons.first.cover, 'http://img/s1.jpg');
      expect(info.seasons.first.episodeCount, 2);
      expect(info.info!.seriesId, '5001');
      expect(info.info!.name, 'Sıcak Kafa');
      expect(info.seasonNumbers, [1, 2]);
    });

    test('episodes as a list of per-season lists', () {
      final info = XtreamSeriesInfo.fromJson({
        'seasons': seasons,
        'episodes': [
          [episode('101', 1), episode('102', 2)],
          [episode('201', 1)],
        ],
      }, seriesId: '5001');
      expectSameShape(info);
    });

    test('episodes as a flat list with season fields', () {
      final info = XtreamSeriesInfo.fromJson({
        'episodes': [
          episode('201', 1, season: '2'),
          episode('101', 1, season: 1),
          episode('102', 2, season: 1),
          'junk',
        ],
      }, seriesId: '5001');
      expectSameShape(info);
      expect(info.seasons, isEmpty);
      expect(info.seasonNumbers, [1, 2]);
    });

    test('map keys win over episode season fields; numbers fall back', () {
      final info = XtreamSeriesInfo.fromJson({
        'episodes': {
          '3': [
            {'id': 'a', 'season': 9},
            {'id': 'b'},
          ],
          'specials': [
            {'id': 'c', 'season': 0, 'episode_num': 1},
          ],
        },
      });
      expect(info.episodes.keys, [0, 3]);
      expect(info.episodes[3]!.map((e) => e.episodeNum), [1, 2]);
      expect(info.episodes[3]!.every((e) => e.season == 3), isTrue);
      expect(info.episodes[3]!.first.title, '');
      expect(info.episodes[0]!.single.id, 'c');
    });

    test('junk never throws', () {
      for (final junk in [
        null,
        [],
        'x',
        {'episodes': 'x', 'seasons': 'y', 'info': []},
        {
          'episodes': {
            '1': {'0': 'bad'},
          },
        },
      ]) {
        final info = XtreamSeriesInfo.fromJson(junk);
        expect(info.episodes, isEmpty);
        expect(info.info, isNull);
      }
    });

    test('episode list stays sorted when numbers arrive out of order', () {
      final info = XtreamSeriesInfo.fromJson({
        'episodes': {
          '1': [episode('3', 3), episode('1', 1), episode('2', 2)],
        },
      });
      expect(info.episodes[1]!.map((e) => e.id), ['1', '2', '3']);
      expect(
        () => info.episodes[1]!.add(info.episodes[1]!.first),
        throwsA(anything),
      );
    });
  });

  group('XtreamEpgListing', () {
    test('base64 title and description, timestamps', () {
      final list = XtreamEpgListing.listFromJson({
        'epg_listings': [
          {
            'id': '55',
            'epg_id': '7',
            'title': 'QWvFn2FtIEhhYmVybGVyaQ==',
            'lang': 'tr',
            'start': '2025-10-17 20:00:00',
            'end': '2025-10-17 21:00:00',
            'description': 'R8O8bsO8biDDtnpldGkgdmUgaGF2YSBkdXJ1bXUu',
            'channel_id': 'trt1.tr',
            'start_timestamp': '1760720400',
            'stop_timestamp': '1760724000',
            'now_playing': 1,
            'has_archive': '1',
          },
        ],
      });
      final l = list.single;
      expect(l.title, 'Akşam Haberleri');
      expect(l.description, 'Günün özeti ve hava durumu.');
      expect(l.start, DateTime.utc(2025, 10, 17, 17));
      expect(l.stop, DateTime.utc(2025, 10, 17, 18));
      expect(l.start.isUtc, isTrue);
      expect(l.channelId, 'trt1.tr');
      expect(l.id, '55');
      expect(l.epgId, '7');
      expect(l.lang, 'tr');
      expect(l.nowPlaying, isTrue);
      expect(l.hasArchive, isTrue);
    });

    test('plain-text titles are kept', () {
      final l = XtreamEpgListing.fromJson({
        'title': 'Evening News',
        'description': '',
        'start_timestamp': 1760720400,
        'stop_timestamp': 1760724000,
      })!;
      expect(l.title, 'Evening News');
      expect(l.description, isNull);
      expect(l.nowPlaying, isFalse);
      expect(l.hasArchive, isFalse);
    });

    test('falls back to server wall-clock strings with the offset', () {
      final l = XtreamEpgListing.fromJson({
        'title': 'TmV3cw==',
        'start': '2025-10-17 20:00:00',
        'end': '2025-10-17 21:30:00',
      }, serverOffset: const Duration(hours: 3))!;
      expect(l.title, 'News');
      expect(l.start, DateTime.utc(2025, 10, 17, 17));
      expect(l.stop, DateTime.utc(2025, 10, 17, 18, 30));
    });

    test('skips invalid rows and sorts by start', () {
      final list = XtreamEpgListing.listFromJson([
        {'title': 'B', 'start_timestamp': 2000, 'stop_timestamp': 3000},
        {'title': 'no times'},
        {'title': 'reversed', 'start_timestamp': 5000, 'stop_timestamp': 4000},
        {'title': 'zero', 'start_timestamp': 5000, 'stop_timestamp': 5000},
        {'title': 'A', 'start_timestamp': '1000', 'stop_timestamp': '2000'},
        'junk',
      ]);
      expect(list.map((l) => l.title), ['A', 'B']);
    });

    test('junk roots', () {
      expect(XtreamEpgListing.listFromJson(null), isEmpty);
      expect(XtreamEpgListing.listFromJson({'epg_listings': {}}), isEmpty);
      expect(XtreamEpgListing.listFromJson({'epg_listings': null}), isEmpty);
      expect(XtreamEpgListing.listFromJson('x'), isEmpty);
    });
  });
}
