/// Country flags for category names (`TR | Ulusal` → `🇹🇷 Ulusal`) and
/// country-prefix stripping for channel names (`TR: Show TV` → `Show TV`).
///
/// A country marker is recognised only at the start of a name:
///
/// * an ISO 3166-1 alpha-2 code (`TR`, `DE`, `UK` → 🇬🇧 …), a few common
///   three-letter codes (`USA`, `UAE`, `KSA`, `GER`, `TUR`, `ITA` …), or a
///   country name in English, Turkish or the local language (`Türkiye`,
///   `Turkey`, `Italia`, `Almanya`, `United Kingdom` …), matched as whole
///   words, case- and diacritics-insensitively (`TÜRKİYE` = `turkiye`);
/// * optionally wrapped or decorated: `|TR|`, `[TR]`, `(TR)`, `★ TR ★`;
/// * followed by an explicit separator (`|`, `:`, `-`, `.`, `/`, `•`, `★` …),
///   by the end of the name, or — for two-letter codes written in capitals
///   and for country names — by a plain space (`TR Ulusal`).
///   Codes that are also common words (`AL`, `AT`, `BE`, `CO`, `ES`, `ID`,
///   `IN`, `IS`, `IT`, `MA`, `ME`, `NO`, `SE`) need an explicit separator,
///   so `AL JAZEERA` and `IN FOCUS` get no flag. Three-letter codes always
///   need one (`USA Network` is a channel, not a prefix).
/// * A name that already starts with a flag emoji keeps it.
///
/// `AR` is deliberately not a flag: in IPTV lists it almost always means
/// Arabic, which is not one country, while ISO says Argentina. It is still
/// stripped from channel names (as are `EN`, `EXYU`, `KU`, `LAT`), and
/// `Argentina` / `ARG` give 🇦🇷.
library;

import 'src/fold.dart';

/// The flag emoji (or null) and the label without the country marker.
typedef FlagParse = ({String? flag, String label});

/// Splits a category name into a flag and the remaining label:
/// `TR | Ulusal` → `(flag: '🇹🇷', label: 'Ulusal')`. Without a recognised
/// country the flag is null and the label is the trimmed name. When nothing
/// follows the country (`Türkiye`), the label is the country as written.
FlagParse parseCategoryFlag(String name) {
  final prefix = _readPrefix(name, 0, namesWithSpace: true, regions: false);
  final iso = prefix?.iso;
  if (prefix == null || iso == null || iso.isEmpty) {
    return (flag: null, label: name.trim());
  }
  final rest = name.substring(prefix.end).trim();
  return (flag: flagEmoji(iso), label: rest.isEmpty ? prefix.matched : rest);
}

/// The flag emoji for a category name, or null (see [parseCategoryFlag]).
String? flagForCategory(String name) => parseCategoryFlag(name).flag;

/// The UI label for a category: `TR | Ulusal` → `🇹🇷 Ulusal`; names without
/// a country are returned trimmed.
String flagged(String name) {
  final p = parseCategoryFlag(name);
  final flag = p.flag;
  if (flag == null) return p.label;
  return p.label.isEmpty ? flag : '$flag ${p.label}';
}

/// `TR` → `🇹🇷` (any case); null unless [iso2] is two ASCII letters.
String? flagEmoji(String iso2) {
  if (iso2.length != 2) return null;
  final a = iso2.codeUnitAt(0) | 0x20;
  final b = iso2.codeUnitAt(1) | 0x20;
  if (a < 0x61 || a > 0x7A || b < 0x61 || b > 0x7A) return null;
  return String.fromCharCodes([0x1F1E6 + a - 0x61, 0x1F1E6 + b - 0x61]);
}

/// Removes a leading country marker from a channel name, as used for EPG
/// matching: `TR: Show TV` / `TR | Show TV` / `|TR| Show TV` / `[TR] Show
/// TV` / `TR - Show TV` / `TR.Show TV` / `TR Show TV` → `Show TV`. Country
/// names need an explicit separator here (`Italia 1` is a channel), and
/// region codes without a flag (`AR`, `EN`, `EXYU`, `KU`, `LAT`) are removed
/// too. At most two markers are removed and the name is never emptied.
String stripCountryPrefix(String name) {
  var s = name;
  for (var round = 0; round < 2; round++) {
    final prefix = _readPrefix(s, 0, namesWithSpace: false, regions: true);
    if (prefix == null || prefix.end >= s.length) break;
    final rest = s.substring(prefix.end);
    if (rest.trim().isEmpty) break;
    s = rest;
  }
  return s;
}

