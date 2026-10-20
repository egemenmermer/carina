/// Generated programme guide: XMLTV (streamed), `get_short_epg` and
/// `get_simple_data_table`.
///
/// Schedules are generated per guide channel and per local calendar day from
/// a fixed seed, so the same programme has the same title and times no
/// matter which window or endpoint asks for it. The XMLTV window is
/// now −7 days … now +7 days, anchored to the current hour.
library;

import 'dart:async';
import 'dart:convert';

import 'catalog.dart';
import 'rng.dart';
import 'text_pools.dart';

const int _minuteMs = 60000;
const int _dayMs = 86400000;

/// One programme of the generated guide.
final class EpgProgramme {
  const EpgProgramme({
    required this.channel,
    required this.day,
    required this.startMinute,
    required this.lengthMinutes,
    required this.title,
    required this.category,
    required this.tier,
    this.subTitle,
    this.description,
    this.season,
    this.episode,
    this.iconPath,
    this.rating,
  });

  final MockEpgChannel channel;

  /// Local calendar day (days since 1970-01-01 in the channel's offset).
  final int day;

  /// Minutes after local midnight.
  final int startMinute;
  final int lengthMinutes;
  final String title;
  final String category;

  /// 0 = title only, 1 = + description and category, 2 = every field.
  final int tier;
  final String? subTitle;
  final String? description;

  /// 1-based season / episode for episodic programmes.
  final int? season;
  final int? episode;
  final String? iconPath;
  final String? rating;

  int get startMs =>
      day * _dayMs +
      startMinute * _minuteMs -
      channel.utcOffsetMinutes * _minuteMs;
  int get stopMs => startMs + lengthMinutes * _minuteMs;
  DateTime get start =>
      DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true);
  DateTime get stop => DateTime.fromMillisecondsSinceEpoch(stopMs, isUtc: true);

  /// Stable programme id (used by the Xtream EPG endpoints).
  int get id => mixHash(channel.seed, startMs ~/ _minuteMs) & 0x7FFFFFFF;
}

/// Lengths (minutes) and weights per channel genre.
const _lengths = <String, (List<int>, List<int>)>{
  'news': ([15, 30, 45, 60, 90, 120], [10, 40, 10, 30, 5, 5]),
  'general': ([30, 45, 60, 90, 105, 120], [15, 15, 20, 20, 10, 20]),
  'sports': ([30, 45, 60, 90, 105, 120], [15, 10, 15, 25, 15, 20]),
  'docs': ([30, 45, 60, 90], [20, 30, 40, 10]),
  'kids': ([15, 20, 25, 30, 45], [30, 20, 20, 20, 10]),
  'movies': ([90, 105, 120], [30, 30, 40]),
  'music': ([30, 60, 120], [30, 50, 20]),
  'local': ([30, 45, 60, 90, 120], [30, 20, 30, 10, 10]),
};

const _jitter = <int>[-5, 0, 0, 0, 5, 10];

const _anchoredNews = <String, Map<int, String>>{
  'tr': {
    7: 'Sabah Haberleri',
    12: 'Gün Ortası',
    19: 'Ana Haber',
    23: 'Gece Haberleri',
  },
  'en': {6: 'Breakfast News', 18: 'The News at Six', 22: 'Newsnight'},
  'it': {13: 'Telegiornale', 20: 'TG Sera'},
  'de': {20: 'Nachrichten am Abend'},
};

const _ratings = <String, (String, List<String>)>{
  'tr': ('RTÜK', ['Genel İzleyici', '7+', '13+', '18+']),
  'en': ('UK', ['U', 'PG', '12', '15', '18']),
  'it': ('IT', ['T', 'VM14', 'VM18']),
  'de': ('FSK', ['0', '6', '12', '16', '18']),
};

const _subTitleLive = <String, String>{
  'tr': 'Canlı Yayın',
  'en': 'Live',
  'it': 'In diretta',
  'de': 'Live',
};

/// Deterministic schedule generator.
final class EpgGenerator {
  /// [rich] controls how many programmes carry descriptions, episode
  /// numbers, icons and ratings (the large guide is leaner to stay near
  /// 150 MB for a million programmes).
  EpgGenerator({required this.rich});

