// Catch-up URL placeholder expansion.

import 'dart:math' as math;

final RegExp _placeholder = RegExp(r'\$?\{([^{}]*)\}');

/// Expands the catch-up placeholders in [template].
///
/// Times: *start* = [startUtc], *end* = [endUtc], *now* = [nowUtc] (default:
/// the current time). Epoch values are Unix seconds and never depend on
/// [serverOffset]. Calendar values are wall-clock fields in the server's
/// zone, i.e. UTC + [serverOffset] (plain UTC by default).
///
/// | Placeholder | Value |
/// |---|---|
/// | `{utc}` `{start}` `${start}` | start, Unix seconds |
/// | `{utcend}` `{end}` `${end}` | end, Unix seconds |
/// | `{lutc}` `{now}` `${now}` `{timestamp}` `${timestamp}` | now, Unix seconds |
/// | `{duration}` `${duration}` | end - start, seconds |
/// | `{duration:N}` | (end - start) / N, truncated, >= 0 (`{duration:60}` = minutes) |
/// | `{offset:N}` | (now - start) / N, truncated, >= 0 |
/// | `{offset}` `${offset}` | now - start, seconds, >= 0 |
/// | `{Y}` | start year, 4 digits |
/// | `{m}` `{d}` | start month, day, 2 digits |
/// | `{H}` `{M}` `{S}` | start hour, minute, second, 2 digits |
/// | `{(b)FMT}` `${(b)FMT}` | start formatted with FMT |
/// | `{(e)FMT}` `${(e)FMT}` | end formatted with FMT |
/// | `{utc:FMT}` `{start:FMT}` | start formatted with FMT (Kodi) |
/// | `{utcend:FMT}` `{end:FMT}` | end formatted with FMT (Kodi) |
/// | `{lutc:FMT}` `{now:FMT}` `{timestamp:FMT}` | now formatted with FMT (Kodi) |
/// | `{channel}` `${channel}` | [channelName], URL-encoded |
///
/// FMT (see [formatCatchupTime]): `Y m d H M S` become the calendar fields
/// above and every other character is copied, so `{(b)YmdHMS}` →
/// `20261017210000` and `{(b)Y-m-d:H-M}` → `2026-10-17:21-00`. A FMT with a
/// doubled letter (`yyyy`, `MM`, `dd`, `HH`, `mm`, `ss`) is read as a Java
/// date pattern instead (`${(b)yyyyMMddHHmmss}`, OTT Navigator style).
///
/// Names are case-sensitive as in Kodi (`{m}` is the month, `{M}` the
/// minute, `{UTC}` is not a placeholder). The `$` prefix is optional on every
/// placeholder. Unknown placeholders (`{catchup-id}`), `{channel}` without a
/// [channelName] and divisors <= 0 (`{duration:0}`) are left untouched.
String expandCatchupTemplate(
  String template, {
  required DateTime startUtc,
  required DateTime endUtc,
  DateTime? nowUtc,
  Duration serverOffset = Duration.zero,
  String? channelName,
}) {
  if (!template.contains('{')) return template;
  final times = _Times(
    startUtc,
    endUtc,
    nowUtc ?? DateTime.now().toUtc(),
    serverOffset,
  );
  return template.replaceAllMapped(
    _placeholder,
    (m) => _resolve(m[1]!, times, channelName) ?? m[0]!,
  );
}

class _Times {
  _Times(DateTime start, DateTime end, DateTime now, Duration offset)
    : start = _epoch(start),
      end = _epoch(end),
      now = _epoch(now),
      localStart = start.toUtc().add(offset),
      localEnd = end.toUtc().add(offset),
      localNow = now.toUtc().add(offset);

  final int start;
  final int end;
  final int now;
  final DateTime localStart;
  final DateTime localEnd;
  final DateTime localNow;

  int get duration => math.max(0, end - start);
  int get offset => math.max(0, now - start);
}

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

