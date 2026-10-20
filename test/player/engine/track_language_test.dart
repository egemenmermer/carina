import 'package:flutter_test/flutter_test.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/engine/track_language.dart';

EngineTrack _audio(String id, {String? lang, String? title, String? codec}) =>
    EngineTrack(
      id: id,
      kind: EngineTrackKind.audio,
      language: lang,
      title: title,
      codec: codec,
    );

void main() {
  group('canonicalLanguage', () {
    test('codes in every form', () {
      expect(canonicalLanguage('tur'), 'tr');
      expect(canonicalLanguage('TR'), 'tr');
      expect(canonicalLanguage('trk'), 'tr');
      expect(canonicalLanguage('tr-TR'), 'tr');
      expect(canonicalLanguage('tr_TR'), 'tr');
      expect(canonicalLanguage('eng'), 'en');
      expect(canonicalLanguage('en-US'), 'en');
      expect(canonicalLanguage('ger'), 'de');
      expect(canonicalLanguage('deu'), 'de');
      expect(canonicalLanguage('fre'), 'fr');
      expect(canonicalLanguage('pt-BR'), 'pt');
      expect(canonicalLanguage('gre'), 'el');
    });

    test('names in English and native/Turkish spellings', () {
      expect(canonicalLanguage('Turkish'), 'tr');
      expect(canonicalLanguage('Türkçe'), 'tr');
      expect(canonicalLanguage('TÜRKÇE'), 'tr');
      expect(canonicalLanguage('English'), 'en');
      expect(canonicalLanguage('İngilizce'), 'en');
      expect(canonicalLanguage('INGILIZCE'), 'en');
      expect(canonicalLanguage('Deutsch'), 'de');
      expect(canonicalLanguage('Français'), 'fr');
      expect(canonicalLanguage('Español'), 'es');
    });

    test('undetermined and unknown', () {
      expect(canonicalLanguage(null), isNull);
      expect(canonicalLanguage(''), isNull);
      expect(canonicalLanguage('und'), isNull);
      expect(canonicalLanguage('unknown'), isNull);
      expect(canonicalLanguage('xx'), isNull);
    });
  });

  test('foldLanguageText', () {
    expect(foldLanguageText('Türkçe'), 'turkce');
    expect(foldLanguageText('İNGİLİZCE'), 'ingilizce');
    expect(foldLanguageText('Işık'), 'isik');
  });

  group('languageMatches', () {
    test('tag match', () {
      expect(languageMatches(trackLanguage: 'tur', preferred: 'tr'), isTrue);
      expect(languageMatches(trackLanguage: 'tr', preferred: 'tur'), isTrue);
      expect(languageMatches(trackLanguage: 'eng', preferred: 'tr'), isFalse);
    });

    test('title match when the tag is missing', () {
      expect(
        languageMatches(trackTitle: 'Türkçe Dublaj', preferred: 'tr'),
        isTrue,
      );
      expect(
        languageMatches(trackTitle: 'English 5.1', preferred: 'en'),
        isTrue,
      );
      expect(languageMatches(trackTitle: 'TR', preferred: 'tr'), isTrue);
    });

    test('two-letter words inside titles are ignored', () {
      // "it" is a word, not Italian.
      expect(
        languageMatches(trackTitle: 'Make it louder', preferred: 'it'),
        isFalse,
      );
    });

    test('unknown preferences compare raw tags', () {
      expect(languageMatches(trackLanguage: 'qaa', preferred: 'QAA'), isTrue);
      expect(languageMatches(trackLanguage: 'eng', preferred: 'qaa'), isFalse);
    });
  });

  group('pickPreferredTrack', () {
    final tracks = [
      _audio('1', lang: 'eng', title: 'English', codec: 'aac'),
      _audio('2', lang: 'tur', title: 'Türkçe', codec: 'ac3'),
    ];

    test('picks by tag', () {
      expect(pickPreferredTrack(tracks, 'tr')?.id, '2');
      expect(pickPreferredTrack(tracks, 'Turkish')?.id, '2');
      expect(pickPreferredTrack(tracks, 'en')?.id, '1');
      expect(pickPreferredTrack(tracks, 'eng')?.id, '1');
    });

    test('no match or no preference keeps the default', () {
      expect(pickPreferredTrack(tracks, 'de'), isNull);
      expect(pickPreferredTrack(tracks, null), isNull);
      expect(pickPreferredTrack(tracks, ''), isNull);
      expect(pickPreferredTrack(tracks, kSubtitlesDisabled), isNull);
    });

    test('tag matches win over title matches', () {
      final mixed = [
        _audio('1', title: 'Turkish commentary', lang: 'eng'),
        _audio('2', lang: 'tur'),
      ];
      expect(pickPreferredTrack(mixed, 'tr')?.id, '2');
    });

    test('falls back to titles', () {
      final untagged = [
        _audio('1', title: 'Original'),
        _audio('2', title: 'Türkçe'),
      ];
      expect(pickPreferredTrack(untagged, 'tr')?.id, '2');
    });
  });

  group('mpvLanguageList and disabled values', () {
    test('lists', () {
      expect(mpvLanguageList('tr'), ['tur', 'tr', 'trk']);
      expect(mpvLanguageList('Türkçe'), ['tur', 'tr', 'trk']);
      expect(mpvLanguageList('en'), ['eng', 'en']);
      expect(mpvLanguageList('de'), ['deu', 'ger', 'de']);
      expect(mpvLanguageList(null), isEmpty);
      expect(mpvLanguageList('disabled'), isEmpty);
      expect(mpvLanguageList('qaa'), ['qaa']);
    });

    test('disabled preference values', () {
      for (final v in ['disabled', 'off', 'none', 'No', ' OFF ']) {
        expect(isDisabledLanguagePreference(v), isTrue, reason: v);
      }
      expect(isDisabledLanguagePreference('tr'), isFalse);
      expect(isDisabledLanguagePreference(null), isFalse);
      expect(
        const EngineOptions(preferredSubtitleLanguage: kSubtitlesDisabled)
            .subtitlesDisabled,
        isTrue,
      );
      expect(const EngineOptions().subtitlesDisabled, isFalse);
    });
  });
}
