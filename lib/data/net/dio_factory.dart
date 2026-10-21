import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../core/user_agent.dart';
import 'retry_interceptor.dart';

export '../../core/user_agent.dart';
export 'download.dart' show downloadToFile;
export 'net_errors.dart';
export 'retry_interceptor.dart';

/// Creates the app's [Dio] for playlist sources, EPG and artwork.
///
/// - User-Agent: [userAgent], else a `User-Agent` entry in [headers], else
///   [defaultUserAgent]. It is also set on the underlying `HttpClient`, so it
///   survives redirects (dart:io re-creates the request on a redirect and
///   would otherwise send its own `Dart/x (dart:io)` agent).
/// - Redirects: GET/HEAD follow 301/302/303/307/308, at most 5 hops.
/// - gzip: `Accept-Encoding: gzip` is sent and bodies are decompressed.
/// - `validateStatus` accepts every status: a 4xx/5xx is returned as a normal
///   [Response] so callers map it themselves (`ensureSuccess`,
///   `sourceExceptionForStatus`). Transport failures still throw
///   [DioException]; map them with `mapDioError`.
/// - Retries: [RetryInterceptor] with [retries] retries for idempotent GETs
///   (override per request with `extra: {kRetriesExtraKey: n}`).
/// - JSON bodies with a JSON content type are decoded by
///   [BackgroundTransformer] (bodies over 50 KB on a background isolate).
///
/// Do not use `Dio.download` with this instance (it would write error pages
/// to disk because every status is accepted); use `downloadToFile`.
Dio createDio({
  String? userAgent,
  Duration connectTimeout = const Duration(seconds: 10),
  Duration receiveTimeout = const Duration(seconds: 60),
  Map<String, String>? headers,
  int retries = 2,
  Duration retryDelay = const Duration(milliseconds: 500),
}) {
  final extraHeaders = <String, String>{};
  String? headerAgent;
  headers?.forEach((key, value) {
    if (key.toLowerCase() == 'user-agent') {
      headerAgent = value;
    } else {
      extraHeaders[key] = value;
    }
  });
  final agent = _nonBlank(userAgent) ?? _nonBlank(headerAgent);
  final effectiveAgent = agent ?? defaultUserAgent();

  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => true,
      receiveDataWhenStatusError: true,
      headers: <String, dynamic>{
        ...extraHeaders,
        HttpHeaders.userAgentHeader: effectiveAgent,
      },
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..userAgent = effectiveAgent
      ..autoUncompress = true
      ..idleTimeout = const Duration(seconds: 15)
      ..connectionTimeout = connectTimeout,
  );
  dio.transformer = BackgroundTransformer();
  dio.interceptors.add(
    RetryInterceptor(dio, retries: retries, baseDelay: retryDelay),
  );
  return dio;
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
