import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

typedef TestHandler = FutureOr<void> Function(HttpRequest request);

/// A request as the test server saw it.
class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers);

  final String method;
  final Uri uri;

  /// Lowercased header names; multiple values joined with `, `.
  final Map<String, String> headers;
}

/// A tiny loopback HTTP server for tests (binds 127.0.0.1, port 0) that
/// serves canned responses by path.
class TestHttpServer {
  TestHttpServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<TestHttpServer> start() async =>
      TestHttpServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final Map<String, TestHandler> _routes = {};
  final List<RecordedRequest> requests = [];
  int _inFlight = 0;

  /// Highest number of requests handled at the same time.
  int maxInFlight = 0;

  int get port => _server.port;
  String get baseUrl => 'http://127.0.0.1:${_server.port}';
  String url(String pathAndQuery) => '$baseUrl$pathAndQuery';

  /// gzip-compress chunked responses for clients that accept gzip.
  set autoCompress(bool value) => _server.autoCompress = value;

  void route(String path, TestHandler handler) => _routes[path] = handler;

  List<RecordedRequest> requestsTo(String path) =>
      requests.where((r) => r.uri.path == path).toList();

  Future<void> _handle(HttpRequest request) async {
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(', ');
    });
    requests.add(RecordedRequest(request.method, request.uri, headers));
    _inFlight++;
    maxInFlight = math.max(maxInFlight, _inFlight);
    try {
      final handler = _routes[request.uri.path];
      if (handler == null) {
        request.response.statusCode = 404;
        await request.response.close();
      } else {
        await handler(request);
      }
    } on Object {
      // The client went away; nothing to do.
      try {
        await request.response.close();
      } on Object {
        // Ignore.
      }
    } finally {
      _inFlight--;
    }
  }

  Future<void> close() => _server.close(force: true);
}

Future<void> sendJson(
  HttpRequest request,
  Object? json, {
  int status = 200,
  String contentType = 'application/json',
}) => sendText(
  request,
  jsonEncode(json),
  status: status,
  contentType: contentType,
);

Future<void> sendText(
  HttpRequest request,
  String body, {
  int status = 200,
  String? contentType = 'text/plain; charset=utf-8',
  bool chunked = false,
}) => sendBytes(
  request,
  utf8.encode(body),
  status: status,
  contentType: contentType,
  chunked: chunked,
);

Future<void> sendBytes(
  HttpRequest request,
  List<int> body, {
  int status = 200,
  String? contentType,
  bool chunked = false,
}) async {
  final response = request.response..statusCode = status;
  if (contentType != null) {
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
  }
  if (!chunked) response.contentLength = body.length;
  response.add(body);
  await response.close();
}

Future<void> sendRedirect(
  HttpRequest request,
  String location, {
  int status = HttpStatus.found,
}) async {
  request.response
    ..statusCode = status
    ..headers.set(HttpHeaders.locationHeader, location)
    ..contentLength = 0;
  await request.response.close();
}

/// Closes the socket without sending a response.
Future<void> dropConnection(HttpRequest request) async {
  final socket = await request.response.detachSocket(writeHeaders: false);
  socket.destroy();
}

/// A port on 127.0.0.1 with nothing listening.
Future<int> closedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