/// Uppercase code → ISO alpha-2 ('' = region or language, no flag).
const Map<String, String> _codes = {
  // ISO 3166-1 alpha-2 codes seen in IPTV category names.
  'TR': 'TR', 'IT': 'IT', 'UK': 'GB', 'GB': 'GB', 'DE': 'DE', 'FR': 'FR',
  'ES': 'ES', 'NL': 'NL', 'US': 'US', 'PT': 'PT', 'PL': 'PL', 'RU': 'RU',
  'AL': 'AL', 'AZ': 'AZ', 'GR': 'GR', 'BG': 'BG', 'RO': 'RO', 'RS': 'RS',
  'BA': 'BA', 'HR': 'HR', 'SE': 'SE', 'NO': 'NO', 'DK': 'DK', 'FI': 'FI',
  'CH': 'CH', 'AT': 'AT', 'BE': 'BE', 'IE': 'IE', 'IN': 'IN', 'PK': 'PK',
  'IR': 'IR', 'IQ': 'IQ', 'SA': 'SA', 'AE': 'AE', 'EG': 'EG', 'MA': 'MA',
  'DZ': 'DZ', 'TN': 'TN', 'CA': 'CA', 'MX': 'MX', 'BR': 'BR', 'UA': 'UA',
  'CZ': 'CZ', 'SK': 'SK', 'HU': 'HU', 'SI': 'SI', 'MK': 'MK', 'ME': 'ME',
  'XK': 'XK', 'CY': 'CY', 'LB': 'LB', 'SY': 'SY', 'JO': 'JO', 'KW': 'KW',
  'QA': 'QA', 'BH': 'BH', 'OM': 'OM', 'IL': 'IL', 'KR': 'KR', 'JP': 'JP',
  'CN': 'CN', 'AU': 'AU', 'NZ': 'NZ', 'ZA': 'ZA', 'LU': 'LU', 'MT': 'MT',
  'IS': 'IS', 'LT': 'LT', 'LV': 'LV', 'EE': 'EE', 'MD': 'MD', 'KZ': 'KZ',
  'BD': 'BD', 'LK': 'LK', 'PH': 'PH', 'ID': 'ID', 'TH': 'TH', 'VN': 'VN',
  'NG': 'NG', 'CL': 'CL', 'CO': 'CO', 'PE': 'PE', 'VE': 'VE', 'LY': 'LY',
  // Three-letter codes (always need an explicit separator).
  'USA': 'US', 'UAE': 'AE', 'KSA': 'SA', 'GBR': 'GB', 'GER': 'DE',
  'DEU': 'DE', 'ITA': 'IT', 'TUR': 'TR', 'FRA': 'FR', 'ESP': 'ES',
  'NED': 'NL', 'NLD': 'NL', 'POR': 'PT', 'PRT': 'PT', 'POL': 'PL',
  'RUS': 'RU', 'ALB': 'AL', 'AZE': 'AZ', 'GRE': 'GR', 'GRC': 'GR',
  'BUL': 'BG', 'BGR': 'BG', 'ROU': 'RO', 'ROM': 'RO', 'SRB': 'RS',
  'BIH': 'BA', 'CRO': 'HR', 'HRV': 'HR', 'SWE': 'SE', 'NOR': 'NO',
  'DEN': 'DK', 'DNK': 'DK', 'FIN': 'FI', 'SUI': 'CH', 'CHE': 'CH',
  'AUT': 'AT', 'BEL': 'BE', 'IRL': 'IE', 'IND': 'IN', 'PAK': 'PK',
  'IRN': 'IR', 'IRQ': 'IQ', 'EGY': 'EG', 'MAR': 'MA', 'ALG': 'DZ',
  'DZA': 'DZ', 'TUN': 'TN', 'CAN': 'CA', 'MEX': 'MX', 'BRA': 'BR',
  'ARG': 'AR', 'UKR': 'UA', 'CZE': 'CZ', 'SVK': 'SK', 'HUN': 'HU',
  'SVN': 'SI', 'MKD': 'MK', 'MNE': 'ME', 'CYP': 'CY', 'LBN': 'LB',
  'SYR': 'SY', 'JOR': 'JO', 'KUW': 'KW', 'KWT': 'KW', 'QAT': 'QA',
  'BHR': 'BH', 'OMA': 'OM', 'OMN': 'OM', 'ISR': 'IL', 'KOR': 'KR',
  'JPN': 'JP', 'CHN': 'CN', 'AUS': 'AU', 'NZL': 'NZ', 'RSA': 'ZA',
  'ZAF': 'ZA', 'LUX': 'LU', 'MLT': 'MT', 'ISL': 'IS', 'LTU': 'LT',
  'LVA': 'LV', 'EST': 'EE', 'MDA': 'MD', 'KAZ': 'KZ', 'LBY': 'LY',
  // Regions and languages: stripped from channel names, no flag.
  'AR': '', 'EN': '', 'ENG': '', 'EXYU': '', 'KU': '', 'KURD': '',
  'LAT': '', 'ARAB': '', 'AFR': '',
};

