/// Normalization helpers for loosely typed Xtream JSON.
///
/// Xtream panels are PHP: the same field can arrive as `1`, `"1"`, `1.0`,
/// `null`, `""`, `"null"`, `false` or `[]` depending on the panel and on
/// whether the value is known. Every helper here accepts any input and never
/// throws.
library;

import 'dart:convert';

/// Integer from an int, a finite double (truncated), a numeric string or a
/// bool (1/0). Anything else → null.
int? asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.isFinite ? v.truncate() : null;
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    return (d != null && d.isFinite) ? d.truncate() : null;
  }
  return null;
}

/// Positive integer ([asInt] > 0), else null. Used for ids like `tmdb_id`
/// where `0` means "unknown".
int? asPositiveInt(Object? v) {
  final i = asInt(v);
  return (i == null || i <= 0) ? null : i;
}

/// Finite double from a number or a numeric string. A single decimal comma
/// (`"7,5"`) is accepted.
double? asDouble(Object? v) {
  if (v == null || v is bool) return null;
  if (v is num) {
    final d = v.toDouble();
    return d.isFinite ? d : null;
  }
  if (v is String) {
    var s = v.trim();
    if (s.isEmpty) return null;
    if (!s.contains('.') && ','.allMatches(s).length == 1) {
      s = s.replaceFirst(',', '.');
    }
    final d = double.tryParse(s);
    return (d != null && d.isFinite) ? d : null;
  }
  return null;
}

/// Trimmed string. `""`, `"null"`, `false`/`true` (PHP "no value"), maps and
/// lists → null. Numbers are converted with `toString()`.
String? asString(Object? v) {
  if (v == null) return null;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }
  if (v is num) return v.isFinite ? v.toString() : null;
  return null;
}

/// Provider id as a string: `1001`, `1001.0` and `" 1001 "` → `"1001"`.
String? asId(Object? v) {
  if (v is int) return '$v';
  if (v is double) {
    if (!v.isFinite) return null;
    return v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
  }
  if (v is String) return asString(v);
  return null;
}

/// `true` for `true`, non-zero numbers, `"1"`, `"true"`, `"yes"`, `"on"`;
/// `false` for `false`, `0`, `"0"`, `"false"`, `"no"`, `"off"`. Anything
/// else (null, `""`, unknown words) → null.
bool? asBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    switch (s) {
      case '1' || 'true' || 'yes' || 'y' || 'on':
        return true;
      case '0' || 'false' || 'no' || 'n' || 'off':
        return false;
    }
    final n = num.tryParse(s);
    return n == null ? null : n != 0;
  }
  return null;
}

/// A list: lists as they are, maps as their values (PHP arrays with
/// non-sequential keys arrive as JSON objects). Anything else → empty.
List<Object?> asList(Object? v) {
  if (v is List<Object?>) return v;
  if (v is Map) return v.values.toList(growable: false);
  return const [];
}

/// A string-keyed map. A PHP empty array `[]` and anything else → empty map.
Map<String, Object?> asMap(Object? v) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return v.map((key, value) => MapEntry('$key', value));
  return const {};
}

/// Strings from a list (or map values), or from a comma-separated string when
/// [splitCommas] is true. Blank entries are dropped.
List<String> asStringList(Object? v, {bool splitCommas = true}) {
  if (v is String) {
    final parts = splitCommas ? v.split(',') : [v];
    return [for (final p in parts) ?asString(p)];
  }
  if (v is num) return [v.toString()];
  return [for (final item in asList(v)) ?asString(item)];
}

const int _maxEpochMs = 8640000000000000;

/// UTC instant from Unix seconds (int, double or numeric string). Values of
/// 1e11 and above are taken as milliseconds. `0`, negatives and blanks → null.
/// A non-numeric string falls back to [asDate].
DateTime? asDateFromEpoch(Object? v) {
  int? n;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    n = int.tryParse(s) ?? _truncateOrNull(double.tryParse(s));
    if (n == null) return asDate(s);
  } else if (v is num) {
    n = asInt(v);
  }
  if (n == null || n <= 0) return null;
  final ms = n >= 100000000000 ? n : n * 1000;
  if (ms > _maxEpochMs) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

int? _truncateOrNull(double? d) =>
    (d != null && d.isFinite) ? d.truncate() : null;

final RegExp _isoDate = RegExp(
  r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})'
  r'(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?',
);
final RegExp _dayFirstDate = RegExp(r'^(\d{1,2})([./])(\d{1,2})[./](\d{4})');
final RegExp _yearOnly = RegExp(r'^(\d{4})$');

