/// Text normalization for search (SQLite FTS5) and EPG channel matching.
///
/// All functions are pure, synchronous and safe to call from any isolate.
/// They do one table lookup per character (see `src/fold.dart`), so
/// normalizing 100k titles takes well under a second.
library;

import 'dart:typed_data';

import 'flags.dart';
import 'src/fold.dart';
import 'src/quality_tokens.dart';

/// Normalizes [s] for full-text search; the same function must be applied
/// to indexed text and to queries.
///
/// * Lowercase, Turkish-aware: `İ`, `I` and `ı` all become `i`.
/// * Diacritics folded: `ş→s ç→c ğ→g ö→o ü→u é→e â→a ñ→n ø→o`, `ß→ss`,
///   `æ→ae`, `œ→oe`, small capitals and super/subscripts (`ʜᴅ`, `ᴴᴰ`) and
///   fullwidth or mathematical letters fold to plain ASCII.
/// * Quality tokens are dropped as whole words: SD, HD, FHD, UHD, 4K, 8K,
///   H265 / H.265 / HEVC / x265, HDR, HDR10, 1080p / 720p / 2160p…, 50FPS /
///   60FPS / `50 fps`, `Full HD`, `Ultra HD` (`HDTV` and `Hdfilm` stay).
/// * Apostrophes are removed without a break (`Grey's` → `greys`,
///   `Türkiye'nin` → `turkiyenin`), and dots inside single-letter acronyms
///   are joined (`S.W.A.T.` → `swat`, `E.T.` → `et`).
/// * Every other punctuation or symbol (emoji included) becomes a space;
///   spaces are collapsed and the result is trimmed.
///
/// Examples: `Sıcak Kafa` → `sicak kafa`, `İSTANBUL` → `istanbul`,
/// `ŞOW TV FHD` → `sow tv`.
String normalizeForSearch(String s) => _normalizer.run(s);

/// [normalizeForSearch] for EPG name matching: a leading country marker is
/// removed first (`TR:`, `TR |`, `|TR|`, `[TR]`, `TR -`, `TR.`, `TR ` — see
/// [stripCountryPrefix]), then every non-alphanumeric character.
///
/// `TR: Show TV HD` → `showtv`, `ShowTV` → `showtv`, `TRT 1` → `trt1`.
String normalizeChannelName(String s) {
  final normalized = _normalizer.run(stripCountryPrefix(s));
  return normalized.contains(' ') ? normalized.replaceAll(' ', '') : normalized;
}

/// At most this many terms go into one FTS query.
const int _maxFtsTerms = 16;

/// Builds an FTS5 `MATCH` expression with prefix matching on every term:
/// `Sıcak Kafa` → `"sicak"* "kafa"*` (terms are implicitly AND-ed).
///
/// The input goes through [normalizeForSearch], so quotes, `*`, `-`, `:`,
/// parentheses, `^`, `+` and FTS5 operators (`AND`, `OR`, `NOT`, `NEAR`)
/// cannot change the query: punctuation becomes a separator and every term is
/// a quoted string (with `"` doubled, should one ever survive). At most 16
/// terms are used.
///
/// Returns an empty string when nothing searchable is left (blank input, or
/// only punctuation / quality tokens); callers must not run `MATCH ''`.
String ftsQuery(String userInput) {
  final normalized = normalizeForSearch(userInput);
  if (normalized.isEmpty) return '';
  final out = StringBuffer();
  var terms = 0;
  for (final term in normalized.split(' ')) {
    if (term.isEmpty) continue;
    if (terms == _maxFtsTerms) break;
    if (terms > 0) out.write(' ');
    out
      ..write('"')
      ..write(term.contains('"') ? term.replaceAll('"', '""') : term)
      ..write('"*');
    terms++;
  }
  return out.toString();
}

final _SearchNormalizer _normalizer = _SearchNormalizer();

// Roles of the previous token, for two-word quality tokens.
const int _roleNone = 0;
const int _rolePairStart = 1; // full, ultra, h, 2–3 digit number

/// Single-pass normalizer. One instance per isolate; [run] is synchronous
/// and re-entrant only in the sense that it never calls itself.
final class _SearchNormalizer {
  Uint16List _out = Uint16List(0);
  int _len = 0;

  /// Start of the current token in [_out], or -1.
  int _tokStart = -1;

  /// Characters since the token start or the last joined acronym dot.
  int _segLen = 0;

  /// Start of the previous kept token, and whether it can start a pair.
  int _prevStart = -1;
  int _prevRole = _roleNone;

