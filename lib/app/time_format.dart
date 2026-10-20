import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/settings/settings_store.dart';

/// Locale-aware date/time formatting used by every screen.
///
/// English defaults to 12-hour times (`3:15 PM`), Turkish to 24-hour
/// (`15:15`); `AppSettings.timeFormat` (`auto` | `h12` | `h24`) overrides.
/// All inputs are converted to local time first.
class CarinaTimeFormat {
  CarinaTimeFormat({required this.locale, required this.use24h});

  final String locale;
  final bool use24h;

  late final DateFormat _time = use24h
      ? DateFormat('HH:mm', locale)
      : DateFormat('h:mm a', locale);
  late final DateFormat _navDate = DateFormat('EEE, MMM d', locale);
  late final DateFormat _dayHeader = DateFormat('EEEE, d MMMM', locale);
  late final DateFormat _shortDate = DateFormat('d MMMM y', locale);
  late final DateFormat _monthYear = DateFormat('MMMM y', locale);

  /// `3:15 PM` / `15:15`.
  String time(DateTime t) => _time.format(t.toLocal());

  /// `3:15 PM – 4:15 PM`.
  String range(DateTime start, DateTime end) => '${time(start)} – ${time(end)}';

  /// Top bar: `Wed, May 20 • 00:26`.
  String navDateTime(DateTime now) =>
      '${_navDate.format(now.toLocal())} • ${time(now)}';

  /// Archive day header: `Monday, 20 July`.
  String dayHeader(DateTime day) => _dayHeader.format(day.toLocal());

  /// `20 January 2008`.
  String date(DateTime d) => _shortDate.format(d.toLocal());

  /// `January 2008`.
  String monthYear(DateTime d) => _monthYear.format(d.toLocal());

  /// `60 min`, `1h 49m` style durations.
  String minutes(Duration d) =>
      locale == 'tr' ? '${d.inMinutes} dk' : '${d.inMinutes} min';

  String runtime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final hs = locale == 'tr' ? 'sa' : 'h';
    final ms = locale == 'tr' ? 'dk' : 'm';
    if (h == 0) return '$m$ms';
    return m == 0 ? '$h$hs' : '$h$hs $m$ms';
  }

  /// Player clock: `0:13`, `1:02:45`.
  static String clock(Duration d) {
    final negative = d.isNegative;
    final a = d.abs();
    final h = a.inHours;
    final m = a.inMinutes.remainder(60);
    final s = a.inSeconds.remainder(60).toString().padLeft(2, '0');
    final body = h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
    return negative ? '-$body' : body;
  }

  static bool defaultUse24h(String languageCode) => languageCode != 'en';
}

/// The effective UI locale code (`en` / `tr`) from the language setting and
/// the system locale.
final appLocaleCodeProvider = Provider<String>(
  (ref) => resolveLanguage(
    ref.watchSetting(AppSettings.language),
    ui.PlatformDispatcher.instance.locale,
  ),
);

final timeFormatProvider = Provider<CarinaTimeFormat>((ref) {
  final locale = ref.watch(appLocaleCodeProvider);
  final mode = ref.watchSetting(AppSettings.timeFormat);
  final use24h = switch (mode) {
    'h12' => false,
    'h24' => true,
    _ => CarinaTimeFormat.defaultUse24h(locale),
  };
  return CarinaTimeFormat(locale: locale, use24h: use24h);
});

/// Convenience for widgets.
extension TimeFormatContext on WidgetRef {
  CarinaTimeFormat get timeFormat => watch(timeFormatProvider);
}

/// Resolves `system` / `en` / `tr` against the platform locale.
String resolveLanguage(String setting, Locale platform) {
  if (setting == 'en' || setting == 'tr') return setting;
  return platform.languageCode == 'tr' ? 'tr' : 'en';
}
