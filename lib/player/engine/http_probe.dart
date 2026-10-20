/// Finds out why an HTTP stream failed to open by asking the server.
///
/// libmpv forwards FFmpeg's own log lines (`http: HTTP error 403 Forbidden`,
/// `tcp: Connection refused`) to a single mpv instance per process — the
/// oldest live one — so with several players (preview, main player,
/// multi-channel tiles) a player often never sees the line that explains its
/// failure. After a failed load the engine sends one GET with the same
/// User-Agent and headers and reads only the status line.
library;

import 'dart:async';
import 'dart:io';

import 'engine_errors.dart';
import 'playback_engine.dart';

/// `http://` or `https://`.
bool isHttpUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('http://') || u.startsWith('https://');
}

/// The server's answer as an [EngineError], or null when it answered with a
/// success status (the failure is then not an HTTP problem).
Future<EngineError?> probeHttpFailure(
  String url, {
  Map<String, String> headers = const {},
  String? userAgent,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !isHttpUrl(url)) return null;
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..idleTimeout = const Duration(seconds: 1)
    ..autoUncompress = false;
  if (userAgent != null && userAgent.isNotEmpty) client.userAgent = userAgent;
  final where = maskUrlForLog(url);
  try {
    final response = await () async {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      headers.forEach((name, value) {
        try {
          request.headers.set(name, value);
        } catch (_) {
          // Ignore header names dart:io rejects.
        }
      });
      return request.close();
    }().timeout(timeout);
    final status = response.statusCode;
    // Never download the stream body.
    unawaited(
      response
          .detachSocket()
          .then((socket) => socket.destroy())
          .catchError((Object _) {}),
    );
    if (status >= 400) {
      return EngineError(
        kind: EngineErrorKind.http,
        statusCode: status,
        message: httpStatusMessage(status),
        detail: 'HTTP $status from $where',
      );
    }
    return null;
  } on TimeoutException {
    return EngineError(
      kind: EngineErrorKind.timeout,
      message: timeoutError().message,
      detail: 'no answer from $where within ${timeout.inSeconds} s',
    );
  } on SocketException catch (e) {
    final text = '${e.message} ${e.osError?.message ?? ''}'.trim();
    if (RegExp(r'timed? ?out', caseSensitive: false).hasMatch(text)) {
      return EngineError(
        kind: EngineErrorKind.timeout,
        message: timeoutError().message,
        detail: scrubUrls('$where: $text'),
      );
    }
    return EngineError(
      kind: EngineErrorKind.network,
      message: 'Could not connect to the server. Check your connection.',
      detail: scrubUrls('$where: $text'),
    );
  } on HandshakeException catch (e) {
    return EngineError(
      kind: EngineErrorKind.network,
      message: 'Secure connection failed (TLS).',
      detail: scrubUrls('$where: ${e.message}'),
    );
  } on HttpException catch (e) {
    return EngineError(
      kind: EngineErrorKind.network,
      message: 'The server closed the connection.',
      detail: scrubUrls('$where: ${e.message}'),
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
