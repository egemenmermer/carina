// The quality-token vocabulary shared by normalize.dart (drops the tokens)
// and quality.dart (turns them into badges). Words are folded lowercase
// ASCII (see fold.dart), so `Hd`, `ʜᴅ` and `ᴴᴰ` all arrive here as `hd`.

/// Resolution ranks; the badge is [resolutionBadges] at the rank.
const int resNone = 0;
const int resSD = 1;
const int resHD = 2;
const int resFHD = 3;
const int res4K = 4;
const int res8K = 5;

const List<String> resolutionBadges = ['', 'SD', 'HD', 'FHD', '4K', '8K'];

/// What a word (or a two-word sequence) says about stream quality.
final class QualityWord {
  const QualityWord({
    this.resolution = resNone,
    this.hdr = false,
    this.h265 = false,
    this.fps = 0,
  });

  final int resolution;
  final bool hdr;
  final bool h265;
  final int fps;
}

const _sd = QualityWord(resolution: resSD);
const _hd = QualityWord(resolution: resHD);
const _fhd = QualityWord(resolution: resFHD);
const _uhd = QualityWord(resolution: res4K);
const _uhd8k = QualityWord(resolution: res8K);
const _hdr = QualityWord(hdr: true);
const _h265 = QualityWord(h265: true);

/// The quality meaning of a single folded word, or null when the word is not
/// a quality token on its own. Whole words only: `hdtv`, `shd`, `hdfilm` and
/// `4kids` are not tokens.
QualityWord? qualityWordOf(String w) {
  switch (w) {
    case 'sd':
      return _sd;
    case 'hd':
      return _hd;
    case 'fhd' || 'fullhd':
      return _fhd;
    case 'uhd' || 'ultrahd' || '4k':
      return _uhd;
    case '8k':
      return _uhd8k;
    case 'hdr' || 'hdr10':
      return _hdr;
    case 'h265' || 'hevc' || 'x265':
      return _h265;
  }
  return _numericWord(w);
}

/// `full` + `hd` → FHD, `ultra` + `hd` → 4K, `h` + `265` (H.265 / H 265)
/// → H265, `50` + `fps` → 50FPS. Returns null when [first] and [second] do
/// not form a token together.
QualityWord? qualityPairOf(String first, String second) {
  switch (second) {
    case 'hd':
      if (first == 'full') return _fhd;
      if (first == 'ultra') return _uhd;
      return null;
    case '265':
      return first == 'h' ? _h265 : null;
    case 'fps':
      final n = _smallNumber(first);
      return n == null ? null : QualityWord(fps: n);
  }
  return null;
}

/// Whether [w] can start a two-word token (see [qualityPairOf]).
bool startsQualityPair(String w) =>
    w == 'full' || w == 'ultra' || w == 'h' || _smallNumber(w) != null;

/// `1080p`, `720i`, `1080p50`, `2160p60`, `50fps`.
QualityWord? _numericWord(String w) {
  final n = w.length;
  if (n < 4 || n > 9) return null;
  var i = 0;
  while (i < n && _isDigit(w.codeUnitAt(i))) {
    i++;
  }
  if (i == 0) return null;
  final number = int.parse(w.substring(0, i));
  final rest = w.substring(i);
  if (rest == 'fps') {
    return i >= 2 && i <= 3 && number >= 10 ? QualityWord(fps: number) : null;
  }
  if (i < 3 || i > 4 || rest.isEmpty) return null;
  final scan = rest.codeUnitAt(0);
  if (scan != 0x70 && scan != 0x69) return null; // p or i
  final int resolution;
  switch (number) {
    case 480 || 576:
      resolution = resSD;
    case 720:
      resolution = resHD;
    case 1080:
      resolution = resFHD;
    case 2160:
      resolution = res4K;
    case 4320:
      resolution = res8K;
    default:
      return null;
  }
  final fpsText = rest.substring(1);
  if (fpsText.isEmpty) return QualityWord(resolution: resolution);
  final fps = _smallNumber(fpsText);
  return fps == null ? null : QualityWord(resolution: resolution, fps: fps);
}

/// A 2–3 digit number (10–999), as used before `fps`.
int? _smallNumber(String w) {
  if (w.length < 2 || w.length > 3) return null;
  for (var i = 0; i < w.length; i++) {
    if (!_isDigit(w.codeUnitAt(i))) return null;
  }
  final n = int.parse(w);
  return n >= 10 ? n : null;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
