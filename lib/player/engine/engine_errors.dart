/// Maps mpv / FFmpeg log lines to readable [EngineError]s and detects
/// hardware-decoder failures. Pure functions; URLs are masked so
/// credentials never reach the UI or the logs.
library;

import 'dart:math' as math;

import 'playback_engine.dart';

final RegExp _url = RegExp(
  r'''\b(?:https?|rtmps?|rtsp|rtp|udp|mms|srt)://[^\s'"<>]+''',
  caseSensitive: false,
);

/// Masks one URL: `http://dom***:8080/…/1001.ts` (host cut after three
/// characters, path reduced to its last segment, query dropped).
String maskUrlForLog(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return '<url>';
  final host = uri.host.substring(0, math.min(3, uri.host.length));
  final port = uri.hasPort ? ':${uri.port}' : '';
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final last = segments.isEmpty ? '' : '/…/${segments.last}';
  return '${uri.scheme}://$host***$port$last';
}

/// Masks every URL in [text].
String scrubUrls(String text) =>
    text.replaceAllMapped(_url, (m) => maskUrlForLog(m.group(0)!));

final RegExp _httpStatus = RegExp(
  r'(?:HTTP error|Server returned|HTTP/\d(?:\.\d)?|status(?: code)?:?)\s+(\d{3})\b',
  caseSensitive: false,
);
final RegExp _http4xx = RegExp(
  r'Server returned 4XX|4XX Client Error',
  caseSensitive: false,
);
final RegExp _http5xx = RegExp(
  r'Server returned 5XX|5XX Server Error',
  caseSensitive: false,
);
final RegExp _timeout = RegExp(
  r'timed? ?out|timeout|ETIMEDOUT',
  caseSensitive: false,
);
final RegExp _network = RegExp(
  r'Connection refused|No route to host|Network is unreachable|'
  r'Network is down|Host is down|Failed to resolve|resolve host|'
  r'Name or service not known|nodename nor servname|getaddrinfo|'
  r'Connection reset|Broken pipe|Failed to connect|Unable to connect|'
  r'Could not connect|connection failed|tls: |SSL|certificate',
  caseSensitive: false,
);
final RegExp _unrecognized = RegExp(
  r'Failed to recognize file format|Invalid data found when processing input|'
  r'unknown format|Could not determine file format',
  caseSensitive: false,
);
final RegExp _codec = RegExp(
  r'Failed to initialize a decoder|Could not open codec|Codec not found|'
  r'codec not supported|Unsupported codec|No decoder|Decoder .* not found|'
  r'not supported by this build|Could not find codec|No video or audio streams',
  caseSensitive: false,
);
final RegExp _fileMissing = RegExp(
  r'No such file or directory|Cannot open file|Failed to open .*\.(ts|mp4|mkv|m3u8)\b',
  caseSensitive: false,
);

/// Readable message for an HTTP status.
String httpStatusMessage(int? status) {
  return switch (status) {
    401 =>
      'Access denied (HTTP 401). Check the playlist username and password.',
    403 =>
      'Access forbidden (HTTP 403). The provider refused the stream; the '
          'connection limit may be reached.',
    404 => 'Stream not found (HTTP 404).',
    null => 'The server rejected the request.',
    final s when s >= 500 => 'Server error (HTTP $s). Try again later.',
    final s => 'The server rejected the request (HTTP $s).',
  };
}

/// Ranks for picking the most specific error out of several lines.
int _rank(EngineError e) => switch (e.kind) {
  EngineErrorKind.http => 6,
  EngineErrorKind.timeout => 5,
  EngineErrorKind.network => 4,
  EngineErrorKind.codec => 3,
  EngineErrorKind.ended => 2,
  EngineErrorKind.unknown => 1,
};

