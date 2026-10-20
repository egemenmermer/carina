// Streaming and isolate entry points of the M3U parser.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'm3u_decoder.dart';
import 'm3u_models.dart';
import 'm3u_parser.dart';

/// Parses an M3U byte stream (HTTP body, file) line by line without holding
/// the whole playlist in memory. Lines are decoded as UTF-8; invalid lines
/// fall back gracefully (see `decodeM3uLine`). A UTF-8 BOM is skipped.
///
/// ```dart
/// final parsed = parseM3uStream(body);
/// await for (final entry in parsed) { ... }
/// final header = await parsed.header;
/// ```
M3uEntryStream parseM3uStream(Stream<List<int>> bytes) =>
    M3uEntryStream._(bytes);

/// [parseM3u] on a background isolate (`Isolate.run`), for large playlists.
Future<M3uParseResult> parseM3uInIsolate(String text) =>
    Isolate.run(() => parseM3u(text), debugName: 'carina-m3u-parse');

/// Streams the file at [path] through [parseM3uStream] on a background
/// isolate, so neither the file text nor the parsing touches the caller's
/// isolate.
Future<M3uParseResult> parseM3uFileInIsolate(String path) => Isolate.run(
  () => parseM3uStream(File(path).openRead()).toResult(),
  debugName: 'carina-m3u-parse-file',
);

/// Single-subscription stream of the entries of an M3U byte stream that also
/// exposes the playlist [header] and the [warnings].
///
/// Parsing starts when the stream is listened to and follows the listener's
/// pause / resume / cancel. Errors of the byte stream are forwarded.
class M3uEntryStream extends Stream<M3uEntry> {
  M3uEntryStream._(this._source);

  final Stream<List<int>> _source;
  final Completer<M3uHeader> _header = Completer<M3uHeader>();
  M3uLineParser? _parser;

  /// The playlist header, merged across every `#EXTM3U` line (concatenated
  /// playlists). Completes when the input ends or the subscription is
  /// cancelled — so await it after (or while) listening, never instead of
  /// it. Never completes with an error.
  Future<M3uHeader> get header => _header.future;

  /// Warnings collected so far; final once the stream is done.
  List<String> get warnings => _parser?.warnings ?? const <String>[];

  /// Number of entries emitted so far.
  int get entryCount => _parser?.entryCount ?? 0;

  /// Collects everything into an [M3uParseResult].
  Future<M3uParseResult> toResult() async {
    final entries = await toList();
    final header = await this.header;
    return M3uParseResult(
      header: header,
      entries: List.unmodifiable(entries),
      warnings: warnings,
    );
  }

  @override
  StreamSubscription<M3uEntry> listen(
    void Function(M3uEntry event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_parser != null) {
      throw StateError('An M3uEntryStream can only be listened to once');
    }
    late final StreamController<M3uEntry> controller;
    final parser = _parser = M3uLineParser((entry) => controller.add(entry));
    final splitter = M3uByteLineSplitter(parser.addLine);
    StreamSubscription<List<int>>? source;

    void completeHeader() {
      if (!_header.isCompleted) _header.complete(parser.header);
    }

    controller = StreamController<M3uEntry>(
      sync: true,
      onListen: () {
        source = _source.listen(
          (chunk) {
            try {
              splitter.add(chunk);
            } on Object catch (error, stack) {
              controller.addError(error, stack);
            }
          },
          onError: controller.addError,
          onDone: () {
            try {
              splitter.close();
              parser.close();
            } on Object catch (error, stack) {
              controller.addError(error, stack);
            }
            completeHeader();
            controller.close();
          },
        );
      },
      onPause: () => source?.pause(),
      onResume: () => source?.resume(),
      onCancel: () {
        parser.close();
        completeHeader();
        return source?.cancel();
      },
    );
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
