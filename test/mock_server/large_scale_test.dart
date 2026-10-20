import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/mock_server/src/server.dart';
import 'helpers.dart';

void main() {
  test('large scale: exact counts, cached lists answer in < 3 s', () async {
    final media = await FakeMedia.create(tsSeconds: 1);
    final watch = Stopwatch()..start();
    final server = await MockServer.start(
      port: 0,
      scale: MockScale.large,
      mediaDir: media.mediaDir,
      liveDir: media.liveDir,
      warmUp: false,
    );
    final startMs = watch.elapsedMilliseconds;
    try {
      expect(server.catalog.channels, hasLength(20000));
      expect(server.catalog.movies, hasLength(60000));
      expect(server.catalog.series, hasLength(8000));
      final api = '${server.baseUrl}/player_api.php?$account&action=';
      final timings = <String, (int, int)>{};
      for (final (action, count) in [
        ('get_live_streams', 20000),
        ('get_vod_streams', 60000),
        ('get_series', 8000),
      ]) {
        final first = await fetch('$api$action');
        final second = await fetch('$api$action');
        expect(first.status, 200);
        expect(second.body, first.body);
        expect(first.json, hasLength(count), reason: action);
        expect(
          second.elapsed,
          lessThan(const Duration(seconds: 3)),
          reason: action,
        );
        timings[action] = (
          first.elapsed.inMilliseconds,
          second.elapsed.inMilliseconds,
        );
      }
      final categories = await fetch('${api}get_live_categories');
      expect(categories.json, hasLength(server.catalog.liveCategories.length));
      final byCategory = await fetch('${api}get_live_streams&category_id=1');
      expect(byCategory.elapsed, lessThan(const Duration(seconds: 3)));
      stdout.writeln(
        'large scale: start ${startMs}ms; '
        '${timings.entries.map((e) => '${e.key} first ${e.value.$1}ms / cached ${e.value.$2}ms').join('; ')}',
      );
    } finally {
      await server.stop();
      await media.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
