import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:carina/data/sources/xmltv/xmltv.dart';

/// A small document exercising most of the format.
const sampleXmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv generator-info-name="carina-test">
  <channel id="ShowTV.tr">
    <display-name lang="tr">Show TV</display-name>
    <display-name lang="en">SHOW</display-name>
    <display-name>Show TV HD</display-name>
    <display-name lang="tr">Show TV</display-name>
    <icon src="http://logos/show.png"/>
  </channel>
  <channel id="TRT1.tr"><display-name>TRT 1</display-name></channel>
  <programme start="20261017120000 +0300" stop="20261017130000 +0300" channel="ShowTV.tr">
    <title lang="tr">Haberler &amp; Gündem</title>
    <sub-title lang="tr">Öğle Bülteni &#039;Canlı&#039;</sub-title>
    <desc lang="tr"><![CDATA[Günün <önemli> haberleri.]]>
İkinci satır.</desc>
    <category lang="tr">Haber</category>
    <category lang="en">News</category>
    <episode-num system="xmltv_ns">0.4.</episode-num>
    <episode-num system="onscreen">S01E05</episode-num>
    <episode-num system="dd_progid">EP0001.0005</episode-num>
    <icon src="http://img/news.jpg"/>
    <rating system="RTÜK"><value>7+</value></rating>
  </programme>
  <programme start="20261017130000 +0300" stop="20261017150000 +0300" channel="ShowTV.tr">
    <title>Dizi Gecesi</title>
    <episode-num system="xmltv_ns">.2.</episode-num>
    <star-rating><value>4/5</value></star-rating>
    <image type="poster">http://img/poster.jpg</image>
  </programme>
  <programme start="20261017120000 -0500" stop="20261017140000 -0500" channel="TRT1.tr">
    <title>Film</title>
    <episode-num>Bölüm 12</episode-num>
  </programme>
</tv>
''';

/// Splits [bytes] into chunks of [size] (one chunk when null).
Iterable<List<int>> chunked(List<int> bytes, int? size) sync* {
  if (size == null) {
    yield bytes;
    return;
  }
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
  }
}

Future<List<XmltvEvent>> parseBytes(
  List<int> bytes, {
  int? chunkSize,
  List<String> languages = const [],
}) => parseXmltv(
  Stream.fromIterable(chunked(bytes, chunkSize)),
  preferredLanguages: languages,
).toList();

Future<List<XmltvEvent>> parseString(
  String xml, {
  int? chunkSize,
  List<String> languages = const [],
}) => parseBytes(utf8.encode(xml), chunkSize: chunkSize, languages: languages);

/// Everything delivered by a batch stream, flattened.
class CollectedBatches {
  final List<XmltvBatch> batches = [];

  List<XmltvChannel> get channels => [
    for (final b in batches.whereType<XmltvChannelBatch>()) ...b.channels,
  ];

  List<XmltvProgramme> get programmes => [
    for (final b in batches.whereType<XmltvProgrammeBatch>()) ...b.programmes,
  ];

  XmltvSummary get summary => batches.last as XmltvSummary;
}

Future<CollectedBatches> collect(Stream<XmltvBatch> stream) async {
  final result = CollectedBatches();
  await for (final batch in stream) {
    result.batches.add(batch);
  }
  return result;
}

/// The UTC start of programme [index] of every channel in [writeXmltv].
DateTime generatedStart(DateTime origin, int index, Duration slot) =>
    origin.add(slot * index);

/// Writes a synthetic XMLTV document without holding it in memory:
/// [channels] channels, each with [programmesPerChannel] back-to-back
/// programmes of [slot] starting at [origin] (written in +0300).
/// Programmes are interleaved by time, like most real feeds. About a third
/// have a description. Returns the number of bytes written.
Future<int> writeXmltv(
  IOSink sink, {
  required int channels,
  required int programmesPerChannel,
  required DateTime origin,
  Duration slot = const Duration(minutes: 30),
  bool withDescriptions = true,
}) async {
  var written = 0;
  final buffer = StringBuffer();

  Future<void> flush({bool force = false}) async {
    final bytes = utf8.encode(buffer.toString());
    buffer.clear();
    written += bytes.length;
    sink.add(bytes);
    if (force || written % (1 << 22) < bytes.length) await sink.flush();
  }

  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln('<tv generator-info-name="carina-bench">');
  for (var c = 0; c < channels; c++) {
    buffer.writeln(
      '<channel id="ch$c.tr"><display-name lang="tr">Kanal $c</display-name>'
      '<icon src="http://logo.example/$c.png"/></channel>',
    );
  }
  await flush();
  final offset = const Duration(hours: 3);
  for (var i = 0; i < programmesPerChannel; i++) {
    final start = generatedStart(origin, i, slot).add(offset);
    final stop = start.add(slot);
    final startText = _xmltvLocal(start);
    final stopText = _xmltvLocal(stop);
    for (var c = 0; c < channels; c++) {
      buffer.write(
        '<programme start="$startText +0300" stop="$stopText +0300" '
        'channel="ch$c.tr"><title lang="tr">Program $i &amp; $c</title>',
      );
      if (withDescriptions && (i + c) % 3 == 0) {
        buffer.write('<desc lang="tr">Açıklama $i: Şehir haberleri</desc>');
      }
      buffer.writeln('</programme>');
      if (buffer.length >= 1 << 16) await flush();
    }
  }
  buffer.writeln('</tv>');
  await flush(force: true);
  return written;
}

String _xmltvLocal(DateTime t) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${t.year}${two(t.month)}${two(t.day)}'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

/// Gzip-compresses [bytes].
Uint8List gz(List<int> bytes) => Uint8List.fromList(gzip.encode(bytes));
