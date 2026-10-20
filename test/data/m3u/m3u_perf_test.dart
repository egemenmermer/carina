import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/m3u/m3u.dart';

/// 100,000 entries: 70% live (with catch-up and option lines), 20% movies,
/// 10% episodes — the shape of a large Xtream `m3u_plus` export.
String _generatePlaylist(int count) {
  final out = StringBuffer(
    '#EXTM3U url-tvg="http://epg.example.com/guide.xml.gz" tvg-shift="0"\n',
  );
  for (var i = 0; i < count; i++) {
    final bucket = i % 10;
    if (bucket < 7) {
      out
        ..write(
          '#EXTINF:-1 tvg-id="channel$i.tr" tvg-name="TR: Channel $i HD" ',
        )
        ..write('tvg-logo="http://logo.example.com/$i.png" ')
        ..write('group-title="TR | Group ${i % 40}" catchup="xc" ')
        ..write('catchup-days="3",TR: Channel $i HD\n');
      if (i % 25 == 0) {
        out.write('#EXTVLCOPT:http-user-agent=Carina/1.0\n');
      }
      out.write('http://example.com:8080/live/kanal/test123/$i.ts\n');
    } else if (bucket < 9) {
      out
        ..write('#EXTINF:-1 tvg-id="" tvg-name="Movie $i (2024)" ')
        ..write('tvg-logo="http://logo.example.com/m$i.jpg" ')
        ..write('group-title="Movies | Action",Movie $i (2024)\n')
        ..write('http://example.com:8080/movie/kanal/test123/$i.mkv\n');
    } else {
      final season = 1 + i % 5;
      final episode = 1 + i % 20;
      final name =
          'Series ${i % 500} S${season.toString().padLeft(2, '0')} '
          'E${episode.toString().padLeft(2, '0')}';
      out
        ..write('#EXTINF:-1 tvg-id="" tvg-name="$name" ')
        ..write('tvg-logo="http://logo.example.com/s$i.jpg" ')
        ..write('group-title="Series | Drama",$name\n')
        ..write('http://example.com:8080/series/kanal/test123/$i.mp4\n');
    }
  }
  return out.toString();
}

void main() {
  test('parses a 100k-entry playlist in an isolate in under 3 s', () async {
    final text = _generatePlaylist(100000);

    final watch = Stopwatch()..start();
    final result = await parseM3uInIsolate(text);
    watch.stop();

    // ignore: avoid_print
    print(
      'parseM3uInIsolate: 100000 entries, '
      '${(text.length / 1024 / 1024).toStringAsFixed(1)} MB, '
      '${watch.elapsedMilliseconds} ms',
    );
    expect(result.entries, hasLength(100000));
    expect(result.warnings, isEmpty);
    final kinds = <M3uKind, int>{};
    for (final e in result.entries) {
      kinds[e.kind] = (kinds[e.kind] ?? 0) + 1;
    }
    expect(kinds, {
      M3uKind.live: 70000,
      M3uKind.movie: 20000,
      M3uKind.episode: 10000,
    });
    final episode = result.entries[9];
    expect(episode.seriesName, 'Series 9');
    expect(episode.season, 5);
    expect(episode.episode, 10);
    expect(result.entries.first.catchup, 'xc');
    expect(result.entries.first.userAgent, 'Carina/1.0');
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('streams the same playlist from a file in an isolate', () async {
    final dir = await Directory.systemTemp.createTemp('carina_m3u_perf_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/big.m3u');
    await file.writeAsBytes(utf8.encode(_generatePlaylist(100000)));

    final watch = Stopwatch()..start();
    final result = await parseM3uFileInIsolate(file.path);
    watch.stop();

    // ignore: avoid_print
    print(
      'parseM3uFileInIsolate: 100000 entries, '
      '${watch.elapsedMilliseconds} ms',
    );
    expect(result.entries, hasLength(100000));
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
