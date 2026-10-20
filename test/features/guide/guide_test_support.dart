/// Shared setup for the TV Guide widget and screenshot tests: the real mock
/// import, a fixed clock, the fake playback engine and recording actions.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/features/guide/guide_screen.dart';
import 'package:carina/features/guide/src/guide_actions.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';
import '../../support/screenshot.dart';

export '../../support/drift_widgets.dart';
export '../../support/mock_import.dart';
export '../../support/screenshot.dart';

/// Records the guide's outgoing calls instead of opening other teams'
/// routes.
class RecordingGuideActions extends GuideActions {
  final List<PlayRequest> played = [];
  final List<({String channelId, Offset position})> channelActions = [];

  @override
  Future<void> openPlayer(BuildContext context, PlayRequest request) async {
    played.add(request);
  }

  @override
  Future<void> showChannelActions(
    BuildContext context, {
    required int playlistId,
    required String channelId,
    required Offset position,
    String? categoryId,
  }) async {
    channelActions.add((channelId: channelId, position: position));
  }
}

/// The current minute: the mock EPG is generated around the real time.
DateTime fixedNow() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
}

/// Overrides for a guide test.
List<Override> guideOverrides(
  MockImportFixture fx, {
  required DateTime now,
  GuideActions? actions,
  FakeEngineFactory? engines,
}) => [
  ...fx.providerOverrides,
  playbackEngineFactoryProvider.overrideWithValue(
    engines ?? FakeEngineFactory(autoTick: false),
  ),
  minuteClockProvider.overrideWith((ref) => Stream.value(now)),
  clockSourceProvider.overrideWithValue(() => now),
  guideActionsProvider.overrideWithValue(actions ?? RecordingGuideActions()),
];

/// Imports the mock playlist inside a widget test.
Future<MockImportFixture> importGuideFixture(
  WidgetTester tester, {
  bool withEpg = true,
}) async =>
    (await tester.runAsync(() => importMockPlaylist(withEpg: withEpg)))!;

/// Pumps the TV Guide tab inside the playlist shell and waits for the data.
Future<void> pumpGuide(
  WidgetTester tester,
  MockImportFixture fx, {
  required DateTime now,
  GuideActions? actions,
  FakeEngineFactory? engines,
  List<Override> extra = const [],
  Locale locale = const Locale('en'),
}) async {
  await pumpScreen(
    tester,
    PlaylistShell(
      playlistId: fx.playlistId,
      location: '/p/${fx.playlistId}/guide',
      child: GuideScreen(playlistId: fx.playlistId),
    ),
    overrides: [
      ...guideOverrides(fx, now: now, actions: actions, engines: engines),
      ...extra,
    ],
    locale: locale,
  );
  await settleDrift(tester, rounds: 30);
}

/// Unmounts and closes the fixture.
Future<void> finishGuide(WidgetTester tester, MockImportFixture fx) async {
  await unmountAndFlush(tester);
  await tester.runAsync(fx.dispose);
}
