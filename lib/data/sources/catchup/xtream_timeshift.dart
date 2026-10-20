// Xtream Codes catch-up (timeshift) URLs. Shared by the M3U
// `xc` catch-up mode and the Xtream client (`XtreamUrls.timeshift…`).

import 'dart:convert';
import 'dart:math' as math;

/// `YYYY-MM-DD:HH-MM` of [startUtc] in the server's zone
/// (UTC + [serverOffset]), as Xtream timeshift URLs expect.
String formatXtreamTimeshiftStart(
  DateTime startUtc, [
  Duration serverOffset = Duration.zero,
]) {
  final t = startUtc.toUtc().add(serverOffset);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      ':${two(t.hour)}-${two(t.minute)}';
}

/// Catch-up length in whole minutes, rounded up so the end of the programme
/// is not cut off (0 when [endUtc] is not after [startUtc]).
int xtreamTimeshiftMinutes(DateTime startUtc, DateTime endUtc) {
  final seconds = endUtc.difference(startUtc).inSeconds;
  return math.max(0, (seconds + 59) ~/ 60);
}

/// Primary Xtream catch-up URL:
/// `{server}/timeshift/{username}/{password}/{durationMinutes}/{YYYY-MM-DD:HH-MM}/{streamId}.ts`.
///
/// [server] is scheme + host + port (a trailing slash is tolerated);
/// [streamId] is an int or a String. The start is written in the server's
/// zone (UTC + [serverOffset]; apply the EPG time shift to [startUtc]
/// before calling). Credentials are percent-encoded where a path segment
/// requires it (`@` and `:` stay as they are).
String xtreamTimeshiftUrl({
  required String server,
  required String username,
  required String password,
  required Object streamId,
  required DateTime startUtc,
  required int durationMinutes,
  Duration serverOffset = Duration.zero,
}) =>
    '${_trimSlash(server)}/timeshift/${_encode(username, _isPathChar)}'
    '/${_encode(password, _isPathChar)}/$durationMinutes'
    '/${formatXtreamTimeshiftStart(startUtc, serverOffset)}'
    '/${_encode('$streamId', _isPathChar)}.ts';

/// Fallback Xtream catch-up URL:
/// `{server}/streaming/timeshift.php?username=…&password=…&stream={streamId}&start={YYYY-MM-DD:HH-MM}&duration={durationMinutes}`.
/// Same arguments as [xtreamTimeshiftUrl].
String xtreamTimeshiftFallbackUrl({
  required String server,
  required String username,
  required String password,
  required Object streamId,
  required DateTime startUtc,
  required int durationMinutes,
  Duration serverOffset = Duration.zero,
}) =>
    '${_trimSlash(server)}/streaming/timeshift.php'
    '?username=${_encode(username, _isQueryChar)}'
    '&password=${_encode(password, _isQueryChar)}'
    '&stream=${_encode('$streamId', _isQueryChar)}'
    '&start=${formatXtreamTimeshiftStart(startUtc, serverOffset)}'
    '&duration=$durationMinutes';

/// Parts of an Xtream live stream URL.
class XtreamStreamUrl {
  const XtreamStreamUrl({
    required this.server,
    required this.username,
    required this.password,
    required this.streamId,
    this.extension,
  });

  /// Scheme + host + port (+ any path prefix), no trailing slash.
  final String server;

  /// Decoded (no percent-encoding).
  final String username;

  /// Decoded (no percent-encoding).
  final String password;
  final String streamId;

  /// `ts`, `m3u8`… or null when the URL has none.
  final String? extension;

  /// Never prints the credentials.
  @override
  String toString() => 'XtreamStreamUrl(stream: $streamId, ext: $extension)';
}

/// Parses `http(s)://host:port/[live/]{username}/{password}/{id}[.ext]`
/// (query, fragment and a Kodi `|` suffix are ignored). Returns null for
/// other shapes and for `/movie/` and `/series/` URLs.
XtreamStreamUrl? parseXtreamStreamUrl(String url) {
  var u = url.trim();
  for (final stop in const ['|', '#', '?']) {
    final i = u.indexOf(stop);
    if (i >= 0) u = u.substring(0, i);
  }
  final schemeEnd = u.indexOf('://');
  if (schemeEnd <= 0) return null;
  final scheme = u.substring(0, schemeEnd).toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  final pathStart = u.indexOf('/', schemeEnd + 3);
  if (pathStart < 0 || pathStart == schemeEnd + 3) return null;
  final origin = u.substring(0, pathStart);
  final segments = u
      .substring(pathStart + 1)
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.length < 3) return null;
  final last = segments.last;
  final dot = last.indexOf('.');
  final id = dot < 0 ? last : last.substring(0, dot);
  if (id.isEmpty) return null;
  var prefix = segments.sublist(0, segments.length - 3);
  if (prefix.isNotEmpty && prefix.last.toLowerCase() == 'live') {
    prefix = prefix.sublist(0, prefix.length - 1);
  }
  if (prefix.isNotEmpty &&
      const {'movie', 'series'}.contains(prefix.last.toLowerCase())) {
    return null;
  }
  final ext = dot < 0 ? null : last.substring(dot + 1);
  return XtreamStreamUrl(
    server: prefix.isEmpty ? origin : '$origin/${prefix.join('/')}',
    username: _decode(segments[segments.length - 3]),
    password: _decode(segments[segments.length - 2]),
    streamId: _decode(id),
    extension: ext == null || ext.isEmpty ? null : ext,
  );
}

String _trimSlash(String server) {
  var s = server.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

String _decode(String s) {
  if (!s.contains('%')) return s;
  try {
    return Uri.decodeComponent(s);
  } on Object {
    return s;
  }
}

bool _isUnreserved(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0x2D ||
    c == 0x2E ||
    c == 0x5F ||
    c == 0x7E;

// RFC 3986 pchar: unreserved / sub-delims / ":" / "@".
bool _isPathChar(int c) =>
    _isUnreserved(c) || "!\$&'()*+,;=:@".contains(String.fromCharCode(c));

// Query value: like pchar, but `&`, `=` and `+` must be encoded.
bool _isQueryChar(int c) =>
    _isUnreserved(c) || "!\$'()*,;:@/".contains(String.fromCharCode(c));

const String _hex = '0123456789ABCDEF';

String _encode(String s, bool Function(int c) allowed) {
  if (s.codeUnits.every((c) => c < 0x80 && allowed(c))) return s;
  final out = StringBuffer();
  for (final b in utf8.encode(s)) {
    if (b < 0x80 && allowed(b)) {
      out.writeCharCode(b);
    } else {
      out
        ..write('%')
        ..write(_hex[b >> 4])
        ..write(_hex[b & 0x0F]);
    }
  }
  return out.toString();
}
