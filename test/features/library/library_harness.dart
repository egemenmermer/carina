/// Shared setup of the Library team's widget and screenshot tests: the
/// imported mock playlist, a fixed clock inside the mock EPG window and
/// fakes for the platform plugins (version, file launcher).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/settings/data/library_maintenance.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';

export '../../support/drift_widgets.dart';
export '../../support/mock_import.dart';

/// The current minute: the mock EPG is generated around the real time.
DateTime nowMinute() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
}

/// Imports the mock playlist inside a widget test.
Future<MockImportFixture> importFixture(WidgetTester tester) async =>
    (await tester.runAsync(importMockPlaylist))!;

/// Overrides for [fx] plus a fixed clock, the fake engine, a fixed app
/// version and a recording file launcher ([launched]).
List<Override> libraryOverrides(
  MockImportFixture fx, {
  DateTime? now,
  List<Uri>? launched,
  List<Override> extra = const [],
  ImportService? importService,
}) {
  final t = now ?? nowMinute();
  return [
    appDatabaseProvider.overrideWithValue(fx.db),
    appPathsProvider.overrideWithValue(fx.paths),
    settingsStoreProvider.overrideWithValue(fx.settings),
    secretStoreProvider.overrideWithValue(fx.secrets),
    importServiceProvider.overrideWithValue(importService ?? fx.importService),
    playbackEngineFactoryProvider.overrideWithValue(FakeEngineFactory()),
    minuteClockProvider.overrideWith((ref) => Stream.value(t)),
    clockSourceProvider.overrideWithValue(() => t),
    libraryAppVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
    libraryUriLauncherProvider.overrideWithValue((uri) async {
      launched?.add(uri);
      return true;
    }),
    ...extra,
  ];
}

/// [child] inside the playlist shell at [location] (top nav as in the app).
Widget inShell(MockImportFixture fx, String location, Widget child) =>
    PlaylistShell(playlistId: fx.playlistId, location: location, child: child);

/// Unmounts, flushes drift timers and disposes the fixture.
Future<void> disposeFixture(WidgetTester tester, MockImportFixture fx) async {
  await unmountAndFlush(tester);
  await tester.runAsync(fx.dispose);
}
