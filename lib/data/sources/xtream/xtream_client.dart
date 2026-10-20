import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../net/mask.dart';
import '../../net/net_errors.dart';
import '../../net/retry_interceptor.dart';
import '../source_exception.dart';
import 'json_utils.dart';
import 'xtream_credentials.dart';
import 'xtream_models.dart';
import 'xtream_urls.dart';

/// Bodies larger than this are decoded and mapped to DTOs on a background
/// isolate (ARCHITECTURE 2.4).
const int xtreamIsolateThreshold = 50 * 1024;

/// Xtream Codes `player_api.php` client.
///
/// Every request is `GET {server}/player_api.php?username=&password=&action=…`.
/// Bodies are decoded whatever their content type (panels often send JSON as
/// `text/html`). Failures throw [SourceException] with a masked URL:
///
/// - transport: `unreachable`, `timeout`, `cancelled`;
/// - HTTP 401 or `user_info.auth == 0`: `unauthorized`; 403: `forbidden`;
///   404: `notFound`; other non-2xx: `http`;
/// - 2xx without bytes: `emptyBody`; an HTML page or invalid JSON:
///   `unparseable`;
/// - [authenticate] with status Expired/Banned/Disabled: `accountInactive`.
class XtreamClient {
  XtreamClient(
    this._dio,
    this.credentials, {
    this.bulkReceiveTimeout = const Duration(seconds: 90),
    this.retries,
  }) : urls = XtreamUrls.fromCredentials(credentials);

  final Dio _dio;
  final XtreamCredentials credentials;
  final XtreamUrls urls;

  /// Receive timeout of the "everything at once" list calls
  /// ([liveStreams], [vodStreams] and [seriesList] without a category).
  final Duration bulkReceiveTimeout;

  /// Retry budget for this client's requests; null keeps the Dio default
  /// (see `RetryInterceptor`).
  final int? retries;

  XtreamAccount? _account;

  /// The account from the last successful [accountInfo]/[authenticate].
  XtreamAccount? get account => _account;

  /// The server clock offset learned from the last account call (zero
  /// before it). Used to read EPG times that come without timestamps.
  Duration get serverUtcOffset => _account?.serverUtcOffset ?? Duration.zero;

  /// `player_api.php` without an action. Throws `unauthorized` when
  /// `user_info.auth == 0`, `unparseable` when there is no `user_info`, but
  /// returns inactive (expired, banned…) accounts — see [authenticate].
  Future<XtreamAccount> accountInfo({CancelToken? cancelToken}) async {
    final account = await _get(
      const {},
      _parseAccount,
      cancelToken: cancelToken,
    );
    if (account == null) {
      throw SourceException(
        SourceErrorKind.unparseable,
        message: 'Response has no user_info',
        url: maskUrl(_apiUrlForErrors(const {})),
      );
    }
    _account = account;
    return account;
  }

  /// [accountInfo] that also requires an active account: throws
  /// `unauthorized` (auth 0 / HTTP 401) or `accountInactive` (Expired,
  /// Banned, Disabled…).
  Future<XtreamAccount> authenticate({CancelToken? cancelToken}) async {
    final account = await accountInfo(cancelToken: cancelToken);
    final url = maskUrl(_apiUrlForErrors(const {}));
    if (!account.userInfo.auth) {
      throw SourceException(
        SourceErrorKind.unauthorized,
        message: 'user_info.auth is 0',
        url: url,
      );
    }
    if (!account.isActive) {
      throw SourceException(
        SourceErrorKind.accountInactive,
        message: 'Account status: ${account.status ?? 'unknown'}',
        url: url,
      );
    }
    return account;
  }

  Future<List<XtreamCategory>> liveCategories({CancelToken? cancelToken}) =>
      _get(
        const {'action': 'get_live_categories'},
        XtreamCategory.listFromJson,
        cancelToken: cancelToken,
      );

