// Character folding shared by normalize.dart, quality.dart and flags.dart.
//
// Every code unit is classified once and cached, so the hot loops only do a
// table lookup per character:
//
// * ASCII is precomputed: letters are lowercased, digits kept, `'` and `` ` ``
//   are dropped (so "Grey's" → "greys"), `.` is reported as [foldDot] (the
//   caller decides between an acronym join and a boundary), everything else
//   is a word boundary.
// * Other BMP characters are resolved on first sight from the generated
//   tables in fold_data.dart (NFKD with combining marks removed, plus manual
//   folds such as `ı → i`, `ß → ss`, `ə → e`, small capitals `ʜ → h`), then
//   from the Unicode category: letters and numbers are kept (lowercased),
//   marks / format characters / modifier symbols are dropped, punctuation,
//   symbols and spaces become boundaries. The category test is a RegExp, but
//   it runs at most once per distinct code point (the result is cached).
// * Supplementary characters (surrogate pairs) are resolved the same way and
//   cached in a map; emoji, flags and other symbols become boundaries.

import 'dart:typed_data';

import 'fold_data.dart';

/// Word boundary (space, punctuation, symbol).
const int foldBoundary = 1;

/// Removed without creating a boundary (combining marks, apostrophes,
/// zero-width characters).
const int foldDrop = 2;

/// ASCII full stop; the caller decides whether it joins an acronym.
const int foldDot = 3;

/// Supplementary letter that is kept unchanged (both surrogates are copied).
const int foldKeepPair = 4;

/// Values `>= foldSingle` encode one replacement code unit:
/// `value - foldSingle`.
const int foldSingle = 0x10000;

/// Values `>= foldMultiBase` encode a multi-character replacement:
/// `foldMultiString(value)`.
const int foldMultiBase = 0x20000;

final Int32List _bmp = _initBmp();
final Map<int, int> _supplementary = <int, int>{};
final List<String> _multi = <String>[];
final Map<String, int> _multiIndex = <String, int>{};

final RegExp _letterOrNumber = RegExp(r'^[\p{L}\p{N}]$', unicode: true);
final RegExp _droppable = RegExp(r'^[\p{M}\p{Cf}\p{Sk}]$', unicode: true);

/// Characters dropped even though their category says otherwise:
/// apostrophe look-alikes, soft hyphen, Arabic tatweel.
const Set<int> _manualDrop = {
  0x00AD, // soft hyphen
  0x02B9, 0x02BA, 0x02BB, 0x02BC, 0x02C8, 0x02CC, // modifier apostrophes/primes
  0x055A, // Armenian apostrophe
  0x05F3, // Hebrew geresh
  0x0640, // Arabic tatweel
  0x2018, 0x2019, 0x201B, 0x2032, // quotes used as apostrophes, prime
  0xFF07, // fullwidth apostrophe
};

Int32List _initBmp() {
  final table = Int32List(0x10000);
  for (var c = 0; c < 0x80; c++) {
    int v;
    if (c >= 0x41 && c <= 0x5A) {
      v = foldSingle + c + 0x20;
    } else if ((c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39)) {
      v = foldSingle + c;
    } else if (c == 0x27 || c == 0x60) {
      v = foldDrop;
    } else if (c == 0x2E) {
      v = foldDot;
    } else {
      v = foldBoundary;
    }
    table[c] = v;
  }
  return table;
}

/// Folds one BMP code unit (not a surrogate). See the constants above for
/// the meaning of the result.
int foldUnit(int c) {
  final cached = _bmp[c];
  if (cached != 0) return cached;
  final v = _computeBmp(c);
  _bmp[c] = v;
  return v;
}

/// Folds one supplementary code point (`>= 0x10000`).
int foldSupplementary(int cp) =>
    _supplementary[cp] ??= _computeSupplementary(cp);

/// The replacement text of a value `>= foldMultiBase`.
String foldMultiString(int value) => _multi[value - foldMultiBase];

