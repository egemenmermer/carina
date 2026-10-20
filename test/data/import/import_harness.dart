// Shared setup of the import tests: the in-process mock server, an
// in-memory database, stores, an ImportService and a filtering proxy.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../../../tools/mock_server/src/server.dart';

export '../../../tools/mock_server/src/server.dart';

/// Fast failure in tests: no retries, short timeouts.
const ImportConfig testImportConfig = ImportConfig(
  connectTimeout: Duration(seconds: 5),
  receiveTimeout: Duration(seconds: 20),
  bulkReceiveTimeout: Duration(seconds: 30),
  retries: 0,
);

const String user = MockFixtures.username;
const String pass = MockFixtures.password;

class ImportHarness {
  ImportHarness._(
    this.tempDir,
    this.server,
    this.db,
    this.paths,
    this.settings,
    this.secrets,
    this.service,
  );

  final Directory tempDir;
  final MockServer server;
  final AppDatabase db;
  final AppPaths paths;
  final SettingsStore settings;
  final MemorySecretStore secrets;
  final ImportService service;

  String get base => server.baseUrl;
  MockCatalog get catalog => server.catalog;
  String get xmltvUrl => '$base/xmltv.php?username=$user&password=$pass';

  static Future<ImportHarness> create({
    MockScale scale = MockScale.small,
    ImportConfig config = testImportConfig,
    Duration slowDelay = const Duration(seconds: 30),
    QueryExecutor? executor,
    bool warmUp = true,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final tempDir = await Directory.systemTemp.createTemp('carina_import_');
    final media = Directory('${tempDir.path}/media');
    final live = Directory('${tempDir.path}/live');
    await media.create(recursive: true);
    await live.create(recursive: true);
    final server = await MockServer.start(
      port: 0,
      scale: scale,
      mediaDir: media.path,
      liveDir: live.path,
      slowDelay: slowDelay,
      warmUp: warmUp,
    );
    final db = AppDatabase.forTesting(executor ?? NativeDatabase.memory());
    final paths = await AppPaths.resolve(override: '${tempDir.path}/data');
    final settings = SettingsStore(db);
    await settings.load();
    final secrets = MemorySecretStore();
    final service = ImportService(
      db: db,
      paths: paths,
      secrets: secrets,
      settings: settings,
      config: config,
    );
    return ImportHarness._(
      tempDir,
      server,
      db,
      paths,
      settings,
      secrets,
      service,
    );
  }

  /// Adds an Xtream playlist. [epgUrl] is stored as is (a custom URL);
  /// without it the playlist uses the default XMLTV (`epgUrl = null`, the
  /// repository contract) or, with [epg] false, has the guide switched off
  /// (`''`).
  Future<int> addXtream({
    String? server,
    String username = user,
    String password = pass,
    String? epgUrl,
    bool epg = true,
    int reloadFrequencyHours = 72,
    DateTime? lastReloadAt,
    int epgShiftHours = 0,
    String name = 'Kanal Demo',
  }) async {
    final id = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: name,
            type: PlaylistType.xtream,
            server: Value(server ?? base),
            username: Value(username),
            epgUrl: Value(epgUrl ?? (epg ? null : '')),
            epgShiftHours: Value(epgShiftHours),
            reloadFrequencyHours: Value(reloadFrequencyHours),
            lastReloadAt: Value(lastReloadAt),
            createdAt: DateTime.now(),
          ),
        );
    await secrets.write(SecretStore.playlistPassword(id), password);
    return id;
  }

  Future<int> addM3u({
    required String url,
    PlaylistType type = PlaylistType.m3u,
    String? epgUrl,
    String? userAgent,
  }) => db
      .into(db.playlists)
      .insert(
        PlaylistsCompanion.insert(
          name: 'M3U',
          type: type,
          m3uUrl: Value(url),
          epgUrl: Value(epgUrl),
          userAgent: Value(userAgent),
          createdAt: DateTime.now(),
        ),
      );

  /// Runs an import and returns every snapshot.
  Future<List<ImportProgress>> runImport(
    int playlistId, {
    ImportScope scope = ImportScope.all,
  }) => service.start(playlistId, scope: scope).toList();

  Future<PlaylistRow> playlist(int id) =>
      (db.select(db.playlists)..where((p) => p.id.equals(id))).getSingle();

  Future<ChannelRow?> channel(int pid, Object providerId) =>
      (db.select(db.channels)..where(
            (c) =>
                c.playlistId.equals(pid) & c.providerId.equals('$providerId'),
          ))
          .getSingleOrNull();

  Future<MovieRow?> movie(int pid, Object providerId) =>
      (db.select(db.movies)..where(
            (c) =>
                c.playlistId.equals(pid) & c.providerId.equals('$providerId'),
          ))
          .getSingleOrNull();

  Future<SeriesRow?> series(int pid, Object providerId) =>
      (db.select(db.series)..where(
            (c) =>
                c.playlistId.equals(pid) & c.providerId.equals('$providerId'),
          ))
          .getSingleOrNull();

  Future<CategoryRow?> category(int pid, SectionKind kind, String providerId) =>
      (db.select(db.categories)..where(
            (c) =>
                c.playlistId.equals(pid) &
                c.kind.equalsValue(kind) &
                c.providerId.equals(providerId),
          ))
          .getSingleOrNull();

  Future<int> count(String table, int pid, [String where = '']) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM "$table" WHERE playlist_id = ?'
          '${where.isEmpty ? '' : ' AND $where'}',
          variables: [Variable.withInt(pid)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// FTS search over `search_index` (normalized prefix query).
  Future<List<({String title, String kind, String ref})>> search(
    int pid,
    String match,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT title, kind, ref_id FROM search_index '
          'WHERE search_index MATCH ? AND playlist_id = ?',
          variables: [Variable.withString(match), Variable.withInt(pid)],
        )
        .get();
    return [
      for (final r in rows)
        (
          title: r.read<String>('title'),
          kind: r.read<String>('kind'),
          ref: r.read<String>('ref_id'),
        ),
    ];
  }

  Future<void> dispose() async {
    await service.dispose();
    await server.stop();
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Best effort.
    }
  }
}