  /// All live streams at once, or one category. The all-at-once call uses
  /// [bulkReceiveTimeout] and is not retried: when it fails or times out,
  /// fall back to [liveStreamsPerCategory].
  Future<List<XtreamLiveStream>> liveStreams({
    String? categoryId,
    CancelToken? cancelToken,
  }) => _get(
    {'action': 'get_live_streams', 'category_id': ?categoryId},
    XtreamLiveStream.listFromJson,
    cancelToken: cancelToken,
    receiveTimeout: categoryId == null ? bulkReceiveTimeout : null,
    retries: categoryId == null ? 0 : retries,
  );

  /// Fallback for [liveStreams]: one request per category, at most
  /// [concurrency] in flight. Streams listed in several categories appear
  /// once (first occurrence, `categoryIds` merged), in category order.
  ///
  /// By default the first failing category aborts the call (other requests
  /// are cancelled) and its [SourceException] is thrown, so an import never
  /// mistakes a failed category for an empty one. With [onCategoryError],
  /// failures are reported there and skipped instead. [onProgress] reports
  /// finished categories.
  Future<List<XtreamLiveStream>> liveStreamsPerCategory(
    List<String> categoryIds, {
    int concurrency = 4,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
    void Function(String categoryId, SourceException error)? onCategoryError,
  }) => _perCategory<XtreamLiveStream>(
    categoryIds,
    (id, token) => liveStreams(categoryId: id, cancelToken: token),
    keyOf: (s) => s.streamId,
    merge: (kept, other) =>
        kept.copyWith(categoryIds: _union(kept.categoryIds, other.categoryIds)),
    concurrency: concurrency,
    cancelToken: cancelToken,
    onProgress: onProgress,
    onCategoryError: onCategoryError,
  );

  Future<List<XtreamCategory>> vodCategories({CancelToken? cancelToken}) =>
      _get(
        const {'action': 'get_vod_categories'},
        XtreamCategory.listFromJson,
        cancelToken: cancelToken,
      );

  /// All movies at once ([bulkReceiveTimeout]) or one category.
  Future<List<XtreamVodStream>> vodStreams({
    String? categoryId,
    CancelToken? cancelToken,
  }) => _get(
    {'action': 'get_vod_streams', 'category_id': ?categoryId},
    XtreamVodStream.listFromJson,
    cancelToken: cancelToken,
    receiveTimeout: categoryId == null ? bulkReceiveTimeout : null,
    retries: retries,
  );

  /// Per-category fallback for [vodStreams]; same rules as
  /// [liveStreamsPerCategory].
  Future<List<XtreamVodStream>> vodStreamsPerCategory(
    List<String> categoryIds, {
    int concurrency = 4,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
    void Function(String categoryId, SourceException error)? onCategoryError,
  }) => _perCategory<XtreamVodStream>(
    categoryIds,
    (id, token) => vodStreams(categoryId: id, cancelToken: token),
    keyOf: (s) => s.streamId,
    merge: (kept, other) => kept,
    concurrency: concurrency,
    cancelToken: cancelToken,
    onProgress: onProgress,
    onCategoryError: onCategoryError,
  );

  Future<List<XtreamCategory>> seriesCategories({CancelToken? cancelToken}) =>
      _get(
        const {'action': 'get_series_categories'},
        XtreamCategory.listFromJson,
        cancelToken: cancelToken,
      );

  /// All series at once ([bulkReceiveTimeout]) or one category.
  Future<List<XtreamSeries>> seriesList({
    String? categoryId,
    CancelToken? cancelToken,
  }) => _get(
    {'action': 'get_series', 'category_id': ?categoryId},
    XtreamSeries.listFromJson,
    cancelToken: cancelToken,
    receiveTimeout: categoryId == null ? bulkReceiveTimeout : null,
    retries: retries,
  );

