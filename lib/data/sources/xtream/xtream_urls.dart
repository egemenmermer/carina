import 'dart:math' as math;

import 'xtream_credentials.dart';

/// Builds Xtream stream, catch-up, XMLTV and API URLs.
///
/// Credentials and ids are percent-encoded: path segments with
/// [Uri.encodeComponent] (`@` → `%40`, `/` → `%2F`, space → `%20`), query
/// values with [Uri.encodeQueryComponent] (space → `+`, `+` → `%2B`,
/// `&` → `%26`). Never log these URLs unmasked (see `maskUrl`).
class XtreamUrls {
  XtreamUrls(String server, this.username, this.password)
    : server = normalizeXtreamServer(server);

  factory XtreamUrls.fromCredentials(XtreamCredentials credentials) =>
      XtreamUrls(
        credentials.server,
        credentials.username,
        credentials.password,
      );

  /// Base URL without trailing slashes.
  final String server;
  final String username;
  final String password;

  /// `{server}/live/{u}/{p}/{streamId}.{ext}`. A usable [directSource]
  /// (non-empty absolute URL) wins.
  String live(Object streamId, {String ext = 'ts', String? directSource}) =>
      usableDirectSource(directSource) ??
      '$server/live/${_credentialPath()}/${_seg(streamId)}.${_ext(ext, 'ts')}';

  /// `{server}/movie/{u}/{p}/{streamId}.{containerExtension}`.
  String movie(Object streamId, String ext, {String? directSource}) =>
      usableDirectSource(directSource) ??
      '$server/movie/${_credentialPath()}/${_seg(streamId)}.${_ext(ext, 'mp4')}';

  /// `{server}/series/{u}/{p}/{episodeId}.{containerExtension}`.
  String episode(Object episodeId, String ext, {String? directSource}) =>
      usableDirectSource(directSource) ??
      '$server/series/${_credentialPath()}/${_seg(episodeId)}.${_ext(ext, 'mp4')}';

  /// Catch-up (primary):
  /// `{server}/timeshift/{u}/{p}/{durationMinutes}/{YYYY-MM-DD:HH-MM}/{streamId}.ts`.
  ///
  /// [startUtc] is the programme start as a UTC instant (EPG time shift
  /// already applied); it is converted to the server's wall clock with
  /// [serverOffset] (`XtreamAccount.serverUtcOffset`). [durationMinutes] is
  /// clamped to at least 1.
  String timeshift(
    Object streamId,
    DateTime startUtc,
    int durationMinutes, {
    Duration serverOffset = Duration.zero,
  }) =>
      '$server/timeshift/${_credentialPath()}/${math.max(1, durationMinutes)}/'
      '${formatXtreamTimeshiftStart(startUtc, serverOffset)}/${_seg(streamId)}.ts';

  /// Catch-up (fallback):
  /// `{server}/streaming/timeshift.php?username=&password=&stream={id}&start={YYYY-MM-DD:HH-MM}&duration={minutes}`.
  String timeshiftFallback(
    Object streamId,
    DateTime startUtc,
    int durationMinutes, {
    Duration serverOffset = Duration.zero,
  }) =>
      '$server/streaming/timeshift.php?${_credentialQuery()}'
      '&stream=${_q('$streamId')}'
      '&start=${formatXtreamTimeshiftStart(startUtc, serverOffset)}'
      '&duration=${math.max(1, durationMinutes)}';

  /// `{server}/xmltv.php?username=&password=`.
  String xmltv() => '$server/xmltv.php?${_credentialQuery()}';

  /// [xmltv] as a [Uri].
  Uri xmltvUri() => Uri.parse(xmltv());

  /// `{server}/player_api.php?username=&password=[&key=value…]`.
  /// Throws [FormatException] when [server] is not a valid URL.
  Uri playerApiUri([Map<String, String> params = const {}]) {
    final b = StringBuffer('$server/player_api.php?${_credentialQuery()}');
    params.forEach((key, value) => b.write('&${_q(key)}=${_q(value)}'));
    return Uri.parse(b.toString());
  }

  String _credentialPath() => '${_seg(username)}/${_seg(password)}';

  String _credentialQuery() =>
      'username=${_q(username)}&password=${_q(password)}';

  static String _seg(Object value) => Uri.encodeComponent('$value'.trim());

  static String _q(String value) => Uri.encodeQueryComponent(value);

  static String _ext(String ext, String fallback) {
    var e = ext.trim();
    while (e.startsWith('.')) {
      e = e.substring(1);
    }
    return e.isEmpty ? fallback : Uri.encodeComponent(e);
  }
}

/// `YYYY-MM-DD:HH-MM` of [startUtc] on the server's wall clock
/// (UTC + [serverOffset]).
String formatXtreamTimeshiftStart(DateTime startUtc, Duration serverOffset) {
  final t = startUtc.toUtc().add(serverOffset);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      ':${two(t.hour)}-${two(t.minute)}';
}

final RegExp _absoluteUrl = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*://\S+$');

/// [directSource] trimmed when it is an absolute URL (`http://…`,
/// `rtmp://…`), else null. Panels fill the field with `""`, `"0"` or
/// relative junk when there is no direct source.
String? usableDirectSource(String? directSource) {
  final s = directSource?.trim();
  if (s == null || s.isEmpty) return null;
  return _absoluteUrl.hasMatch(s) ? s : null;
}

const List<String> _liveFormats = ['ts', 'm3u8'];

/// Picks the live stream extension: [preferred] (the user setting, `ts` by
/// default) when [allowed] (`user_info.allowed_output_formats`) permits it,
/// else the first playable allowed format (`ts`, then `m3u8`). `rtmp` is not
/// a `/live/` extension and is ignored. An empty or unusable list → the
/// preference.
String pickLiveExt(List<String> allowed, {String preferred = 'ts'}) {
  String norm(String f) {
    var s = f.trim().toLowerCase();
    while (s.startsWith('.')) {
      s = s.substring(1);
    }
    return s == 'hls' ? 'm3u8' : s;
  }

  final pref = norm(preferred).isEmpty ? 'ts' : norm(preferred);
  final formats = {
    for (final f in allowed)
      if (_liveFormats.contains(norm(f))) norm(f),
  };
  if (formats.isEmpty || formats.contains(pref)) return pref;
  for (final f in _liveFormats) {
    if (formats.contains(f)) return f;
  }
  return pref;
}
