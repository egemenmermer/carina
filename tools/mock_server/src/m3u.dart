/// M3U playlists for the mock catalog.
///
/// * [xtreamExport]: what a panel's `get.php?type=m3u_plus` returns.
/// * [extendedPlaylist]: `/playlist.m3u`, the same catalog as an extended
///   M3U with every edge case the parser must survive (BOM, CRLF, blank
///   lines, unquoted attributes, `#EXTVLCOPT`, `#EXTHTTP`, `#EXTGRP`,
///   `#KODIPROP` DRM, catch-up modes, `/movie/` and `/series/` entries).
///
/// Both are streamed in chunks; the large catalog is ~60 MB of M3U.
library;

import 'dart:async';
import 'dart:convert';

import 'catalog.dart';

const _userAgent = 'CarinaMock/1.0';

String _attr(String value) => value.replaceAll('"', "'");

/// `get.php?username=…&password=…&type=m3u_plus&output=ts`.
Stream<List<int>> xtreamExport({
  required MockCatalog catalog,
  required String origin,
  required String username,
  required String password,
  bool plus = true,
  String output = 'ts',
  int chunkSize = 1 << 16,
}) async* {
  final liveExt = output == 'm3u8' || output == 'hls' ? 'm3u8' : 'ts';
  final cats = {
    for (final c in [
      ...catalog.liveCategories,
      ...catalog.vodCategories,
      ...catalog.seriesCategories,
    ])
      '${c.section.name}/${c.id}': c.name,
  };
  final base = '$origin/';
  final b = StringBuffer('#EXTM3U\n');

  void entry(String name, String tvgId, String logo, String group, String url) {
    if (plus) {
      b
        ..write('#EXTINF:-1 tvg-id="')
        ..write(_attr(tvgId))
        ..write('" tvg-name="')
        ..write(_attr(name))
        ..write('" tvg-logo="')
        ..write(_attr(logo))
        ..write('" group-title="')
        ..write(_attr(group))
        ..write('",')
        ..write(name)
        ..write('\n');
    } else {
      b
        ..write('#EXTINF:-1,')
        ..write(name)
        ..write('\n');
    }
    b
      ..write(url)
      ..write('\n');
  }

  for (final c in catalog.channels) {
    entry(
      c.name,
      c.epgChannelId ?? '',
      c.logoPath == null ? '' : '$origin${c.logoPath}',
      cats['live/${c.categoryId}'] ?? '',
      '${base}live/$username/$password/${c.streamId}.$liveExt',
    );
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
    }
  }
  var n = 0;
  for (final m in catalog.movies) {
    entry(
      m.name,
      '',
      m.posterPath == null ? '' : '$origin${m.posterPath}',
      cats['movie/${m.categoryId}'] ?? '',
      '${base}movie/$username/$password/${m.streamId}.${m.containerExtension}',
    );
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
      if (++n % 16 == 0) await Future<void>.delayed(Duration.zero);
    }
  }
  for (final s in catalog.series) {
    final cover = s.coverPath == null ? '' : '$origin${s.coverPath}';
    final group = cats['series/${s.categoryId}'] ?? '';
    for (final e in catalog.episodesOf(s)) {
      entry(
        '${s.name} S${_two(e.season)} E${_two(e.episode)}',
        '',
        cover,
        group,
        '${base}series/$username/$password/${e.id}.${e.containerExtension}',
      );
    }
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
      if (++n % 16 == 0) await Future<void>.delayed(Duration.zero);
    }
  }
  yield utf8.encode(b.toString());
}

String _two(int v) => v < 10 ? '0$v' : '$v';

