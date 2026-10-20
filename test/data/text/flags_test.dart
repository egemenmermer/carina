import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/text/flags.dart';

void main() {
  const tr = '🇹🇷';

  // category name → (flag, label)
  const cases = <String, (String?, String)>{
    // Codes with explicit separators.
    'TR | Ulusal': (tr, 'Ulusal'),
    'TR: Spor': (tr, 'Spor'),
    'TR - Haber': (tr, 'Haber'),
    'TR.Belgesel': (tr, 'Belgesel'),
    'TR|Ulusal': (tr, 'Ulusal'),
    'TR || Ulusal': (tr, 'Ulusal'),
    'tr | ulusal': (tr, 'ulusal'),
    'TR ★ Ulusal': (tr, 'Ulusal'),
    // Wrapped or decorated codes.
    '|TR| Haber': (tr, 'Haber'),
    '[UK] Movies': ('🇬🇧', 'Movies'),
    '(DE) Sport': ('🇩🇪', 'Sport'),
    '★ TR ★ Ulusal': (tr, 'Ulusal'),
    // Plain space after a two-letter code written in capitals.
    'TR Ulusal': (tr, 'Ulusal'),
    'DE SKY SPORT': ('🇩🇪', 'SKY SPORT'),
    // UK is GB; other codes.
    'UK: Entertainment': ('🇬🇧', 'Entertainment'),
    'GB | News': ('🇬🇧', 'News'),
    'IT | RAI': ('🇮🇹', 'RAI'),
    'FR: Canal+': ('🇫🇷', 'Canal+'),
    'NL | Ziggo': ('🇳🇱', 'Ziggo'),
    'US | NEWS': ('🇺🇸', 'NEWS'),
    'AL | Shqip': ('🇦🇱', 'Shqip'),
    'AZ: Xəbər': ('🇦🇿', 'Xəbər'),
    'SA | MBC': ('🇸🇦', 'MBC'),
    'AE | Abu Dhabi': ('🇦🇪', 'Abu Dhabi'),
    'BR: Globo': ('🇧🇷', 'Globo'),
    'USA | Entertainment': ('🇺🇸', 'Entertainment'),
    'UAE: News': ('🇦🇪', 'News'),
    'KSA | Sports': ('🇸🇦', 'Sports'),
    // Country names (English, Turkish, local), any case, diacritics.
    'Türkiye': (tr, 'Türkiye'),
    'TÜRKİYE | ULUSAL': (tr, 'ULUSAL'),
    'Turkey Documentaries': (tr, 'Documentaries'),
    'Italia: Sport': ('🇮🇹', 'Sport'),
    'Italy': ('🇮🇹', 'Italy'),
    'Almanya - Spor': ('🇩🇪', 'Spor'),
    'Germany': ('🇩🇪', 'Germany'),
    'United Kingdom | Sports': ('🇬🇧', 'Sports'),
    'İngiltere: Futbol': ('🇬🇧', 'Futbol'),
    'Bosnia-Herzegovina | TV': ('🇧🇦', 'TV'),
    'ABD Filmleri': ('🇺🇸', 'Filmleri'),
    'Argentina | Futbol': ('🇦🇷', 'Futbol'),
    'ARG: Telefe': ('🇦🇷', 'Telefe'),
    // A flag emoji already present is kept (and a repeated code consumed).
    '🇹🇷 Ulusal': (tr, 'Ulusal'),
    '🇹🇷 TR | Ulusal': (tr, 'Ulusal'),
    // Alone: the code itself is the label.
    'TR': (tr, 'TR'),
    // No flag.
    'AR | MBC': (null, 'AR | MBC'), // Arabic, not Argentina
    'AR: OSN': (null, 'AR: OSN'),
    'EN | Movies': (null, 'EN | Movies'),
    'AL JAZEERA': (null, 'AL JAZEERA'), // word-like code needs a separator
    'IN FOCUS': (null, 'IN FOCUS'),
    'IN | Hindi': ('🇮🇳', 'Hindi'),
    'USA Network': (null, 'USA Network'), // three letters need a separator
    'Tr Ulusal': (null, 'Tr Ulusal'), // lowercase code with a plain space
    'TRT Haber': (null, 'TRT Haber'),
    'TR1 Haber': (null, 'TR1 Haber'),
    'Turkish Movies': (null, 'Turkish Movies'),
    'Ulusal | TR': (null, 'Ulusal | TR'),
    'Spor': (null, 'Spor'),
    '  Belgesel  ': (null, 'Belgesel'),
    'VIP | Sports': (null, 'VIP | Sports'),
    '4K | UHD': (null, '4K | UHD'),
    '[TR Haber]': (null, '[TR Haber]'),
    '': (null, ''),
  };

  cases.forEach((name, expected) {
    test('"$name" → ${expected.$1} "${expected.$2}"', () {
      final parsed = parseCategoryFlag(name);
      expect(parsed.flag, expected.$1);
      expect(parsed.label, expected.$2);
      expect(flagForCategory(name), expected.$1);
    });
  });

  test('flagged builds the pill label', () {
    expect(flagged('TR | Ulusal'), '🇹🇷 Ulusal');
    expect(flagged('|TR| Haber'), '🇹🇷 Haber');
    expect(flagged('Türkiye'), '🇹🇷 Türkiye');
    expect(flagged('Spor'), 'Spor');
    expect(flagged('AR | MBC'), 'AR | MBC');
    expect(flagged('🇹🇷'), '🇹🇷');
  });

  test('flagEmoji', () {
    expect(flagEmoji('TR'), '🇹🇷');
    expect(flagEmoji('gb'), '🇬🇧');
    expect(flagEmoji('T'), isNull);
    expect(flagEmoji('T1'), isNull);
  });

  group('stripCountryPrefix (channel names)', () {
    const cases = {
      'TR: Show TV': 'Show TV',
      'TR | Show TV': 'Show TV',
      '|TR| Show TV': 'Show TV',
      '[TR] Show TV': 'Show TV',
      'TR - Show TV': 'Show TV',
      'TR.Show TV': 'Show TV',
      'TR Show TV': 'Show TV',
      'AR: MBC 1': 'MBC 1',
      'EXYU: Pink': 'Pink',
      'Türkiye: Show TV': 'Show TV',
      'Italia 1': 'Italia 1',
      'AL JAZEERA': 'AL JAZEERA',
      'USA Network': 'USA Network',
      'TRT 1': 'TRT 1',
      'TR:': 'TR:',
      '|TR| TR: Show TV': 'Show TV',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(stripCountryPrefix(input), expected);
      });
    });
  });

  test('has at least 15 category cases', () {
    expect(cases.length, greaterThanOrEqualTo(15));
  });
}
