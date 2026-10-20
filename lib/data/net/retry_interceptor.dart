import 'dart:async';

import 'package:dio/dio.dart';

import 'net_errors.dart';

/// Request `extra` key: the maximum number of retries for one request (int).
/// `0` disables retries, e.g. for a bulk call that has its own fallback.
const String kRetriesExtraKey = 'carina.retries';

/// Request `extra` key holding the number of retries already made.
const String kRetryAttemptExtraKey = 'carina.retryAttempt';

/// Retries idempotent requests (GET/HEAD) on transient failures:
/// connection errors, connection/receive timeouts, dropped connections and
/// 502/503/504 gateway statuses. Never retries 4xx, cancellations, TLS
/// failures or redirect errors.
///
/// The delay doubles with each attempt: [baseDelay], 2×[baseDelay], …
/// A cancel token cancelled during the delay stops the retry.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.retries = 2,
    this.baseDelay = const Duration(milliseconds: 500),
  });

  final Dio _dio;

  /// Default maximum retries; a request can override it with
  /// [kRetriesExtraKey] in its `extra` map.
  final int retries;
  final Duration baseDelay;

  /// Statuses that are retried even though the server answered.
  static const Set<int> retryStatuses = {502, 503, 504};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isIdempotent(options) || !_isRetryable(err) || !_hasBudget(options)) {
      handler.next(err);
      return;
    }
    final retried = await _retry(options);
    switch (retried) {
      case Response<dynamic>():
        handler.resolve(retried);
      case DioException():
        handler.next(retried);
      default:
        handler.next(err);
    }
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    if (!retryStatuses.contains(response.statusCode) ||
        !_isIdempotent(options) ||
        !_hasBudget(options)) {
      handler.next(response);
      return;
    }
    // Discard a streamed body we are not going to use.
    final data = response.data;
    if (data is ResponseBody) {
      unawaited(data.stream.listen(null, onError: (_) {}).cancel());
    }
    final retried = await _retry(options);
    switch (retried) {
      case Response<dynamic>():
        handler.resolve(retried);
      case DioException():
        handler.reject(retried);
      default:
        handler.next(response);
    }
  }

  bool _isIdempotent(RequestOptions options) {
    final method = options.method.toUpperCase();
    return method == 'GET' || method == 'HEAD';
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        return retryStatuses.contains(err.response?.statusCode);
      case DioExceptionType.unknown:
        return isTransientNetworkError(err.error);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return false;
    }
  }

  int _attempt(RequestOptions options) {
    final value = options.extra[kRetryAttemptExtraKey];
    return value is int ? value : 0;
  }

  int _maxRetries(RequestOptions options) {
    final value = options.extra[kRetriesExtraKey];
    return value is int ? value : retries;
  }

  bool _hasBudget(RequestOptions options) =>
      _attempt(options) < _maxRetries(options);

  /// Waits, then re-sends [options]. Returns the [Response], the final
  /// [DioException], or null when the request was cancelled meanwhile.
  Future<Object?> _retry(RequestOptions options) async {
    final attempt = _attempt(options);
    final cancelToken = options.cancelToken;
    final delay = baseDelay * (1 << attempt);
    if (delay > Duration.zero) {
      await Future.any<Object?>([
        Future<Object?>.delayed(delay),
        if (cancelToken != null) cancelToken.whenCancel,
      ]);
    }
    if (cancelToken?.isCancelled ?? false) return cancelToken!.cancelError;
    options.extra[kRetryAttemptExtraKey] = attempt + 1;
    try {
      return await _dio.fetch<dynamic>(options);
    } on DioException catch (e) {
      return e;
    }
  }
}
