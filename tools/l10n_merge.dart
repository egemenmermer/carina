// Merges lib/l10n/parts/<feature>.<locale>.json into lib/l10n/app_<locale>.arb.
//
// Each feature owns its own part files, so parallel work never edits the same
// ARB file. Run `dart run tools/l10n_merge.dart && flutter gen-l10n` after
// changing a part.
import 'dart:convert';
import 'dart:io';

void main() {
  final parts = Directory('lib/l10n/parts');
  final byLocale = <String, Map<String, Object?>>{};
  final owners = <String, String>{};
  final files = parts.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  var failed = false;
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final match = RegExp(r'^(.+)\.([a-z]{2})\.json$').firstMatch(name);
    if (match == null) continue;
    final locale = match.group(2)!;
    final data = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final target = byLocale.putIfAbsent(locale, () => {});
    for (final entry in data.entries) {
      final ownerKey = '$locale:${entry.key}';
      if (target.containsKey(entry.key)) {
        stderr.writeln(
          'Duplicate key "${entry.key}" in $name (already in ${owners[ownerKey]})',
        );
        failed = true;
        continue;
      }
      owners[ownerKey] = name;
      target[entry.key] = entry.value;
    }
  }
  final en = byLocale['en'] ?? {};
  for (final entry in byLocale.entries) {
    if (entry.key == 'en') continue;
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      if (!entry.value.containsKey(key)) {
        stderr.writeln('Missing "${entry.key}" translation for "$key"');
        failed = true;
      }
    }
  }
  if (failed) exit(1);
  const encoder = JsonEncoder.withIndent('  ');
  for (final entry in byLocale.entries) {
    final keys = entry.value.keys.toList()
      ..sort((a, b) {
        final ka = a.startsWith('@') ? a.substring(1) : a;
        final kb = b.startsWith('@') ? b.substring(1) : b;
        final c = ka.compareTo(kb);
        if (c != 0) return c;
        return a.startsWith('@') ? 1 : -1;
      });
    final out = <String, Object?>{'@@locale': entry.key};
    for (final k in keys) {
      if (entry.key != 'en' && k.startsWith('@')) continue;
      out[k] = entry.value[k];
    }
    File('lib/l10n/app_${entry.key}.arb')
        .writeAsStringSync('${encoder.convert(out)}\n');
  }
  stdout.writeln('Merged ${files.length} part files.');
}
