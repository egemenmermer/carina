/// Shared helpers for the TV Live widget and screenshot tests: the mock
/// playlist import, a fixed clock, the fake engine, an offline short EPG and
/// a recording [LiveExternals].
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/repositories/epg_repository.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/features/live/live_externals.dart';
import 'package:carina/features/live/live_screen.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';

import '../../support/mock_import.dart';

/// "Now" for the tests: the current minute (the mock guide is generated
/// around the real time).
DateTime liveTestNow() {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, t.hour, t.minute);
}

/// Every call TV Live made to another team's API.
class RecordingExternals extends LiveExternals {
  final List<PlayRequest> played = [];
  final List<String> calls = [];

  /// What [ensureChannelUnlocked] answers.
  bool unlock = true;

  /// Called while the fake player is "open" (e.g. to check the preview
  /// stopped).
  void Function()? onPlayerOpen;

  @override
  Future<void> openPlayer(BuildContext context, PlayRequest request) async {
    played.add(request);
    calls.add('openPlayer');
    onPlayerOpen?.call();
  }

  @override
  Future<bool> ensureChannelUnlocked(
    BuildContext context, {
    required int playlistId,
    required String channelId,
  }) async {
    calls.add('ensureChannelUnlocked $channelId');
    return unlock;
  }

  @override
  Future<void> toggleReminder(
    BuildContext context, {
    required int playlistId,
    required String channelId,
    required DateTime startUtc,
  }) async => calls.add('toggleReminder $channelId ${startUtc.toUtc()}');

  @override
  Future<void> showProgrammeDetails(
    BuildContext context, {
    required int playlistId,
    required String channelId,
    required DateTime startUtc,
  }) async => calls.add('showProgrammeDetails $channelId ${startUtc.toUtc()}');

  @override
  Future<void> showArchiveSheet(
    BuildContext context, {
    required int playlistId,
    required String channelId,
  }) async => calls.add('showArchiveSheet $channelId');

  @override
  Future<void> showFavoriteTagsSheet(
    BuildContext context, {
    required int playlistId,
    required String providerId,
    required String title,
  }) async => calls.add('showFavoriteTagsSheet $providerId');

  @override
  Future<void> addToMultiview(
    BuildContext context, {
    required int playlistId,
    required String channelId,
  }) async => calls.add('addToMultiview $channelId');
}

/// Answers every short-EPG request with a connection error at once (no
/// network, no timers in fake-async tests).
class OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline (test)',
  );

  @override
  void close({bool force = false}) {}
}

/// Provider overrides for TV Live tests.
List<Override> liveOverrides(
  MockImportFixture fx, {
  required FakeEngineFactory engines,
  required RecordingExternals externals,
  required DateTime now,
}) => [
  ...fx.providerOverrides,
  playbackEngineFactoryProvider.overrideWithValue(engines),
  liveExternalsProvider.overrideWithValue(externals),
  clockSourceProvider.overrideWithValue(() => now),
  minuteClockProvider.overrideWith((ref) => Stream.value(now)),
  epgRepositoryProvider.overrideWith(
    (ref) => EpgRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(playlistRepositoryProvider),
      clock: () => now,
      dioFactory: () => Dio()..httpClientAdapter = OfflineAdapter(),
    ),
  ),
];

/// TV Live inside the real playlist shell (top nav, FAB, sidebar).
Widget liveInShell(int playlistId) => PlaylistShell(
  playlistId: playlistId,
  location: '/p/$playlistId/live',
  child: LiveScreen(playlistId: playlistId),
);
