/// Day arithmetic of the guide: the day picker (−7…+7 days, limited by the
/// EPG data), the scrollable time range and day labels.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../../app/time_format.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'guide_cells.dart';

/// Local midnights the day picker offers: today, plus the days of
/// −7…+7 that overlap [range] (the stored programmes).
List<DateTime> guideDays(DateTime now, EpgDataRange? range) {
  final today = localDay(now);
  final out = <DateTime>[];
  for (var d = -7; d <= 7; d++) {
    final day = DateTime(today.year, today.month, today.day + d);
    if (d == 0) {
      out.add(day);
      continue;
    }
    if (range == null) continue;
    final next = DateTime(today.year, today.month, today.day + d + 1);
    if (next.isAfter(range.start.toLocal()) &&
        day.isBefore(range.end.toLocal())) {
      out.add(day);
    }
  }
  return out;
}

/// The grid's scrollable time range (UTC ms): the picker days, cut to the
/// stored programmes, always containing now and one screen after it.
({int startMs, int endMs}) guideTimeRange(
  DateTime now,
  EpgDataRange? range,
  int zoomMinutes,
) {
  final days = guideDays(now, range);
  final first = days.first;
  final last = days.last;
  var start = first.millisecondsSinceEpoch;
  var end = DateTime(
    last.year,
    last.month,
    last.day + 1,
  ).millisecondsSinceEpoch;
  if (range != null) {
    start = math.max(
      start,
      floorToLocalHour(range.start.millisecondsSinceEpoch),
    );
    end = math.min(
      end,
      floorToLocalHour(range.end.millisecondsSinceEpoch - 1) + kHourMs,
    );
  }
  final slot = floorToSlot(now.millisecondsSinceEpoch);
  start = math.min(floorToSlot(start), slot - kHourMs);
  end = math.max(end, slot + (zoomMinutes + 60) * kMinuteMs);
  return (startMs: start, endMs: end);
}

/// Whole calendar days from [from] to [to] (local dates).
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = localDay(from);
  final b = localDay(to);
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// "Today", "Yesterday", "Tomorrow", else a short date ("Wed, Oct 21").
String guideDayLabel(
  L10n l10n,
  CarinaTimeFormat format,
  DateTime day,
  DateTime now,
) {
  switch (calendarDaysBetween(now, day)) {
    case 0:
      return l10n.guideToday;
    case -1:
      return l10n.guideYesterday;
    case 1:
      return l10n.guideTomorrow;
  }
  return DateFormat.MMMEd(format.locale).format(day.toLocal());
}

/// The day picker label of [day] with its date for the relative names
/// ("Tomorrow · Sun, Oct 18").
String guideDayMenuLabel(
  L10n l10n,
  CarinaTimeFormat format,
  DateTime day,
  DateTime now,
) {
  final label = guideDayLabel(l10n, format, day, now);
  final date = DateFormat.MMMEd(format.locale).format(day.toLocal());
  return label == date ? date : '$label · $date';
}
