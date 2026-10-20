/// Language matching for default audio/subtitle track selection.
///
/// Tracks carry ISO 639-1 (`tr`), ISO 639-2/B or /T (`tur`, `ger`/`deu`),
/// BCP 47 (`tr-TR`) tags, or no tag at all with the language only in the
/// title (`Türkçe`, `English 5.1`). Everything is folded to a canonical
/// ISO 639-1 code before comparing.
library;

import 'playback_engine.dart';

/// Canonical code → aliases (codes first, then English and native names).
/// The first three-letter alias is what mpv's `alang`/`slang` see first.
const Map<String, List<String>> kLanguageAliases = {
  'tr': ['tur', 'tr', 'trk', 'turkish', 'turkce', 'turk', 'turkiye'],
  'en': ['eng', 'en', 'english', 'ingilizce'],
  'de': ['deu', 'ger', 'de', 'german', 'deutsch', 'almanca'],
  'fr': ['fra', 'fre', 'fr', 'french', 'francais', 'fransizca'],
  'es': ['spa', 'es', 'esp', 'spanish', 'espanol', 'castellano', 'ispanyolca'],
  'it': ['ita', 'it', 'italian', 'italiano', 'italyanca'],
  'pt': ['por', 'pt', 'portuguese', 'portugues', 'portekizce'],
  'nl': ['nld', 'dut', 'nl', 'dutch', 'nederlands', 'flemenkce'],
  'ru': ['rus', 'ru', 'russian', 'russkiy', 'rusca'],
  'uk': ['ukr', 'uk', 'ukrainian', 'ukraynaca'],
  'pl': ['pol', 'pl', 'polish', 'polski', 'lehce'],
  'cs': ['ces', 'cze', 'cs', 'czech', 'cestina', 'cekce'],
  'sk': ['slk', 'slo', 'sk', 'slovak', 'slovakca'],
  'hu': ['hun', 'hu', 'hungarian', 'magyar', 'macarca'],
  'ro': ['ron', 'rum', 'ro', 'romanian', 'romana', 'rumence'],
  'bg': ['bul', 'bg', 'bulgarian', 'bulgarca'],
  'el': ['ell', 'gre', 'el', 'greek', 'ellinika', 'yunanca'],
  'sr': ['srp', 'sr', 'serbian', 'srpski', 'sirpca'],
  'hr': ['hrv', 'hr', 'croatian', 'hrvatski', 'hirvatca'],
  'bs': ['bos', 'bs', 'bosnian', 'bosanski', 'bosnakca'],
  'sq': ['sqi', 'alb', 'sq', 'albanian', 'shqip', 'arnavutca'],
  'mk': ['mkd', 'mac', 'mk', 'macedonian', 'makedonca'],
  'sl': ['slv', 'sl', 'slovenian', 'slovenski', 'slovence'],
  'sv': ['swe', 'sv', 'swedish', 'svenska', 'isvecce'],
  'da': ['dan', 'da', 'danish', 'dansk', 'danca'],
  'no': ['nor', 'nob', 'nno', 'no', 'nb', 'nn', 'norwegian', 'norsk'],
  'fi': ['fin', 'fi', 'finnish', 'suomi', 'fince'],
  'ar': ['ara', 'ar', 'arabic', 'arapca'],
  'fa': ['fas', 'per', 'fa', 'persian', 'farsi', 'farsca'],
  'ku': ['kur', 'kmr', 'ckb', 'ku', 'kurdish', 'kurdi', 'kurtce'],
  'az': ['aze', 'az', 'azerbaijani', 'azeri', 'azerice', 'azerbaycanca'],
  'he': ['heb', 'he', 'iw', 'hebrew', 'ibranice'],
  'hi': ['hin', 'hi', 'hindi', 'hintce'],
  'ur': ['urd', 'ur', 'urdu'],
  'ja': ['jpn', 'ja', 'japanese', 'japonca'],
  'zh': ['zho', 'chi', 'zh', 'chinese', 'mandarin', 'cince'],
  'ko': ['kor', 'ko', 'korean', 'korece'],
  'ka': ['kat', 'geo', 'ka', 'georgian', 'gurcuce'],
  'hy': ['hye', 'arm', 'hy', 'armenian', 'ermenice'],
};

/// Tags that mean "no language".
const Set<String> _undetermined = {'und', 'unk', 'unknown', 'mis', 'zxx', ''};

final Map<String, String> _aliasToCode = () {
  final map = <String, String>{};
  kLanguageAliases.forEach((code, aliases) {
    map[code] = code;
    for (final alias in aliases) {
      map.putIfAbsent(alias, () => code);
    }
  });
  return map;
}();

