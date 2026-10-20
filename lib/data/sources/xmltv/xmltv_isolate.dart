/// Runs the XMLTV batch parser in a background isolate.
///
/// Intended use by the importer: download the XMLTV to a temporary file,
/// then [parseXmltvFileInIsolate] it, inserting each batch in a transaction
/// before asking for the next one.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../source_exception.dart';
import 'xmltv_batches.dart';
import 'xmltv_models.dart';

/// Parses the XMLTV file at [path] (plain or gzip, sniffed from the content)
/// in a new isolate and streams the batches of [parseXmltvBatches] back.
///
/// * Back-pressure: the isolate parses at most two batches ahead of the
///   listener. Consume with `await for` (or pause the subscription while a
///   batch is being stored) and memory stays bounded for any file size.
/// * Cancelling the subscription stops the parser, closes the file and ends
///   the isolate.
/// * Parse failures arrive as [SourceException]s (`unparseable`, or
///   `emptyBody` for an empty file); a file that cannot be read is
///   `unparseable` too, with the OS error in the message.
Stream<XmltvBatch> parseXmltvFileInIsolate(
  String path, {
  int batchSize = xmltvDefaultBatchSize,
  Duration shift = Duration.zero,
  DateTime? windowStart,
  DateTime? windowEnd,
  List<String> preferredLanguages = const [],
}) => _IsolateRun(
  _Options.of(batchSize, shift, windowStart, windowEnd, preferredLanguages),
  path,
  null,
).stream;

/// Like [parseXmltvFileInIsolate], for bytes produced on this isolate (for
/// example a download that is not written to disk). The bytes are moved to
/// the parser isolate without copying, in chunks of about 256 KB, and only
/// as fast as the parser consumes them. Errors of [bytes] are passed through
/// unchanged.
Stream<XmltvBatch> parseXmltvBytesInIsolate(
  Stream<List<int>> bytes, {
  int batchSize = xmltvDefaultBatchSize,
  Duration shift = Duration.zero,
  DateTime? windowStart,
  DateTime? windowEnd,
  List<String> preferredLanguages = const [],
}) => _IsolateRun(
  _Options.of(batchSize, shift, windowStart, windowEnd, preferredLanguages),
  null,
  bytes,
).stream;

/// Batches the worker may send before the listener asks for more.
const int _initialCredits = 2;

/// Size of the byte chunks sent to the worker for stream input.
const int _chunkBytes = 256 * 1024;

/// How long a cancelled worker gets to shut down before it is killed.
const Duration _cancelGrace = Duration(seconds: 2);

final class _Options {
  const _Options(
    this.batchSize,
    this.shiftMs,
    this.windowStartMs,
    this.windowEndMs,
    this.languages,
  );

  factory _Options.of(
    int batchSize,
    Duration shift,
    DateTime? windowStart,
    DateTime? windowEnd,
    List<String> languages,
  ) {
    if (batchSize < 1) {
      throw ArgumentError.value(batchSize, 'batchSize', 'must be at least 1');
    }
    return _Options(
      batchSize,
      shift.inMilliseconds,
      windowStart?.millisecondsSinceEpoch,
      windowEnd?.millisecondsSinceEpoch,
      List<String>.of(languages),
    );
  }

  final int batchSize;
  final int shiftMs;
  final int? windowStartMs;
  final int? windowEndMs;
  final List<String> languages;
}

final class _WorkerArgs {
  const _WorkerArgs(this.main, this.path, this.options);

  final SendPort main;

  /// File to parse, or null when the bytes come from the main isolate.
  final String? path;
  final _Options options;
}

// Main → worker.
final class _Credit {
  const _Credit(this.count);
  final int count;
}

final class _Cancel {
  const _Cancel();
}

final class _Chunk {
  const _Chunk(this.data);
  final TransferableTypedData data;
}

final class _EndOfInput {
  const _EndOfInput();
}

// Worker → main.
final class _Pull {
  const _Pull();
}

final class _Done {
  const _Done();
}