  /// Per-category fallback for [seriesList]; same rules as
  /// [liveStreamsPerCategory].
  Future<List<XtreamSeries>> seriesListPerCategory(
    List<String> categoryIds, {
    int concurrency = 4,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
    void Function(String categoryId, SourceException error)? onCategoryError,
  }) => _perCategory<XtreamSeries>(
    categoryIds,
    (id, token) => seriesList(categoryId: id, cancelToken: token),
    keyOf: (s) => s.seriesId,
    merge: (kept, other) => kept,
    concurrency: concurrency,
    cancelToken: cancelToken,
    onProgress: onProgress,
    onCategoryError: onCategoryError,
  );

  /// `get_vod_info`. An unknown id usually yields an empty info
  /// ([XtreamVodInfo.isEmpty]) rather than an error.
  Future<XtreamVodInfo> vodInfo(String vodId, {CancelToken? cancelToken}) =>
      _get(
        {'action': 'get_vod_info', 'vod_id': vodId},
        _vodInfoParser(vodId),
        cancelToken: cancelToken,
        retries: retries,
      );

  /// `get_series_info`.
  Future<XtreamSeriesInfo> seriesInfo(
    String seriesId, {
    CancelToken? cancelToken,
  }) => _get(
    {'action': 'get_series_info', 'series_id': seriesId},
    _seriesInfoParser(seriesId),
    cancelToken: cancelToken,
    retries: retries,
  );

  /// `get_short_epg` (now + next [limit] programmes).
  Future<List<XtreamEpgListing>> shortEpg(
    String streamId, {
    int limit = 10,
    CancelToken? cancelToken,
  }) => _get(
    {
      'action': 'get_short_epg',
      'stream_id': streamId,
      'limit': '${math.max(1, limit)}',
    },
    _epgParser(serverUtcOffset),
    cancelToken: cancelToken,
    retries: retries,
  );

  /// `get_simple_data_table` (full day with `now_playing` / `has_archive`).
  Future<List<XtreamEpgListing>> simpleDataTable(
    String streamId, {
    CancelToken? cancelToken,
  }) => _get(
    {'action': 'get_simple_data_table', 'stream_id': streamId},
    _epgParser(serverUtcOffset),
    cancelToken: cancelToken,
    retries: retries,
  );

  /// `{server}/xmltv.php?username=&password=`.
  Uri xmltvUri() => urls.xmltvUri();

  // -------------------------------------------------------------------------

  Future<T> _get<T>(
    Map<String, String> params,
    T Function(Object? json) parse, {
    CancelToken? cancelToken,
    Duration? receiveTimeout,
    int? retries,
  }) async {
    final Uri uri;
    try {
      uri = urls.playerApiUri(params);
    } on FormatException {
      throw SourceException(
        SourceErrorKind.unreachable,
        message: 'Invalid server URL',
        url: maskServer(credentials.server),
      );
    }
    final url = uri.toString();
    final effectiveRetries = retries ?? this.retries;

    final Response<List<int>> response;
    try {
      response = await _dio.getUri<List<int>>(
        uri,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
          extra: {kRetriesExtraKey: ?effectiveRetries},
        ),
      );
    } on DioException catch (e) {
      throw mapDioError(e, url: url);
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    final bytes = data == null
        ? Uint8List(0)
        : (data is Uint8List ? data : Uint8List.fromList(data));

    if (!isSuccessStatus(status)) {
      if (status == 401 || _isAuthFailureBody(bytes)) {
        throw SourceException(
          SourceErrorKind.unauthorized,
          statusCode: status,
          message: 'Credentials rejected (HTTP $status)',
          url: maskUrl(url),
        );
      }
      throw sourceExceptionForStatus(status, url: url);
    }

    final decoded = bytes.length > xtreamIsolateThreshold
        ? await _decodeInBackground(bytes, parse)
        : _decodeAndParse(bytes, parse);
    if (cancelToken?.isCancelled ?? false) {
      throw SourceException(
        SourceErrorKind.cancelled,
        message: 'Request cancelled',
        url: maskUrl(url),
      );
    }
    final kind = decoded.kind;
    if (kind != null) {
      throw SourceException(
        kind,
        statusCode: status,
        message: decoded.message,
        url: maskUrl(url),
      );
    }
    return decoded.value as T;
  }

