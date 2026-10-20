import 'package:flutter/widgets.dart';

/// Locale-aware upper case: Turkish maps `i` → `İ` and `ı` → `I`
/// ("Sıradaki" → "SIRADAKİ"), which `String.toUpperCase` does not.
String upperFor(String text, String languageCode) {
  if (languageCode != 'tr' && languageCode != 'az') return text.toUpperCase();
  return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}

extension LocaleUpperCase on String {
  /// Upper case using the app locale of [context].
  String upper(BuildContext context) => upperFor(
    this,
    Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
  );
}