final class _Failure {
  const _Failure(this.kind, this.message);

  /// [SourceErrorKind.index].
  final int kind;
  final String? message;
}

/// The main-isolate side of one run.
final class _IsolateRun {
  /// Exactly one of [_path] and [_input] is non-null.
  _IsolateRun(this._options, this._path, this._input) {
    _controller = StreamController<XmltvBatch>(
      onListen: _start,
      onResume: _grantOwed,
      onCancel: _cancel,
    );
  }

  final _Options _options;
  final String? _path;
  final Stream<List<int>>? _input;
  late final StreamController<XmltvBatch> _controller;

  Stream<XmltvBatch> get stream => _controller.stream;

  ReceivePort? _port;
  Isolate? _isolate;
  SendPort? _worker;

  /// Credits held back while the listener is paused.
  int _owed = 0;

  /// No more events go to the listener (done, failed or cancelled).
  bool _finished = false;
  bool _cancelled = false;
  bool _workerExited = false;
  Completer<void>? _exited;

  StreamSubscription<List<int>>? _inputSubscription;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  Future<void> _start() async {
    final port = _port = ReceivePort('carina-xmltv');
    port.listen(_onMessage);
    try {
      _isolate = await Isolate.spawn<_WorkerArgs>(
        _xmltvWorker,
        _WorkerArgs(port.sendPort, _path, _options),
        onExit: port.sendPort,
        onError: port.sendPort,
        debugName: 'carina-xmltv',
      );
    } catch (error) {
      _fail(
        SourceException(
          SourceErrorKind.unparseable,
          message: 'Could not start the XMLTV parser isolate: $error',
        ),
      );
      return;
    }
    if (_cancelled) _isolate?.kill(priority: Isolate.immediate);
  }

  void _onMessage(Object? message) {
    switch (message) {
      case final SendPort worker:
        _worker = worker;
        if (_cancelled) {
          worker.send(const _Cancel());
        } else {
          worker.send(const _Credit(_initialCredits));
        }
      case final XmltvBatch batch:
        if (_finished) return;
        _controller.add(batch);
        if (_controller.isPaused) {
          _owed++;
        } else {
          _worker?.send(const _Credit(1));
        }
      case _Pull():
        _pull();
      case _Done():
        _finish();
      case final _Failure failure:
        _fail(
          SourceException(
            SourceErrorKind.values[failure.kind],
            message: failure.message,
          ),
        );
      case final List<Object?> error:
        // Uncaught error in the worker: [message, stackTrace].
        _fail(
          SourceException(
            SourceErrorKind.unparseable,
            message:
                'XMLTV parser isolate failed: '
                '${error.isEmpty ? 'unknown error' : error.first}',
          ),
        );
      case null:
        // The worker isolate exited.
        _workerExited = true;
        _exited?.complete();
        _exited = null;
        if (!_finished) {
          _fail(
            const SourceException(
              SourceErrorKind.unparseable,
              message: 'XMLTV parser isolate exited unexpectedly',
            ),
          );
        }
        _port?.close();
    }
  }

  void _grantOwed() {
    final worker = _worker;
    if (_owed > 0 && worker != null && !_finished) {
      worker.send(_Credit(_owed));
      _owed = 0;
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _inputSubscription?.cancel();
    _controller.close();
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_finished) return;
    _finished = true;
    _inputSubscription?.cancel();
    _worker?.send(const _Cancel());
    _controller
      ..addError(error, stackTrace)
      ..close();
  }

  Future<void> _cancel() async {
    final wasFinished = _finished;
    _finished = true;
    _cancelled = true;
    await _inputSubscription?.cancel();
    // After done or a failure the worker ends on its own (and was told to).
    if (wasFinished || _workerExited) return;
    final worker = _worker;
    final isolate = _isolate;
    if (worker == null || isolate == null) {
      // Still starting: _start / the handshake will stop the worker.
      return;
    }
    final exited = _exited = Completer<void>();
    worker.send(const _Cancel());
    await exited.future.timeout(
      _cancelGrace,
      onTimeout: () => isolate.kill(priority: Isolate.immediate),
    );
    _port?.close();
  }

