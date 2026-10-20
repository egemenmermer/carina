import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../sources/source_exception.dart';
import 'mask.dart';
import 'net_errors.dart';
import 'retry_interceptor.dart';

/// What the first bytes of a body look like.
enum UrlContentKind { m3u, xml, gzip, html, json, empty, other }

/// Result of [checkUrlReachable] (wizard live check for M3U / EPG URLs).
///
/// A green check is not a promise that the import will succeed: only the
/// first [UrlCheckResult.bytesRead] bytes were looked at.
class UrlCheckResult {
  const UrlCheckResult({
    required this.ok,
    required this.reachable,
    this.statusCode,
    this.kind,
    this.compressedKind,
    this.error,
    this.message,
    this.contentType,
    this.contentLength,
    this.bytesRead = 0,
    this.m3uEpgUrls = const [],
    this.maskedUrl,
  });

  /// Reachable, 2xx, not empty, and of the expected kind (when one was
  /// requested).
  final bool ok;

  /// The server answered (any HTTP status).
  final bool reachable;
  final int? statusCode;

  /// Sniffed from the first bytes of a 2xx body; null when no body was read.
  final UrlContentKind? kind;

  /// For [UrlContentKind.gzip]: the kind of the decompressed first bytes
  /// (null when they could not be decompressed).
  final UrlContentKind? compressedKind;

  /// Why the check failed (null when [ok]): unreachable, timeout, cancelled,
  /// unauthorized, forbidden, notFound, http, emptyBody, or unparseable
  /// ("not an M3U", "not XML").
  final SourceErrorKind? error;

  /// Developer detail, never with credentials.
  final String? message;
  final String? contentType;

  /// `Content-Length` when sent.
  final int? contentLength;
  final int bytesRead;

  /// `url-tvg` / `x-tvg-url` values from the `#EXTM3U` header line (to
  /// pre-fill the EPG field).
  final List<String> m3uEpgUrls;
  final String? maskedUrl;

  @override
  String toString() =>
      'UrlCheckResult(ok: $ok, reachable: $reachable, status: $statusCode, '
      'kind: ${kind?.name}, error: ${error?.name}, url: $maskedUrl)';
}

/// GETs [url], reads at most [maxBytes] (then aborts the transfer) and
/// classifies the content. Never throws.
///
/// [expectM3u] requires an M3U playlist; [expectXml] requires XML (XMLTV) or
/// gzip-compressed XML. With both, either kind passes. With neither, any
/// non-empty 2xx body passes. [headers] are sent with the request (e.g. a
/// custom `Referer`); set a custom User-Agent on the [Dio] itself so it
/// survives redirects.
Future<UrlCheckResult> checkUrlReachable(
  Dio dio,
  String url, {
  bool expectM3u = false,
  bool expectXml = false,
  int maxBytes = 64 * 1024,
  Map<String, String>? headers,
  CancelToken? cancelToken,
}) async {
  final masked = maskUrl(url);
  final token = CancelToken();
  if (cancelToken != null) {
    if (cancelToken.isCancelled) {
      return UrlCheckResult(
        ok: false,
        reachable: false,
        error: SourceErrorKind.cancelled,
        message: 'Request cancelled',
        maskedUrl: masked,
      );
    }
    unawaited(
      cancelToken.whenCancel.then((_) {
        if (!token.isCancelled) token.cancel('cancelled by caller');
      }),
    );
  }

  final Response<ResponseBody> response;
  try {
    response = await dio.get<ResponseBody>(
      url,
      cancelToken: token,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        extra: {kRetriesExtraKey: 1},
      ),
    );
  } on DioException catch (e) {
    final mapped = mapDioError(e, url: url);
    return UrlCheckResult(
      ok: false,
      reachable: false,
      error: mapped.kind,
      statusCode: mapped.statusCode,
      message: mapped.message,
      maskedUrl: masked,
    );
  }

  final status = response.statusCode;
  final contentType = response.headers.value(Headers.contentTypeHeader);
  final contentLength = int.tryParse(
    response.headers.value(Headers.contentLengthHeader) ?? '',
  );
  final body = response.data;
  if (!isSuccessStatus(status) || body == null) {
    if (!token.isCancelled) token.cancel('status');
    return UrlCheckResult(
      ok: false,
      reachable: true,
      statusCode: status,
      error: sourceErrorKindForStatus(status ?? 0),
      message: 'HTTP $status',
      contentType: contentType,
      contentLength: contentLength,
      maskedUrl: masked,
    );
  }

  final Uint8List prefix;
  try {
    prefix = await _readPrefix(body.stream, maxBytes);
  } on Object catch (e) {
    if (!token.isCancelled) token.cancel('read failed');
    final mapped = (cancelToken?.isCancelled ?? false)
        ? SourceException(SourceErrorKind.cancelled, message: 'Cancelled')
        : mapNetworkError(e, url: url);
    return UrlCheckResult(
      ok: false,
      reachable: true,
      statusCode: status,
      error: mapped.kind,
      message: mapped.message,
      contentType: contentType,
      contentLength: contentLength,
      maskedUrl: masked,
    );
  } finally {
    // Only the prefix is needed: abort the rest of the transfer.
    if (!token.isCancelled) token.cancel('prefix read');
  }

  final kind = sniffContentKind(prefix);
  final compressedKind = kind == UrlContentKind.gzip
      ? _sniffGzipPrefix(prefix)
      : null;
  final epgUrls = kind == UrlContentKind.m3u
      ? m3uHeaderEpgUrls(prefix)
      : const <String>[];

  SourceErrorKind? error;
  String? message;
  if (kind == UrlContentKind.empty) {
    error = SourceErrorKind.emptyBody;
    message = 'Empty body';
  } else if (expectM3u || expectXml) {
    final m3uOk = expectM3u && kind == UrlContentKind.m3u;
    final xmlOk =
        expectXml &&
        (kind == UrlContentKind.xml ||
            (kind == UrlContentKind.gzip &&
                compressedKind == UrlContentKind.xml));
    if (!m3uOk && !xmlOk) {
      error = SourceErrorKind.unparseable;
      final got = kind == UrlContentKind.gzip && compressedKind != null
          ? 'gzip/${compressedKind.name}'
          : kind.name;
      message = expectM3u && !expectXml
          ? 'Not an M3U playlist ($got)'
          : 'Not an XML document ($got)';
    }
  }

  return UrlCheckResult(
    ok: error == null,
    reachable: true,
    statusCode: status,
    kind: kind,
    compressedKind: compressedKind,
    error: error,
    message: message,
    contentType: contentType,
    contentLength: contentLength,
    bytesRead: prefix.length,
    m3uEpgUrls: epgUrls,
    maskedUrl: masked,
  );
}