int _computeBmp(int c) {
  if (c >= 0xD800 && c <= 0xDFFF) return foldBoundary; // lone surrogate
  if (_manualDrop.contains(c)) return foldDrop;
  final run = _lookupRun(c);
  if (run >= 0) return foldSingle + run;
  final multi = foldMulti[c];
  if (multi != null) return _multiValue(multi);
  final nonAscii = foldNonAscii[c];
  if (nonAscii != null) return foldSingle + nonAscii;
  final ch = String.fromCharCode(c);
  if (_letterOrNumber.hasMatch(ch)) {
    final lower = ch.toLowerCase();
    return foldSingle + (lower.length == 1 ? lower.codeUnitAt(0) : c);
  }
  if (_droppable.hasMatch(ch)) return foldDrop;
  return foldBoundary;
}

int _computeSupplementary(int cp) {
  // Regional indicators (flag emoji) and other emoji/symbol blocks.
  if (cp >= 0x1F1E6 && cp <= 0x1F1FF) return foldBoundary;
  // Tags and variation selectors supplement.
  if ((cp >= 0xE0000 && cp <= 0xE007F) || (cp >= 0xE0100 && cp <= 0xE01EF)) {
    return foldDrop;
  }
  final run = _lookupRun(cp);
  if (run >= 0) return foldSingle + run;
  final multi = foldMulti[cp];
  if (multi != null) return _multiValue(multi);
  final ch = String.fromCharCode(cp);
  if (_letterOrNumber.hasMatch(ch)) return foldKeepPair;
  if (_droppable.hasMatch(ch)) return foldDrop;
  return foldBoundary;
}

int _multiValue(String s) {
  final existing = _multiIndex[s];
  if (existing != null) return foldMultiBase + existing;
  _multi.add(s);
  _multiIndex[s] = _multi.length - 1;
  return foldMultiBase + _multi.length - 1;
}

/// Binary search in [foldRuns]; returns the ASCII code or -1.
int _lookupRun(int cp) {
  var lo = 0;
  var hi = foldRuns.length ~/ 4 - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final base = mid * 4;
    final start = foldRuns[base];
    if (cp < start) {
      hi = mid - 1;
    } else if (cp > foldRuns[base + 1]) {
      lo = mid + 1;
    } else {
      return foldRuns[base + 2] + (cp - start) * foldRuns[base + 3];
    }
  }
  return -1;
}

/// Lowercases and folds [s] (Turkish-aware, diacritics removed); every run of
/// boundaries becomes one space and the result is trimmed. Unlike
/// `normalizeForSearch` it keeps quality tokens and treats `.` as a boundary.
String foldLower(String s) {
  final n = s.length;
  if (n == 0) return '';
  final out = scratch(n * 3 + 4);
  var len = 0;
  var pendingSpace = false;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    int v;
    var pair = false;
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n) {
      final lo = s.codeUnitAt(i + 1);
      if (lo >= 0xDC00 && lo <= 0xDFFF) {
        v = foldSupplementary(0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00));
        pair = true;
      } else {
        v = foldBoundary;
      }
    } else {
      v = foldUnit(c);
    }
    if (v == foldDrop) {
      if (pair) i++;
      continue;
    }
    if (v < foldSingle && v != foldKeepPair) {
      // boundary or dot
      if (len > 0) pendingSpace = true;
      if (pair) i++;
      continue;
    }
    if (pendingSpace) {
      out[len++] = 0x20;
      pendingSpace = false;
    }
    if (v == foldKeepPair) {
      out[len++] = c;
      out[len++] = s.codeUnitAt(++i);
    } else if (v < foldMultiBase) {
      out[len++] = v - foldSingle;
      if (pair) i++;
    } else {
      final m = foldMultiString(v);
      for (var k = 0; k < m.length; k++) {
        out[len++] = m.codeUnitAt(k);
      }
      if (pair) i++;
    }
  }
  return String.fromCharCodes(out, 0, len);
}

/// True when [c] (a BMP code unit) folds to a letter or digit.
bool isWordUnit(int c) {
  final v = foldUnit(c);
  return v >= foldSingle || v == foldKeepPair;
}

Uint16List _scratch = Uint16List(256);

/// A reusable output buffer of at least [length] code units. Callers must
/// not hold on to it across calls (everything here is synchronous).
Uint16List scratch(int length) {
  if (_scratch.length < length) {
    var size = _scratch.length;
    while (size < length) {
      size *= 2;
    }
    _scratch = Uint16List(size);
  }
  return _scratch;
}