/// Two-letter codes that are also everyday words; they need an explicit
/// separator (`IN | Hindi`, not `IN FOCUS`).
const Set<String> _wordLikeCodes = {
  'AL', 'AT', 'BE', 'CO', 'ES', 'ID', 'IN', 'IS', 'IT', 'MA', 'ME', 'NO', //
  'SE',
};

/// Folded country names (see `foldLower`) → ISO alpha-2 ('' = region).
const Map<String, String> _names = {
  'turkiye': 'TR', 'turkey': 'TR', 'turkei': 'TR', 'turquie': 'TR',
  'turchia': 'TR', 'turquia': 'TR',
  'italia': 'IT', 'italy': 'IT', 'italya': 'IT', 'italien': 'IT',
  'italie': 'IT',
  'united kingdom': 'GB', 'great britain': 'GB', 'britain': 'GB',
  'england': 'GB', 'ingiltere': 'GB', 'birlesik krallik': 'GB',
  'germany': 'DE', 'almanya': 'DE', 'deutschland': 'DE', 'allemagne': 'DE',
  'alemania': 'DE', 'germania': 'DE',
  'france': 'FR', 'fransa': 'FR', 'frankreich': 'FR', 'francia': 'FR',
  'spain': 'ES', 'ispanya': 'ES', 'espana': 'ES', 'spanien': 'ES',
  'espagne': 'ES', 'spagna': 'ES',
  'netherlands': 'NL', 'the netherlands': 'NL', 'holland': 'NL',
  'hollanda': 'NL', 'nederland': 'NL', 'niederlande': 'NL',
  'united states': 'US', 'united states of america': 'US', 'america': 'US',
  'amerika': 'US', 'abd': 'US', 'amerika birlesik devletleri': 'US',
  'portugal': 'PT', 'portekiz': 'PT',
  'poland': 'PL', 'polonya': 'PL', 'polska': 'PL', 'polen': 'PL',
  'pologne': 'PL',
  'russia': 'RU', 'rusya': 'RU', 'rossiya': 'RU', 'russland': 'RU',
  'russie': 'RU',
  'albania': 'AL', 'arnavutluk': 'AL', 'shqiperia': 'AL', 'shqiperi': 'AL',
  'albanien': 'AL', 'albanie': 'AL',
  'azerbaijan': 'AZ', 'azerbaycan': 'AZ', 'azerbaidschan': 'AZ',
  'greece': 'GR', 'yunanistan': 'GR', 'ellada': 'GR', 'hellas': 'GR',
  'griechenland': 'GR', 'grece': 'GR',
  'bulgaria': 'BG', 'bulgaristan': 'BG', 'bulgarien': 'BG',
  'balgariya': 'BG',
  'romania': 'RO', 'romanya': 'RO', 'rumanien': 'RO', 'roumanie': 'RO',
  'serbia': 'RS', 'sirbistan': 'RS', 'srbija': 'RS', 'serbien': 'RS',
  'bosnia': 'BA', 'bosnia herzegovina': 'BA', 'bosnia and herzegovina': 'BA',
  'bosna': 'BA', 'bosna i hercegovina': 'BA', 'bosna hersek': 'BA',
  'bosnien': 'BA',
  'croatia': 'HR', 'hirvatistan': 'HR', 'hrvatska': 'HR', 'kroatien': 'HR',
  'sweden': 'SE', 'isvec': 'SE', 'sverige': 'SE', 'schweden': 'SE',
  'suede': 'SE',
  'norway': 'NO', 'norvec': 'NO', 'norge': 'NO', 'norwegen': 'NO',
  'norvege': 'NO',
  'denmark': 'DK', 'danimarka': 'DK', 'danmark': 'DK', 'danemark': 'DK',
  'finland': 'FI', 'finlandiya': 'FI', 'suomi': 'FI', 'finnland': 'FI',
  'finlande': 'FI',
  'switzerland': 'CH', 'isvicre': 'CH', 'schweiz': 'CH', 'suisse': 'CH',
  'svizzera': 'CH',
  'austria': 'AT', 'avusturya': 'AT', 'osterreich': 'AT', 'autriche': 'AT',
  'belgium': 'BE', 'belcika': 'BE', 'belgie': 'BE', 'belgique': 'BE',
  'belgien': 'BE',
  'ireland': 'IE', 'irlanda': 'IE', 'eire': 'IE',
  'india': 'IN', 'hindistan': 'IN', 'bharat': 'IN', 'indien': 'IN',
  'pakistan': 'PK',
  'iran': 'IR',
  'iraq': 'IQ', 'irak': 'IQ',
  'saudi arabia': 'SA', 'suudi arabistan': 'SA', 'saudi': 'SA',
  'united arab emirates': 'AE', 'emirates': 'AE',
  'birlesik arap emirlikleri': 'AE', 'bae': 'AE',
  'egypt': 'EG', 'misir': 'EG', 'masr': 'EG', 'egypte': 'EG',
  'agypten': 'EG',
  'morocco': 'MA', 'fas': 'MA', 'maroc': 'MA', 'marokko': 'MA',
  'algeria': 'DZ', 'cezayir': 'DZ', 'algerie': 'DZ', 'algerien': 'DZ',
  'tunisia': 'TN', 'tunus': 'TN', 'tunisie': 'TN', 'tunesien': 'TN',
  'canada': 'CA', 'kanada': 'CA',
  'mexico': 'MX', 'meksika': 'MX', 'mexiko': 'MX', 'mexique': 'MX',
  'brazil': 'BR', 'brezilya': 'BR', 'brasil': 'BR', 'bresil': 'BR',
  'brasilien': 'BR',
  'argentina': 'AR', 'arjantin': 'AR', 'argentinien': 'AR',
  'ukraine': 'UA', 'ukrayna': 'UA', 'ukraina': 'UA',
  'czechia': 'CZ', 'czech republic': 'CZ', 'cekya': 'CZ', 'cesko': 'CZ',
  'tschechien': 'CZ',
  'slovakia': 'SK', 'slovakya': 'SK', 'slovensko': 'SK', 'slowakei': 'SK',
  'hungary': 'HU', 'macaristan': 'HU', 'magyarorszag': 'HU', 'ungarn': 'HU',
  'slovenia': 'SI', 'slovenya': 'SI', 'slovenija': 'SI', 'slowenien': 'SI',
  'north macedonia': 'MK', 'macedonia': 'MK', 'makedonya': 'MK',
  'kuzey makedonya': 'MK', 'makedonija': 'MK',
  'montenegro': 'ME', 'karadag': 'ME', 'crna gora': 'ME',
  'kosovo': 'XK', 'kosova': 'XK',
  'cyprus': 'CY', 'kibris': 'CY',
  'lebanon': 'LB', 'lubnan': 'LB', 'liban': 'LB',
  'syria': 'SY', 'suriye': 'SY',
  'jordan': 'JO', 'urdun': 'JO',
  'kuwait': 'KW', 'kuveyt': 'KW',
  'qatar': 'QA', 'katar': 'QA',
  'bahrain': 'BH', 'bahreyn': 'BH',
  'oman': 'OM', 'umman': 'OM',
  'israel': 'IL', 'israil': 'IL',
  'korea': 'KR', 'south korea': 'KR', 'guney kore': 'KR',
  'japan': 'JP', 'japonya': 'JP',
  'china': 'CN', 'cin': 'CN',
  'australia': 'AU', 'avustralya': 'AU',
  'new zealand': 'NZ', 'yeni zelanda': 'NZ',
  'south africa': 'ZA', 'guney afrika': 'ZA',
  'luxembourg': 'LU', 'luksemburg': 'LU',
  'malta': 'MT',
  'iceland': 'IS', 'izlanda': 'IS',
  'lithuania': 'LT', 'litvanya': 'LT',
  'latvia': 'LV', 'letonya': 'LV',
  'estonia': 'EE', 'estonya': 'EE',
  'moldova': 'MD',
  'kazakhstan': 'KZ', 'kazakistan': 'KZ',
  'bangladesh': 'BD', 'banglades': 'BD',
  'sri lanka': 'LK',
  'philippines': 'PH', 'filipinler': 'PH',
  'indonesia': 'ID', 'endonezya': 'ID',
  'thailand': 'TH', 'tayland': 'TH',
  'vietnam': 'VN',
  'nigeria': 'NG', 'nijerya': 'NG',
  'chile': 'CL', 'sili': 'CL',
  'colombia': 'CO', 'kolombiya': 'CO',
  'peru': 'PE',
  'venezuela': 'VE',
  'libya': 'LY',
  // Regions / languages (no flag).
  'arabic': '', 'arab': '', 'latino': '', 'kurdish': '', 'kurdistan': '',
};

