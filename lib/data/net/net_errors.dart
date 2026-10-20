import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../sources/source_exception.dart';
import 'mask.dart';

/// Maps an HTTP status to a [SourceErrorKind]: 401 → unauthorized,
/// 403 → forbidden, 404/410 → notFound, anything else → http.
SourceErrorKind sourceErrorKindForStatus(int status) => switch (status) {
  401 => SourceErrorKind.unauthorized,
  403 => SourceErrorKind.forbidden,
  404 || 410 => SourceErrorKind.notFound,
  _ => SourceErrorKind.http,
};

/// Builds the [SourceException] for a non-2xx [status]. [url] is masked here.
SourceException sourceExceptionForStatus(
  int status, {
  required String url,
  String? message,
}) => SourceException(
  sourceErrorKindForStatus(status),
  statusCode: status,
  message: message ?? 'HTTP $status',
  url: maskUrl(url),
);

/// Whether [status] is a 2xx status.
bool isSuccessStatus(int? status) =>
    status != null && status >= 200 && status < 300;

/// Throws the mapped [SourceException] unless [response] has a 2xx status.
///
/// Dio instances from `createDio` accept every status (see `validateStatus`),
/// so callers check the status with this helper.
void ensureSuccess(Response<dynamic> response, {required String url}) {
  final status = response.statusCode;
  if (!isSuccessStatus(status)) {
    throw sourceExceptionForStatus(status ?? 0, url: url);
  }
}

/// Maps a [DioException] to a [SourceException] with a masked [url]:
/// unreachable / timeout / cancelled / unauthorized / forbidden / notFound /
/// http / unparseable. The message never contains credentials.
SourceException mapDioError(DioException e, {required String url}) {
  final masked = maskUrl(url);
  switch (e.type) {
    case DioExceptionType.cancel:
      return SourceException(
        SourceErrorKind.cancelled,
        message: 'Request cancelled',
        url: masked,
      );
    case DioExceptionType.connectionTimeout:
      return SourceException(
        SourceErrorKind.timeout,
        message: 'Connection timed out',
        url: masked,
      );
    case DioExceptionType.receiveTimeout:
      return SourceException(
        SourceErrorKind.timeout,
        message: 'Server did not respond in time',
        url: masked,
      );
    case DioExceptionType.sendTimeout:
      return SourceException(
        SourceErrorKind.timeout,
        message: 'Sending the request timed out',
        url: masked,
      );
    case DioExceptionType.transformTimeout:
      return SourceException(
        SourceErrorKind.timeout,
        message: 'Decoding the response timed out',
        url: masked,
      );
    case DioExceptionType.badCertificate:
      return SourceException(
        SourceErrorKind.unreachable,
        message: 'TLS certificate rejected',
        url: masked,
      );
    case DioExceptionType.badResponse:
      return sourceExceptionForStatus(e.response?.statusCode ?? 0, url: url);
    case DioExceptionType.connectionError:
      final error = e.error;
      if (error != null) return mapNetworkError(error, url: url);
      return SourceException(
        SourceErrorKind.unreachable,
        message: _connectionMessage(e.message ?? ''),
        url: masked,
      );
    case DioExceptionType.unknown:
      return mapNetworkError(e.error ?? e, url: url);
  }
}

/// Maps any error thrown while talking to a server (a [DioException], or a raw
/// [SocketException] / [HttpException] / [TimeoutException] delivered through
/// a response stream) to a [SourceException]. [SourceException]s pass through.
SourceException mapNetworkError(Object error, {required String url}) {
  final masked = maskUrl(url);
  if (error is SourceException) return error;
  if (error is DioException) {
    // Avoid infinite recursion for an unknown DioException without a cause.
    if (error.type != DioExceptionType.unknown || error.error != null) {
      return mapDioError(error, url: url);
    }
    return SourceException(
      SourceErrorKind.unreachable,
      message: 'Request failed',
      url: masked,
    );
  }
  if (error is SocketException) {
    final text = '${error.message} ${error.osError?.message ?? ''}';
    if (text.toLowerCase().contains('timed out')) {
      return SourceException(
        SourceErrorKind.timeout,
        message: 'Connection timed out',
        url: masked,
      );
    }
    return SourceException(
      SourceErrorKind.unreachable,
      message: _connectionMessage(text, errno: error.osError?.errorCode),
      url: masked,
    );
  }
  if (error is TlsException) {
    return SourceException(
      SourceErrorKind.unreachable,
      message: 'TLS handshake failed',
      url: masked,
    );
  }
  if (error is RedirectException) {
    final loop = error.message.toLowerCase().contains('loop');
    return SourceException(
      SourceErrorKind.http,
      statusCode: error.redirects.isEmpty
          ? null
          : error.redirects.last.statusCode,
      message: loop ? 'Redirect loop' : 'Too many redirects',
      url: masked,
    );
  }
  if (error is HttpException) {
    return SourceException(
      SourceErrorKind.unreachable,
      message: _connectionMessage(error.message),
      url: masked,
    );
  }
  if (error is TimeoutException) {
    return SourceException(
      SourceErrorKind.timeout,
      message: 'Request timed out',
      url: masked,
    );
  }
  if (error is FormatException) {
    // Either the URL itself is malformed, or a JSON body failed to decode.
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return SourceException(
        SourceErrorKind.unreachable,
        message: 'Invalid URL',
        url: masked,
      );
    }
    return SourceException(
      SourceErrorKind.unparseable,
      message: 'Malformed response',
      url: masked,
    );
  }
  if (error is ArgumentError) {
    return SourceException(
      SourceErrorKind.unreachable,
      message: 'Invalid URL',
      url: masked,
    );
  }
  return SourceException(
    SourceErrorKind.unreachable,
    message: 'Request failed (${error.runtimeType})',
    url: masked,
  );
}

/// Whether [error] is a transient transport failure worth retrying.
bool isTransientNetworkError(Object? error) {
  if (error is SocketException) return true;
  if (error is RedirectException) return false;
  if (error is HttpException) return true;
  return false;
}

String _connectionMessage(String raw, {int? errno}) {
  final text = raw.toLowerCase();
  if (text.contains('host lookup') ||
      text.contains('nodename nor servname') ||
      text.contains('name or service not known') ||
      text.contains('no address associated')) {
    return 'DNS lookup failed';
  }
  if (text.contains('refused') ||
      errno == 61 ||
      errno == 111 ||
      errno == 10061) {
    return 'Connection refused';
  }
  if (text.contains('unreachable') || text.contains('no route')) {
    return 'Network unreachable';
  }
  if (text.contains('reset')) return 'Connection reset';
  if (text.contains('before full header')) {
    return 'Connection closed before the response';
  }
  if (text.contains('closed while receiving')) {
    return 'Connection closed while receiving data';
  }
  return 'Connection failed';
}
