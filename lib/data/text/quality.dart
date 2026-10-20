/// Quality badges parsed from channel names (TV Live channel card).
library;

import 'src/fold.dart';
import 'src/quality_tokens.dart';

/// `displayName`: the name without quality tokens; `badges`: normalized
/// badges in display order.
typedef QualityParse = ({String displayName, List<String> badges});

/// Extracts quality tokens from a channel name:
/// `Show TV FHD` → `(displayName: 'Show TV', badges: ['FHD'])`.
///
/// * Tokens are whole words in any position and any case, also wrapped in
///   brackets or set off by separators: `[FHD]`, `(HD)`, `| HD`, `- 4K`,
///   `hd`, small-capital / superscript forms (`ʜᴅ`, `ᶠᴴᴰ`).
/// * Badges are normalized and ordered: one resolution (the highest of
///   `SD HD FHD 4K 8K`), then `HDR`, then `H265`, then the frame rate
///   (`50FPS`). `UHD`/`Ultra HD`/`2160p` → `4K`, `Full HD`/`FullHD`/`1080p`
///   → `FHD`, `720p` → `HD`, `576i`/`480p` → `SD`, `HEVC`/`H.265`/`x265` →
///   `H265`, `HDR10` → `HDR`, `50 fps` → `50FPS`, `1080p50` → `FHD` + `50FPS`.
/// * Words that merely contain a token stay untouched: `HDTV` (by contract
///   `HDTV` is not `HD`), `SHD`, `Hdfilm`, `4Kids`. `H.264` is not a badge.
/// * Separators and brackets left behind by a removed token are cleaned up
///   (`Show TV (HD) - Yedek` → `Show TV - Yedek`, `[FHD] Show TV` →
///   `Show TV`, `TRT 1 HD+` → `TRT 1`); whitespace is collapsed.
/// * A name made only of tokens (`4K UHD`) is returned unchanged without
///   badges, so the display name is never empty.
///
/// Stored in `channels.quality` as the comma-joined badges.
QualityParse parseQuality(String rawName) {
  final words = _scanWords(rawName);
  var resolution = resNone;
  var hdr = false;
  var h265 = false;
  var fps = 0;
  var removed = 0;

  void apply(QualityWord q) {
    if (q.resolution > resolution) resolution = q.resolution;
    hdr = hdr || q.hdr;
    h265 = h265 || q.h265;
    if (q.fps > fps) fps = q.fps;
  }

  for (var k = 0; k < words.length; k++) {
    final w = words[k];
    final f = w.folded;
    if (f == null) continue;
    if (k + 1 < words.length && startsQualityPair(f)) {
      final next = words[k + 1];
      final nf = next.folded;
      final pair = nf == null ? null : qualityPairOf(f, nf);
      if (pair != null && _isTightGap(rawName, w.end, next.start)) {
        w
          ..removed = true
          ..joinsNext = true;
        next
          ..removed = true
          ..resolution = pair.resolution != resNone;
        apply(pair);
        removed += 2;
        k++;
        continue;
      }
    }
    final q = qualityWordOf(f);
    if (q != null) {
      w
        ..removed = true
        ..resolution = q.resolution != resNone;
      apply(q);
      removed++;
    }
  }

  if (removed == 0 || removed == words.length) {
    return (displayName: _tidy(rawName), badges: const <String>[]);
  }
  return (
    displayName: _rebuild(rawName, words),
    badges: [
      if (resolution != resNone) resolutionBadges[resolution],
      if (hdr) 'HDR',
      if (h265) 'H265',
      if (fps > 0) '${fps}FPS',
    ],
  );
}

final class _Word {
  _Word(this.start, this.end, this.folded);

  final int start;
  final int end;

  /// Lowercase folded ASCII form, or null when it cannot be a token.
  final String? folded;
  bool removed = false;

  /// Removed as a resolution token: a `+` right after it goes too (`HD+`).
  bool resolution = false;

  /// First half of a two-word token: the gap after it belongs to the token.
  bool joinsNext = false;
}

/// Splits [s] into words: runs of letters and digits (combining marks and
/// apostrophes inside a run belong to it). Dots separate words, so `H.265`
/// is the pair `H` + `265`.
List<_Word> _scanWords(String s) {
  final words = <_Word>[];
  final n = s.length;
  var i = 0;
  while (i < n) {
    if (!_isWordStart(s, i)) {
      i++;
      continue;
    }
    final start = i;
    final folded = StringBuffer();
    var candidate = true;
    while (i < n) {
      final c = s.codeUnitAt(i);
      final pair = _pairAt(s, i);
      if (pair >= 0) {
        final v = foldSupplementary(pair);
        if (v == foldKeepPair) {
          candidate = false;
        } else if (v >= foldSingle) {
          candidate = _addFolded(folded, v) && candidate;
        } else if (v != foldDrop) {
          break;
        }
        i += 2;
        continue;
      }
      final v = foldUnit(c);
      if (v >= foldSingle) {
        candidate = _addFolded(folded, v) && candidate;
      } else if (v != foldDrop) {
        break;
      }
      i++;
    }
    words.add(
      _Word(
        start,
        i,
        candidate && folded.length <= 12 ? folded.toString() : null,
      ),
    );
  }
  return words;
}