/// `/playlist.m3u`: extended M3U with edge cases.
Stream<List<int>> extendedPlaylist({
  required MockCatalog catalog,
  required String origin,
  int chunkSize = 1 << 16,
}) async* {
  const u = MockFixtures.username;
  const p = MockFixtures.password;
  final cats = {
    for (final c in [
      ...catalog.liveCategories,
      ...catalog.vodCategories,
      ...catalog.seriesCategories,
    ])
      '${c.section.name}/${c.id}': c.name,
  };
  final b = StringBuffer();
  // UTF-8 byte order mark, then the header with the guide URLs.
  b
    ..write('﻿#EXTM3U url-tvg="')
    ..write(origin)
    ..write('/epg.xml.gz" x-tvg-url="')
    ..write(origin)
    ..write('/epg.xml.gz" tvg-shift=0 refresh="3600"\r\n')
    ..write(
      '# Carina mock playlist (generated). Edge cases are spread through the list.\r\n',
    )
    ..write('\r\n');

  var entryIndex = 0;
  for (final c in catalog.channels) {
    final crlf = entryIndex % 9 == 4;
    final nl = crlf ? '\r\n' : '\n';
    if (entryIndex % 25 == 13) b.write(entryIndex % 50 == 13 ? '\n' : '   \n');
    final group = cats['live/${c.categoryId}'];
    final useExtGrp = group != null && entryIndex % 30 == 7;
    b.write('#EXTINF:-1');
    b
      ..write(' tvg-id="')
      ..write(_attr(c.epgChannelId ?? ''))
      ..write('" tvg-name="')
      ..write(_attr(c.name))
      ..write('" tvg-logo="')
      ..write(c.logoPath == null ? '' : '$origin${c.logoPath}')
      ..write('"');
    // An attribute without quotes now and then.
    if (entryIndex % 50 == 3) {
      b
        ..write(' tvg-chno=')
        ..write(c.num);
    } else {
      b
        ..write(' tvg-chno="')
        ..write(c.num)
        ..write('"');
    }
    if (group != null && !useExtGrp) {
      b
        ..write(' group-title="')
        ..write(_attr(group))
        ..write('"');
    }
    var url = '$origin/live/$u/$p/${c.streamId}.ts';
    final mode = c.catchupMode;
    if (c.archiveDays > 0 && mode != null) {
      b
        ..write(' catchup="')
        ..write(mode)
        ..write('" catchup-days="')
        ..write(c.archiveDays)
        ..write('"');
      switch (mode) {
        case 'default':
          b
            ..write(' catchup-source="')
            ..write(origin)
            ..write(
              '/timeshift/$u/$p/{duration:60}/{Y}-{m}-{d}:{H}-{M}/${c.streamId}.ts"',
            );
        case 'append':
          b.write(' catchup-source="?utc={utc}&lutc={lutc}"');
        case 'flussonic':
          url = '$origin/fs/ch${c.streamId}/mpegts';
      }
      if (entryIndex % 4 == 1) {
        b
          ..write(' tvg-rec="')
          ..write(c.archiveDays)
          ..write('"');
      }
    }
    b
      ..write(',')
      ..write(c.name)
      ..write(nl);
    if (useExtGrp) {
      b
        ..write('#EXTGRP:')
        ..write(group)
        ..write(nl);
    }
    if (c.streamId == MockFixtures.showTvFhd || entryIndex % 40 == 21) {
      b
        ..write('#EXTVLCOPT:http-user-agent=$_userAgent')
        ..write(nl)
        ..write('#EXTVLCOPT:http-referrer=$origin/')
        ..write(nl);
    } else if (entryIndex % 45 == 30) {
      b
        ..write('#EXTHTTP:{"User-Agent":"$_userAgent","Referer":"$origin/"}')
        ..write(nl);
    }
    b
      ..write(url)
      ..write(nl);
    entryIndex++;
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
    }
  }

  _edgeCases(b, origin);

  var n = 0;
  for (final m in catalog.movies) {
    final group = cats['movie/${m.categoryId}'];
    b
      ..write('#EXTINF:-1 tvg-id="" tvg-name="')
      ..write(_attr(m.name))
      ..write('" tvg-logo="')
      ..write(m.posterPath == null ? '' : '$origin${m.posterPath}')
      ..write('"');
    if (group != null) {
      b
        ..write(' group-title="')
        ..write(_attr(group))
        ..write('"');
    }
    b
      ..write(',')
      ..write(m.name)
      ..write(n % 9 == 4 ? '\r\n' : '\n')
      ..write('$origin/movie/$u/$p/${m.streamId}.${m.containerExtension}\n');
    n++;
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
      if (n % 64 == 0) await Future<void>.delayed(Duration.zero);
    }
  }
  for (final s in catalog.series) {
    final group = cats['series/${s.categoryId}'];
    final cover = s.coverPath == null ? '' : '$origin${s.coverPath}';
    for (final e in catalog.episodesOf(s)) {
      // Both "S01E02" and "S01 E02" naming styles.
      final code = e.id.isEven
          ? 'S${_two(e.season)}E${_two(e.episode)}'
          : 'S${_two(e.season)} E${_two(e.episode)}';
      final name = '${s.name} $code';
      b
        ..write('#EXTINF:-1 tvg-name="')
        ..write(_attr(name))
        ..write('" tvg-logo="')
        ..write(cover)
        ..write('"');
      if (group != null) {
        b
          ..write(' group-title="')
          ..write(_attr(group))
          ..write('"');
      }
      b
        ..write(',')
        ..write(name)
        ..write('\n')
        ..write('$origin/series/$u/$p/${e.id}.${e.containerExtension}\n');
    }
    n++;
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
      if (n % 64 == 0) await Future<void>.delayed(Duration.zero);
    }
  }
  yield utf8.encode(b.toString());
}