  final bool rich;

  /// Calls [emit] for every programme of [channel] that overlaps
  /// `[fromMs, toMs)` (UTC epoch milliseconds), in start order.
  void forEach(
    MockEpgChannel channel,
    int fromMs,
    int toMs,
    void Function(EpgProgramme p) emit,
  ) {
    final offsetMs = channel.utcOffsetMinutes * _minuteMs;
    final firstDay = (fromMs + offsetMs) ~/ _dayMs;
    final lastDay = (toMs - 1 + offsetMs) ~/ _dayMs;
    for (var day = firstDay; day <= lastDay; day++) {
      _day(channel, day, (p) {
        if (p.stopMs > fromMs && p.startMs < toMs) emit(p);
      });
    }
  }

  /// Programmes of [channel] that overlap `[from, to)`.
  List<EpgProgramme> programmes(
    MockEpgChannel channel,
    DateTime from,
    DateTime to,
  ) {
    final out = <EpgProgramme>[];
    forEach(
      channel,
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
      out.add,
    );
    return out;
  }

  void _day(MockEpgChannel ch, int day, void Function(EpgProgramme p) emit) {
    final r = MockRandom(mixHash(ch.seed, day));
    final lang = ch.lang;
    final titles = programmeTitles[lang] ?? programmeTitles['en']!;
    final lengths = _lengths[ch.genre] ?? _lengths['general']!;
    var minute = 0;
    while (minute < 1440) {
      final remaining = 1440 - minute;
      final jitter = r.pick<int>(_jitter);
      var len = r.weighted<int>(lengths.$1, lengths.$2) + jitter;
      if (len < 15) len = 15;
      if (len > 120) len = 120;
      if (len >= remaining) {
        len = remaining;
      } else if (remaining - len < 15) {
        len = remaining <= 120 ? remaining : remaining - 15;
      }
      final hour = minute ~/ 60;
      var kind = ch.genre;
      String title;
      int? season;
      int? episode;
      final newsTimes = ch.genre == 'news' ? _anchoredNews[lang] : null;
      final anchored = newsTimes == null ? null : newsTimes[hour];
      if (anchored != null && minute % 60 == 0) {
        title = anchored;
      } else if (ch.genre == 'general' || ch.genre == 'local') {
        final prime = hour >= 20 && hour < 23;
        final late = hour >= 23 || hour < 2;
        if (ch.genre == 'general' &&
            (prime ? r.chance(0.65) : r.chance(0.25))) {
          kind = 'series';
          final list = titles['series']!;
          final index = r.nextInt(list.length);
          title = list[index];
          season = 1 + ((day ~/ 90) + index) % 4;
          episode = 1 + (day + index * 7) % 90;
        } else if (ch.genre == 'general' && late && r.chance(0.5)) {
          kind = 'movies';
          title = _fill(r.pick(titles['movies']!), r, lang);
        } else if (ch.genre == 'general' && hour >= 12) {
          title = r.pick(_afternoonTitles(lang));
        } else {
          title = r.pick(titles[ch.genre == 'local' ? 'local' : 'general']!);
        }
      } else if (ch.genre == 'sports' && r.chance(0.45)) {
        title = _fill(r.pick(_matchTitles(lang)), r, lang);
      } else if (ch.genre == 'movies') {
        title = _fill(r.pick(titles['movies']!), r, lang);
      } else {
        final list = titles[ch.genre] ?? titles['general']!;
        title = _fill(r.pick(list), r, lang);
      }

      final roll = r.nextDouble();
      final tier = rich
          ? (roll < 0.35 ? 0 : (roll < 0.75 ? 1 : 2))
          : (roll < 0.82 ? 0 : (roll < 0.95 ? 1 : 2));
      String? subTitle;
      String? description;
      String? icon;
      String? rating;
      if (tier >= 1) {
        description = r.pick(
          programmeDescriptions[lang] ?? programmeDescriptions['en']!,
        );
      }
      if (tier == 2) {
        if (season != null) {
          subTitle = '${episodeWord[lang] ?? 'Episode'} $episode';
        } else if (ch.genre == 'sports' &&
            (title.contains(' - ') || title.contains(' v '))) {
          subTitle = _subTitleLive[lang];
        }
        icon = MockMedia.stillPath(mixHash(ch.seed, day, minute));
        final (_, values) = _ratings[lang] ?? _ratings['en']!;
        rating = r.pick(values);
      } else {
        season = tier == 1 ? season : null;
        episode = tier == 1 ? episode : null;
      }
      final category =
          (programmeCategories[lang] ?? programmeCategories['en']!)[kind] ??
          programmeCategories['en']!['general']!;
      emit(
        EpgProgramme(
          channel: ch,
          day: day,
          startMinute: minute,
          lengthMinutes: len,
          title: title,
          category: category,
          tier: tier,
          subTitle: subTitle,
          description: description,
          season: season,
          episode: episode,
          iconPath: icon,
          rating: rating,
        ),
      );
      minute += len;
    }
  }