/// Lowercases (Turkish-aware) and folds diacritics: `Türkçe` → `turkce`,
/// `İngilizce` → `ingilizce`, `Français` → `francais`.
String foldLanguageText(String input) {
  const fold = <String, String>{
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'ç': 'c',
    'Ç': 'c',
    'ş': 's',
    'Ş': 's',
    'ğ': 'g',
    'Ğ': 'g',
    'ö': 'o',
    'Ö': 'o',
    'ü': 'u',
    'Ü': 'u',
    'â': 'a',
    'à': 'a',
    'á': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'ô': 'o',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ø': 'o',
    'û': 'u',
    'ú': 'u',
    'ù': 'u',
    'ñ': 'n',
    'č': 'c',
    'ć': 'c',
    'š': 's',
    'ž': 'z',
    'đ': 'd',
    'ł': 'l',
    'ř': 'r',
    'ě': 'e',
    'ý': 'y',
    'ș': 's',
    'ț': 't',
    'ă': 'a',
    '̇': '',
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(fold[ch] ?? ch.toLowerCase());
  }
  return buffer.toString();
}

/// Canonical ISO 639-1 code for a tag or language name, or null when it is
/// unknown or undetermined. `tr-TR` → `tr`, `ger` → `de`, `Türkçe` → `tr`.
String? canonicalLanguage(String? codeOrName) {
  if (codeOrName == null) return null;
  final folded = foldLanguageText(codeOrName.trim());
  if (_undetermined.contains(folded)) return null;
  final direct = _aliasToCode[folded];
  if (direct != null) return direct;
  // BCP 47 / locale forms: tr-TR, pt_BR, en-US.
  final primary = folded.split(RegExp(r'[-_]')).first;
  if (primary != folded) return _aliasToCode[primary];
  return null;
}

/// True for preferences meaning "no subtitles".
bool isDisabledLanguagePreference(String? preference) {
  final p = preference?.trim().toLowerCase();
  return p == kSubtitlesDisabled || p == 'off' || p == 'none' || p == 'no';
}

/// Values for mpv `alang` / `slang` (three-letter codes first, then the
/// two-letter code). Unknown preferences are passed through as-is.
List<String> mpvLanguageList(String? preference) {
  if (preference == null || preference.trim().isEmpty) return const [];
  if (isDisabledLanguagePreference(preference)) return const [];
  final code = canonicalLanguage(preference);
  if (code == null) return [preference.trim().toLowerCase()];
  final aliases = kLanguageAliases[code] ?? const <String>[];
  return [
    for (final a in aliases)
      if (a.length <= 3) a,
  ];
}

/// Whether a track's language tag (or, when the tag is missing, its title)
/// names [preferred].
bool languageMatches({
  String? trackLanguage,
  String? trackTitle,
  required String preferred,
}) {
  final want = canonicalLanguage(preferred);
  if (want == null) {
    final raw = preferred.trim().toLowerCase();
    return raw.isNotEmpty && trackLanguage?.trim().toLowerCase() == raw;
  }
  if (canonicalLanguage(trackLanguage) == want) return true;
  return titleNamesLanguage(trackTitle, want);
}

/// Whether a word of [title] is a code or name of [canonicalCode].
bool titleNamesLanguage(String? title, String canonicalCode) {
  if (title == null || title.trim().isEmpty) return false;
  final words = foldLanguageText(title)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty);
  for (final word in words) {
    // Two-letter words are too ambiguous in titles ("it", "no", "de")
    // unless the title is just that code.
    if (word.length < 3 && foldLanguageText(title.trim()) != word) continue;
    if (_aliasToCode[word] == canonicalCode) return true;
  }
  return false;
}

/// The first track in [preferred] language: tag matches win over title
/// matches. Null when nothing matches or there is no preference.
EngineTrack? pickPreferredTrack(List<EngineTrack> tracks, String? preferred) {
  if (preferred == null || preferred.trim().isEmpty) return null;
  if (isDisabledLanguagePreference(preferred)) return null;
  final want = canonicalLanguage(preferred);
  for (final t in tracks) {
    if (want != null && canonicalLanguage(t.language) == want) return t;
    if (want == null &&
        t.language?.trim().toLowerCase() == preferred.trim().toLowerCase()) {
      return t;
    }
  }
  if (want == null) return null;
  for (final t in tracks) {
    if (titleNamesLanguage(t.title, want)) return t;
  }
  return null;
}