  String run(String s) {
    final n = s.length;
    if (n == 0) return '';
    _out = scratch(n * 4 + 4);
    _len = 0;
    _tokStart = -1;
    _segLen = 0;
    _prevStart = -1;
    _prevRole = _roleNone;
    for (var i = 0; i < n; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x80) {
        final v = foldUnit(c);
        if (v >= foldSingle) {
          _append(v - foldSingle);
        } else if (v == foldBoundary) {
          _endToken();
        } else if (v == foldDot) {
          if (_isAcronymDot(s, i)) {
            _segLen = 0;
          } else {
            _endToken();
          }
        }
        // foldDrop: apostrophes
        continue;
      }
      if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n) {
        final lo = s.codeUnitAt(i + 1);
        if (lo >= 0xDC00 && lo <= 0xDFFF) {
          final v = foldSupplementary(
            0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00),
          );
          if (v == foldKeepPair) {
            _append(c);
            _out[_len++] = lo;
          } else {
            _emit(v);
          }
          i++;
          continue;
        }
      }
      _emit(foldUnit(c));
    }
    _endToken();
    return String.fromCharCodes(_out, 0, _len);
  }

  void _emit(int v) {
    if (v >= foldMultiBase) {
      final m = foldMultiString(v);
      for (var k = 0; k < m.length; k++) {
        _append(m.codeUnitAt(k));
      }
    } else if (v >= foldSingle) {
      _append(v - foldSingle);
    } else if (v == foldBoundary || v == foldDot) {
      _endToken();
    }
    // foldDrop: nothing
  }

  void _append(int unit) {
    if (_tokStart < 0) {
      if (_len > 0) _out[_len++] = 0x20;
      _tokStart = _len;
      _segLen = 0;
    }
    _out[_len++] = unit;
    _segLen++;
  }

  /// A dot joins an acronym when it follows a single letter and precedes a
  /// single letter that is itself followed by a dot, a boundary or the end:
  /// `S.W.A.T.`, `U.S. Open`, `E.T.`, but not `Dr.House` or `H.265`.
  bool _isAcronymDot(String s, int i) {
    if (_tokStart < 0 || _segLen != 1) return false;
    final last = _out[_len - 1];
    if (last < 0x61 || last > 0x7A) return false;
    if (i + 1 >= s.length || !_isAsciiFoldedLetter(s.codeUnitAt(i + 1))) {
      return false;
    }
    if (i + 2 >= s.length) return true;
    final after = s.codeUnitAt(i + 2);
    if (after >= 0xD800 && after <= 0xDFFF) return true;
    final v = foldUnit(after);
    return v < foldSingle && v != foldKeepPair && v != foldDrop;
  }

  static bool _isAsciiFoldedLetter(int c) {
    if (c >= 0xD800 && c <= 0xDFFF) return false;
    final v = foldUnit(c);
    if (v < foldSingle || v >= foldMultiBase) return false;
    final f = v - foldSingle;
    return f >= 0x61 && f <= 0x7A;
  }

  void _endToken() {
    final start = _tokStart;
    if (start < 0) return;
    _tokStart = -1;
    final word = _asciiWord(start, _len);
    if (word == null) {
      _keep(start, _roleNone);
      return;
    }
    if (_prevRole == _rolePairStart) {
      final prev = String.fromCharCodes(_out, _prevStart, start - 1);
      if (qualityPairOf(prev, word) != null) {
        _drop(_prevStart);
        return;
      }
    }
    if (qualityWordOf(word) != null) {
      _drop(start);
      return;
    }
    _keep(start, startsQualityPair(word) ? _rolePairStart : _roleNone);
  }

  void _keep(int start, int role) {
    _prevStart = start;
    _prevRole = role;
  }

  /// Removes everything from [start] (and the space before it).
  void _drop(int start) {
    _len = start > 0 ? start - 1 : 0;
    _prevStart = -1;
    _prevRole = _roleNone;
  }

  /// The token as a string when it could be a quality token (short, ASCII,
  /// plausible first character); null otherwise, without allocating.
  String? _asciiWord(int start, int end) {
    final length = end - start;
    if (length > 9) return null;
    final first = _out[start];
    final plausible =
        (first >= 0x30 && first <= 0x39) ||
        first == 0x73 || // s
        first == 0x68 || // h
        first == 0x66 || // f
        first == 0x75 || // u
        first == 0x78; // x
    if (!plausible) return null;
    for (var k = start; k < end; k++) {
      if (_out[k] > 0x7A) return null;
    }
    return String.fromCharCodes(_out, start, end);
  }
}
