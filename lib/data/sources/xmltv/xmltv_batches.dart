/// Batching on top of the streaming XMLTV parser: the import pipeline
/// inserts each programme batch in one transaction.
library;

import '../source_exception.dart';
import 'xmltv_models.dart';
import 'xmltv_parser.dart';

/// Default number of programmes per [XmltvProgrammeBatch].
const int xmltvDefaultBatchSize = 5000;

/// An [XmltvProgress] is emitted when this many input bytes were read
/// without any other batch.
const int xmltvProgressInterval = 8 << 20;

/// Parses an XMLTV document (plain or gzip, see [parseXmltv]) into batches:
/// [XmltvChannelBatch]es and [XmltvProgrammeBatch]es of up to [batchSize]
/// items, occasional [XmltvProgress] items, and a final [XmltvSummary].
///
/// * [shift] (the playlist EPG time shift) is added to every programme time.
/// * Only programmes overlapping [windowStart] – [windowEnd] are delivered
///   (`stop > windowStart && start < windowEnd`, shifted times; either bound
///   may be null). Programmes outside the window are dropped while parsing,
///   before their text is even collected.
/// * Channels are delivered in their own batches; buffered channels are
///   always flushed before the next programme batch.
///
/// The work runs on the current isolate; use `parseXmltvFileInIsolate` to
/// keep it off the UI isolate. Errors are [SourceException]s as described in
/// [parseXmltv]. Throws an [ArgumentError] right away when [batchSize] < 1.
Stream<XmltvBatch> parseXmltvBatches(
  Stream<List<int>> bytes, {
  int batchSize = xmltvDefaultBatchSize,
  Duration shift = Duration.zero,
  DateTime? windowStart,
  DateTime? windowEnd,
  List<String> preferredLanguages = const [],
}) {
  if (batchSize < 1) {
    throw ArgumentError.value(batchSize, 'batchSize', 'must be at least 1');
  }
  return _batches(
    bytes,
    batchSize,
    shift,
    windowStart,
    windowEnd,
    preferredLanguages,
  );
}

Stream<XmltvBatch> _batches(
  Stream<List<int>> bytes,
  int batchSize,
  Duration shift,
  DateTime? windowStart,
  DateTime? windowEnd,
  List<String> preferredLanguages,
) async* {
  var channels = <XmltvChannel>[];
  var programmes = <XmltvProgramme>[];
  final ready = <XmltvBatch>[];
  late final XmltvSaxParser parser;

  void flushChannels() {
    if (channels.isEmpty) return;
    ready.add(XmltvChannelBatch(channels, parser.bytesRead));
    channels = <XmltvChannel>[];
  }

  void flushProgrammes() {
    if (programmes.isEmpty) return;
    ready.add(XmltvProgrammeBatch(programmes, parser.bytesRead));
    programmes = <XmltvProgramme>[];
  }

  parser = XmltvSaxParser(
    onChannel: (channel) {
      channels.add(channel);
      if (channels.length >= batchSize) flushChannels();
    },
    onProgramme: (programme) {
      if (channels.isNotEmpty) flushChannels();
      programmes.add(programme);
      if (programmes.length >= batchSize) flushProgrammes();
    },
    preferredLanguages: preferredLanguages,
    shift: shift,
    windowStart: windowStart,
    windowEnd: windowEnd,
  );

  var reported = 0;
  await for (final chunk in bytes) {
    parser.add(chunk);
    if (ready.isNotEmpty) {
      final out = List<XmltvBatch>.of(ready);
      ready.clear();
      for (final batch in out) {
        yield batch;
      }
      reported = parser.bytesRead;
    } else if (parser.bytesRead - reported >= xmltvProgressInterval) {
      reported = parser.bytesRead;
      yield XmltvProgress(reported);
    }
  }
  parser.close();
  flushChannels();
  flushProgrammes();
  for (final batch in ready) {
    yield batch;
  }
  yield XmltvSummary(
    bytesRead: parser.bytesRead,
    channels: parser.channelCount,
    programmes: parser.programmeCount,
    outsideWindow: parser.outsideWindowCount,
    invalid: parser.invalidCount,
    derivedStops: parser.derivedStopCount,
  );
}
