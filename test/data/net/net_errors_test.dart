import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/net_errors.dart';
import 'package:carina/data/sources/source_exception.dart';

const _url =
    'http://domain.com:8080/player_api.php?username=kanal&password=test123';

DioException _dio(
  DioExceptionType type, {
  Object? error,
  int? status,
  String? message,
}) {
  final options = RequestOptions(path: _url);
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    message: message,
    response: status == null
        ? null
        : Response<void>(requestOptions: options, statusCode: status),
  );
}

void main() {
  void expectKind(
    DioException e,
    SourceErrorKind kind, {
    int? status,
    String? message,
  }) {
    final mapped = mapDioError(e, url: _url);
    expect(mapped.kind, kind, reason: '$e');
    if (status != null) expect(mapped.statusCode, status);
    if (message != null) expect(mapped.message, message);
    expect(
      mapped.url,
      'http://dom***:8080/player_api.php?username=***&password=***',
    );
    expect(mapped.toString(), isNot(contains('test123')));
    expect(mapped.message ?? '', isNot(contains('test123')));
  }

  test('cancel and timeouts', () {
    expectKind(_dio(DioExceptionType.cancel), SourceErrorKind.cancelled);
    expectKind(
      _dio(DioExceptionType.connectionTimeout),
      SourceErrorKind.timeout,
    );
    expectKind(_dio(DioExceptionType.receiveTimeout), SourceErrorKind.timeout);
    expectKind(_dio(DioExceptionType.sendTimeout), SourceErrorKind.timeout);
    expectKind(
      _dio(DioExceptionType.transformTimeout),
      SourceErrorKind.timeout,
    );
  });

  test('bad certificate', () {
    expectKind(
      _dio(DioExceptionType.badCertificate),
      SourceErrorKind.unreachable,
      message: 'TLS certificate rejected',
    );
  });

  test('bad responses by status', () {
    expectKind(
      _dio(DioExceptionType.badResponse, status: 401),
      SourceErrorKind.unauthorized,
      status: 401,
    );
    expectKind(
      _dio(DioExceptionType.badResponse, status: 403),
      SourceErrorKind.forbidden,
      status: 403,
    );
    expectKind(
      _dio(DioExceptionType.badResponse, status: 404),
      SourceErrorKind.notFound,
      status: 404,
    );
    expectKind(
      _dio(DioExceptionType.badResponse, status: 410),
      SourceErrorKind.notFound,
      status: 410,
    );
    expectKind(
      _dio(DioExceptionType.badResponse, status: 500),
      SourceErrorKind.http,
      status: 500,
    );
    expectKind(
      _dio(DioExceptionType.badResponse, status: 429),
      SourceErrorKind.http,
      status: 429,
    );
  });

  test('connection errors', () {
    expectKind(
      _dio(
        DioExceptionType.connectionError,
        error: const SocketException(
          "Failed host lookup: 'domain.com'",
          osError: OSError('nodename nor servname provided', 8),
        ),
      ),
      SourceErrorKind.unreachable,
      message: 'DNS lookup failed',
    );
    expectKind(
      _dio(
        DioExceptionType.connectionError,
        error: const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 61),
        ),
      ),
      SourceErrorKind.unreachable,
      message: 'Connection refused',
    );
    expectKind(
      _dio(
        DioExceptionType.connectionError,
        error: const HttpException(
          'Connection closed before full header was received',
        ),
      ),
      SourceErrorKind.unreachable,
      message: 'Connection closed before the response',
    );
    expectKind(
      _dio(
        DioExceptionType.connectionError,
        message: "Dio can't establish a new connection after it was closed.",
      ),
      SourceErrorKind.unreachable,
    );
    expectKind(
      _dio(
        DioExceptionType.unknown,
        error: const SocketException('Connection timed out'),
      ),
      SourceErrorKind.timeout,
    );
  });

  test('unknown errors by cause', () {
    expectKind(
      _dio(
        DioExceptionType.unknown,
        error: const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      ),
      SourceErrorKind.unreachable,
      message: 'TLS handshake failed',
    );
    expectKind(
      _dio(
        DioExceptionType.unknown,
        error: const RedirectException('Redirect limit exceeded', []),
      ),
      SourceErrorKind.http,
      message: 'Too many redirects',
    );
    expectKind(
      _dio(
        DioExceptionType.unknown,
        error: const RedirectException('Redirect loop detected', []),
      ),
      SourceErrorKind.http,
      message: 'Redirect loop',
    );
    expectKind(
      _dio(
        DioExceptionType.unknown,
        error: HttpException(
          'Connection closed while receiving data',
          uri: Uri.parse(_url),
        ),
      ),
      SourceErrorKind.unreachable,
      message: 'Connection closed while receiving data',
    );
    expectKind(
      _dio(DioExceptionType.unknown, error: TimeoutException('slow')),
      SourceErrorKind.timeout,
    );
    expectKind(
      _dio(DioExceptionType.unknown, error: const FormatException('bad json')),
      SourceErrorKind.unparseable,
    );
    expectKind(
      _dio(DioExceptionType.unknown, error: ArgumentError('No host')),
      SourceErrorKind.unreachable,
      message: 'Invalid URL',
    );
    expectKind(
      _dio(DioExceptionType.unknown, error: StateError('closed')),
      SourceErrorKind.unreachable,
    );
    expectKind(_dio(DioExceptionType.unknown), SourceErrorKind.unreachable);
  });

  test('a FormatException for a malformed URL is unreachable', () {
    final mapped = mapNetworkError(
      const FormatException('Invalid port'),
      url: 'http://[bad',
    );
    expect(mapped.kind, SourceErrorKind.unreachable);
    expect(mapped.message, 'Invalid URL');
  });

  test('mapNetworkError passes SourceException through', () {
    const original = SourceException(SourceErrorKind.emptyBody);
    expect(identical(mapNetworkError(original, url: _url), original), isTrue);
  });

  test('status helpers', () {
    expect(sourceErrorKindForStatus(401), SourceErrorKind.unauthorized);
    expect(sourceErrorKindForStatus(403), SourceErrorKind.forbidden);
    expect(sourceErrorKindForStatus(404), SourceErrorKind.notFound);
    expect(sourceErrorKindForStatus(502), SourceErrorKind.http);
    expect(isSuccessStatus(200), isTrue);
    expect(isSuccessStatus(206), isTrue);
    expect(isSuccessStatus(304), isFalse);
    expect(isSuccessStatus(null), isFalse);
    final e = sourceExceptionForStatus(404, url: _url);
    expect(e.statusCode, 404);
    expect(e.url, isNot(contains('test123')));
  });

  test('transient error classification', () {
    expect(isTransientNetworkError(const SocketException('reset')), isTrue);
    expect(isTransientNetworkError(const HttpException('closed')), isTrue);
    expect(
      isTransientNetworkError(const RedirectException('loop', [])),
      isFalse,
    );
    expect(isTransientNetworkError(const FormatException('x')), isFalse);
    expect(isTransientNetworkError(null), isFalse);
  });
}