  static final _afternoonCache = <String, List<String>>{};

  /// General titles without morning shows ("Sabah …", "Morning …").
  static List<String> _afternoonTitles(String lang) =>
      _afternoonCache.putIfAbsent(lang, () {
        final all =
            (programmeTitles[lang] ?? programmeTitles['en']!)['general']!;
        return [
          for (final t in all)
            if (!t.startsWith('Sabah') &&
                !t.startsWith('Morning') &&
                !t.contains('Mattino'))
              t,
        ];
      });

  static final _matchTitleCache = <String, List<String>>{};

  static List<String> _matchTitles(String lang) => _matchTitleCache.putIfAbsent(
    lang,
    () {
      final all = (programmeTitles[lang] ?? programmeTitles['en']!)['sports']!;
      return [
        for (final t in all)
          if (t.contains('{A}')) t,
      ];
    },
  );

  static String _fill(String template, MockRandom r, String lang) {
    if (!template.contains('{')) return template;
    var out = template;
    if (out.contains('{A}')) {
      final teams = teamNames[lang] ?? teamNames['en']!;
      final a = r.nextInt(teams.length);
      var b = r.nextInt(teams.length - 1);
      if (b >= a) b++;
      out = out.replaceAll('{A}', teams[a]).replaceAll('{B}', teams[b]);
    }
    if (out.contains('{M}')) {
      final movies = switch (lang) {
        'tr' => trMovieTitles,
        'it' => itMovieTitles,
        'de' => deMovieTitles,
        _ => enMovieTitles,
      };
      out = out.replaceAll('{M}', r.pick(movies));
    }
    return out;
  }
}

/// The current hour (UTC), the anchor of the guide window.
DateTime epgAnchor(DateTime now) {
  final u = now.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour);
}

// ---------------------------------------------------------------------------
// XMLTV
// ---------------------------------------------------------------------------

final _escapeCache = <String, String>{};

String _esc(String s) {
  final cached = _escapeCache[s];
  if (cached != null) return cached;
  final out = s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  if (_escapeCache.length < 50000) _escapeCache[s] = out;
  return out;
}

final _dayStrings = <int, String>{};

String _dayString(int day) => _dayStrings.putIfAbsent(day, () {
  final d = DateTime.fromMillisecondsSinceEpoch(day * _dayMs, isUtc: true);
  final m = d.month < 10 ? '0${d.month}' : '${d.month}';
  final dd = d.day < 10 ? '0${d.day}' : '${d.day}';
  return '${d.year}$m$dd';
});

String _offsetString(int minutes) {
  final sign = minutes < 0 ? '-' : '+';
  final abs = minutes.abs();
  final h = abs ~/ 60;
  final m = abs % 60;
  return '$sign${h < 10 ? '0$h' : '$h'}${m < 10 ? '0$m' : '$m'}';
}

const _hhmm = <String>[
  '00', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', //
  '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23',
  '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35',
  '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47',
  '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59',
];

