import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/xmltv/xmltv.dart';

import 'xmltv_fixtures.dart';

void main() {
  final origin = DateTime.utc(2026, 10, 17);

  /// [channels] × [perChannel] half-hour programmes from [origin].
  Future<List<int>> document({
    int channels = 3,
    int perChannel = 4,
    bool withDescriptions = true,
  }) async {
    final dir = await Directory.systemTemp.createTemp('carina_xmltv');
    try {
      final file = File('${dir.path}/doc.xml');
      final sink = file.openWrite();
      await writeXmltv(
        sink,
        channels: channels,
        programmesPerChannel: perChannel,
        origin: origin,
        withDescriptions: withDescriptions,
      );
      await sink.close();
      return await file.readAsBytes();
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Stream<List<int>> stream(List<int> bytes, [int? chunkSize = 4096]) =>
      Stream.fromIterable(chunked(bytes, chunkSize));

  test('delivers channels first, then programme batches of batchSize, then '
      'a summary', () async {
    final bytes = await document(channels: 3, perChannel: 4); // 12
    final result = await collect(
      parseXmltvBatches(stream(bytes), batchSize: 5),
    );
    final kinds = result.batches.map(
      (b) => switch (b) {
        XmltvChannelBatch(:final channels) => 'C${channels.length}',
        XmltvProgrammeBatch(:final programmes) => 'P${programmes.length}',
        XmltvProgress() => 'progress',
        XmltvSummary() => 'summary',
      },
    );
    expect(kinds, ['C3', 'P5', 'P5', 'P2', 'summary']);
    expect(result.channels.map((c) => c.id), ['ch0.tr', 'ch1.tr', 'ch2.tr']);
    expect(result.programmes, hasLength(12));
    final summary = result.summary;
    expect(summary.channels, 3);
    expect(summary.programmes, 12);
    expect(summary.outsideWindow, 0);
    expect(summary.invalid, 0);
    expect(summary.derivedStops, 0);
    expect(summary.bytesRead, bytes.length);
    // bytesRead never decreases.
    final read = result.batches.map((b) => b.bytesRead).toList();
    for (var i = 1; i < read.length; i++) {
      expect(read[i], greaterThanOrEqualTo(read[i - 1]));
    }
  });

  test('batch size 1 and a batch size larger than the document', () async {
    final bytes = await document(channels: 2, perChannel: 2);
    final one = await collect(parseXmltvBatches(stream(bytes), batchSize: 1));
    expect(one.batches.whereType<XmltvChannelBatch>(), hasLength(2));
    expect(one.batches.whereType<XmltvProgrammeBatch>(), hasLength(4));
    final big = await collect(parseXmltvBatches(stream(bytes)));
    expect(big.batches.whereType<XmltvProgrammeBatch>(), hasLength(1));
    expect(big.programmes, one.programmes);
  });

  test('rejects a batch size below 1 right away', () {
    expect(
      () => parseXmltvBatches(stream(const []), batchSize: 0),
      throwsArgumentError,
    );
  });

  test('flushes channels that appear after programmes before the next '
      'programme batch', () async {
    const doc = '''
<tv>
  <channel id="a"><display-name>A</display-name></channel>
  <programme start="20261017100000" stop="20261017110000" channel="a"><title>1</title></programme>
  <channel id="b"><display-name>B</display-name></channel>
  <programme start="20261017100000" stop="20261017110000" channel="b"><title>2</title></programme>
</tv>''';
    final result = await collect(
      parseXmltvBatches(stream(utf8.encode(doc), null), batchSize: 1),
    );
    final order = [
      for (final b in result.batches)
        switch (b) {
          XmltvChannelBatch(:final channels) => 'C:${channels.single.id}',
          XmltvProgrammeBatch(:final programmes) =>
            'P:${programmes.single.title}',
          _ => b.runtimeType.toString(),
        },
    ];
    expect(order, ['C:a', 'P:1', 'C:b', 'P:2', 'XmltvSummary']);
  });

  group('window', () {
    test('keeps only programmes overlapping the window', () async {
      // 1 channel, 10 programmes: 00:00, 00:30 … 04:30 UTC.
      final bytes = await document(channels: 1, perChannel: 10);
      final result = await collect(
        parseXmltvBatches(
          stream(bytes),
          windowStart: origin.add(const Duration(hours: 1, minutes: 15)),
          windowEnd: origin.add(const Duration(hours: 3)),
        ),
      );
      // 01:00–01:30 overlaps the start; 03:00 starts at the end (excluded).
      expect(result.programmes.map((p) => p.start.toIso8601String()), [
        '2026-10-17T01:00:00.000Z',
        '2026-10-17T01:30:00.000Z',
        '2026-10-17T02:00:00.000Z',
        '2026-10-17T02:30:00.000Z',
      ]);
      expect(result.summary.programmes, 4);
      expect(result.summary.outsideWindow, 6);
    });

    test('applies to derived stops too', () async {
      const doc = '''
<tv>
  <programme start="20261017080000" channel="a"><title>old</title></programme>
  <programme start="20261017090000" channel="a"><title>overlaps</title></programme>
  <programme start="20261017110000" stop="20261017120000" channel="a"><title>inside</title></programme>
</tv>''';
      final result = await collect(
        parseXmltvBatches(
          stream(utf8.encode(doc), null),
          windowStart: DateTime.utc(2026, 10, 17, 10),
        ),
      );
      expect(result.programmes.map((p) => p.title), ['overlaps', 'inside']);
      expect(result.programmes.first.stop, DateTime.utc(2026, 10, 17, 11));
      expect(result.summary.derivedStops, 1);
      expect(result.summary.outsideWindow, 1);
    });

    test('reports progress while skipping a long stretch', () async {
      // ~10 MB of programmes, all before the window.
      final bytes = await document(
        channels: 50,
        perChannel: 2000,
        withDescriptions: false,
      );
      expect(bytes.length, greaterThan(xmltvProgressInterval));
      final result = await collect(
        parseXmltvBatches(
          stream(bytes, 1 << 16),
          windowStart: DateTime.utc(2030),
        ),
      );
      expect(result.programmes, isEmpty);
      expect(result.batches.whereType<XmltvProgress>(), isNotEmpty);
      expect(result.summary.outsideWindow, 100000);
    });
  });

  group('time shift', () {
    test('is added to every time and the window uses shifted times', () async {
      final bytes = await document(channels: 1, perChannel: 4);
      const shift = Duration(hours: 2);
      final plain = await collect(parseXmltvBatches(stream(bytes)));
      final shifted = await collect(
        parseXmltvBatches(stream(bytes), shift: shift),
      );
      for (var i = 0; i < 4; i++) {
        expect(
          shifted.programmes[i].start,
          plain.programmes[i].start.add(shift),
        );
        expect(shifted.programmes[i].stop, plain.programmes[i].stop.add(shift));
        expect(shifted.programmes[i].start.isUtc, isTrue);
      }
      // Shifted, the programmes run 02:00–04:00 in half hours; a window
      // from 03:00 keeps the two that end after 03:00.
      final windowed = await collect(
        parseXmltvBatches(
          stream(bytes),
          shift: shift,
          windowStart: origin.add(const Duration(hours: 3)),
        ),
      );
      expect(windowed.programmes.map((p) => p.start.toIso8601String()), [
        '2026-10-17T03:00:00.000Z',
        '2026-10-17T03:30:00.000Z',
      ]);
      final negative = await collect(
        parseXmltvBatches(stream(bytes), shift: const Duration(hours: -1)),
      );
      expect(negative.programmes.first.start, DateTime.utc(2026, 10, 16, 23));
    });

    test('parseXmltv itself applies no shift', () async {
      final bytes = await document(channels: 1, perChannel: 1);
      final events = await parseXmltv(stream(bytes)).toList();
      expect(events.whereType<XmltvProgramme>().single.start, origin);
    });
  });

  test('passes preferred languages through', () async {
    const doc = '''
<tv><programme start="20261017100000" stop="20261017110000" channel="a">
<title lang="en">News</title><title lang="tr">Haberler</title></programme></tv>''';
    final result = await collect(
      parseXmltvBatches(
        stream(utf8.encode(doc), null),
        preferredLanguages: const ['tr'],
      ),
    );
    expect(result.programmes.single.title, 'Haberler');
  });

  test('gzip input reports compressed bytes', () async {
    final bytes = await document(channels: 2, perChannel: 50);
    final compressed = gz(bytes);
    final result = await collect(parseXmltvBatches(stream(compressed)));
    expect(result.programmes, hasLength(100));
    expect(result.summary.bytesRead, compressed.length);
  });
}