Future<Uint8List> _readPrefix(Stream<Uint8List> stream, int maxBytes) {
  final builder = BytesBuilder(copy: false);
  final completer = Completer<Uint8List>();
  late final StreamSubscription<Uint8List> subscription;
  subscription = stream.listen(
    (chunk) {
      builder.add(chunk);
      if (builder.length >= maxBytes && !completer.isCompleted) {
        unawaited(subscription.cancel());
        final bytes = builder.takeBytes();
        completer.complete(
          bytes.length > maxBytes
              ? Uint8List.sublistView(bytes, 0, maxBytes)
              : bytes,
        );
      }
    },
    onError: (Object e, StackTrace st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete(builder.takeBytes());
    },
    cancelOnError: true,
  );
  return completer.future;
}

/// Classifies the first bytes of a body. A UTF-8 BOM and leading whitespace
/// are skipped (gzip is detected by its magic bytes `1f 8b`).
UrlContentKind sniffContentKind(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
    return UrlContentKind.gzip;
  }
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  while (start < bytes.length && _isSpace(bytes[start])) {
    start++;
  }
  if (start >= bytes.length) return UrlContentKind.empty;

  final end = math.min(bytes.length, start + 4096);
  final head = latin1.decode(bytes.sublist(start, end)).toLowerCase();

  if (head.startsWith('#extm3u') ||
      head.startsWith('#extinf') ||
      head.startsWith('#ext-x-') ||
      (head.startsWith('#') && head.contains('#extinf:'))) {
    return UrlContentKind.m3u;
  }
  if (head.startsWith('{') || head.startsWith('[')) return UrlContentKind.json;
  if (head.startsWith('<')) {
    if (head.startsWith('<!doctype html')) return UrlContentKind.html;
    final root = _rootElement(head);
    if (root == 'html') return UrlContentKind.html;
    if (root == null &&
        (head.contains('<html') ||
            head.contains('<head') ||
            head.contains('<body'))) {
      return UrlContentKind.html;
    }
    if (root == 'head' || root == 'body' || root == 'title') {
      return UrlContentKind.html;
    }
    return UrlContentKind.xml;
  }
  return UrlContentKind.other;
}

bool _isSpace(int b) => b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D;

final RegExp _elementStart = RegExp(r'<([a-z][a-z0-9_:\-]*)');

/// Name of the first element, skipping `<?xml …?>`, comments and doctype.
String? _rootElement(String lowerHead) {
  var rest = lowerHead;
  while (true) {
    rest = rest.trimLeft();
    if (rest.startsWith('<?')) {
      final end = rest.indexOf('?>');
      if (end < 0) return null;
      rest = rest.substring(end + 2);
    } else if (rest.startsWith('<!--')) {
      final end = rest.indexOf('-->');
      if (end < 0) return null;
      rest = rest.substring(end + 3);
    } else if (rest.startsWith('<!')) {
      final end = rest.indexOf('>');
      if (end < 0) return null;
      rest = rest.substring(end + 1);
    } else {
      final m = _elementStart.matchAsPrefix(rest);
      return m?.group(1);
    }
  }
}

/// Decompresses as much of a (possibly truncated) gzip prefix as possible
/// and classifies it.
UrlContentKind? _sniffGzipPrefix(Uint8List prefix) {
  final collector = _ByteCollector();
  final input = gzip.decoder.startChunkedConversion(collector);
  try {
    input.add(prefix);
  } on Object {
    // Corrupt data, or the decoder wants more input; use what we have.
  }
  final out = collector.builder.takeBytes();
  if (out.isEmpty) return null;
  return sniffContentKind(out);
}

class _ByteCollector implements Sink<List<int>> {
  final BytesBuilder builder = BytesBuilder(copy: false);

  @override
  void add(List<int> data) => builder.add(data);

  @override
  void close() {}
}

final RegExp _tvgUrlAttribute = RegExp(
  r'''(?:url-tvg|x-tvg-url)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"']+))''',
  caseSensitive: false,
);

/// `url-tvg` / `x-tvg-url` values of the `#EXTM3U` header line (comma
/// separated lists are split), deduplicated in order.
List<String> m3uHeaderEpgUrls(List<int> bytes) {
  final text = utf8.decode(
    bytes.length > 16384 ? bytes.sublist(0, 16384) : bytes,
    allowMalformed: true,
  );
  final lines = const LineSplitter().convert(text.replaceFirst('﻿', ''));
  final header = lines
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (!header.toUpperCase().startsWith('#EXTM3U')) return const [];
  final urls = <String>[];
  for (final m in _tvgUrlAttribute.allMatches(header)) {
    final value = m[1] ?? m[2] ?? m[3] ?? '';
    for (final part in value.split(',')) {
      final url = part.trim();
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
  }
  return List.unmodifiable(urls);
}