bool _isWordStart(String s, int i) {
  final pair = _pairAt(s, i);
  if (pair >= 0) {
    final v = foldSupplementary(pair);
    return v >= foldSingle || v == foldKeepPair;
  }
  return isWordUnit(s.codeUnitAt(i));
}

/// The supplementary code point of a valid surrogate pair at [i], or -1.
int _pairAt(String s, int i) {
  final c = s.codeUnitAt(i);
  if (c < 0xD800 || c > 0xDBFF || i + 1 >= s.length) return -1;
  final lo = s.codeUnitAt(i + 1);
  if (lo < 0xDC00 || lo > 0xDFFF) return -1;
  return 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00);
}

/// Appends a folded value; false when it is not plain ASCII alphanumeric.
bool _addFolded(StringBuffer out, int v) {
  if (v >= foldMultiBase) {
    out.write(foldMultiString(v));
    return true;
  }
  final f = v - foldSingle;
  out.writeCharCode(f);
  return (f >= 0x61 && f <= 0x7A) || (f >= 0x30 && f <= 0x39);
}

/// The gap inside a two-word token: at most two of space `.` `-` `_`
/// (`H.265`, `Full HD`, `Full-HD`, `50 FPS`).
bool _isTightGap(String s, int from, int to) {
  if (to - from > 2) return false;
  for (var i = from; i < to; i++) {
    final c = s.codeUnitAt(i);
    if (c != 0x20 && c != 0x2E && c != 0x2D && c != 0x5F && c != 0xA0) {
      return false;
    }
  }
  return true;
}

String _rebuild(String raw, List<_Word> words) {
  final out = StringBuffer();
  final gap = StringBuffer();
  var gapHadRemoval = false;
  var seenKept = false;
  var pos = 0;
  _Word? previous;

  void addGap(int from, int to) {
    if (previous != null && previous.joinsNext) return;
    var start = from;
    if (previous != null &&
        previous.removed &&
        previous.resolution &&
        start < to &&
        raw.codeUnitAt(start) == 0x2B) {
      start++; // `HD+`
    }
    gap.write(raw.substring(start, to));
  }

  for (final w in words) {
    addGap(pos, w.start);
    if (w.removed) {
      gapHadRemoval = true;
    } else {
      final g = gap.toString();
      out.write(
        !gapHadRemoval
            ? g
            : seenKept
            ? _cleanMiddle(g)
            : _cleanEdge(g, leading: true),
      );
      out.write(raw.substring(w.start, w.end));
      seenKept = true;
      gap.clear();
      gapHadRemoval = false;
    }
    pos = w.end;
    previous = w;
  }
  addGap(pos, raw.length);
  final g = gap.toString();
  out.write(gapHadRemoval ? _cleanEdge(g, leading: false) : g);
  return _tidy(out.toString());
}

/// Gap before the first or after the last kept word: drop dangling
/// separators and emptied brackets.
String _cleanEdge(String gap, {required bool leading}) {
  var t = _innerTrim(_removeEmptyBrackets(gap));
  if (leading) {
    var i = 0;
    while (i < t.length && _isSpaceOrSep(t.codeUnitAt(i))) {
      i++;
    }
    t = t.substring(i);
  } else {
    var e = t.length;
    while (e > 0 && _isSpaceOrSep(t.codeUnitAt(e - 1))) {
      e--;
    }
    t = t.substring(0, e);
  }
  return t;
}

/// Gap between two kept words that contained a removed token: keep one
/// separator (with the original spacing) or a single space.
String _cleanMiddle(String gap) {
  final t = _removeEmptyBrackets(gap);
  int? separator;
  var onlySpaceAndSep = true;
  for (var i = 0; i < t.length; i++) {
    final c = t.codeUnitAt(i);
    if (_isSpace(c)) continue;
    if (_cleanupSeparators.contains(c)) {
      separator ??= c;
    } else {
      onlySpaceAndSep = false;
      break;
    }
  }
  if (!onlySpaceAndSep) return _innerTrim(t);
  if (separator == null) return ' ';
  final spaced =
      t.isNotEmpty &&
      (_isSpace(t.codeUnitAt(0)) || _isSpace(t.codeUnitAt(t.length - 1)));
  final sep = String.fromCharCode(separator);
  return spaced ? ' $sep ' : sep;
}