/// First words of the multi-word entries of [_names].
final Set<String> _multiWordStarts = {
  for (final name in _names.keys)
    if (name.contains(' ')) name.substring(0, name.indexOf(' ')),
};

/// Explicit separators and decorations between a country marker and the
/// rest of the name.
const Set<int> _separators = {
  0x7C,
  0x3A,
  0x2D,
  0x2E,
  0x2F,
  0x5C,
  0x5F,
  0x2A,
  0x7E,
  0x3D,
  0x23, // | : - . / \ _ * ~ = #
  0x2C, 0x3B, 0x3E, 0xA6, 0xB7, 0xBB, // , ; > ¦ · »
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
  0x2727, 0x272A, 0x2B50, 0x27A4, 0x279C, 0x27A1, // ✧ ✪ ⭐ ➤ ➜ ➡
};

final class _Prefix {
  const _Prefix(this.iso, this.end, this.matched);

  /// ISO alpha-2, or '' for a region without a flag.
  final String iso;

  /// Where the rest of the name starts.
  final int end;

  /// The marker as written (used when nothing follows it).
  final String matched;
}

final class _Word {
  const _Word(this.start, this.end, this.folded, this.ascii);
  final int start;
  final int end;
  final String folded;

  /// Raw text is ASCII letters only (a candidate country code).
  final bool ascii;
}

