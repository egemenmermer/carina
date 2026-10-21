import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/mock_server/src/server.dart';
import 'helpers.dart';

void main() {
  late FakeMedia media;
  late MockServer server;
  late String base;

  setUpAll(() async {
    media = await FakeMedia.create();
    server = await MockServer.start(
      port: 0,
      mediaDir: media.mediaDir,
      liveDir: media.liveDir,
      dropAfter: const Duration(seconds: 1),
    );
    base = server.baseUrl;
  });

  tearDownAll(() async {
    await server.stop();
    await media.delete();
  });

  group('VOD files with HTTP Range', () {
    test('full GET advertises ranges', () async {
      final r = await fetch('$base/movie/$creds/3001.mkv');
      expect(r.status, 200);
      expect(r.header('accept-ranges'), 'bytes');
      expect(r.header('content-type'), 'video/x-matroska');
      expect(r.body, await media.media(MockMedia.vodTracksMkv).readAsBytes());
    });

    test('206 with the exact bytes', () async {
      final file = await media.media(MockMedia.vodTracksMkv).readAsBytes();
      final r = await fetch(
        '$base/movie/$creds/3001.mkv',
        headers: {'range': 'bytes=1000-1999'},
      );
      expect(r.status, 206);
      expect(r.header('content-range'), 'bytes 1000-1999/${file.length}');
      expect(r.header('content-length'), '1000');
      expect(r.body, file.sublist(1000, 2000));

      final open = await fetch(
        '$base/movie/$creds/3001.mkv',
        headers: {'range': 'bytes=299000-'},
      );
      expect(open.status, 206);
      expect(open.body, file.sublist(299000));

      final suffix = await fetch(
        '$base/movie/$creds/3001.mkv',
        headers: {'range': 'bytes=-500'},
      );
      expect(suffix.status, 206);
      expect(suffix.body, file.sublist(file.length - 500));
      expect(
        suffix.header('content-range'),
        'bytes ${file.length - 500}-${file.length - 1}/${file.length}',
      );

      final clipped = await fetch(
        '$base/movie/$creds/3001.mkv',
        headers: {'range': 'bytes=299990-999999'},
      );
      expect(clipped.status, 206);
      expect(clipped.body, file.sublist(299990));
    });

    test('416 for an unsatisfiable range', () async {
      final r = await fetch(
        '$base/movie/$creds/3001.mkv',
        headers: {'range': 'bytes=999999-'},
      );
      expect(r.status, 416);
      expect(r.header('content-range'), 'bytes */300000');
    });

    test('HEAD returns the length without a body', () async {
      final r = await fetch('$base/movie/$creds/3001.mkv', method: 'HEAD');
      expect(r.status, 200);
      expect(r.header('content-length'), '300000');
      expect(r.body, isEmpty);
    });

    test('movies alternate the two files; episodes resolve', () async {
      final mp4 = server.catalog.movies.firstWhere(
        (m) => m.containerExtension == 'mp4',
      );
      final r = await fetch(
        '$base/movie/$creds/${mp4.streamId}.mp4',
        headers: {'range': 'bytes=0-9'},
      );
      expect(r.status, 206);
      expect(r.header('content-type'), 'video/mp4');
      expect(
        r.body,
        (await media.media(MockMedia.h264Aac720p50Mp4).readAsBytes()).sublist(
          0,
          10,
        ),
      );

      final episodeId = MockFixtures.episodeId(MockFixtures.sicakKafa, 1, 1);
      final ep = await fetch(
        '$base/series/$creds/$episodeId.mkv',
        headers: {'range': 'bytes=0-99'},
      );
      expect(ep.status, 206);
      expect(
        ep.body,
        (await media.media(MockMedia.vodTracksMkv).readAsBytes()).sublist(
          0,
          100,
        ),
      );
      expect((await fetch('$base/series/$creds/123.mkv')).status, 404);
      expect((await fetch('$base/movie/$creds/1.mkv')).status, 404);
    });

    test('credentials are checked on stream URLs', () async {
      expect((await fetch('$base/movie/carina/wrong/3001.mkv')).status, 401);
      expect((await fetch('$base/movie/expired/test123/3001.mkv')).status, 403);
      expect((await fetch('$base/live/carina/wrong/1001.ts')).status, 401);
    });
  });

  group('live TS', () {
    test('is paced near real time after a ~2 s burst', () async {
      // The fake TS carries 1,000 packets (188 kB) per second of PCR time.
      const perSecond = 188 * 1000;
      final r = await readStreamFor(
        '$base/live/$creds/1001.ts',
        const Duration(milliseconds: 1500),
      );
      expect(r.status, 200);
      expect(r.done, isFalse);
      expect(r.bytes, greaterThan(perSecond * 2.4), reason: 'burst + 1.5 s');
      expect(
        r.bytes,
        lessThan(perSecond * 6.5),
        reason: 'not the whole 10 s file at once',
      );
    });

    test('loops the file', () async {
      final short = await FakeMedia.create(tsSeconds: 1);
      final s = await MockServer.start(
        port: 0,
        mediaDir: short.mediaDir,
        liveDir: short.liveDir,
      );
      try {
        final r = await readStreamFor(
          '${s.baseUrl}/live/$creds/1001.ts',
          const Duration(milliseconds: 1500),
        );
        expect(
          r.bytes,
          greaterThan(188 * 1000 * 2),
          reason: 'more than two copies of a 1 s file',
        );
      } finally {
        await s.stop();
        await short.delete();
      }
    });

    test('every TS variant is served as video/mp2t', () async {
      for (final id in [1001, 1002, 1003, 1004]) {
        final r = await readStreamFor(
          '$base/live/$creds/$id.ts',
          const Duration(milliseconds: 200),
        );
        expect(r.status, 200, reason: '$id');
        expect(r.contentType, 'video/mp2t');
        expect(r.bytes, greaterThan(0));
      }
    });

    test('the drop channel ends after dropAfter', () async {
      final r = await readStreamFor(
        '$base/live/$creds/${MockFixtures.dropAfter10s}.ts',
        const Duration(seconds: 6),
      );
      expect(r.done, isTrue);
      expect(r.elapsed, lessThan(const Duration(seconds: 4)));
      expect(r.bytes, greaterThan(0));
    });

    test('404 channels and unknown ids', () async {
      for (final id in MockFixtures.notFoundLiveIds) {
        final r = await fetch('$base/live/$creds/$id.ts');
        expect(r.status, 404);
        expect(r.text, contains('offline'));
      }
      expect((await fetch('$base/live/$creds/777.ts')).status, 404);
    });

    test('missing media gives a clear 404', () async {
      final empty = await Directory.systemTemp.createTemp('carina_mock_empty_');
      final s = await MockServer.start(port: 0, mediaDir: empty.path);
      try {
        final r = await fetch('${s.baseUrl}/live/$creds/1001.ts');
        expect(r.status, 404);
        expect(
          r.text,
          contains('Media file not found: ${MockMedia.h264Aac1080p25}'),
        );
        final m = await fetch('${s.baseUrl}/movie/$creds/3001.mkv');
        expect(m.status, 404);
        expect(m.text, contains(MockMedia.vodTracksMkv));
        final hls = await fetch('${s.baseUrl}/live/$creds/1005.m3u8');
        expect(hls.status, 404);
        expect(hls.text, contains('not running'));
        final img = await fetch('${s.baseUrl}/img/poster_00.jpg');
        expect(img.status, 404);
      } finally {
        await s.stop();
        await empty.delete(recursive: true);
      }
    });

    test('direct_source URLs play', () async {
      final direct = server.catalog.channels.firstWhere(
        (c) => c.directSourcePath != null,
      );
      final r = await readStreamFor(
        '$base${direct.directSourcePath}',
        const Duration(milliseconds: 200),
      );
      expect(r.status, anyOf(200, 302));
    });
  });

  group('live HLS', () {
    test('the HLS channel redirects .ts to .m3u8', () async {
      final r = await fetch('$base/live/$creds/1005.ts');
      expect(r.status, 302);
      expect(r.header('location'), endsWith('/live/$creds/1005.m3u8'));
    });

    test('the playlist is served with rewritten segment URIs', () async {
      await media.writePlaylist();
      final r = await fetch('$base/live/$creds/1005.m3u8');
      expect(r.status, 200);
      expect(r.header('content-type'), 'application/vnd.apple.mpegurl');
      expect(r.text, contains('#EXT-X-MEDIA-SEQUENCE:42'));
      expect(r.text, contains('\n/hls/seg_00042.ts\n'));
      expect(r.text, contains('\n/hls/seg_00043.ts\n'));
      expect(r.text, isNot(contains('writer.invalid')));
      final seg = await fetch('$base/hls/seg_00042.ts');
      expect(seg.status, 200);
      expect(seg.header('content-type'), 'video/mp2t');
      expect((await fetch('$base/hls/seg_99999.ts')).status, 404);
    });

    test('a stale playlist means the writer is not running', () async {
      final playlist = media.live('index.m3u8');
      await playlist.setLastModified(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final r = await fetch('$base/live/$creds/1005.m3u8');
      expect(r.status, 404);
      expect(r.text, contains('stopped'));
      await media.writePlaylist();
      expect((await fetch('$base/live/$creds/1005.m3u8')).status, 200);
      // A playlist that ended means the writer stopped.
      await media
          .live('index.m3u8')
          .writeAsString(
            '#EXTM3U\n#EXTINF:2.0,\nseg_00042.ts\n#EXT-X-ENDLIST\n',
          );
      final ended = await fetch('$base/live/$creds/1005.m3u8');
      expect(ended.status, 404);
      expect(ended.text, contains('ENDLIST'));
      await media.writePlaylist();
    });
  });

  group('catch-up', () {
    String serverTime(DateTime utc) {
      final d = utc.add(const Duration(hours: 3));
      String two(int v) => v.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)}:${two(d.hour)}-${two(d.minute)}';
    }

    test('timeshift serves the archive with Range support', () async {
      final start = serverTime(
        DateTime.now().toUtc().subtract(const Duration(hours: 5)),
      );
      final url = '$base/timeshift/$creds/60/$start/1001.ts';
      final r = await fetch(url, headers: {'range': 'bytes=188-375'});
      expect(r.status, 206);
      expect(r.header('content-type'), 'video/mp2t');
      expect(
        r.body,
        (await media.media(MockMedia.h264Aac1080p25).readAsBytes()).sublist(
          188,
          376,
        ),
      );
      expect(server.requests.last.note, startsWith('archive start'));

      final php = await fetch(
        '$base/streaming/timeshift.php?$account&stream=1001&start=$start&duration=60',
        headers: {'range': 'bytes=0-187'},
      );
      expect(php.status, 206);
    });

    test('timeshift validates channel, window and format', () async {
      final recent = serverTime(
        DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      );
      expect(
        (await fetch('$base/timeshift/$creds/60/$recent/1002.ts')).status,
        404,
        reason: 'no archive',
      );
      final old = serverTime(
        DateTime.now().toUtc().subtract(const Duration(days: 10)),
      );
      expect(
        (await fetch('$base/timeshift/$creds/60/$old/1001.ts')).status,
        404,
        reason: 'outside 3 days',
      );
      final future = serverTime(
        DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      expect(
        (await fetch('$base/timeshift/$creds/60/$future/1001.ts')).status,
        404,
      );
      expect(
        (await fetch('$base/timeshift/$creds/60/yesterday/1001.ts')).status,
        400,
      );
      expect(
        (await fetch('$base/timeshift/carina/nope/60/$recent/1001.ts')).status,
        401,
      );
    });

    test(
      'append/shift style ?utc= on the live URL serves the archive',
      () async {
        final utc = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
        final r = await fetch(
          '$base/live/$creds/1001.ts?utc=$utc&lutc=${utc + 3600}',
          headers: {'range': 'bytes=0-187'},
        );
        expect(r.status, 206);
      },
    );

    test('flussonic paths', () async {
      final utc = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
      final abs = await fetch(
        '$base/fs/ch1001/timeshift_abs-$utc.ts',
        headers: {'range': 'bytes=0-187'},
      );
      expect(abs.status, 206);
      final playlist = await fetch('$base/fs/ch1001/index-$utc-3600.m3u8');
      expect(playlist.status, 200);
      expect(playlist.text, contains('/fs/ch1001/archive-$utc-3600.ts'));
      final live = await readStreamFor(
        '$base/fs/ch1001/mpegts',
        const Duration(milliseconds: 200),
      );
      expect(live.status, 200);
    });
  });

  group('M3U helper endpoints', () {
    test(
      'header-protected streams need the headers from the playlist',
      () async {
        expect((await fetch('$base/secure/ua/1001.ts')).status, 403);
        final ok = await readStreamFor(
          '$base/secure/ua/1001.ts',
          const Duration(milliseconds: 200),
          headers: {'user-agent': 'CarinaMock/1.0'},
        );
        expect(ok.status, 200);
        expect((await fetch('$base/secure/referer/1002.ts')).status, 403);
        final referer = await readStreamFor(
          '$base/secure/referer/1002.ts',
          const Duration(milliseconds: 200),
          headers: {'referer': '$base/'},
        );
        expect(referer.status, 200);
        expect((await fetch('$base/drm/kanal-drm.mpd')).status, 403);
      },
    );

    test('plain VOD file by extension', () async {
      final r = await fetch(
        '$base/vod/ornek-film.mp4',
        headers: {'range': 'bytes=0-9'},
      );
      expect(r.status, 206);
      expect(r.header('content-type'), 'video/mp4');
    });
  });

  group('images', () {
    test('content type, cache headers and 304', () async {
      final r = await fetch('$base/img/poster_00.jpg');
      expect(r.status, 200);
      expect(r.header('content-type'), 'image/jpeg');
      expect(r.header('cache-control'), contains('max-age'));
      final etag = r.header('etag')!;
      final again = await fetch(
        '$base/img/poster_00.jpg',
        headers: {'if-none-match': etag},
      );
      expect(again.status, 304);
      final png = await fetch('$base/img/logo_00.png');
      expect(png.header('content-type'), 'image/png');
      final since = await fetch(
        '$base/img/logo_00.png',
        headers: {'if-modified-since': r.header('last-modified')!},
      );
      expect(since.status, 304);
      final missing = await fetch('$base/img/poster_39.jpg');
      expect(missing.status, 404);
      expect(missing.text, contains('Image not found'));
      expect((await fetch('$base/img/..%2Fsecret')).status, anyOf(400, 404));
    });
  });
}