/// Calendar date (or date-time) as a UTC `DateTime` with the given fields:
/// `"2008-01-20"`, `"2008/01/20"`, `"2008-01-20 21:30:00"`,
/// `"20.01.2008"`, `"20/01/2008"` (day first unless that is impossible),
/// `"2008"` (1 January). `"0000-00-00"`, impossible dates and anything else
/// → null. Numbers: a plausible year, else Unix seconds.
///
/// Times without an offset are returned as wall-clock fields in a UTC
/// `DateTime`; the caller applies the server offset when needed.
DateTime? asDate(Object? v) {
  if (v is num) {
    final n = asInt(v);
    if (n == null) return null;
    if (n >= 1800 && n <= 2200) return DateTime.utc(n);
    return asDateFromEpoch(n);
  }
  if (v is! String) return null;
  final s = v.trim();
  if (s.isEmpty) return null;

  final iso = _isoDate.firstMatch(s);
  if (iso != null) {
    return _validDate(
      int.parse(iso[1]!),
      int.parse(iso[2]!),
      int.parse(iso[3]!),
      hour: iso[4] == null ? 0 : int.parse(iso[4]!),
      minute: iso[5] == null ? 0 : int.parse(iso[5]!),
      second: iso[6] == null ? 0 : int.parse(iso[6]!),
    );
  }
  final dayFirst = _dayFirstDate.firstMatch(s);
  if (dayFirst != null) {
    var day = int.parse(dayFirst[1]!);
    var month = int.parse(dayFirst[3]!);
    // `01/20/2008` can only be month-first.
    if (dayFirst[2] == '/' && month > 12 && day <= 12) {
      final t = day;
      day = month;
      month = t;
    }
    return _validDate(int.parse(dayFirst[4]!), month, day);
  }
  final year = _yearOnly.firstMatch(s);
  if (year != null) {
    final y = int.parse(year[1]!);
    return (y >= 1800 && y <= 2200) ? DateTime.utc(y) : null;
  }
  if (RegExp(r'^\d{9,}$').hasMatch(s)) return asDateFromEpoch(s);
  return null;
}

DateTime? _validDate(
  int year,
  int month,
  int day, {
  int hour = 0,
  int minute = 0,
  int second = 0,
}) {
  if (year < 1800 || year > 2200) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;
  final d = DateTime.utc(year, month, day, hour, minute, second);
  // DateTime normalizes overflow (31 February → 3 March): reject it.
  if (d.month != month || d.day != day) return null;
  return d;
}

final RegExp _yearInText = RegExp(r'(?<!\d)(1[89]\d\d|2[01]\d\d)(?!\d)');

/// A year from `2008`, `"2008"`, `"2008-01-20"`, `"20.01.2008"` or
/// `"(2008)"`. Only 1800–2199 is accepted.
int? asYear(Object? v) {
  if (v is num) {
    final n = asInt(v);
    return (n != null && n >= 1800 && n < 2200) ? n : null;
  }
  final s = asString(v);
  if (s == null) return null;
  final m = _yearInText.firstMatch(s);
  return m == null ? null : int.parse(m[1]!);
}

final RegExp _hms = RegExp(r'^(\d+):(\d{1,2})(?::(\d{1,2}))?$');
final RegExp _minutesText = RegExp(
  r'^(\d+)\s*(?:min|mins|minutes|dk|dakika)\.?$',
  caseSensitive: false,
);

/// Duration in seconds from an int (seconds), `"6750"`, `"01:52:30"`,
/// `"1:52"` (hours:minutes) or `"112 min"`.
int? asDurationSecs(Object? v) {
  if (v is num) {
    final n = asInt(v);
    return (n == null || n < 0) ? null : n;
  }
  final s = asString(v);
  if (s == null) return null;
  final plain = int.tryParse(s);
  if (plain != null) return plain < 0 ? null : plain;
  final hms = _hms.firstMatch(s);
  if (hms != null) {
    final a = int.parse(hms[1]!);
    final b = int.parse(hms[2]!);
    final c = hms[3] == null ? null : int.parse(hms[3]!);
    return c == null ? a * 3600 + b * 60 : a * 3600 + b * 60 + c;
  }
  final minutes = _minutesText.firstMatch(s);
  if (minutes != null) return int.parse(minutes[1]!) * 60;
  return null;
}

final RegExp _base64Shape = RegExp(r'^[A-Za-z0-9+/\-_]+={0,2}$');
final RegExp _lineBreaks = RegExp(r'[\r\n]');
final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Decodes base64 text (Xtream EPG titles and descriptions). Plain text that
/// is not base64 is returned unchanged, so panels that send plain text work.
///
/// A value is treated as base64 only when it has the base64 shape (no spaces,
/// length a multiple of 4, padding only at the end), decodes to valid UTF-8,
/// and the result looks like text (no control characters, mostly letters,
/// digits and spaces). This keeps short plain words such as `"News"` or
/// `"Kids"` intact.
String? decodeMaybeBase64(String? value) {
  if (value == null) return null;
  final s = value.trim();
  if (s.isEmpty) return s;
  final compact = s.replaceAll(_lineBreaks, '');
  if (compact.length % 4 != 0 || !_base64Shape.hasMatch(compact)) return s;
  final String decoded;
  try {
    final bytes = base64.decode(
      compact.replaceAll('-', '+').replaceAll('_', '/'),
    );
    decoded = utf8.decode(bytes);
  } on FormatException {
    return s;
  }
  return _looksLikeText(decoded) ? decoded.trim() : s;
}

bool _looksLikeText(String s) {
  if (s.isEmpty) return true;
  var good = 0;
  var total = 0;
  for (final rune in s.runes) {
    total++;
    final isWhitespace = rune == 0x09 || rune == 0x0A || rune == 0x0D;
    if (rune < 0x20 && !isWhitespace) return false;
    if (rune == 0x7F || rune == 0xFFFD) return false;
    if (rune == 0x20 ||
        isWhitespace ||
        _letterOrDigit.hasMatch(String.fromCharCode(rune))) {
      good++;
    }
  }
  return good * 10 >= total * 6;
}