_Prefix? _readPrefix(
  String s,
  int from, {
  required bool namesWithSpace,
  required bool regions,
}) {
  final n = s.length;
  var i = _skipSpaces(s, from);
  if (i >= n) return null;

  // A name that already starts with a flag emoji keeps it, and a repeated
  // marker for the same country after it is consumed too.
  final emoji = _flagEmojiAt(s, i);
  if (emoji != null) {
    final after = _skipSeparators(s, i + 4);
    final again = _readPrefix(
      s,
      after,
      namesWithSpace: namesWithSpace,
      regions: false,
    );
    final end = again != null && again.iso == emoji ? again.end : after;
    // Nothing to fall back to as a label: the flag is already shown.
    return _Prefix(emoji, end, '');
  }

  int? close;
  final first = s.codeUnitAt(i);
  final bracket = _closingBracket(first);
  if (bracket != null) {
    close = bracket;
    i = _skipSpaces(s, i + 1);
  } else if (_separators.contains(first)) {
    // Decoration before the marker: `|TR|`, `★ TR ★`, `• TR •`.
    while (i < n && _separators.contains(s.codeUnitAt(i))) {
      i++;
    }
    i = _skipSpaces(s, i);
  }

  final firstWord = _readWord(s, i);
  if (firstWord == null) return null;
  final words = [firstWord];
  // Further words only when the first one can start a multi-word name.
  if (_multiWordStarts.contains(firstWord.folded)) {
    var e = firstWord.end;
    while (words.length < 4 &&
        e + 1 < n &&
        (s.codeUnitAt(e) == 0x20 || s.codeUnitAt(e) == 0x2D) &&
        _isLetter(s.codeUnitAt(e + 1))) {
      final w = _readWord(s, e + 1)!;
      words.add(w);
      e = w.end;
    }
  }

  // Longest country name first.
  for (var k = words.length; k >= 1; k--) {
    final key = k == 1
        ? words[0].folded
        : words.take(k).map((w) => w.folded).join(' ');
    final iso = _names[key];
    if (iso == null || (iso.isEmpty && !regions)) continue;
    final matched = s.substring(words[0].start, words[k - 1].end);
    final r = _finish(
      s,
      words[k - 1].end,
      iso,
      matched,
      close: close,
      allowSpace: namesWithSpace,
      allowAlone: true,
    );
    if (r != null) return r;
  }

  final w = words[0];
  final length = w.end - w.start;
  if (!w.ascii || length < 2 || length > 4) return null;
  final raw = s.substring(w.start, w.end);
  final code = raw.toUpperCase();
  final iso = _codes[code];
  if (iso == null || (iso.isEmpty && !regions)) return null;
  final upper = raw == code;
  return _finish(
    s,
    w.end,
    iso,
    raw,
    close: close,
    allowSpace: upper && length == 2 && !_wordLikeCodes.contains(code),
    allowAlone: upper,
  );
}