  String _apiUrlForErrors(Map<String, String> params) {
    try {
      return urls.playerApiUri(params).toString();
    } on FormatException {
      return credentials.server;
    }
  }

  Future<List<T>> _perCategory<T>(
    List<String> categoryIds,
    Future<List<T>> Function(String categoryId, CancelToken token) fetch, {
    required String Function(T item) keyOf,
    required T Function(T kept, T other) merge,
    required int concurrency,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
    void Function(String categoryId, SourceException error)? onCategoryError,
  }) async {
    if (categoryIds.isEmpty) return [];
    if (cancelToken?.isCancelled ?? false) {
      throw SourceException(
        SourceErrorKind.cancelled,
        message: 'Request cancelled',
        url: maskServer(credentials.server),
      );
    }
    // One token for the whole batch: cancelled by the caller, or by us after
    // the first failure in strict mode.
    final batchToken = CancelToken();
    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancel.then((_) {
          if (!batchToken.isCancelled) batchToken.cancel('cancelled by caller');
        }),
      );
    }

    final results = List<List<T>?>.filled(categoryIds.length, null);
    var next = 0;
    var done = 0;
    SourceException? failure;

    Future<void> worker() async {
      while (failure == null) {
        final index = next++;
        if (index >= categoryIds.length) return;
        try {
          results[index] = await fetch(categoryIds[index], batchToken);
        } on SourceException catch (e) {
          if (cancelToken?.isCancelled ?? false) {
            failure ??= SourceException(
              SourceErrorKind.cancelled,
              message: 'Request cancelled',
              url: e.url,
            );
            return;
          }
          if (e.kind == SourceErrorKind.cancelled) {
            // Cancelled by us after another category failed.
            return;
          }
          if (onCategoryError == null) {
            failure ??= e;
            if (!batchToken.isCancelled) batchToken.cancel('category failed');
            return;
          }
          onCategoryError(categoryIds[index], e);
          results[index] = const [];
        }
        done++;
        onProgress?.call(done, categoryIds.length);
      }
    }

    final workers = math.max(1, math.min(concurrency, categoryIds.length));
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    final error = failure;
    if (error != null) throw error;

    final merged = <String, T>{};
    for (final list in results) {
      for (final item in list ?? <T>[]) {
        final key = keyOf(item);
        final kept = merged[key];
        merged[key] = kept == null ? item : merge(kept, item);
      }
    }
    return merged.values.toList();
  }
}

List<String> _union(List<String> a, List<String> b) =>
    List.unmodifiable({...a, ...b});

// ---------------------------------------------------------------------------
// Decoding (runs on the calling isolate for small bodies, else in
// Isolate.run). Parsers are static or top-level so the closures sent to the
// background isolate capture only sendable values.
// ---------------------------------------------------------------------------

XtreamAccount? _parseAccount(Object? json) =>
    (json is Map && json['user_info'] is Map)
    ? XtreamAccount.fromJson(json)
    : null;

XtreamVodInfo Function(Object?) _vodInfoParser(String vodId) =>
    (json) => XtreamVodInfo.fromJson(json, vodId: vodId);

XtreamSeriesInfo Function(Object?) _seriesInfoParser(String seriesId) =>
    (json) => XtreamSeriesInfo.fromJson(json, seriesId: seriesId);

List<XtreamEpgListing> Function(Object?) _epgParser(Duration offset) =>
    (json) => XtreamEpgListing.listFromJson(json, serverOffset: offset);

final class _Decoded<T> {
  _Decoded.ok(this.value) : kind = null, message = null;
  _Decoded.fail(SourceErrorKind this.kind, String this.message) : value = null;

  final T? value;
  final SourceErrorKind? kind;
  final String? message;
}

Future<_Decoded<T>> _decodeInBackground<T>(
  Uint8List bytes,
  T Function(Object? json) parse,
) => Isolate.run(
  () => _decodeAndParse(bytes, parse),
  debugName: 'xtream-decode',
);

