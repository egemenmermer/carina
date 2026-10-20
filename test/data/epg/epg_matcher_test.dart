import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/epg/epg_matcher.dart';

void main() {
  final matcher = EpgMatcher(const [
    EpgChannelRef('ShowTV.tr', ['Show TV', 'SHOW']),
    EpgChannelRef('TRT1.tr', ['TRT 1', 'TRT1 HD']),
    EpgChannelRef('trthaber.tr', ['TRT Haber']),
    EpgChannelRef('KanalD.tr', ['Kanal D']),
    // Same normalized name as Kanal D: the first declared wins.
    EpgChannelRef('KanalD.backup', ['KANAL D HD']),
    EpgChannelRef('Atv.tr', ['atv', 'A TV']),
    EpgChannelRef('', ['Ignored without id']),
    EpgChannelRef('Fox.tr', []),
  ]);

  EpgMatchResult m({String? custom, String? tvgId, required String name}) =>
      matcher.matchDetailed(customEpgId: custom, tvgId: tvgId, name: name);

  test('TR: Show TV HD matches ShowTV.tr through its display name', () {
    expect(
      m(name: 'TR: Show TV HD'),
      const EpgMatchResult('ShowTV.tr', EpgMatchMethod.normalizedName),
    );
    expect(matcher.match(name: 'TR: Show TV HD'), 'ShowTV.tr');
  });

  group('order: custom > exact id > case-insensitive id > name > none', () {
    test('a custom assignment wins over everything', () {
      expect(
        m(custom: 'TRT1.tr', tvgId: 'ShowTV.tr', name: 'Show TV'),
        const EpgMatchResult('TRT1.tr', EpgMatchMethod.custom),
      );
    });

    test('a custom id is resolved to the declared spelling', () {
      expect(
        m(custom: ' trt1.TR ', name: 'x'),
        const EpgMatchResult('TRT1.tr', EpgMatchMethod.custom),
      );
    });

    test('a custom id unknown to this XMLTV is still the user\'s choice', () {
      expect(
        m(custom: 'Gone.tr', tvgId: 'ShowTV.tr', name: 'Show TV'),
        const EpgMatchResult('Gone.tr', EpgMatchMethod.custom),
      );
    });

    test('an empty custom id is ignored', () {
      expect(
        m(custom: '  ', tvgId: 'ShowTV.tr', name: 'x'),
        const EpgMatchResult('ShowTV.tr', EpgMatchMethod.exactId),
      );
    });

    test('the exact id beats a name that points elsewhere', () {
      expect(
        m(tvgId: 'TRT1.tr', name: 'Show TV'),
        const EpgMatchResult('TRT1.tr', EpgMatchMethod.exactId),
      );
    });

    test('a case-insensitive id comes next', () {
      expect(
        m(tvgId: 'showtv.TR', name: 'TRT 1'),
        const EpgMatchResult('ShowTV.tr', EpgMatchMethod.caseInsensitiveId),
      );
      expect(
        m(tvgId: ' ShowTV.tr ', name: 'x'),
        const EpgMatchResult('ShowTV.tr', EpgMatchMethod.caseInsensitiveId),
      );
    });

    test('an unknown id falls back to the name', () {
      expect(
        m(tvgId: 'unknown.id', name: '|TR| TRT 1 FHD'),
        const EpgMatchResult('TRT1.tr', EpgMatchMethod.normalizedName),
      );
    });

    test('nothing matches', () {
      expect(m(tvgId: 'unknown.id', name: 'Kanal 7'), EpgMatchResult.noMatch);
      expect(matcher.match(name: 'Kanal 7'), isNull);
    });
  });

  group('name matching', () {
    const cases = {
      'Show TV': 'ShowTV.tr',
      'SHOW TV FHD': 'ShowTV.tr',
      'ShowTV': 'ShowTV.tr',
      'Show-TV (HD)': 'ShowTV.tr',
      '[TR] Show TV': 'ShowTV.tr',
      'TR | SHOW': 'ShowTV.tr', // secondary display name
      'TRT1': 'TRT1.tr',
      'TRT 1 ᴴᴰ': 'TRT1.tr',
      'TR - TRT Haber HD': 'trthaber.tr',
      'Kanal D HD': 'KanalD.tr', // first declared wins the tie
      'ATV': 'Atv.tr',
      'A TV': 'Atv.tr',
    };
    cases.forEach((name, id) {
      test('$name → $id', () {
        expect(
          m(name: name),
          EpgMatchResult(id, EpgMatchMethod.normalizedName),
        );
      });
    });

    test('names that normalize to nothing never match', () {
      expect(m(name: 'HD'), EpgMatchResult.noMatch);
      expect(m(name: '★ ★'), EpgMatchResult.noMatch);
      expect(m(name: ''), EpgMatchResult.noMatch);
    });

    test('channels without an id are ignored; ids without names still match '
        'by id', () {
      expect(m(name: 'Ignored without id'), EpgMatchResult.noMatch);
      expect(
        m(tvgId: 'Fox.tr', name: 'Fox'),
        const EpgMatchResult('Fox.tr', EpgMatchMethod.exactId),
      );
      expect(matcher.channelCount, 7);
    });
  });

  test('ties between ids differing only in case go to the first declared', () {
    final tie = EpgMatcher(const [
      EpgChannelRef('abc', ['One']),
      EpgChannelRef('ABC', ['Two']),
    ]);
    expect(tie.match(tvgId: 'ABC', name: ''), 'ABC'); // exact
    expect(tie.match(tvgId: 'Abc', name: ''), 'abc'); // first declared
  });

  test('builds once and matches 50k channels quickly', () {
    final refs = [
      for (var i = 0; i < 20000; i++)
        EpgChannelRef('ch$i.tr', ['Kanal $i', 'K$i HD']),
    ];
    final sw = Stopwatch()..start();
    final big = EpgMatcher(refs);
    var matched = 0;
    for (var i = 0; i < 50000; i++) {
      if (big.match(
            tvgId: i.isEven ? 'CH$i.TR' : null,
            name: 'TR: Kanal $i FHD',
          ) !=
          null) {
        matched++;
      }
    }
    sw.stop();
    expect(matched, 20000);
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });
}
