import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/settings/settings_model.dart';
import 'package:carina/features/settings/settings_screen.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

import '../../support/screenshot.dart';
import 'library_harness.dart';

/// Records reload requests instead of downloading.
class RecordingImportService extends ImportService {
  RecordingImportService(MockImportFixture fx)
    : super(
        db: fx.db,
        paths: fx.paths,
        secrets: fx.secrets,
        settings: fx.settings,
      );

  final List<(int, ImportScope)> started = [];

  @override
  Stream<ImportProgress> start(
    int playlistId, {
    ImportScope scope = ImportScope.all,
  }) {
    started.add((playlistId, scope));
    return const Stream.empty();
  }

  @override
  bool isRunning(int playlistId) => false;
}

Finder inPanel(String text) =>
    find.descendant(of: find.byType(KFrostedPanel), matching: find.text(text));

Future<void> pumpSettings(
  WidgetTester tester,
  MockImportFixture fx,
  String section, {
  ImportService? importService,
}) async {
  await pumpScreen(
    tester,
    SettingsScreen(playlistId: fx.playlistId, section: section),
    overrides: libraryOverrides(fx, importService: importService),
  );
  await settleDrift(tester);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('every keyed settings row writes its key', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final store = fx.settings;
    // Rows that show only in a mode.
    await tester.runAsync(
      () => store.set(PlaylistSettings.bufferPolicy, 'custom', playlistId: pid),
    );
    final checked = <String>[];
    for (final section in SettingsSection.values) {
      final specs = LibrarySettingSpecs.all
          .where((s) => s.section == section)
          .toList();
      if (specs.isEmpty) continue;
      await pumpSettings(tester, fx, section.id);
      for (final spec in specs) {
        final l10n = L10n.of(tester.element(find.byType(SettingsScreen)));
        if (!spec.isVisible(store, pid)) {
          // Custom buffer shows with the Custom policy only.
          await tester.runAsync(
            () => store.set(
              PlaylistSettings.bufferPolicy,
              'custom',
              playlistId: pid,
            ),
          );
          await settle(tester);
        }
        final row = find.byKey(spec.rowKey);
        expect(row, findsOneWidget, reason: '${spec.key} row is placed');
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final before = store.get(spec.key, playlistId: pid);
        await tester.tap(row);
        await settle(tester);
        expect(
          find.text(spec.title(l10n)),
          findsWidgets,
          reason: 'chooser of ${spec.key}',
        );
        expect(inPanel(spec.description(l10n)), findsOneWidget);
        final target = spec.options(l10n).firstWhere((o) => o.value != before);
        final option = inPanel(target.label);
        await tester.ensureVisible(option.first);
        await tester.pumpAndSettle();
        await tester.tap(option.first);
        await settleDrift(tester, rounds: 4);
        expect(
          store.get(spec.key, playlistId: pid),
          target.value,
          reason: '${spec.key} stored',
        );
        // The row shows the new value in red.
        expect(
          find.descendant(of: row, matching: find.text(target.label)),
          findsOneWidget,
        );
        checked.add(spec.key.id);
        // Toasts fade out before the next row.
        await tester.pump(const Duration(seconds: 3));
        await settle(tester);
      }
    }
    expect(checked.length, LibrarySettingSpecs.all.length);
    await disposeFixture(tester, fx);
  });

  testWidgets('text rows store User-Agent and Referer', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await tester.runAsync(
      () => fx.settings.set(
        PlaylistSettings.userAgentMode,
        'custom',
        playlistId: pid,
      ),
    );
    await pumpSettings(tester, fx, 'player');
    for (final (key, value) in [
      ('userAgentCustom', 'MyBox/1.0'),
      ('referer', 'https://example.org/'),
    ]) {
      final row = find.byKey(ValueKey('setting:$key'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(KFrostedPanel),
          matching: find.byType(EditableText),
        ),
        value,
      );
      await tester.tap(inPanel('Save'));
      await settleDrift(tester, rounds: 4);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
    }
    expect(
      fx.settings.get(PlaylistSettings.userAgentCustom, playlistId: pid),
      'MyBox/1.0',
    );
    expect(
      fx.settings.get(PlaylistSettings.referer, playlistId: pid),
      'https://example.org/',
    );
    await disposeFixture(tester, fx);
  });

  testWidgets('reload frequency and EPG shift edit the playlist', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final imports = RecordingImportService(fx);
    await pumpSettings(tester, fx, 'management', importService: imports);

    Future<void> choose(String rowKey, String label) async {
      final row = find.byKey(ValueKey(rowKey));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await settle(tester);
      final option = inPanel(label);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await settleDrift(tester, rounds: 6);
    }

    await choose('row:reload-frequency', 'Every day');
    await choose('row:epg-shift', '+2 h');
    final row = await tester.runAsync(
      () => PlaylistRepository(fx.db, fx.secrets, fx.settings).get(pid),
    );
    expect(row!.reloadFrequencyHours, 24);
    expect(row.epgShiftHours, 2);
    // Credentials and source untouched.
    expect(row.server, fx.server.baseUrl);
    expect(row.epgUrl, isNull);
    // The shift applies on import: the guide reloads.
    expect(imports.started, [(pid, ImportScope.epg)]);

    await tester.tap(find.byKey(const ValueKey('action:reload')));
    await settle(tester);
    expect(imports.started.last, (pid, ImportScope.all));
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });

  testWidgets('sections switch and Esc closes a subpage', (tester) async {
    final fx = await importFixture(tester);
    await pumpSettings(tester, fx, 'management');
    expect(find.byKey(const ValueKey('row:hidden')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('row:hidden')));
    await settleDrift(tester, rounds: 4);
    expect(find.byKey(const ValueKey('subpage-back')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const ValueKey('subpage-back')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('section:player')));
    await settle(tester);
    expect(find.byKey(LibrarySettingSpecs.aspect.rowKey), findsOneWidget);
    await disposeFixture(tester, fx);
  });

  testWidgets('app-level settings show only app sections', (tester) async {
    final fx = await importFixture(tester);
    await pumpScreen(
      tester,
      const SettingsScreen(),
      overrides: libraryOverrides(fx),
    );
    await settleDrift(tester);
    expect(find.byKey(const ValueKey('section:general')), findsOneWidget);
    expect(find.byKey(const ValueKey('section:player')), findsNothing);
    expect(find.byKey(const ValueKey('section:parental')), findsNothing);
    await disposeFixture(tester, fx);
  });
}
