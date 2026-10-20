// Opt-in benchmark: CARINA_BENCH=1 flutter test test/data/xmltv/xmltv_benchmark_test.dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/xmltv/xmltv.dart';

import 'xmltv_fixtures.dart';

void main() {
  final enabled = Platform.environment['CARINA_BENCH'] == '1';
  final origin = DateTime.utc(2026, 10, 17);
  const channels = 500;
  const perChannel = 2000; // 1,000,000 programmes

  String mb(int bytes) => (bytes / (1 << 20)).toStringAsFixed(1);

  Future<({int programmes, Duration took, int peakRss})> run(
    Stream<XmltvBatch> stream,
  ) async {
    final sw = Stopwatch()..start();
    var programmes = 0;
    var peakRss = ProcessInfo.currentRss;
    await for (final batch in stream) {
      if (batch is XmltvProgrammeBatch) programmes += batch.programmes.length;
      final rss = ProcessInfo.currentRss;
      if (rss > peakRss) peakRss = rss;
    }
    sw.stop();
    return (programmes: programmes, took: sw.elapsed, peakRss: peakRss);
  }

  void report(String label, int size, int programmes, Duration took, int rss) {
    final s = took.inMicroseconds / 1e6;
    print(
      '$label: ${mb(size)} MB, $programmes programmes in '
      '${s.toStringAsFixed(2)} s → ${(size / (1 << 20) / s).toStringAsFixed(1)} '
      'MB/s, ${(programmes / s).round()} programmes/s, peak RSS ${mb(rss)} MB',
    );
  }

  test(
    'parses ~1M programmes / ~150 MB in the isolate',
    () async {
      final dir = await Directory.systemTemp.createTemp('carina_xmltv_bench');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/bench.xml');

      final write = Stopwatch()..start();
      final sink = file.openWrite();
      final size = await writeXmltv(
        sink,
        channels: channels,
        programmesPerChannel: perChannel,
        origin: origin,
      );
      await sink.close();
      write.stop();
      final baseline = ProcessInfo.currentRss;
      print(
        'generated ${mb(size)} MB in ${write.elapsed.inMilliseconds} ms; '
        'RSS before parsing ${mb(baseline)} MB',
      );

      final full = await run(parseXmltvFileInIsolate(file.path));
      report(
        'plain, no window',
        size,
        full.programmes,
        full.took,
        full.peakRss,
      );
      expect(full.programmes, channels * perChannel);
      expect(full.took, lessThan(const Duration(seconds: 60)));

      // Typical import window: now - 1 day … now + 7 days.
      final now = origin.add(const Duration(days: 10));
      final windowed = await run(
        parseXmltvFileInIsolate(
          file.path,
          windowStart: now.subtract(const Duration(days: 1)),
          windowEnd: now.add(const Duration(days: 7)),
        ),
      );
      report(
        'plain, 8-day window',
        size,
        windowed.programmes,
        windowed.took,
        windowed.peakRss,
      );
      expect(windowed.programmes, channels * 8 * 48);

      final gzFile = File('${dir.path}/bench.xml.gz');
      await file.openRead().transform(gzip.encoder).pipe(gzFile.openWrite());
      final gzSize = await gzFile.length();
      final zipped = await run(parseXmltvFileInIsolate(gzFile.path));
      report(
        'gzip (${mb(gzSize)} MB on disk), no window',
        size,
        zipped.programmes,
        zipped.took,
        zipped.peakRss,
      );
      expect(zipped.programmes, channels * perChannel);
      print(
        'process max RSS ${mb(ProcessInfo.maxRss)} MB '
        '(baseline before parsing ${mb(baseline)} MB)',
      );
    },
    skip: enabled ? false : 'Set CARINA_BENCH=1 to run the XMLTV benchmark',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