/// The distinct steps of [events], in order.
List<ImportStep> stepsOf(List<ImportProgress> events) {
  final out = <ImportStep>[];
  for (final e in events) {
    if (out.isEmpty || out.last != e.step) out.add(e.step);
  }
  return out;
}

/// A local HTTP proxy in front of the mock server that can hide catalog
/// items (simulating items that disappeared upstream) and fail the bulk
/// live call (to exercise the per-category fallback).
class FilteringProxy {
  FilteringProxy._(this._server, this.upstream);

  final HttpServer _server;
  final String upstream;
  final HttpClient _client = HttpClient();

  /// `get_live_streams` / `get_vod_streams` / `get_series` ids to hide.
  final Set<String> hiddenLive = {};
  final Set<String> hiddenMovies = {};
  final Set<String> hiddenSeries = {};

  /// `category_id`s hidden from `get_live_categories`.
  final Set<String> hiddenLiveCategories = {};

  /// `get_vod_streams` stream id → new name (an item changed upstream).
  final Map<String, String> renamedMovies = {};

  /// Answer the bulk `get_live_streams` (no category) with HTTP 500.
  bool failBulkLive = false;

  /// Actions answered with HTTP 500 (bulk and per category).
  final Set<String> failingActions = {};

  final List<String> actions = [];

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<FilteringProxy> start(String upstream) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = FilteringProxy._(server, upstream);
    server.listen(proxy._handle);
    return proxy;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final uri = request.uri;
      final action = uri.queryParameters['action'];
      if (action != null) actions.add(action);
      if (failingActions.contains(action) ||
          (failBulkLive &&
              action == 'get_live_streams' &&
              !uri.queryParameters.containsKey('category_id'))) {
        request.response.statusCode = 500;
        request.response.write('Internal Server Error');
        await request.response.close();
        return;
      }
      final upstreamRequest = await _client.getUrl(
        Uri.parse('$upstream${uri.toString()}'),
      );
      upstreamRequest.followRedirects = false;
      final ua = request.headers.value(HttpHeaders.userAgentHeader);
      if (ua != null) {
        upstreamRequest.headers.set(HttpHeaders.userAgentHeader, ua);
      }
      final upstreamResponse = await upstreamRequest.close();
      request.response.statusCode = upstreamResponse.statusCode;
      final type = upstreamResponse.headers.contentType;
      if (type != null) request.response.headers.contentType = type;
      final hidden = switch (action) {
        'get_live_streams' => (hiddenLive, 'stream_id'),
        'get_vod_streams' => (hiddenMovies, 'stream_id'),
        'get_series' => (hiddenSeries, 'series_id'),
        'get_live_categories' => (hiddenLiveCategories, 'category_id'),
        _ => null,
      };
      final rename = action == 'get_vod_streams' && renamedMovies.isNotEmpty;
      if ((hidden == null || hidden.$1.isEmpty) && !rename) {
        await request.response.addStream(upstreamResponse);
      } else {
        final body = await utf8.decodeStream(upstreamResponse);
        final list = jsonDecode(body) as List<Object?>;
        if (hidden != null) {
          list.removeWhere(
            (item) => item is Map && hidden.$1.contains('${item[hidden.$2]}'),
          );
        }
        if (rename) {
          for (final item in list) {
            final name = item is Map
                ? renamedMovies['${item['stream_id']}']
                : null;
            if (name != null) (item as Map)['name'] = name;
          }
        }
        request.response.write(jsonEncode(list));
      }
      await request.response.close();
    } on Object {
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } on Object {
        // The client went away.
      }
    }
  }

  Future<void> stop() async {
    _client.close(force: true);
    await _server.close(force: true);
  }
}
