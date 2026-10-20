// Catch-up URL builder for M3U catch-up modes, following Kodi IPTV Simple
// conventions.

import 'catchup_template.dart';
import 'xtream_timeshift.dart';

/// Catch-up modes understood by [buildCatchupUrl] (compared lower-cased).
const Set<String> catchupModes = {
  'default',
  'append',
  'shift',
  'timeshift',
  'flussonic',
  'flussonic-hls',
  'flussonic-ts',
  'fs',
  'xc',
};

/// Builds the catch-up URL of the programme [startUtc]–[endUtc] on the
/// channel [streamUrl], or returns null when [mode] cannot produce one
/// (unknown mode, missing [source], stream URL of the wrong shape).
///
/// Modes ([mode] is trimmed and compared lower-cased; an empty [mode] with a
/// [source] means `default`):
///
/// | Mode | URL template |
/// |---|---|
/// | `default` | [source] is the full template. Tolerance: a source starting with `?`/`&` is appended to the stream URL, `/path` is resolved against its origin, a bare relative path against its directory. |
/// | `append` | stream URL + [source] (`?` becomes `&` when the stream URL already has a query) |
/// | `shift`, `timeshift` | stream URL + `?utc={utc}&lutc={lutc}` (`&` when it already has a query) |
/// | `flussonic`, `flussonic-hls`, `flussonic-ts`, `fs` | `…/<name>.m3u8` → `…/<name>-{utc}-{duration}.m3u8`; `…/mpegts` or `….ts` → `…/timeshift_abs-{utc}.ts`; any query is kept. For other URLs `flussonic-ts` / `fs` give the TS form and `flussonic` / `flussonic-hls` the `index-…` HLS form (Kodi). The URL needs a channel path segment (`host/<channel>/<file>`). |
/// | `xc` | `http://host:port/[live/]user/pass/id[.ext]` → [xtreamTimeshiftUrl] with the start in server time (UTC + [serverOffset]) and the duration in minutes rounded up |
///
/// A Kodi `|User-Agent=…` suffix on [streamUrl] is removed before the
/// template is built and appended to the result again, unless the template
/// already has its own `|` suffix (Kodi behavior).
///
/// Placeholders in the template are then expanded by
/// [expandCatchupTemplate] (see its table for every placeholder), using
/// [nowUtc] (default: now), [serverOffset] for calendar fields and
/// [channelName] for `{channel}`. Pass EPG times with the playlist's EPG
/// time shift already applied.
String? buildCatchupUrl({
  required String streamUrl,
  required String mode,
  String? source,
  required DateTime startUtc,
  required DateTime endUtc,
  DateTime? nowUtc,
  String? channelName,
  Duration serverOffset = Duration.zero,
}) {
  final (base, options) = _splitProtocolOptions(streamUrl.trim());
  final trimmed = source?.trim();
  final template = trimmed == null || trimmed.isEmpty ? null : trimmed;
  var m = mode.trim().toLowerCase();
  if (m.isEmpty) {
    if (template == null) return null;
    m = 'default';
  }
  String? url;
  switch (m) {
    case 'default':
      url = template == null ? null : _resolveSource(base, template);
    case 'append':
      url = template == null ? null : _append(base, template);
    case 'shift' || 'timeshift':
      url = _append(base, '?utc={utc}&lutc={lutc}');
    case 'flussonic' || 'flussonic-hls' || 'flussonic-ts' || 'fs':
      url = _flussonic(base, preferTs: m == 'flussonic-ts' || m == 'fs');
    case 'xc':
      final parts = parseXtreamStreamUrl(base);
      if (parts == null) return null;
      url = xtreamTimeshiftUrl(
        server: parts.server,
        username: parts.username,
        password: parts.password,
        streamId: parts.streamId,
        startUtc: startUtc,
        durationMinutes: xtreamTimeshiftMinutes(startUtc, endUtc),
        serverOffset: serverOffset,
      );
    default:
      return null;
  }
  if (url == null) return null;
  if (options.isNotEmpty && !url.contains('|')) url += options;
  return expandCatchupTemplate(
    url,
    startUtc: startUtc,
    endUtc: endUtc,
    nowUtc: nowUtc,
    serverOffset: serverOffset,
    channelName: channelName,
  );
}

/// a programme can be replayed when it has ended (`end < now`) and started
/// inside the archive window (`start > now - archiveDays`). Always false when
/// [archiveDays] <= 0.
bool isReplayable({
  required DateTime startUtc,
  required DateTime endUtc,
  required int archiveDays,
  DateTime? nowUtc,
}) {
  if (archiveDays <= 0) return false;
  final now = nowUtc ?? DateTime.now().toUtc();
  return endUtc.isBefore(now) &&
      startUtc.isAfter(now.subtract(Duration(days: archiveDays)));
}

/// Splits a Kodi `url|options` string at the first `|`; the options keep
/// their leading `|`.
(String, String) _splitProtocolOptions(String url) {
  final bar = url.indexOf('|');
  if (bar < 0) return (url, '');
  return (url.substring(0, bar), url.substring(bar));
}

String _append(String base, String suffix) {
  if (suffix.startsWith('?') && base.contains('?')) {
    return '$base&${suffix.substring(1)}';
  }
  return base + suffix;
}

String _resolveSource(String base, String source) {
  if (source.startsWith('?') || source.startsWith('&')) {
    return _append(base, source);
  }
  if (source.contains('://')) return source;
  final schemeEnd = base.indexOf('://');
  if (schemeEnd < 0) return source;
  if (source.startsWith('//')) {
    return '${base.substring(0, schemeEnd + 1)}$source';
  }
  final pathStart = base.indexOf('/', schemeEnd + 3);
  final origin = pathStart < 0 ? base : base.substring(0, pathStart);
  if (source.startsWith('/')) return '$origin$source';
  var path = pathStart < 0 ? '/' : base.substring(pathStart);
  final q = path.indexOf('?');
  if (q >= 0) path = path.substring(0, q);
  return '$origin${path.substring(0, path.lastIndexOf('/') + 1)}$source';
}

String? _flussonic(String url, {required bool preferTs}) {
  final q = url.indexOf('?');
  final path = q < 0 ? url : url.substring(0, q);
  final query = q < 0 ? '' : url.substring(q);
  final schemeEnd = path.indexOf('://');
  if (schemeEnd < 0) return null;
  final hostEnd = path.indexOf('/', schemeEnd + 3);
  final lastSlash = path.lastIndexOf('/');
  if (hostEnd < 0 || lastSlash <= hostEnd) return null;
  final dir = path.substring(0, lastSlash);
  final file = path.substring(lastSlash + 1);
  final lower = file.toLowerCase();
  if (lower.endsWith('.m3u8')) {
    final name = file.substring(0, file.length - 5);
    return '$dir/${name.isEmpty ? 'index' : name}-{utc}-{duration}.m3u8$query';
  }
  if (lower == 'mpegts' || lower.endsWith('.ts') || preferTs) {
    return '$dir/timeshift_abs-{utc}.ts$query';
  }
  return '$dir/index-{utc}-{duration}.m3u8$query';
}