_Prefix? _finish(
  String s,
  int end,
  String iso,
  String matched, {
  required int? close,
  required bool allowSpace,
  required bool allowAlone,
}) {
  final n = s.length;
  final j = _skipSpaces(s, end);
  if (close != null) {
    if (j < n && s.codeUnitAt(j) == close) {
      return _Prefix(iso, _skipSeparators(s, j + 1), matched);
    }
    return null;
  }
  if (j >= n) return allowAlone ? _Prefix(iso, n, matched) : null;
  final c = s.codeUnitAt(j);
  if (_separators.contains(c)) {
    return _Prefix(iso, _skipSeparators(s, j), matched);
  }
  if (j > end && allowSpace) return _Prefix(iso, j, matched);
  return null;
}

/// Reads a run of letters starting at [i] (combining marks and apostrophes
/// inside the run are allowed); null when [i] is not a letter.
_Word? _readWord(String s, int i) {
  final n = s.length;
  if (i >= n || !_isLetter(s.codeUnitAt(i))) return null;
  final folded = StringBuffer();
  var ascii = true;
  var j = i;
  while (j < n) {
    final c = s.codeUnitAt(j);
    final v = foldUnit(c);
    if (v >= foldSingle && v < foldMultiBase) {
      final f = v - foldSingle;
      if (f >= 0x30 && f <= 0x39) break; // digits end the word
      folded.writeCharCode(f);
    } else if (v >= foldMultiBase) {
      folded.write(foldMultiString(v));
    } else if (v != foldDrop) {
      break;
    }
    final isAsciiLetter = (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A;
    if (!isAsciiLetter) ascii = false;
    j++;
  }
  return _Word(i, j, folded.toString(), ascii);
}

bool _isLetter(int c) {
  if (c >= 0xD800 && c <= 0xDFFF) return false;
  final v = foldUnit(c);
  if (v >= foldMultiBase) return true;
  if (v < foldSingle) return false;
  final f = v - foldSingle;
  return f < 0x30 || f > 0x39;
}

int? _closingBracket(int c) => switch (c) {
  0x5B => 0x5D, // [ ]
  0x28 => 0x29, // ( )
  0x7B => 0x7D, // { }
  0xAB => 0xBB, // « »
  0x3C => 0x3E, // < >
  _ => null,
};

/// ISO code of a regional-indicator pair at [i], or null.
String? _flagEmojiAt(String s, int i) {
  if (i + 3 >= s.length) return null;
  if (s.codeUnitAt(i) != 0xD83C || s.codeUnitAt(i + 2) != 0xD83C) {
    return null;
  }
  final a = s.codeUnitAt(i + 1);
  final b = s.codeUnitAt(i + 3);
  if (a < 0xDDE6 || a > 0xDDFF || b < 0xDDE6 || b > 0xDDFF) return null;
  return String.fromCharCodes([0x41 + a - 0xDDE6, 0x41 + b - 0xDDE6]);
}

bool _isSpace(int c) =>
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    c == 0xA0 ||
    (c >= 0x2000 && c <= 0x200D) ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000 ||
    c == 0xFE0F;

int _skipSpaces(String s, int i) {
  while (i < s.length && _isSpace(s.codeUnitAt(i))) {
    i++;
  }
  return i;
}

int _skipSeparators(String s, int i) {
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (!_isSpace(c) && !_separators.contains(c)) break;
    i++;
  }
  return i;
}
