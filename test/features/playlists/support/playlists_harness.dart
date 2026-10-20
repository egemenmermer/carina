/// Shared helpers for the Playlists widget and screenshot tests: a
/// go_router with the Playlists routes (other routes are stubs), fakes for
/// the import service, the live checks and the file picker, and an import
/// service that runs real imports outside the fake-async zone.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/sources/xtream/xtream_check.dart';
import 'package:carina/data/sources/xtream/xtream_credentials.dart';
import 'package:carina/features/playlists/avatar_picker_screen.dart';
import 'package:carina/features/playlists/data/source_checker.dart';
import 'package:carina/features/playlists/import_progress_screen.dart';
import 'package:carina/features/playlists/playlist_manager_screen.dart';
import 'package:carina/features/playlists/playlist_wizard_screen.dart';

/// The Playlists routes as `lib/app/router.dart` defines them, plus
/// `/playlists/new?type=xtream|m3u|m3uFile` (the capture-mode wiring) and
/// stubs for every other destination (they show `route: <location>`).
GoRouter playlistsTestRouter({
  String initialLocation = '/',
  Object? initialExtra,
}) {
  int pid(GoRouterState s) => int.parse(s.pathParameters['pid']!);
  Widget stub(BuildContext context, GoRouterState state) =>
      _RouteStub(location: state.uri.toString());
  return GoRouter(
    initialLocation: initialLocation,
    initialExtra: initialExtra,
    routes: [
      GoRoute(path: '/', builder: (c, s) => const PlaylistManagerScreen()),
      GoRoute(
        path: '/playlists/new',
        builder: (c, s) => PlaylistWizardScreen(
          initialType: PlaylistType.values
              .asNameMap()[s.uri.queryParameters['type']],
        ),
      ),
      GoRoute(
        path: '/playlists/:pid/edit',
        builder: (c, s) => PlaylistWizardScreen(playlistId: pid(s)),
      ),
      GoRoute(
        path: '/playlists/:pid/import',
        builder: (c, s) => ImportProgressScreen(playlistId: pid(s)),
      ),
      GoRoute(
        path: '/playlists/:pid/avatar',
        builder: (c, s) => AvatarPickerScreen(playlistId: pid(s)),
      ),
      GoRoute(
        path: '/settings',
        builder: stub,
        routes: [GoRoute(path: ':section', builder: stub)],
      ),
      GoRoute(path: '/downloads', builder: stub),
      GoRoute(
        path: '/p/:pid/:tab',
        builder: stub,
        routes: [GoRoute(path: ':section', builder: stub)],
      ),
    ],
  );
}

/// [router] as a widget for `pumpScreen`.
Widget routerHost(GoRouter router) => Router.withConfig(config: router);