/// Removes bracket pairs that contain only spaces and separators, replacing
/// each with a space.
String _removeEmptyBrackets(String t) {
  var s = t;
  var a = 0;
  while (a < s.length) {
    final close = _closingBracket(s.codeUnitAt(a));
    if (close != null) {
      var b = a + 1;
      while (b < s.length && _isSpaceOrSep(s.codeUnitAt(b))) {
        b++;
      }
      if (b < s.length && s.codeUnitAt(b) == close) {
        s = '${s.substring(0, a)} ${s.substring(b + 1)}';
        a = 0;
        continue;
      }
    }
    a++;
  }
  return s;
}

/// Drops spaces and separators right after an opening bracket and right
/// before a closing one (`(- Yedek` → `(Yedek`).
String _innerTrim(String t) {
  final out = StringBuffer();
  var i = 0;
  while (i < t.length) {
    final c = t.codeUnitAt(i);
    out.writeCharCode(c);
    i++;
    if (_closingBracket(c) != null) {
      while (i < t.length && _isSpaceOrSep(t.codeUnitAt(i))) {
        i++;
      }
    }
  }
  final s = out.toString();
  final back = StringBuffer();
  var pendingFrom = -1;
  for (var k = 0; k < s.length; k++) {
    final c = s.codeUnitAt(k);
    if (_isSpaceOrSep(c)) {
      if (pendingFrom < 0) pendingFrom = k;
      continue;
    }
    if (pendingFrom >= 0) {
      if (!_isClosingBracket(c)) back.write(s.substring(pendingFrom, k));
      pendingFrom = -1;
    }
    back.writeCharCode(c);
  }
  if (pendingFrom >= 0) back.write(s.substring(pendingFrom));
  return back.toString();
}

/// Collapses whitespace, removes spaces just inside brackets, trims.
String _tidy(String s) {
  final out = StringBuffer();
  var pendingSpace = false;
  var lastWasOpen = false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (_isSpace(c)) {
      pendingSpace = out.isNotEmpty;
      continue;
    }
    if (pendingSpace && !lastWasOpen && !_isClosingBracket(c)) {
      out.writeCharCode(0x20);
    }
    pendingSpace = false;
    out.writeCharCode(c);
    lastWasOpen = _closingBracket(c) != null;
  }
  return out.toString();
}

int? _closingBracket(int c) => switch (c) {
  0x28 => 0x29, // ( )
  0x5B => 0x5D, // [ ]
  0x7B => 0x7D, // { }
  0x3010 => 0x3011, // 【 】
  0x3014 => 0x3015, // 〔 〕
  0xFF08 => 0xFF09, // （ ）
  0xFF3B => 0xFF3D, // ［ ］
  _ => null,
};

bool _isClosingBracket(int c) =>
    c == 0x29 ||
    c == 0x5D ||
    c == 0x7D ||
    c == 0x3011 ||
    c == 0x3015 ||
    c == 0xFF09 ||
    c == 0xFF3D;

bool _isSpace(int c) =>
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    c == 0xA0 ||
    (c >= 0x2000 && c <= 0x200B) ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000;

bool _isSpaceOrSep(int c) => _isSpace(c) || _cleanupSeparators.contains(c);

/// Separators that may dangle after a token is removed. `+`, `&`, `.`, `!`
/// and `'` are not separators (`Canal+`, `Tom & Jerry`).
const Set<int> _cleanupSeparators = {
  0x7C,
  0x2D,
  0x5F,
  0x2F,
  0x5C,
  0x3A,
  0x2C,
  0x3B,
  0x7E,
  0x2A,
  0x3D,
  0x23, // | - _ / \ : , ; ~ * = #
  0x3C, 0x3E, 0xA6, 0xAB, 0xB7, 0xBB, // < > ¦ « · »
  0x2010,
  0x2011,
  0x2012,
  0x2013,
  0x2014,
  0x2015,
  0x2016,
  0x2022,
  0x2039, // ‐ ‑ ‒ – — ― ‖ • ‹
  0x203A,
  0x2192,
  0x21D2,
  0x2212,
  0x2219,
  0x2500,
  0x2501,
  0x2502,
  0x2503, // › → ⇒ − ∙ ─ ━ │ ┃
  0x2550,
  0x2551,
  0x25A0,
  0x25A1,
  0x25AA,
  0x25AB,
  0x25B6,
  0x25B8,
  0x25BA, // ═ ║ ■ □ ▪ ▫ ▶ ▸ ►
  0x25C6,
  0x25C7,
  0x25CB,
  0x25C9,
  0x25CF,
  0x2605,
  0x2606,
  0x2666,
  0x2726, // ◆ ◇ ○ ◉ ● ★ ☆ ♦ ✦
  0x2727, 0x272A, 0x2B50, // ✧ ✪ ⭐
};