void _writeTime(StringBuffer b, int day, int minute, String offset) {
  var d = day;
  var m = minute;
  if (m >= 1440) {
    d += 1;
    m -= 1440;
  }
  b
    ..write(_dayString(d))
    ..write(_hhmm[m ~/ 60])
    ..write(_hhmm[m % 60])
    ..write('00 ')
    ..write(offset);
}

void _writeChannel(StringBuffer b, MockEpgChannel ch, String origin) {
  b
    ..write('  <channel id="')
    ..write(_esc(ch.id))
    ..write('">\n');
  for (var i = 0; i < ch.displayNames.length; i++) {
    final name = _esc(ch.displayNames[i]);
    if (i == 0) {
      b
        ..write('    <display-name lang="')
        ..write(ch.lang)
        ..write('">')
        ..write(name)
        ..write('</display-name>\n');
    } else {
      b
        ..write('    <display-name>')
        ..write(name)
        ..write('</display-name>\n');
    }
  }
  if (ch.iconPath != null) {
    b
      ..write('    <icon src="')
      ..write(origin)
      ..write(ch.iconPath)
      ..write('"/>\n');
  }
  b.write('  </channel>\n');
}

void _writeProgramme(
  StringBuffer b,
  EpgProgramme p,
  String origin,
  String offset,
) {
  final lang = p.channel.lang;
  b.write('  <programme start="');
  _writeTime(b, p.day, p.startMinute, offset);
  b.write('" stop="');
  _writeTime(b, p.day, p.startMinute + p.lengthMinutes, offset);
  b
    ..write('" channel="')
    ..write(_esc(p.channel.id))
    ..write('"><title lang="')
    ..write(lang)
    ..write('">')
    ..write(_esc(p.title))
    ..write('</title>');
  if (p.tier == 0) {
    b.write('</programme>\n');
    return;
  }
  if (p.subTitle != null) {
    b
      ..write('<sub-title lang="')
      ..write(lang)
      ..write('">')
      ..write(_esc(p.subTitle!))
      ..write('</sub-title>');
  }
  if (p.description != null) {
    b
      ..write('<desc lang="')
      ..write(lang)
      ..write('">')
      ..write(_esc(p.description!))
      ..write('</desc>');
  }
  b
    ..write('<category lang="')
    ..write(lang)
    ..write('">')
    ..write(_esc(p.category))
    ..write('</category>');
  if (p.season != null && p.episode != null) {
    final s = p.season!;
    final e = p.episode!;
    b
      ..write('<episode-num system="xmltv_ns">')
      ..write(s - 1)
      ..write('.')
      ..write(e - 1)
      ..write('.</episode-num><episode-num system="onscreen">S')
      ..write(s < 10 ? '0$s' : '$s')
      ..write('E')
      ..write(e < 10 ? '0$e' : '$e')
      ..write('</episode-num>');
  }
  if (p.iconPath != null) {
    b
      ..write('<icon src="')
      ..write(origin)
      ..write(p.iconPath)
      ..write('"/>');
  }
  if (p.rating != null) {
    final (system, _) = _ratings[lang] ?? _ratings['en']!;
    b
      ..write('<rating system="')
      ..write(_esc(system))
      ..write('"><value>')
      ..write(_esc(p.rating!))
      ..write('</value></rating>');
  }
  b.write('</programme>\n');
}

/// Streams the XMLTV document for [catalog] (UTF-8 chunks of about
/// [chunkSize] bytes). Never builds the whole document in memory.
Stream<List<int>> xmltvStream({
  required MockCatalog catalog,
  required String origin,
  required DateTime now,
  int chunkSize = 1 << 16,
  void Function(int programmes)? onDone,
}) async* {
  final generator = EpgGenerator(rich: catalog.scale == MockScale.small);
  final anchor = epgAnchor(now);
  final fromMs = anchor
      .subtract(const Duration(days: 7))
      .millisecondsSinceEpoch;
  final toMs = anchor.add(const Duration(days: 7)).millisecondsSinceEpoch;
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
    ..write('<!DOCTYPE tv SYSTEM "xmltv.dtd">\n')
    ..write('<tv generator-info-name="Carina Mock EPG" generator-info-url="')
    ..write(_esc(origin))
    ..write('/" source-info-name="Carina mock server">\n');
  for (final ch in catalog.epgChannels) {
    if (!ch.declared) continue;
    _writeChannel(b, ch, origin);
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
    }
  }
  var count = 0;
  var chunks = 0;
  for (final ch in catalog.epgChannels) {
    final offset = _offsetString(ch.utcOffsetMinutes);
    generator.forEach(ch, fromMs, toMs, (p) {
      _writeProgramme(b, p, origin, offset);
      count++;
    });
    if (b.length >= chunkSize) {
      yield utf8.encode(b.toString());
      b.clear();
      // Let other requests (live streams) run between chunks.
      if (++chunks % 8 == 0) await Future<void>.delayed(Duration.zero);
    }
  }
  b.write('</tv>\n');
  yield utf8.encode(b.toString());
  onDone?.call(count);
}