/// Classifies one log line, or null when it is not an error signal.
EngineError? classifyLogLine(String line) {
  final text = line.trim();
  if (text.isEmpty) return null;
  final detail = scrubUrls(text);
  final status = _httpStatus.firstMatch(text);
  if (status != null) {
    final code = int.parse(status.group(1)!);
    if (code >= 400 && code <= 599) {
      return EngineError(
        kind: EngineErrorKind.http,
        statusCode: code,
        message: httpStatusMessage(code),
        detail: detail,
      );
    }
  }
  if (_http5xx.hasMatch(text)) {
    return EngineError(
      kind: EngineErrorKind.http,
      message: 'Server error. Try again later.',
      detail: detail,
    );
  }
  if (_http4xx.hasMatch(text)) {
    return EngineError(
      kind: EngineErrorKind.http,
      message: httpStatusMessage(null),
      detail: detail,
    );
  }
  if (_timeout.hasMatch(text)) {
    return EngineError(
      kind: EngineErrorKind.timeout,
      message: 'The stream did not respond in time (timeout).',
      detail: detail,
    );
  }
  if (_network.hasMatch(text)) {
    return EngineError(
      kind: EngineErrorKind.network,
      message: 'Could not connect to the server. Check your connection.',
      detail: detail,
    );
  }
  if (_unrecognized.hasMatch(text)) {
    return EngineError(
      kind: EngineErrorKind.codec,
      message:
          'Unrecognized stream format. The server may have sent an error '
          'page instead of video.',
      detail: detail,
    );
  }
  if (_codec.hasMatch(text)) {
    return EngineError(
      kind: EngineErrorKind.codec,
      message: 'This stream uses a codec that is not supported.',
      detail: detail,
    );
  }
  if (_fileMissing.hasMatch(text)) {
    return EngineError(
      kind: EngineErrorKind.unknown,
      message: 'The file could not be opened.',
      detail: detail,
    );
  }
  return null;
}

/// Whether a formatted log line (`[prefix] text`) came from FFmpeg's logger.
/// libmpv routes those to a single mpv instance per process, so with
/// several players they may describe another player.
bool isSharedFfmpegLine(String line) => line.startsWith('[ffmpeg');

/// The most specific error among [lines] (HTTP status > timeout > network >
/// codec > other). Falls back to a timeout when [timedOut], else to a
/// generic failure.
EngineError errorFromLogLines(Iterable<String> lines, {bool timedOut = false}) {
  EngineError? best;
  for (final line in lines) {
    final e = classifyLogLine(line);
    if (e == null) continue;
    if (best == null || _rank(e) > _rank(best)) best = e;
  }
  if (best != null) return best;
  if (timedOut) return timeoutError();
  return const EngineError(
    kind: EngineErrorKind.unknown,
    message: 'Playback failed.',
  );
}

/// The live stream stopped sending data.
EngineError endedError() => const EngineError(
  kind: EngineErrorKind.ended,
  message: 'The stream ended.',
);

/// No data arrived before the open watchdog fired.
EngineError timeoutError() => const EngineError(
  kind: EngineErrorKind.timeout,
  message: 'The stream did not respond in time (timeout).',
);

final RegExp _hwdecFailure = RegExp(
  r'Attempting next decoding method after failure|'
  r'hardware decoding failed|hwdec.*(?:fail|error|not available|unsupported)|'
  r'(?:fail|error|could not|unable to|cannot).{0,40}'
  r'(?:vdpau|d3d11|dxva|videotoolbox|vaapi|nvdec|cuda|mediacodec|hwaccel|'
  r'hardware decod)|'
  r'(?:vdpau|d3d11|dxva|videotoolbox|vaapi|nvdec|cuda|hwaccel)'
  r'.{0,40}(?:fail|error|could not|unable|not supported)|'
  r'Could not create device',
  caseSensitive: false,
);

/// A warning/error line that means hardware decoding failed (mpv usually
/// falls back by itself; the engine records it and pins software decoding).
///
/// One-off "Error while decoding frame (hardware decoding)!" lines are not
/// counted: joining a TS mid-GOP produces those with any decoder.
bool isHwdecFailureLine(String prefix, String text) {
  if (prefix == 'media_kit') return false;
  // FFmpeg's own messages reach only one mpv instance per process, so they
  // may belong to another player.
  if (prefix.startsWith('ffmpeg')) return false;
  if (RegExp(
    r'Error while decoding frame',
    caseSensitive: false,
  ).hasMatch(text)) {
    return false;
  }
  return _hwdecFailure.hasMatch(text);
}
