import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/xmltv/xmltv_time.dart';

void main() {
  DateTime utc(int y, int mo, int d, [int h = 0, int mi = 0, int s = 0]) =>
      DateTime.utc(y, mo, d, h, mi, s);

  group('parseXmltvTime', () {
    const valid = <String, List<int>>{
      // Offsets.
      '20261017120000 +0300': [2026, 10, 17, 9, 0, 0],
      '20261017120000 -0500': [2026, 10, 17, 17, 0, 0],
      '20261017120000 +0000': [2026, 10, 17, 12, 0, 0],
      '20261017120000+0300': [2026, 10, 17, 9, 0, 0],
      '20261017120000 +03:00': [2026, 10, 17, 9, 0, 0],
      '20261017120000 -03:30': [2026, 10, 17, 15, 30, 0],
      '20261017120000 +03': [2026, 10, 17, 9, 0, 0],
      '20261017120000 +0545': [2026, 10, 17, 6, 15, 0],
      // No offset means UTC.
      '20261017120000': [2026, 10, 17, 12, 0, 0],
      '20261017123456': [2026, 10, 17, 12, 34, 56],
      // Short forms.
      '202610171200': [2026, 10, 17, 12, 0, 0],
      '202610171200 +0100': [2026, 10, 17, 11, 0, 0],
      '2026101712': [2026, 10, 17, 12, 0, 0],
      '20261017': [2026, 10, 17, 0, 0, 0],
      '202610': [2026, 10, 1, 0, 0, 0],
      '2026': [2026, 1, 1, 0, 0, 0],
      // Zone names, fractions, whitespace, midnight as 24h.
      '20261017120000 Z': [2026, 10, 17, 12, 0, 0],
      '20261017120000 UTC': [2026, 10, 17, 12, 0, 0],
      '20261017120000 GMT': [2026, 10, 17, 12, 0, 0],
      '20261017120000 BST': [2026, 10, 17, 11, 0, 0],
      '20261017120000 TRT': [2026, 10, 17, 9, 0, 0],
      '20261017120000 GMT+3': [2026, 10, 17, 9, 0, 0],
      '20261017120000 XYZ': [2026, 10, 17, 12, 0, 0],
      '20261017120000.000 +0300': [2026, 10, 17, 9, 0, 0],
      '  20261017120000   +0300  ': [2026, 10, 17, 9, 0, 0],
      '20261017240000': [2026, 10, 18, 0, 0, 0],
      // Calendar edges: leap day, offset crossing midnight and the year.
      '20240229120000 +0000': [2024, 2, 29, 12, 0, 0],
      '20231231233000 -0100': [2024, 1, 1, 0, 30, 0],
      '20260101013000 +0300': [2025, 12, 31, 22, 30, 0],
    };
    valid.forEach((input, parts) {
      test('"$input"', () {
        final expected = utc(
          parts[0],
          parts[1],
          parts[2],
          parts[3],
          parts[4],
          parts[5],
        );
        final parsed = parseXmltvTime(input);
        expect(parsed, expected);
        expect(parsed.isUtc, isTrue);
        expect(xmltvTimeToEpochMs(input), expected.millisecondsSinceEpoch);
      });
    });

    const invalid = [
      '',
      '   ',
      'abc',
      '2026101',
      '202610171',
      '20261317120000',
      '20261000120000',
      '20261032120000',
      '20261017250000',
      '20261017126000',
      '20261017120000 +2500',
      '20261017120000 +0360',
      '20261017120000 +03x',
      '20261017120000 +0300 extra',
      '20261017120000 :',
      '2026-10-17T12:00:00Z',
      '202610171200000',
    ];
    for (final input in invalid) {
      test('rejects "$input"', () {
        expect(xmltvTimeToEpochMs(input), isNull);
        expect(() => parseXmltvTime(input), throwsFormatException);
      });
    }

    test('round-trips random times and offsets', () {
      final random = Random(42);
      String two(int v) => v.toString().padLeft(2, '0');
      for (var i = 0; i < 2000; i++) {
        final local = DateTime.utc(
          1990 + random.nextInt(60),
          1 + random.nextInt(12),
          1 + random.nextInt(28),
          random.nextInt(24),
          random.nextInt(60),
          random.nextInt(60),
        );
        final offsetMinutes =
            (random.nextInt(27) - 12) * 60 +
            (random.nextBool() ? 30 : 0) * (random.nextBool() ? 1 : 0);
        final sign = offsetMinutes < 0 ? '-' : '+';
        final abs = offsetMinutes.abs();
        final text =
            '${local.year}${two(local.month)}${two(local.day)}'
            '${two(local.hour)}${two(local.minute)}${two(local.second)} '
            '$sign${two(abs ~/ 60)}${two(abs % 60)}';
        expect(
          parseXmltvTime(text),
          local.subtract(Duration(minutes: offsetMinutes)),
          reason: text,
        );
      }
    });
  });
}