/// Hand-written entries in the `TEST | M3U` group.
void _edgeCases(StringBuffer b, String o) {
  const u = MockFixtures.username;
  const p = MockFixtures.password;
  const g = 'TEST | M3U';
  b
    ..write('\n# --- edge cases ---\n')
    // Plain HTTP stream URLs pointing back at the mock /live endpoints.
    ..write('#EXTINF:-1,Plain HTTP TRT 1\n')
    ..write('$o/live/$u/$p/${MockFixtures.trt1Hd}.ts?plain=1\n')
    // Unquoted attributes, duration 0.
    ..write(
      '#EXTINF:0 tvg-chno=901 group-title=Test tvg-id=kanald.tr,Plain HTTP Kanal D\r\n',
    )
    ..write('$o/live/$u/$p/${MockFixtures.kanalDSd}.ts?plain=2\r\n')
    // Live HLS by extension.
    ..write(
      '#EXTINF:-1 tvg-id="habercanli.tr" tvg-logo="$o/img/logo_04.png" group-title="$g",Haber Canlı (HLS)\n',
    )
    ..write('$o/live/$u/$p/${MockFixtures.haberCanliHls}.m3u8\n')
    // Requires the User-Agent from #EXTVLCOPT (403 otherwise).
    ..write(
      '#EXTINF:-1 tvg-id="trt1.tr" group-title="$g",Header Test (User-Agent)\n',
    )
    ..write('#EXTVLCOPT:http-user-agent=$_userAgent\n')
    ..write('$o/secure/ua/${MockFixtures.trt1Hd}.ts\n')
    // Requires the Referer from #EXTVLCOPT.
    ..write(
      '#EXTINF:-1 tvg-id="showtv.tr" group-title="$g",Header Test (Referer)\n',
    )
    ..write('#EXTVLCOPT:http-referrer=$o/\n')
    ..write('$o/secure/referer/${MockFixtures.showTvFhd}.ts\n')
    // Both headers through #EXTHTTP.
    ..write(
      '#EXTINF:-1 tvg-id="kanald.tr" group-title="$g",Header Test (EXTHTTP)\n',
    )
    ..write('#EXTHTTP:{"User-Agent":"$_userAgent","Referer":"$o/"}\n')
    ..write('$o/secure/headers/${MockFixtures.kanalDSd}.ts\n')
    // DRM entry: must be marked unsupported.
    ..write(
      '#EXTINF:-1 tvg-id="" tvg-logo="$o/img/logo_10.png" group-title="$g",DRM Test (Widevine)\n',
    )
    ..write('#KODIPROP:inputstream.adaptive.manifest_type=mpd\n')
    ..write('#KODIPROP:inputstream.adaptive.license_type=com.widevine.alpha\n')
    ..write(
      '#KODIPROP:inputstream.adaptive.license_key=https://license.example.invalid/widevine\n',
    )
    ..write('$o/drm/kanal-drm.mpd\n')
    // Comma inside an attribute value and inside the display name.
    ..write(
      '#EXTINF:-1 tvg-name="Haber, Spor ve Fazlası" group-title="Spor, Canlı",Haber, Spor ve Fazlası\n',
    )
    ..write('$o/live/$u/$p/${MockFixtures.trtHaberHd}.ts?plain=3\n')
    // Extra attributes the parser should ignore.
    ..write(
      '#EXTINF:-1 tvg-id="" tvg-country="TR" tvg-language="Turkish" tvg-type="live" radio="false" group-title="$g",Extra Attributes\n',
    )
    ..write('#EXTVLCOPT:network-caching=1000\n')
    ..write('$o/live/$u/$p/${MockFixtures.uhdTest4k}.ts?plain=4\n')
    // VOD by extension: duration > 0 and .mp4 outside /movie/.
    ..write(
      '#EXTINF:5400 tvg-logo="$o/img/poster_05.jpg" group-title="$g",Örnek Film (mp4)\n',
    )
    ..write('$o/vod/ornek-film.mp4\n')
    // No group-title, only #EXTGRP.
    ..write('#EXTINF:-1 tvg-id="trthaber.tr",Grup Testi (EXTGRP)\n')
    ..write('#EXTGRP:$g\n')
    ..write('$o/live/$u/$p/${MockFixtures.trtHaberHd}.ts?plain=5\n')
    // Broken: #EXTINF without a URL (followed by another #EXTINF).
    ..write('#EXTINF:-1 group-title="$g",Broken Entry (no URL)\n')
    ..write(
      '#EXTINF:-1 tvg-id="trt1.tr" group-title="$g" catchup="shift" catchup-days="3",Catch-up Shift Test\n',
    )
    ..write('$o/live/$u/$p/${MockFixtures.trt1Hd}.ts?plain=6\n')
    ..write('\n');
}