class _RouteStub extends StatelessWidget {
  const _RouteStub({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Text(
        'route: $location',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

/// Text of the stub page for [location].
String routeStubText(String location) => 'route: $location';

/// Pumps frames while giving real async work (drift, HTTP, isolates) time
/// to run, until [until] holds or [rounds] are used up.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() until, {
  int rounds = 200,
  Duration realStep = const Duration(milliseconds: 40),
}) async {
  for (var i = 0; i < rounds; i++) {
    if (until()) return;
    await tester.runAsync(() => Future<void>.delayed(realStep));
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (!until()) {
    fail('pumpUntil: condition not met after $rounds rounds');
  }
}

/// Temporary app folders for an [ImportService].
Future<AppPaths> tempAppPaths() async {
  final dir = await Directory.systemTemp.createTemp('carina_playlists_test_');
  return AppPaths.resolve(override: dir.path);
}

/// Creates real `HttpClient`s even when the Flutter test binding mocks them.
class RealHttpOverrides extends HttpOverrides {}

/// Runs [body] with real HTTP clients.
Future<T> withRealHttp<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, RealHttpOverrides());

/// An [ImportService] whose imports run in the root zone with real HTTP, so
/// a `testWidgets` body can drive a real import with [pumpUntil].
class RootZoneImportService extends ImportService {
  RootZoneImportService({
    required super.db,
    required super.paths,
    required super.secrets,
    required super.settings,
    super.config = const ImportConfig(retries: 0),
  });

  final List<ImportScope> startedScopes = [];

  @override
  Stream<ImportProgress> start(
    int playlistId, {
    ImportScope scope = ImportScope.all,
  }) {
    startedScopes.add(scope);
    return Zone.root.run(
      () => HttpOverrides.runWithHttpOverrides(
        () => super.start(playlistId, scope: scope),
        RealHttpOverrides(),
      ),
    );
  }
}

/// An [ImportService] driven by the test: [start] returns a stream the
/// test feeds with [emit].
class FakeImportService extends ImportService {
  FakeImportService({
    required super.db,
    required super.paths,
    required super.secrets,
    required super.settings,
  });

  final Map<int, StreamController<ImportProgress>> _controllers = {};
  final Map<int, ImportProgress> _latest = {};
  final List<(int, ImportScope)> started = [];
  final List<int> cancelled = [];

  @override
  Stream<ImportProgress> start(
    int playlistId, {
    ImportScope scope = ImportScope.all,
  }) {
    started.add((playlistId, scope));
    return _controllers
        .putIfAbsent(
          playlistId,
          () => StreamController<ImportProgress>.broadcast(),
        )
        .stream;
  }

  /// Sends [progress] to the listeners of its playlist.
  void emit(ImportProgress progress) {
    _latest[progress.playlistId] = progress;
    _controllers[progress.playlistId]?.add(progress);
  }

  @override
  void cancel(int playlistId) => cancelled.add(playlistId);

  @override
  bool isRunning(int playlistId) =>
      _controllers.containsKey(playlistId) &&
      !(_latest[playlistId]?.done ?? false);

  @override
  ImportProgress? current(int playlistId) => null;

  @override
  Stream<ImportProgress?> watch(int playlistId) =>
      Stream<ImportProgress?>.value(null);

  @override
  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
  }
}

/// Every planned step of an Xtream import with a guide.
const List<ImportStep> allSteps = [
  ...ImportStep.contentSteps,
  ...ImportStep.epgSteps,
  ImportStep.completed,
];

/// A [PlaylistSourceChecker] that answers from canned results.
class FakeSourceChecker extends PlaylistSourceChecker {
  FakeSourceChecker({this.xtream, this.playlistUrl, this.epgUrl, this.file});

  XtreamCheckResult Function(XtreamCredentials credentials)? xtream;
  UrlCheckResult Function(String url)? playlistUrl;
  UrlCheckResult Function(String url)? epgUrl;
  FileCheckResult Function(String path)? file;

  final List<String> calls = [];

  @override
  Future<XtreamCheckResult> checkXtream(
    XtreamCredentials credentials, {
    CancelToken? cancelToken,
  }) async {
    calls.add('xtream ${credentials.server}');
    return xtream?.call(credentials) ??
        const XtreamCheckResult(ok: false, error: null);
  }

  @override
  Future<UrlCheckResult> checkPlaylistUrl(
    String url, {
    String? userAgent,
    CancelToken? cancelToken,
  }) async {
    calls.add('m3u $url');
    return playlistUrl?.call(url) ??
        const UrlCheckResult(ok: false, reachable: false);
  }

  @override
  Future<UrlCheckResult> checkEpgUrl(
    String url, {
    String? userAgent,
    CancelToken? cancelToken,
  }) async {
    calls.add('epg $url');
    return epgUrl?.call(url) ??
        const UrlCheckResult(ok: false, reachable: false);
  }

  @override
  Future<FileCheckResult> checkFile(String path) async {
    calls.add('file $path');
    return file?.call(path) ?? const FileCheckResult(exists: false);
  }
}
