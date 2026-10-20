import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/xtream/json_utils.dart';

void main() {
  test('asInt', () {
    expect(asInt(1), 1);
    expect(asInt('1'), 1);
    expect(asInt(' 42 '), 42);
    expect(asInt(1.9), 1);
    expect(asInt('3.7'), 3);
    expect(asInt(true), 1);
    expect(asInt(false), 0);
    expect(asInt(''), isNull);
    expect(asInt('  '), isNull);
    expect(asInt(null), isNull);
    expect(asInt('abc'), isNull);
    expect(asInt('null'), isNull);
    expect(asInt(double.nan), isNull);
    expect(asInt(double.infinity), isNull);
    expect(asInt(const [1]), isNull);
    expect(asInt(const {'a': 1}), isNull);
  });

  test('asPositiveInt', () {
    expect(asPositiveInt('0'), isNull);
    expect(asPositiveInt(-5), isNull);
    expect(asPositiveInt('12'), 12);
  });

  test('asDouble', () {
    expect(asDouble(7), 7.0);
    expect(asDouble('7.5'), 7.5);
    expect(asDouble('7,5'), 7.5);
    expect(asDouble(' 8 '), 8.0);
    expect(asDouble('1,234.5'), isNull);
    expect(asDouble(''), isNull);
    expect(asDouble('N/A'), isNull);
    expect(asDouble(true), isNull);
    expect(asDouble('NaN'), isNull);
    expect(asDouble(null), isNull);
  });

  test('asString', () {
    expect(asString('  TRT 1 HD  '), 'TRT 1 HD');
    expect(asString(''), isNull);
    expect(asString('   '), isNull);
    expect(asString('null'), isNull);
    expect(asString('NULL'), isNull);
    expect(asString(null), isNull);
    expect(asString(12), '12');
    expect(asString(1.5), '1.5');
    expect(asString(false), isNull, reason: 'PHP false means no value');
    expect(asString(true), isNull);
    expect(asString(const []), isNull);
    expect(asString(const {'a': 'b'}), isNull);
  });

  test('asId', () {
    expect(asId(1001), '1001');
    expect(asId(1001.0), '1001');
    expect(asId(' 1001 '), '1001');
    expect(asId('abc'), 'abc');
    expect(asId(''), isNull);
    expect(asId(null), isNull);
    expect(asId(true), isNull);
    expect(asId(const [1]), isNull);
  });

  test('asBool', () {
    for (final v in [true, 1, 2, 1.0, '1', 'true', 'TRUE', ' yes ', 'on']) {
      expect(asBool(v), isTrue, reason: '$v');
    }
    for (final v in [false, 0, 0.0, '0', 'false', 'no', 'off']) {
      expect(asBool(v), isFalse, reason: '$v');
    }
    for (final v in [null, '', 'maybe', const [], const {}]) {
      expect(asBool(v), isNull, reason: '$v');
    }
  });

  test('asList', () {
    expect(asList([1, 2]), [1, 2]);
    expect(asList({'0': 'a', '1': 'b'}), ['a', 'b']);
    expect(asList(null), isEmpty);
    expect(asList('x'), isEmpty);
    expect(asList(1), isEmpty);
  });

  test('asMap', () {
    expect(asMap({'a': 1}), {'a': 1});
    expect(asMap({1: 'x'}), {'1': 'x'});
    expect(asMap(const []), isEmpty, reason: 'PHP empty array');
    expect(asMap(null), isEmpty);
    expect(asMap('x'), isEmpty);
  });

  test('asStringList', () {
    expect(asStringList(['ts', ' m3u8 ', '', null, 5]), ['ts', 'm3u8', '5']);
    expect(asStringList('ts, m3u8,,rtmp'), ['ts', 'm3u8', 'rtmp']);
    expect(asStringList('a,b', splitCommas: false), ['a,b']);
    expect(asStringList({'0': 'x'}), ['x']);
    expect(asStringList(null), isEmpty);
    expect(asStringList(''), isEmpty);
    expect(asStringList(7), ['7']);
  });

  test('asDateFromEpoch', () {
    final expected = DateTime.utc(2027, 3, 1);
    expect(asDateFromEpoch(1803859200), expected);
    expect(asDateFromEpoch('1803859200'), expected);
    expect(asDateFromEpoch(' 1803859200 '), expected);
    expect(asDateFromEpoch(1803859200.0), expected);
    expect(asDateFromEpoch(1803859200000), expected, reason: 'milliseconds');
    expect(asDateFromEpoch('1803859200000'), expected);
    expect(asDateFromEpoch(1803859200)!.isUtc, isTrue);
    expect(asDateFromEpoch('0'), isNull);
    expect(asDateFromEpoch(0), isNull);
    expect(asDateFromEpoch(-1), isNull);
    expect(asDateFromEpoch(''), isNull);
    expect(asDateFromEpoch(null), isNull);
    expect(asDateFromEpoch('soon'), isNull);
    expect(asDateFromEpoch(true), isNull);
    expect(asDateFromEpoch('99999999999999999999'), isNull);
    // A date string falls back to asDate.
    expect(asDateFromEpoch('2027-03-01 00:00:00'), expected);
  });

  test('asDate', () {
    expect(asDate('2008-01-20'), DateTime.utc(2008, 1, 20));
    expect(asDate(' 2008/01/20 '), DateTime.utc(2008, 1, 20));
    expect(asDate('2008-1-2'), DateTime.utc(2008, 1, 2));
    expect(
      asDate('2008-01-20 21:30:15'),
      DateTime.utc(2008, 1, 20, 21, 30, 15),
    );
    expect(asDate('2008-01-20T21:30'), DateTime.utc(2008, 1, 20, 21, 30));
    expect(asDate('20.01.2008'), DateTime.utc(2008, 1, 20));
    expect(asDate('20/01/2008'), DateTime.utc(2008, 1, 20));
    expect(asDate('01/20/2008'), DateTime.utc(2008, 1, 20));
    expect(asDate('2008'), DateTime.utc(2008));
    expect(asDate(2008), DateTime.utc(2008));
    expect(asDate('1200787200'), DateTime.utc(2008, 1, 20));
    expect(asDate('0000-00-00'), isNull);
    expect(asDate('2008-02-31'), isNull);
    expect(asDate('2008-13-01'), isNull);
    expect(asDate('2008-01-20 25:00:00'), isNull);
    expect(asDate(''), isNull);
    expect(asDate('unknown'), isNull);
    expect(asDate(null), isNull);
    expect(asDate(const {}), isNull);
  });

  test('asYear', () {
    expect(asYear(2008), 2008);
    expect(asYear('2008'), 2008);
    expect(asYear('2008-01-20'), 2008);
    expect(asYear('20.01.2008'), 2008);
    expect(asYear('Movie (1999)'), 1999);
    expect(asYear('1080p'), isNull);
    expect(asYear('12345'), isNull);
    expect(asYear(''), isNull);
    expect(asYear(99), isNull);
  });

  test('asDurationSecs', () {
    expect(asDurationSecs(6750), 6750);
    expect(asDurationSecs('6750'), 6750);
    expect(asDurationSecs('01:52:30'), 6750);
    expect(asDurationSecs('1:52'), 6720);
    expect(asDurationSecs('112 min'), 6720);
    expect(asDurationSecs('112 dk'), 6720);
    expect(asDurationSecs(''), isNull);
    expect(asDurationSecs('long'), isNull);
    expect(asDurationSecs(-5), isNull);
  });

  group('decodeMaybeBase64', () {
    test('decodes base64 UTF-8 text', () {
      expect(decodeMaybeBase64('QWvFn2FtIEhhYmVybGVyaQ=='), 'Akşam Haberleri');
      expect(
        decodeMaybeBase64('R8O8bsO8biDDtnpldGkgdmUgaGF2YSBkdXJ1bXUu'),
        'Günün özeti ve hava durumu.',
      );
      expect(decodeMaybeBase64('TmV3cw=='), 'News');
      expect(decodeMaybeBase64('SGFiZXJsZXI='), 'Haberler');
    });

    test('keeps plain text', () {
      for (final plain in [
        'News',
        'Kids',
        'Film',
        'TV',
        'Akşam Haberleri',
        'Evening News 20:00',
        'Haber',
        'Spor',
        'Live',
        '',
      ]) {
        expect(decodeMaybeBase64(plain), plain, reason: plain);
      }
      expect(decodeMaybeBase64(null), isNull);
    });

    test('tolerates surrounding whitespace and line breaks', () {
      expect(decodeMaybeBase64('  TmV3cw==\n'), 'News');
      expect(
        decodeMaybeBase64('QWvFn2FtIEhh\nYmVybGVyaQ=='),
        'Akşam Haberleri',
      );
    });

    test('decodes the URL-safe alphabet', () {
      expect(decodeMaybeBase64('SGVsbG8_IFdvcmxk'), 'Hello? World');
      expect(decodeMaybeBase64('U3BvciA-PiBNYcOnPw=='), 'Spor >> Maç?');
      expect(decodeMaybeBase64('SGVsbG8gV29ybGQ='), 'Hello World');
    });

    test('keeps base64-shaped text that does not decode to text', () {
      // "AAAA" decodes to three NUL bytes, "Kids" to "*']".
      expect(decodeMaybeBase64('AAAA'), 'AAAA');
      expect(decodeMaybeBase64('Kids'), 'Kids');
    });
  });
}