String? _resolve(String body, _Times t, String? channelName) {
  switch (body) {
    case 'utc' || 'start':
      return '${t.start}';
    case 'utcend' || 'end':
      return '${t.end}';
    case 'lutc' || 'now' || 'timestamp':
      return '${t.now}';
    case 'duration':
      return '${t.duration}';
    case 'offset':
      return '${t.offset}';
    case 'Y':
      return _pad(t.localStart.year, 4);
    case 'm':
      return _pad(t.localStart.month, 2);
    case 'd':
      return _pad(t.localStart.day, 2);
    case 'H':
      return _pad(t.localStart.hour, 2);
    case 'M':
      return _pad(t.localStart.minute, 2);
    case 'S':
      return _pad(t.localStart.second, 2);
    case 'channel':
      return channelName == null ? null : Uri.encodeComponent(channelName);
  }
  if (body.startsWith('(b)')) {
    return formatCatchupTime(t.localStart, body.substring(3));
  }
  if (body.startsWith('(e)')) {
    return formatCatchupTime(t.localEnd, body.substring(3));
  }
  final colon = body.indexOf(':');
  if (colon <= 0) return null;
  final arg = body.substring(colon + 1);
  switch (body.substring(0, colon)) {
    case 'duration':
      return _divide(t.duration, arg);
    case 'offset':
      return _divide(t.offset, arg);
    case 'utc' || 'start':
      return formatCatchupTime(t.localStart, arg);
    case 'utcend' || 'end':
      return formatCatchupTime(t.localEnd, arg);
    case 'lutc' || 'now' || 'timestamp':
      return formatCatchupTime(t.localNow, arg);
  }
  return null;
}

String? _divide(int value, String divisor) {
  final d = int.tryParse(divisor.trim());
  if (d == null || d <= 0) return null;
  return '${math.max(0, value ~/ d)}';
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');

final RegExp _javaPattern = RegExp('yy|MM|dd|HH|mm|ss');

/// Formats the wall-clock fields of [time] (already shifted to the server's
/// zone) with a catch-up FMT.
///
/// Kodi style (default): `Y` → `2026`, `m` → `03`, `d` → `05`, `H` → `07`,
/// `M` → `08`, `S` → `09`; any other character is copied.
///
/// Java style (when FMT doubles one of `y M d H m s`): runs of `y` (`yy` =
/// two digits), `M` month, `d` day, `H` hour, `m` minute, `s` second, `S`
/// milliseconds, padded to the run length; `'text'` is literal.
String formatCatchupTime(DateTime time, String fmt) {
  if (_javaPattern.hasMatch(fmt)) return _formatJava(time, fmt);
  final out = StringBuffer();
  for (var i = 0; i < fmt.length; i++) {
    final c = fmt[i];
    switch (c) {
      case 'Y':
        out.write(_pad(time.year, 4));
      case 'm':
        out.write(_pad(time.month, 2));
      case 'd':
        out.write(_pad(time.day, 2));
      case 'H':
        out.write(_pad(time.hour, 2));
      case 'M':
        out.write(_pad(time.minute, 2));
      case 'S':
        out.write(_pad(time.second, 2));
      default:
        out.write(c);
    }
  }
  return out.toString();
}

String _formatJava(DateTime time, String fmt) {
  final out = StringBuffer();
  var i = 0;
  while (i < fmt.length) {
    final c = fmt[i];
    if (c == "'") {
      final close = fmt.indexOf("'", i + 1);
      if (close < 0) {
        out.write(fmt.substring(i + 1));
        break;
      }
      out.write(close == i + 1 ? "'" : fmt.substring(i + 1, close));
      i = close + 1;
      continue;
    }
    var j = i + 1;
    while (j < fmt.length && fmt[j] == c) {
      j++;
    }
    final run = j - i;
    switch (c) {
      case 'y':
        out.write(run == 2 ? _pad(time.year % 100, 2) : _pad(time.year, run));
      case 'M':
        out.write(_pad(time.month, run));
      case 'd':
        out.write(_pad(time.day, run));
      case 'H':
        out.write(_pad(time.hour, run));
      case 'm':
        out.write(_pad(time.minute, run));
      case 's':
        out.write(_pad(time.second, run));
      case 'S':
        out.write(_pad(time.millisecond, run));
      default:
        out.write(fmt.substring(i, j));
    }
    i = j;
  }
  return out.toString();
}
