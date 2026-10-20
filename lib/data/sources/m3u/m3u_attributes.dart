// Attribute scanner for `#EXTINF` and `#EXTM3U` lines. Internal to the M3U
// parser; not exported from `m3u.dart`.

/// Result of [scanM3uAttributes].
class M3uAttributeScan {
  const M3uAttributeScan(this.pairs, this.nameStart, this.bareText);

  /// `(key, value)` pairs in source order. Keys are lower-cased; duplicates
  /// are kept (callers decide which occurrence wins).
  final List<(String, String)> pairs;

  /// Index just after the display-name comma, or -1 when the line has none.
  final int nameStart;

  /// Words that were not `key=value` pairs, joined by spaces, or null.
  final String? bareText;
}

const int _tab = 0x09;
const int _space = 0x20;
const int _dquote = 0x22;
const int _squote = 0x27;
const int _comma = 0x2C;
const int _equals = 0x3D;

bool isM3uSpace(int c) =>
    c == _space || c == _tab || c == 0x0B || c == 0x0C || c == 0xA0;

bool _isKeyChar(int c) =>
    (c >= 0x61 && c <= 0x7A) || // a-z
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x30 && c <= 0x39) || // 0-9
    c == 0x2D || // -
    c == 0x5F || // _
    c == 0x3A || // :
    c == 0x2E; // .

/// Scans `key="value" key='value' key=value` attributes starting at [start].
///
/// With [stopAtComma] (the `#EXTINF` case) the first comma outside a quoted
/// value ends the attribute list and starts the display name, so commas
/// inside quoted values (`tvg-name="A, B"`) are safe. Unquoted values end at
/// a comma or at whitespace followed by another `key=`; they may contain
/// spaces (`group-title=News Channel tvg-id=x`). Without [stopAtComma] (the
/// `#EXTM3U` header) commas are ordinary value characters
/// (`x-tvg-url=a.xml,b.xml`).
///
/// Never throws: malformed input degrades to fewer attributes. An
/// unterminated double quote runs to the last comma of the line (or the end),
/// so the display name survives.
M3uAttributeScan scanM3uAttributes(
  String s,
  int start, {
  bool stopAtComma = true,
}) {
  final pairs = <(String, String)>[];
  List<String>? bare;
  final n = s.length;
  var nameStart = -1;
  var i = start;
  while (i < n) {
    var c = s.codeUnitAt(i);
    if (isM3uSpace(c)) {
      i++;
      continue;
    }
    if (stopAtComma && c == _comma) {
      nameStart = i + 1;
      break;
    }
    if (c == _dquote || c == _squote) {
      // Quoted text that does not belong to an attribute.
      final close = s.indexOf(c == _dquote ? '"' : "'", i + 1);
      final end = close < 0 ? n : close;
      if (end > i + 1) (bare ??= <String>[]).add(s.substring(i + 1, end));
      i = close < 0 ? n : close + 1;
      continue;
    }
    if (c == _equals) {
      i++;
      continue;
    }
    final keyStart = i;
    while (i < n) {
      c = s.codeUnitAt(i);
      if (isM3uSpace(c) ||
          c == _equals ||
          c == _dquote ||
          c == _squote ||
          (stopAtComma && c == _comma)) {
        break;
      }
      i++;
    }
    final key = s.substring(keyStart, i);
    var j = i;
    while (j < n && isM3uSpace(s.codeUnitAt(j))) {
      j++;
    }
    if (j < n && s.codeUnitAt(j) == _equals) {
      final (value, next) = _readValue(s, j + 1, stopAtComma);
      pairs.add((key.toLowerCase(), value));
      i = next;
    } else {
      (bare ??= <String>[]).add(key);
    }
  }
  return M3uAttributeScan(pairs, nameStart, bare?.join(' '));
}

/// Reads one attribute value at [i]; returns the value and the index after
/// it.
(String, int) _readValue(String s, int i, bool stopAtComma) {
  final n = s.length;
  // `key = "value"`: skip spaces after `=` only when a quote follows, so
  // `key= other="x"` still reads an empty value.
  var p = i;
  while (p < n && isM3uSpace(s.codeUnitAt(p))) {
    p++;
  }
  if (p < n && (s.codeUnitAt(p) == _dquote || s.codeUnitAt(p) == _squote)) {
    i = p;
  }
  if (i < n) {
    final q = s.codeUnitAt(i);
    if (q == _dquote || q == _squote) {
      final close = s.indexOf(q == _dquote ? '"' : "'", i + 1);
      if (close >= 0) return (s.substring(i + 1, close), close + 1);
      if (q == _dquote) {
        final comma = stopAtComma ? s.lastIndexOf(',') : -1;
        if (comma > i) return (s.substring(i + 1, comma).trim(), comma);
        return (s.substring(i + 1).trim(), n);
      }
      // A lone apostrophe starts an unquoted value (`group-title='80s`).
    }
  }
  var k = i;
  while (k < n) {
    final c = s.codeUnitAt(k);
    if (stopAtComma && c == _comma) break;
    if (isM3uSpace(c)) {
      var m = k + 1;
      while (m < n && isM3uSpace(s.codeUnitAt(m))) {
        m++;
      }
      if (m >= n) break;
      if (stopAtComma && s.codeUnitAt(m) == _comma) break;
      var e = m;
      while (e < n && _isKeyChar(s.codeUnitAt(e))) {
        e++;
      }
      var f = e;
      while (f < n && isM3uSpace(s.codeUnitAt(f))) {
        f++;
      }
      if (e > m && f < n && s.codeUnitAt(f) == _equals) break;
      k = m;
      continue;
    }
    k++;
  }
  return (s.substring(i, k).trim(), k);
}