// ---------------------------------------------------------------------------
// Xtream EPG endpoints
// ---------------------------------------------------------------------------

String _b64(String s) => base64.encode(utf8.encode(s));

/// `YYYY-MM-DD HH:MM:SS` in the server time zone (+03:00).
String serverTimeString(int utcMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    utcMs + MockFixtures.utcOffset.inMilliseconds,
    isUtc: true,
  );
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

Map<String, Object?> _listing(
  EpgProgramme p,
  MockChannel channel, {
  int? nowMs,
}) {
  final startSec = p.startMs ~/ 1000;
  final stopSec = p.stopMs ~/ 1000;
  final listing = <String, Object?>{
    'id': '${p.id}',
    'epg_id': '1',
    'title': _b64(p.title),
    'lang': p.channel.lang,
    'start': serverTimeString(p.startMs),
    'end': serverTimeString(p.stopMs),
    'description': _b64(p.description ?? ''),
    'channel_id': channel.epgChannelId ?? p.channel.id,
    'start_timestamp': '$startSec',
    'stop_timestamp': '$stopSec',
  };
  if (nowMs != null) {
    final archiveFrom = nowMs - channel.archiveDays * _dayMs;
    listing['now_playing'] = p.startMs <= nowMs && p.stopMs > nowMs ? 1 : 0;
    listing['has_archive'] =
        channel.archiveDays > 0 && p.stopMs <= nowMs && p.startMs >= archiveFrom
        ? 1
        : 0;
  }
  return listing;
}

/// `get_short_epg`: the current and the next [limit] programmes.
Map<String, Object?> shortEpgJson(
  MockCatalog catalog,
  MockChannel channel, {
  required DateTime now,
  int limit = 4,
}) {
  final epg = channel.xmltvId == null
      ? null
      : catalog.epgChannelById(channel.xmltvId!);
  if (epg == null || limit <= 0) return {'epg_listings': <Object?>[]};
  final generator = EpgGenerator(rich: catalog.scale == MockScale.small);
  final nowMs = now.millisecondsSinceEpoch;
  final out = <Map<String, Object?>>[];
  generator.forEach(epg, nowMs, nowMs + 3 * _dayMs, (p) {
    if (out.length < limit) out.add(_listing(p, channel));
  });
  return {'epg_listings': out};
}

/// `get_simple_data_table`: the whole stored guide of the channel (archive
/// days back, two days ahead) with `now_playing` / `has_archive` flags.
Map<String, Object?> simpleDataTableJson(
  MockCatalog catalog,
  MockChannel channel, {
  required DateTime now,
}) {
  final epg = channel.xmltvId == null
      ? null
      : catalog.epgChannelById(channel.xmltvId!);
  if (epg == null) return {'epg_listings': <Object?>[]};
  final generator = EpgGenerator(rich: catalog.scale == MockScale.small);
  final nowMs = now.millisecondsSinceEpoch;
  final back = (channel.archiveDays < 1 ? 1 : channel.archiveDays) * _dayMs;
  final out = <Map<String, Object?>>[];
  generator.forEach(epg, nowMs - back, nowMs + 2 * _dayMs, (p) {
    out.add(_listing(p, channel, nowMs: nowMs));
  });
  return {'epg_listings': out};
}
