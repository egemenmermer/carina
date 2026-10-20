/// Shared setup for the player widget / screenshot tests: the mock playlist
/// (real import), cached VOD details, a [FakeEngineFactory], a fixed clock
/// and a fake window.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';
import 'package:carina/player/ui/player_menus.dart';
import 'package:carina/player/ui/player_screen.dart';
import 'package:carina/player/ui/player_window.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';
import '../../support/screenshot.dart';

export 'package:carina/player/engine/fake_engine.dart';

export '../../support/drift_widgets.dart';
export '../../support/mock_import.dart';
export '../../support/screenshot.dart';

/// Real HTTP for setup code that runs outside `importMockPlaylist`.
class RealHttpOverrides extends HttpOverrides {}

/// Imports the mock playlist and caches the details the player reads
/// (Kış Uykusu's `get_vod_info`, Sıcak Kafa's episodes), so no request
/// leaves a widget test's fake-async zone.
Future<MockImportFixture> importPlayerFixture() async {
  final fx = await importMockPlaylist();
  await HttpOverrides.runWithHttpOverrides(() async {
    final vod = VodRepository(
      db: fx.db,
      settings: fx.settings,
      secrets: fx.secrets,
    );
    await vod.movieDetails(fx.playlistId, '${MockFixtures.kisUykusu}');
    await vod.seriesDetails(fx.playlistId, '${MockFixtures.sicakKafa}');
    vod.dispose();
  }, RealHttpOverrides());
  return fx;
}

/// Records full-screen toggles instead of calling window_manager.
class FakePlayerWindow extends PlayerWindow {
  bool fullscreen = false;
  int toggles = 0;

  @override
  Future<bool> isFullscreen() async => fullscreen;

  @override
  Future<void> toggleFullscreen() async {
    toggles++;
    fullscreen = !fullscreen;
  }

  @override
  Future<void> exitFullscreen() async => fullscreen = false;
}

/// "Now" for the tests: the current minute (the mock EPG is generated
/// around the real time).
final DateTime testNow = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
}();

/// Overrides for a player test.
List<Override> playerOverrides(
  MockImportFixture fx, {
  required FakeEngineFactory factory,
  FakePlayerWindow? window,
  SubtitleFilePicker? picker,
}) => [
  ...fx.providerOverrides,
  playbackEngineFactoryProvider.overrideWithValue(factory),
  minuteClockProvider.overrideWith((ref) => Stream.value(testNow)),
  clockSourceProvider.overrideWithValue(() => testNow),
  playerWindowProvider.overrideWithValue(window ?? FakePlayerWindow()),
  if (picker != null) subtitleFilePickerProvider.overrideWithValue(picker),
];

/// Pumps [PlayerScreen] for [request] and waits until the stream opened.
Future<PlayerScreenState> pumpPlayer(
  WidgetTester tester,
  MockImportFixture fx,
  PlayRequest request, {
  required FakeEngineFactory factory,
  FakePlayerWindow? window,
  SubtitleFilePicker? picker,
  Locale locale = const Locale('en'),
}) async {
  await pumpScreen(
    tester,
    PlayerScreen(request: request),
    overrides: playerOverrides(
      fx,
      factory: factory,
      window: window,
      picker: picker,
    ),
    locale: locale,
  );
  await settleDrift(tester, rounds: 12);
  return tester.state<PlayerScreenState>(find.byType(PlayerScreen));
}

/// The engine of the player under test.
FakeEngine playerEngine(FakeEngineFactory factory) => factory.created.single;

/// A factory whose engines do not tick by themselves (tests advance them).
FakeEngineFactory manualFactory({Duration? vodDuration}) => FakeEngineFactory(
  autoTick: false,
  vodDuration: vodDuration ?? const Duration(minutes: 42, seconds: 17),
);

/// Lets drift answer and pumps [frames] frames of 50 ms.
Future<void> settlePlayer(WidgetTester tester, {int frames = 4}) async {
  await settleDrift(tester, rounds: 4);
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Two frames: engine events arrive on a stream (a microtask) after the
/// first pump, the rebuild they cause needs the second.
Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Ends a player test cleanly (disposes the engine, flushes drift).
Future<void> closePlayer(WidgetTester tester) async {
  await unmountAndFlush(tester);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
}

/// [ProviderContainer] of the pumped app.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PlayerScreen)));

/// Playback engine options used by the player under test.
EngineOptions optionsOf(FakeEngineFactory factory) =>
    factory.created.single.options;
