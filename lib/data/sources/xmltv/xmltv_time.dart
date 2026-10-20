/// XMLTV timestamps: `YYYYMMDDhhmmss ±hhmm`.
library;

/// Parses an XMLTV time into a UTC [DateTime].
///
/// Accepted forms (the XMLTV DTD allows any leading part of the date):
/// `YYYYMMDDhhmmss`, `YYYYMMDDhhmm`, `YYYYMMDDhh`, `YYYYMMDD`, `YYYYMM`,
/// `YYYY`, optionally with ignored fractional seconds (`…00.000`), followed
/// by an optional offset `+0300`, `-0500`, `+03:00`, `+03`, with or without a
/// space, or a zone name (`Z`, `UTC`, `GMT`, `BST`, `CET`, `CEST`, `EET`,
/// `EEST`, `TRT`, `MSK`, `WET`, `WEST`, `EST`, `EDT`, `MST`, `MDT`, `PST`,
/// `PDT`; `UTC+3` style also works). No offset means UTC; unknown zone names
/// are treated as UTC. Hour 24 is accepted (`240000` = next midnight).
///
/// Throws a [FormatException] for anything else. No EPG time shift is
/// applied here.
DateTime parseXmltvTime(String value) {
  final ms = xmltvTimeToEpochMs(value);
  if (ms == null) {
    throw FormatException('Invalid XMLTV time', value);
  }
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// [parseXmltvTime] as UTC epoch milliseconds; null when [value] is invalid.
/// Allocation-free, used by the parser for every `start` / `stop`.
int? xmltvTimeToEpochMs(String value) {
  final s = value;
  final n = s.length;
  var i = 0;
  while (i < n && s.codeUnitAt(i) <= 0x20) {
    i++;
  }
  final digitsStart = i;
  while (i < n && _isDigit(s.codeUnitAt(i))) {
    i++;
  }
  final digits = i - digitsStart;
  if (digits < 4 || digits > 14 || digits.isOdd) return null;

  final year = _two(s, digitsStart) * 100 + _two(s, digitsStart + 2);
  final month = digits >= 6 ? _two(s, digitsStart + 4) : 1;
  final day = digits >= 8 ? _two(s, digitsStart + 6) : 1;
  final hour = digits >= 10 ? _two(s, digitsStart + 8) : 0;
  final minute = digits >= 12 ? _two(s, digitsStart + 10) : 0;
  final second = digits >= 14 ? _two(s, digitsStart + 12) : 0;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (minute > 59 || second > 60) return null;
  if (hour > 24 || (hour == 24 && (minute != 0 || second != 0))) return null;

  // Fractional seconds are ignored.
  if (i < n && s.codeUnitAt(i) == 0x2E) {
    i++;
    while (i < n && _isDigit(s.codeUnitAt(i))) {
      i++;
    }
  }
  while (i < n && s.codeUnitAt(i) <= 0x20) {
    i++;
  }

  var offsetMinutes = 0;
  if (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x2B || c == 0x2D) {
      final parsed = _parseOffset(s, i);
      if (parsed < 0) return null;
      offsetMinutes = _offsetMinutes(parsed);
      i = _offsetEnd(parsed);
    } else if (_isLetter(c)) {
      final nameStart = i;
      while (i < n && _isLetter(s.codeUnitAt(i))) {
        i++;
      }
      final zone = s.substring(nameStart, i).toUpperCase();
      offsetMinutes = _zones[zone] ?? 0;
      if (i < n && (s.codeUnitAt(i) == 0x2B || s.codeUnitAt(i) == 0x2D)) {
        // `UTC+3`, `GMT-05:00`
        final parsed = _parseOffset(s, i);
        if (parsed < 0) return null;
        offsetMinutes += _offsetMinutes(parsed);
        i = _offsetEnd(parsed);
      }
    } else {
      return null;
    }
    while (i < n && s.codeUnitAt(i) <= 0x20) {
      i++;
    }
    if (i < n) return null;
  }

  final days = _daysFromCivil(year, month, day);
  return (((days * 24 + hour) * 60 + minute - offsetMinutes) * 60 + second) *
      1000;
}

/// `+0300`, `-0500`, `+03:00`, `+03`, `+3` starting at the sign. Returns -1
/// when invalid, else the end index and the offset packed into one int (no
/// allocation on the hot path): see [_offsetEnd] and [_offsetMinutes].
int _parseOffset(String s, int i) {
  final n = s.length;
  final negative = s.codeUnitAt(i) == 0x2D;
  var j = i + 1;
  final start = j;
  while (j < n && _isDigit(s.codeUnitAt(j))) {
    j++;
  }
  final count = j - start;
  int hours;
  var minutes = 0;
  if (count == 4) {
    hours = _two(s, start);
    minutes = _two(s, start + 2);
  } else if (count == 2 || count == 1) {
    hours = count == 2 ? _two(s, start) : s.codeUnitAt(start) - 0x30;
    if (j < n && s.codeUnitAt(j) == 0x3A) {
      if (j + 2 >= n ||
          !_isDigit(s.codeUnitAt(j + 1)) ||
          !_isDigit(s.codeUnitAt(j + 2))) {
        return -1;
      }
      minutes = _two(s, j + 1);
      j += 3;
    }
  } else {
    return -1;
  }
  if (hours > 23 || minutes > 59) return -1;
  final total = hours * 60 + minutes;
  return j * 4096 + (negative ? -total : total) + 2048;
}

int _offsetEnd(int packed) => packed ~/ 4096;

int _offsetMinutes(int packed) => packed % 4096 - 2048;

int _two(String s, int i) =>
    (s.codeUnitAt(i) - 0x30) * 10 + s.codeUnitAt(i + 1) - 0x30;

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isLetter(int c) => (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A;

/// Days since 1970-01-01 for a proleptic Gregorian date (H. Hinnant's
/// `days_from_civil`). Day overflow (`Feb 30`) rolls over like DateTime.
int _daysFromCivil(int year, int month, int day) {
  final y = month <= 2 ? year - 1 : year;
  final era = (y >= 0 ? y : y - 399) ~/ 400;
  final yoe = y - era * 400;
  final mp = month > 2 ? month - 3 : month + 9;
  final doy = (153 * mp + 2) ~/ 5 + day - 1;
  final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
  return era * 146097 + doe - 719468;
}

/// Zone names some XMLTV generators still emit (the DTD deprecates them).
/// Ambiguous abbreviations (`IST`, `CST`) are not listed and count as UTC.
const Map<String, int> _zones = {
  'Z': 0,
  'UT': 0,
  'UTC': 0,
  'GMT': 0,
  'WET': 0,
  'WEST': 60,
  'BST': 60,
  'CET': 60,
  'MET': 60,
  'CEST': 120,
  'MEST': 120,
  'EET': 120,
  'EEST': 180,
  'TRT': 180,
  'MSK': 180,
  'EST': -300,
  'EDT': -240,
  'MST': -420,
  'MDT': -360,
  'PST': -480,
  'PDT': -420,
};
