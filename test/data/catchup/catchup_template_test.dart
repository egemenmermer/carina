import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/catchup/catchup.dart';

// Programme 18:00–19:30 UTC on 2026-10-17, watched at 21:00 UTC.
final DateTime _start = DateTime.utc(2026, 10, 17, 18);
final DateTime _end = DateTime.utc(2026, 10, 17, 19, 30);
final DateTime _now = DateTime.utc(2026, 10, 17, 21);
const int _startEpoch = 1792260000;
const int _endEpoch = 1792265400;
const int _nowEpoch = 1792270800;
const Duration _plus3 = Duration(hours: 3);

String _x(
  String template, {
  DateTime? start,
  DateTime? end,
  DateTime? now,
  Duration serverOffset = Duration.zero,
  String? channelName,
}) => expandCatchupTemplate(
  template,
  startUtc: start ?? _start,
  endUtc: end ?? _end,
  nowUtc: now ?? _now,
  serverOffset: serverOffset,
  channelName: channelName,
);

void main() {
  test('fixture epochs are what the tests assume', () {
    expect(_start.millisecondsSinceEpoch ~/ 1000, _startEpoch);
    expect(_end.millisecondsSinceEpoch ~/ 1000, _endEpoch);
    expect(_now.millisecondsSinceEpoch ~/ 1000, _nowEpoch);
  });

  group('epoch placeholders', () {
    test('{utc} is the start', () => expect(_x('a={utc}'), 'a=$_startEpoch'));
    test('{start} is the start', () => expect(_x('{start}'), '$_startEpoch'));
    test(r'${start} is the start', () {
      expect(_x(r'?s=${start}'), '?s=$_startEpoch');
    });
    test('{utcend} is the end', () => expect(_x('{utcend}'), '$_endEpoch'));
    test('{end} is the end', () => expect(_x('{end}'), '$_endEpoch'));
    test(r'${end} is the end', () => expect(_x(r'${end}'), '$_endEpoch'));
    test('{lutc} is now', () => expect(_x('{lutc}'), '$_nowEpoch'));
    test(r'{now} and ${now} are now', () {
      expect(_x(r'{now}/${now}'), '$_nowEpoch/$_nowEpoch');
    });
    test('{timestamp} is now', () => expect(_x('{timestamp}'), '$_nowEpoch'));
    test(r'${timestamp} is now', () {
      expect(_x(r't=${timestamp}'), 't=$_nowEpoch');
    });

    test('epoch values ignore serverOffset', () {
      expect(
        _x('{utc}-{utcend}-{lutc}', serverOffset: _plus3),
        '$_startEpoch-$_endEpoch-$_nowEpoch',
      );
    });

    test('local DateTimes give the same epoch values', () {
      expect(
        expandCatchupTemplate(
          '{utc}-{utcend}-{lutc}',
          startUtc: _start.toLocal(),
          endUtc: _end.toLocal(),
          nowUtc: _now.toLocal(),
        ),
        '$_startEpoch-$_endEpoch-$_nowEpoch',
      );
    });
  });

  group('duration and offset placeholders', () {
    test('{duration} is in seconds', () => expect(_x('{duration}'), '5400'));
    test(r'${duration} is in seconds', () {
      expect(_x(r'${duration}'), '5400');
    });

    test('{duration:N} divides and truncates', () {
      expect(_x('{duration:60}'), '90');
      expect(_x('{duration:3600}'), '1');
      expect(_x('{duration:7}'), '771');
    });

    test('{duration:N} with a bad divisor stays untouched', () {
      expect(
        _x('{duration:0}|{duration:x}|{duration:}'),
        '{duration:0}|{duration:x}|{duration:}',
      );
    });

    test('a negative duration is clamped to 0', () {
      expect(
        _x(
          '{duration}/{duration:60}',
          end: _start.subtract(const Duration(minutes: 5)),
        ),
        '0/0',
      );
    });

    test('{offset:N} is (now - start) / N', () {
      expect(_x('{offset:1}'), '10800');
      expect(_x('{offset:60}'), '180');
      expect(_x('{offset:7}'), '1542');
    });

    test('{offset:N} is 0 for a programme that has not started', () {
      expect(
        _x('{offset:1}', now: _start.subtract(const Duration(hours: 1))),
        '0',
      );
    });

    test(r'${offset} and {offset} are in seconds', () {
      expect(_x(r'${offset}/{offset}'), '10800/10800');
    });
  });

  group('calendar placeholders', () {
    test('{Y} is the 4-digit start year', () => expect(_x('{Y}'), '2026'));
    test('{m} is the 2-digit start month', () => expect(_x('{m}'), '10'));
    test('{d} is the 2-digit start day', () => expect(_x('{d}'), '17'));
    test('{H} is the 2-digit start hour', () => expect(_x('{H}'), '18'));
    test('{M} is the 2-digit start minute', () {
      expect(_x('{M}', start: DateTime.utc(2026, 10, 17, 18, 45)), '45');
    });
    test('{S} is the 2-digit start second', () {
      expect(_x('{S}', start: DateTime.utc(2026, 10, 17, 18, 0, 9)), '09');
    });

    test('single-digit fields are zero-padded', () {
      expect(
        _x('{Y}-{m}-{d} {H}:{M}:{S}', start: DateTime.utc(2026, 3, 5, 7, 8, 9)),
        '2026-03-05 07:08:09',
      );
    });

    test('serverOffset +3h shifts the calendar fields', () {
      expect(
        _x('{Y}/{m}/{d}/{H}/{M}/{S}', serverOffset: _plus3),
        '2026/10/17/21/00/00',
      );
    });

    test('serverOffset +3h rolls over day, month and year', () {
      expect(
        _x(
          '{Y}-{m}-{d}:{H}-{M}',
          start: DateTime.utc(2026, 12, 31, 22, 30),
          serverOffset: _plus3,
        ),
        '2027-01-01:01-30',
      );
    });

    test('a negative serverOffset goes back a day', () {
      expect(
        _x(
          '{d} {H}',
          start: DateTime.utc(2026, 10, 17, 2),
          serverOffset: const Duration(hours: -5),
        ),
        '16 21',
      );
    });

    test('names are case-sensitive', () {
      final t = DateTime.utc(2026, 10, 17, 18, 45);
      expect(_x('{m}{M}', start: t), '1045');
      expect(_x('{UTC}{Utc}{y}{D}', start: t), '{UTC}{Utc}{y}{D}');
    });
  });

  group('format strings', () {
    test('{(b)YmdHMS} formats the start', () {
      expect(_x('{(b)YmdHMS}'), '20261017180000');
    });

    test('{(e)YmdHMS} formats the end', () {
      expect(_x('{(e)YmdHMS}'), '20261017193000');
    });

    test('{(b)Y-m-d:H-M} keeps separators; serverOffset applies', () {
      expect(_x('{(b)Y-m-d:H-M}'), '2026-10-17:18-00');
      expect(_x('{(b)Y-m-d:H-M}', serverOffset: _plus3), '2026-10-17:21-00');
      expect(_x('{(e)Y-m-d:H-M}', serverOffset: _plus3), '2026-10-17:22-30');
    });

    test(r'${(b)…} and ${(e)…} work too', () {
      expect(
        _x(r'/${(b)YmdHMS}/${(e)YmdHMS}/'),
        '/20261017180000/20261017193000/',
      );
    });

    test('any order and combination of fields', () {
      expect(_x('{(b)d.m.Y H:M}'), '17.10.2026 18:00');
      expect(_x('{(e)HMS}-{(b)Yd}'), '193000-202617');
      expect(_x('{(b)}'), '');
    });

    test('Java date patterns (OTT Navigator style)', () {
      expect(_x(r'${(b)yyyyMMddHHmmss}'), '20261017180000');
      expect(_x("{(e)yyyy-MM-dd'T'HH:mm:ss}"), '2026-10-17T19:30:00');
      expect(_x('{(b)yyMMdd}', serverOffset: _plus3), '261017');
      expect(_x("{(b)dd''MM}"), "17'10");
    });

    test('Kodi {name:FMT} forms', () {
      expect(_x('{utc:Y-m-d H:M:S}'), '2026-10-17 18:00:00');
      expect(_x('{start:YmdH}'), '2026101718');
      expect(_x('{utcend:H-M}'), '19-30');
      expect(_x('{end:H-M}'), '19-30');
      expect(_x('{lutc:H}|{now:H}|{timestamp:H}'), '21|21|21');
      expect(
        _x(r'${start:Y}|${end:H}|${now:H}|${timestamp:Y}'),
        '2026|19|21|2026',
      );
    });
  });

  group('other placeholders', () {
    test('{channel} is the URL-encoded channel name', () {
      expect(
        _x(r'/{channel}/${channel}', channelName: 'TRT 1 HD/ç'),
        '/TRT%201%20HD%2F%C3%A7/TRT%201%20HD%2F%C3%A7',
      );
      expect(_x('/{channel}'), '/{channel}');
    });

    test('unknown placeholders and stray braces are left untouched', () {
      expect(_x('{catchup-id}/{foo}/{}/{utc'), '{catchup-id}/{foo}/{}/{utc');
    });

    test('repeated placeholders are all replaced', () {
      expect(_x('{utc}{utc}{H}{H}'), '$_startEpoch${_startEpoch}1818');
    });

    test('a template without braces is returned unchanged', () {
      expect(_x('http://example.com/a.ts?x=1'), 'http://example.com/a.ts?x=1');
    });

    test('nowUtc defaults to the current time', () {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final value = int.parse(
        expandCatchupTemplate('{lutc}', startUtc: _start, endUtc: _end),
      );
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(value, inInclusiveRange(before, after));
    });
  });
}