  // Stream input: the worker pulls; each pull sends about [_chunkBytes].

  void _pull() {
    if (_finished) return;
    final subscription = _inputSubscription;
    if (subscription == null) {
      _inputSubscription = _input!.listen(
        _onInputData,
        onError: _onInputError,
        onDone: _onInputDone,
        cancelOnError: true,
      );
    } else {
      subscription.resume();
    }
  }

  void _onInputData(List<int> data) {
    _buffer.add(data);
    if (_buffer.length >= _chunkBytes) {
      _inputSubscription!.pause();
      _sendBuffer();
    }
  }

  void _onInputDone() {
    if (_buffer.isNotEmpty) _sendBuffer();
    _worker?.send(const _EndOfInput());
  }

  void _onInputError(Object error, StackTrace stackTrace) {
    _fail(error, stackTrace);
  }

  void _sendBuffer() {
    final bytes = _buffer.takeBytes();
    _worker?.send(_Chunk(TransferableTypedData.fromList([bytes])));
  }
}

/// The worker isolate: parses and sends batches as credits allow.
Future<void> _xmltvWorker(_WorkerArgs args) async {
  final main = args.main;
  final options = args.options;
  final inbox = ReceivePort();
  var credits = 0;
  var cancelled = false;
  Completer<void>? wake;
  StreamController<List<int>>? remote;
  var pulling = false;
  var inputEnded = false;

  void pull() {
    if (pulling || inputEnded || cancelled) return;
    pulling = true;
    main.send(const _Pull());
  }

  void wakeUp() {
    final w = wake;
    wake = null;
    w?.complete();
  }

  inbox.listen((Object? message) {
    switch (message) {
      case _Credit(:final count):
        credits += count;
        wakeUp();
      case _Cancel():
        cancelled = true;
        wakeUp();
        final r = remote;
        if (r != null && !r.isClosed) r.close();
      case _Chunk(:final data):
        pulling = false;
        final r = remote;
        if (r == null || r.isClosed) return;
        r.add(data.materialize().asUint8List());
        if (!r.isPaused) pull();
      case _EndOfInput():
        inputEnded = true;
        remote?.close();
    }
  });
  main.send(inbox.sendPort);

  final path = args.path;
  final Stream<List<int>> source;
  if (path != null) {
    source = File(path).openRead();
  } else {
    final r = remote = StreamController<List<int>>(
      onListen: pull,
      onResume: pull,
    );
    source = r.stream;
  }

  try {
    final batches = parseXmltvBatches(
      // Stops reading at the next chunk once cancelled.
      source.takeWhile((_) => !cancelled),
      batchSize: options.batchSize,
      shift: Duration(milliseconds: options.shiftMs),
      windowStart: _dateOrNull(options.windowStartMs),
      windowEnd: _dateOrNull(options.windowEndMs),
      preferredLanguages: options.languages,
    );
    await for (final batch in batches) {
      while (credits <= 0 && !cancelled) {
        final w = wake = Completer<void>();
        await w.future;
      }
      if (cancelled) break;
      credits--;
      main.send(batch);
    }
    if (!cancelled) main.send(const _Done());
  } on SourceException catch (e) {
    if (!cancelled) main.send(_Failure(e.kind.index, e.message));
  } on FileSystemException catch (e) {
    if (!cancelled) {
      final os = e.osError?.message;
      main.send(
        _Failure(
          SourceErrorKind.unparseable.index,
          'Cannot read the XMLTV file: ${e.message}'
          '${os == null || os.isEmpty ? '' : ' ($os)'}',
        ),
      );
    }
  } catch (e) {
    if (!cancelled) {
      main.send(
        _Failure(SourceErrorKind.unparseable.index, 'XMLTV parsing failed: $e'),
      );
    }
  } finally {
    inbox.close();
  }
}

DateTime? _dateOrNull(int? ms) =>
    ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