final Converter<List<int>, Object?> _utf8Json = const Utf8Decoder(
  allowMalformed: true,
).fuse(const JsonDecoder());

const int _lt = 0x3C; // <
const int _lbrace = 0x7B; // {
const int _lbracket = 0x5B; // [

_Decoded<T> _decodeAndParse<T>(
  Uint8List bytes,
  T Function(Object? json) parse,
) {
  final start = _contentStart(bytes);
  if (start >= bytes.length) {
    return _Decoded<T>.fail(SourceErrorKind.emptyBody, 'Empty response body');
  }

  Object? json;
  var decoded = false;
  final first = bytes[start];
  if (first == _lt) {
    // PHP notices (`<br /><b>Notice</b>: …`) sometimes precede the JSON;
    // a real HTML document never parses.
    final html = _looksLikeHtmlDocument(bytes, start);
    final jsonStart = html ? -1 : _jsonStart(bytes, start);
    if (jsonStart >= 0) {
      (json, decoded) = _tryDecode(bytes, jsonStart);
    }
    if (!decoded) {
      return _Decoded<T>.fail(
        SourceErrorKind.unparseable,
        html ? 'HTML page instead of JSON' : 'Markup instead of JSON',
      );
    }
  } else {
    (json, decoded) = _tryDecode(bytes, start);
    if (!decoded && first != _lbrace && first != _lbracket) {
      // Plain-text junk before the JSON.
      final jsonStart = _jsonStart(bytes, start);
      if (jsonStart >= 0) (json, decoded) = _tryDecode(bytes, jsonStart);
    }
    if (!decoded) {
      return _Decoded<T>.fail(
        SourceErrorKind.unparseable,
        'Response is not valid JSON',
      );
    }
  }

  if (_isAuthFailureJson(json)) {
    return _Decoded<T>.fail(
      SourceErrorKind.unauthorized,
      'user_info.auth is 0',
    );
  }
  try {
    return _Decoded<T>.ok(parse(json));
  } on Object {
    return _Decoded<T>.fail(
      SourceErrorKind.unparseable,
      'Unexpected JSON structure',
    );
  }
}

(Object?, bool) _tryDecode(Uint8List bytes, int start) {
  try {
    return (_utf8Json.convert(Uint8List.sublistView(bytes, start)), true);
  } on FormatException {
    return (null, false);
  }
}

/// Index of the first byte after a UTF-8 BOM and whitespace.
int _contentStart(Uint8List bytes) {
  var i = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    i = 3;
  }
  while (i < bytes.length) {
    final b = bytes[i];
    if (b != 0x20 && b != 0x09 && b != 0x0A && b != 0x0D) break;
    i++;
  }
  return i;
}

int _jsonStart(Uint8List bytes, int from) {
  for (var i = from; i < bytes.length; i++) {
    final b = bytes[i];
    if (b == _lbrace || b == _lbracket) return i;
  }
  return -1;
}

bool _looksLikeHtmlDocument(Uint8List bytes, int start) {
  final end = math.min(bytes.length, start + 2048);
  final head = latin1.decode(Uint8List.sublistView(bytes, start, end));
  final lower = head.toLowerCase();
  return lower.contains('<html') ||
      lower.contains('<!doctype') ||
      lower.contains('<head') ||
      lower.contains('<body') ||
      lower.contains('<title');
}

bool _isAuthFailureJson(Object? json) {
  if (json is! Map) return false;
  final userInfo = json['user_info'];
  return userInfo is Map && asBool(userInfo['auth']) == false;
}

/// `{"user_info":{"auth":0}}` in a small non-2xx body.
bool _isAuthFailureBody(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 64 * 1024) return false;
  final start = _contentStart(bytes);
  if (start >= bytes.length || bytes[start] != _lbrace) return false;
  final (json, ok) = _tryDecode(bytes, start);
  return ok && _isAuthFailureJson(json);
}
