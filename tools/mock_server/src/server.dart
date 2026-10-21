/// The Carina mock IPTV server (Xtream Codes API, streams, EPG, M3U and
/// failure endpoints) built on shelf.
///
/// ```dart
/// final server = await MockServer.start(port: 0, mediaDir: 'tools/mock_server/media');
/// print(server.baseUrl); // http://127.0.0.1:54321
/// await server.stop();
/// ```
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'catalog.dart';
import 'epg.dart';
import 'm3u.dart';
import 'media.dart';
import 'xtream.dart';

export 'catalog.dart';
export 'xtream.dart' show MockAccount, accountFor;

/// One logged request.
final class MockRequest {
  MockRequest({
    required this.time,
    required this.method,
    required this.path,
    this.userAgent,
    this.referer,
    this.range,
  });

  final DateTime time;
  final String method;

  /// Path and query as requested (`/live/carina/test123/1001.ts`).
  final String path;
  final String? userAgent;
  final String? referer;
  final String? range;
  int? status;

  /// Extra diagnostics (for example how a timeshift start was matched).
  String? note;

  Map<String, Object?> toJson() => {
    'time': time.toUtc().toIso8601String(),
    'method': method,
    'path': path,
    'status': status,
    if (userAgent != null) 'user_agent': userAgent,
    if (referer != null) 'referer': referer,
    if (range != null) 'range': range,
    if (note != null) 'note': note,
  };
}

const _logCapacity = 2000;
const _noteKey = 'carina_mock.note';
const _emptySectionsKey = 'carina_mock.empty_sections';

const _failureKinds = <String>[
  'empty', 'html', 'slow', '401', 'notm3u', 'badxml', 'emptysection', //
  'redirect', '500',
];

/// The mock server.
final class MockServer {
  MockServer._(
    this._server,
    this._clock, {
    required this.catalog,
    required this.baseUrl,
    required this.media,
    required this.slowDelay,
    required this.dropAfter,
    required this.liveBurst,
  }) : _api = XtreamApi(catalog),
       _startedAt = DateTime.now();

  /// Starts the server. Use `port: 0` for an ephemeral port (tests).
  ///
  /// [liveDir] defaults to the `live` folder next to [mediaDir]. The test
  /// hooks [slowDelay], [dropAfter] and [liveBurst] default to the documented
  /// behaviour (30 s, 10 s, 2 s); [clock] overrides "now" for the guide and
  /// `server_info`.
  static Future<MockServer> start({
    int port = 8787,
    MockScale scale = MockScale.small,
    required String mediaDir,
    String? liveDir,
    InternetAddress? address,
    Duration slowDelay = const Duration(seconds: 30),
    Duration dropAfter = const Duration(seconds: 10),
    Duration liveBurst = const Duration(seconds: 2),
    DateTime Function()? clock,
    bool warmUp = true,
  }) async {
    final now = clock ?? DateTime.now;
    final catalog = MockCatalog.generate(scale, now: now());
    final bindAddress = address ?? InternetAddress.loopbackIPv4;
    final http = await HttpServer.bind(bindAddress, port);
    http.autoCompress = false;
    http.idleTimeout = const Duration(seconds: 120);
    // Real panels (nginx + PHP) do not send dart:io's security headers.
    http.defaultResponseHeaders.clear();
    final media = MediaLibrary(
      mediaDir: mediaDir,
      liveDir: liveDir ?? _siblingLiveDir(mediaDir),
    );
    final server = MockServer._(
      http,
      now,
      catalog: catalog,
      baseUrl: 'http://${_hostFor(bindAddress)}:${http.port}',
      media: media,
      slowDelay: slowDelay,
      dropAfter: dropAfter,
      liveBurst: liveBurst,
    );
    server._listen();
    if (warmUp && scale == MockScale.large) {
      Timer(Duration.zero, () {
        if (!server._closed) server._api.warmUp(server.baseUrl);
      });
    }
    return server;
  }

  final HttpServer _server;
  final DateTime Function() _clock;
  final XtreamApi _api;
  final DateTime _startedAt;
  final _log = ListQueue<MockRequest>();
  final _gzCache = <String, Uint8List>{};
  var _closed = false;

  final MockCatalog catalog;

  /// `http://127.0.0.1:<port>` (no trailing slash).
  final String baseUrl;
  final MediaLibrary media;
  final Duration slowDelay;
  final Duration dropAfter;
  final Duration liveBurst;

  int get port => _server.port;

  /// Request paths (with query), newest last, at most 2,000.
  List<String> get requestLog => List.unmodifiable(_log.map((r) => r.path));

  /// Detailed request log, newest last.
  List<MockRequest> get requests => List.unmodifiable(_log);

  void clearRequestLog() => _log.clear();

  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    await _server.close(force: true);
  }

  static String _hostFor(InternetAddress a) {
    if (a.isLoopback) {
      return a.type == InternetAddressType.IPv6 ? '[::1]' : '127.0.0.1';
    }
    if (a == InternetAddress.anyIPv4 || a == InternetAddress.anyIPv6) {
      return '127.0.0.1';
    }
    return a.type == InternetAddressType.IPv6 ? '[${a.address}]' : a.address;
  }

  static String _siblingLiveDir(String mediaDir) {
    var dir = mediaDir;
    while (dir.length > 1 && (dir.endsWith('/') || dir.endsWith(r'\'))) {
      dir = dir.substring(0, dir.length - 1);
    }
    final cut = dir.lastIndexOf(RegExp(r'[/\\]'));
    final parent = cut <= 0 ? '.' : dir.substring(0, cut);
    return joinPath(parent, 'live');
  }

  void _listen() {
    final handler = const Pipeline()
        .addMiddleware(_logRequests)
        .addMiddleware(_catchErrors)
        .addHandler(_dispatch);
    runZonedGuarded(
      () {
        _server.listen((request) {
          shelf_io.handleRequest(
            request,
            handler,
            poweredByHeader: 'Carina mock server',
          );
        });
      },
      (error, stack) {
        // Clients closing a stream (zapping) is normal.
        if (error is SocketException || error is HttpException) return;
        stderr.writeln('mock_server: unexpected error: $error\n$stack');
      },
    );
  }

  // ------------------------------------------------------------ middleware

  Handler _logRequests(Handler inner) => (request) async {
    final uri = request.requestedUri;
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final skip = uri.path.startsWith('/mock/');
    MockRequest? entry;
    if (!skip) {
      entry = MockRequest(
        time: DateTime.now(),
        method: request.method,
        path: path,
        userAgent: request.headers['user-agent'],
        referer: request.headers['referer'],
        range: request.headers['range'],
      );
      _log.addLast(entry);
      while (_log.length > _logCapacity) {
        _log.removeFirst();
      }
    }
    final response = await inner(request);
    if (entry != null) {
      entry.status = response.statusCode;
      final note = response.context[_noteKey];
      if (note is String) entry.note = note;
    }
    return response;
  };

  Handler _catchErrors(Handler inner) => (request) async {
    try {
      return await inner(request);
    } catch (error, stack) {
      stderr.writeln(
        'mock_server: ${request.method} ${request.requestedUri.path}: $error\n$stack',
      );
      return textResponse(500, 'Mock server error: $error');
    }
  };

  Future<Response> _dispatch(Request request) async {
    final segments = request.url.pathSegments;
    if (segments.isNotEmpty && segments.first == 'fail') {
      return _failure(request);
    }
    return _router.call(request);
  }

  // ----------------------------------------------------------------- routes

  late final Router _router = Router(notFoundHandler: _notFound)
    ..get('/', _index)
    ..get('/player_api.php', _playerApi)
    ..post('/player_api.php', _playerApi)
    ..get('/xmltv.php', _xmltvPhp)
    ..get('/epg.xml', _epgXml)
    ..get('/epg.xml.gz', _epgXmlGz)
    ..get('/get.php', _getPhp)
    ..get('/playlist.m3u', _playlist)
    ..get('/playlist.m3u8', _playlist)
    ..get('/live/<u>/<p>/<file>', _live)
    ..get('/movie/<u>/<p>/<file>', _movie)
    ..get('/series/<u>/<p>/<file>', _episode)
    ..get('/timeshift/<u>/<p>/<duration>/<start>/<file>', _timeshift)
    ..get('/streaming/timeshift.php', _timeshiftPhp)
    ..get(
      '/hls/<name>',
      (Request r, String name) => media.hlsSegment(r, _decode(name)),
    )
    ..get(
      '/img/<name>',
      (Request r, String name) => media.image(r, _decode(name)),
    )
    ..get('/direct/live/<file>', _directLive)
    ..get('/direct/movie/<file>', _directMovie)
    ..get('/fs/<name>/<file>', _flussonic)
    ..get('/secure/<kind>/<file>', _secure)
    ..get('/vod/<file>', _plainVod)
    ..get('/drm/<file>', _drm)
    ..get('/mock/health', _health)
    ..get('/mock/requests', _requests)
    ..delete('/mock/requests', (Request r) {
      clearRequestLog();
      return _json({'cleared': true});
    });

  Response _notFound(Request request) => textResponse(
    404,
    'Not found: /${request.url.path}\nSee $baseUrl/ for the list of endpoints.',
  );

  static String _decode(String s) {
    try {
      return Uri.decodeComponent(s);
    } on ArgumentError {
      return s;
    }
  }

  String _origin(Request request) {
    try {
      return request.requestedUri.origin;
    } on StateError {
      return baseUrl;
    }
  }

  Response _json(Object? value, {int status = 200}) => Response(
    status,
    body: jsonUtf8.convert(value),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// Query parameters, merged with a form body for POST requests.
  Future<Map<String, String>> _params(Request request) async {
    final params = Map<String, String>.of(request.url.queryParameters);
    if (request.method == 'POST') {
      final body = await request.readAsString();
      if (body.isNotEmpty) {
        try {
          params.addAll(Uri.splitQueryString(body));
        } on FormatException {
          // Ignore a body that is not form-encoded.
        }
      }
    }
    return params;
  }

  Response _index(Request request) {
    final o = _origin(request);
    return textResponse(200, '''
Carina mock IPTV server (${catalog.scale.name}: ${catalog.channels.length} live, ${catalog.movies.length} movies, ${catalog.series.length} series)

Xtream API    $o/player_api.php?username=carina&password=test123[&action=...]
XMLTV         $o/xmltv.php?username=carina&password=test123  |  $o/epg.xml  |  $o/epg.xml.gz
M3U           $o/get.php?username=carina&password=test123&type=m3u_plus&output=ts  |  $o/playlist.m3u
Streams       /live/u/p/<id>.ts|.m3u8  /movie/u/p/<id>.<ext>  /series/u/p/<id>.<ext>
Catch-up      /timeshift/u/p/<minutes>/<YYYY-MM-DD:HH-MM>/<id>.ts  /streaming/timeshift.php?...
Images        /img/<file>
Failures      /fail/<kind>/... with kind = ${_failureKinds.join(', ')}
Diagnostics   /mock/health  /mock/requests (DELETE clears)
Accounts      carina/test123 (active), expired/test123 (expired), anything else 401
''');
  }

  // ------------------------------------------------------------ Xtream API

  Future<Response> _playerApi(Request request) async {
    final params = await _params(request);
    final username = params['username'] ?? '';
    final password = params['password'] ?? '';
    final account = accountFor(username, password);
    final result = _api.handle(
      account: account,
      username: username,
      password: password,
      action: params['action'],
      params: params,
      origin: _origin(request),
      requestedUri: request.requestedUri,
      now: _clock(),
      emptySections: request.context[_emptySectionsKey] == true,
    );
    return Response(
      result.status,
      body: result.body,
      headers: {
        'content-type': result.html
            ? 'text/html; charset=UTF-8'
            : 'application/json; charset=utf-8',
        'access-control-allow-origin': '*',
      },
    );
  }

  Response? _credentialProblem(MockAccount account) => switch (account) {
    MockAccount.active => null,
    MockAccount.expired => textResponse(403, 'Account expired'),
    MockAccount.invalid => textResponse(401, 'Invalid username or password'),
  };

  // ------------------------------------------------------------------- EPG

  Response _xmlStream(Request request) => Response.ok(
    xmltvStream(catalog: catalog, origin: _origin(request), now: _clock()),
    headers: {'content-type': 'application/xml; charset=utf-8'},
    context: {'shelf.io.buffer_output': false},
  );

  Response _xmltvPhp(Request request) {
    final q = request.url.queryParameters;
    final problem = _credentialProblem(
      accountFor(q['username'], q['password']),
    );
    return problem ?? _xmlStream(request);
  }

  Response _epgXml(Request request) => _xmlStream(request);

  Response _epgXmlGz(Request request) {
    final origin = _origin(request);
    final anchor = epgAnchor(_clock());
    final key = '$origin|${anchor.millisecondsSinceEpoch}';
    final cached = _gzCache[key];
    const headers = {
      'content-type': 'application/gzip',
      'content-disposition': 'attachment; filename="epg.xml.gz"',
    };
    if (cached != null) {
      return Response.ok(cached, headers: headers);
    }
    return Response.ok(
      _gzipAndCache(
        key,
        xmltvStream(catalog: catalog, origin: origin, now: _clock()),
      ),
      headers: headers,
      context: {'shelf.io.buffer_output': false},
    );
  }

  Stream<List<int>> _gzipAndCache(String key, Stream<List<int>> xml) async* {
    final builder = BytesBuilder();
    await for (final chunk in xml.transform(gzip.encoder)) {
      builder.add(chunk);
      yield chunk;
    }
    if (_gzCache.length > 4) _gzCache.clear();
    _gzCache[key] = builder.takeBytes();
  }

  // ------------------------------------------------------------------- M3U

  Response _getPhp(Request request) {
    final q = request.url.queryParameters;
    final username = q['username'] ?? '';
    final password = q['password'] ?? '';
    final account = accountFor(username, password);
    if (account == MockAccount.invalid) return Response(401);
    if (account == MockAccount.expired) {
      return textResponse(403, 'Account expired');
    }
    final type = q['type'] ?? 'm3u_plus';
    return Response.ok(
      xtreamExport(
        catalog: catalog,
        origin: _origin(request),
        username: username,
        password: password,
        plus: type != 'm3u',
        output: q['output'] ?? 'ts',
      ),
      headers: {
        'content-type': 'audio/x-mpegurl; charset=utf-8',
        'content-disposition':
            'attachment; filename="tv_channels_$username.m3u"',
      },
      context: {'shelf.io.buffer_output': false},
    );
  }

  Response _playlist(Request request) => Response.ok(
    extendedPlaylist(catalog: catalog, origin: _origin(request)),
    headers: {'content-type': 'audio/x-mpegurl; charset=utf-8'},
    context: {'shelf.io.buffer_output': false},
  );

  // --------------------------------------------------------------- streams

  /// `1001.ts` → (1001, 'ts'); `1001` → (1001, null).
  static (int?, String?) _idAndExt(String file) {
    final name = _decode(file);
    final dot = name.lastIndexOf('.');
    final idPart = dot < 0 ? name : name.substring(0, dot);
    final ext = dot < 0 ? null : name.substring(dot + 1).toLowerCase();
    return (int.tryParse(idPart), ext);
  }

  Future<Response> _live(
    Request request,
    String u,
    String p,
    String file,
  ) async {
    final problem = _credentialProblem(accountFor(_decode(u), _decode(p)));
    if (problem != null) return problem;
    final (id, ext) = _idAndExt(file);
    return _liveChannel(request, id, ext, viaPath: '/live/$u/$p/');
  }

  Future<Response> _liveChannel(
    Request request,
    int? id,
    String? ext, {
    required String viaPath,
  }) async {
    final channel = id == null ? null : catalog.channelById(id);
    if (channel == null) {
      return textResponse(404, 'Unknown live stream id: ${id ?? '?'}');
    }
    if (channel.behavior == LiveBehavior.notFound) {
      return textResponse(
        404,
        'Stream ${channel.streamId} is offline (deliberate 404 test channel).',
      );
    }
    final utc = request.url.queryParameters['utc'];
    if (utc != null) {
      // catchup="append" / "shift": `?utc={utc}&lutc={lutc}` on the live URL.
      final seconds = int.tryParse(utc);
      if (seconds == null) return textResponse(400, 'Bad utc parameter: $utc');
      return _archive(
        request,
        channel,
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
        null,
      );
    }
    if (ext == 'm3u8') return media.hlsPlaylist();
    if (channel.variant == LiveVariant.hls) {
      final query = request.url.hasQuery ? '?${request.url.query}' : '';
      return Response.found('$viaPath${channel.streamId}.m3u8$query');
    }
    return media.liveTs(
      channel.variant.tsFile!,
      burst: liveBurst,
      dropAfter: channel.behavior == LiveBehavior.dropAfter ? dropAfter : null,
      isClosed: () => _closed,
    );
  }

  Future<Response> _movie(
    Request request,
    String u,
    String p,
    String file,
  ) async {
    final problem = _credentialProblem(accountFor(_decode(u), _decode(p)));
    if (problem != null) return problem;
    final (id, _) = _idAndExt(file);
    final movie = id == null ? null : catalog.movieById(id);
    if (movie == null) {
      return textResponse(404, 'Unknown movie id: ${id ?? '?'}');
    }
    return media.serveMedia(request, movie.mediaFile);
  }

  Future<Response> _episode(
    Request request,
    String u,
    String p,
    String file,
  ) async {
    final problem = _credentialProblem(accountFor(_decode(u), _decode(p)));
    if (problem != null) return problem;
    final (id, _) = _idAndExt(file);
    final episode = id == null ? null : catalog.episodeById(id);
    if (episode == null) {
      return textResponse(404, 'Unknown episode id: ${id ?? '?'}');
    }
    return media.serveMedia(request, episode.mediaFile);
  }

  Future<Response> _directLive(Request request, String file) async {
    final (id, ext) = _idAndExt(file);
    return _liveChannel(request, id, ext, viaPath: '/direct/live/');
  }

  Future<Response> _directMovie(Request request, String file) async {
    final (id, _) = _idAndExt(file);
    final movie = id == null ? null : catalog.movieById(id);
    if (movie == null) {
      return textResponse(404, 'Unknown movie id: ${id ?? '?'}');
    }
    return media.serveMedia(request, movie.mediaFile);
  }

  Future<Response> _plainVod(Request request, String file) async {
    final name = _decode(file).toLowerCase();
    if (name.endsWith('.mp4')) {
      return media.serveMedia(request, MockMedia.h264Aac720p50Mp4);
    }
    if (name.endsWith('.mkv')) {
      return media.serveMedia(request, MockMedia.vodTracksMkv);
    }
    return textResponse(404, 'Unknown VOD file: $name');
  }

  Response _drm(Request request, String file) => textResponse(
    403,
    'DRM-protected test entry (#KODIPROP license key): clients should mark '
    'it as unsupported instead of playing it.',
  );

  Future<Response> _secure(Request request, String kind, String file) async {
    final (id, ext) = _idAndExt(file);
    final ua = request.headers['user-agent'] ?? '';
    final referer = request.headers['referer'] ?? '';
    final origin = _origin(request);
    if (kind != 'ua' && kind != 'referer' && kind != 'headers') {
      return textResponse(404, 'Unknown secure kind: $kind');
    }
    final needUa = kind == 'ua' || kind == 'headers';
    final needReferer = kind == 'referer' || kind == 'headers';
    final missing = <String>[
      if (needUa && !ua.contains('CarinaMock/1.0'))
        'User-Agent: CarinaMock/1.0 (got "$ua")',
      if (needReferer && !referer.startsWith(origin))
        'Referer: $origin/ (got "$referer")',
    ];
    if (missing.isNotEmpty) {
      return textResponse(
        403,
        'Missing required header(s): ${missing.join('; ')}',
      );
    }
    return _liveChannel(request, id, ext, viaPath: '/secure/$kind/');
  }

  // --------------------------------------------------------------- archive

  static final _startPattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[:_ T](\d{2})[-:](\d{2})(?:[-:](\d{2}))?$',
  );

  /// Parses `YYYY-MM-DD:HH-MM` in the server time zone (+03:00) to UTC.
  static DateTime? _parseServerTime(String raw) {
    final m = _startPattern.firstMatch(raw.trim());
    if (m == null) return null;
    final local = DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    );
    return local.subtract(MockFixtures.utcOffset);
  }

  Future<Response> _timeshift(
    Request request,
    String u,
    String p,
    String duration,
    String start,
    String file,
  ) async {
    final problem = _credentialProblem(accountFor(_decode(u), _decode(p)));
    if (problem != null) return problem;
    final (id, _) = _idAndExt(file);
    return _timeshiftFor(
      request,
      id,
      _decode(start),
      int.tryParse(_decode(duration)),
    );
  }

  Future<Response> _timeshiftPhp(Request request) async {
    final q = request.url.queryParameters;
    final problem = _credentialProblem(
      accountFor(q['username'], q['password']),
    );
    if (problem != null) return problem;
    return _timeshiftFor(
      request,
      int.tryParse(q['stream'] ?? ''),
      q['start'] ?? '',
      int.tryParse(q['duration'] ?? ''),
    );
  }

  Future<Response> _timeshiftFor(
    Request request,
    int? id,
    String start,
    int? durationMinutes,
  ) async {
    final channel = id == null ? null : catalog.channelById(id);
    if (channel == null) {
      return textResponse(404, 'Unknown live stream id: ${id ?? '?'}');
    }
    final startUtc = _parseServerTime(start);
    if (startUtc == null) {
      return textResponse(
        400,
        'Bad start "$start" (expected YYYY-MM-DD:HH-MM in ${MockFixtures.timezone}).',
      );
    }
    if (durationMinutes == null ||
        durationMinutes <= 0 ||
        durationMinutes > 24 * 60) {
      return textResponse(400, 'Bad duration (minutes): $durationMinutes');
    }
    return _archive(request, channel, startUtc, durationMinutes);
  }

  Future<Response> _archive(
    Request request,
    MockChannel channel,
    DateTime startUtc,
    int? durationMinutes,
  ) async {
    final now = _clock().toUtc();
    if (channel.archiveDays <= 0) {
      return textResponse(
        404,
        'Channel ${channel.streamId} has no archive (tv_archive = 0).',
      );
    }
    // A few hours of tolerance so a client that mixes up UTC and server
    // time still plays; the request note says what was matched.
    final earliest = now.subtract(
      Duration(days: channel.archiveDays, hours: 3),
    );
    if (startUtc.isBefore(earliest)) {
      return textResponse(
        404,
        'Start ${startUtc.toIso8601String()} is outside the ${channel.archiveDays}-day archive of channel ${channel.streamId}.',
      );
    }
    if (startUtc.isAfter(now.add(const Duration(hours: 3)))) {
      return textResponse(
        404,
        'Start ${startUtc.toIso8601String()} is in the future.',
      );
    }
    final response = await media.serveMedia(
      request,
      channel.variant.archiveFile,
      headers: const {'content-type': 'video/mp2t'},
    );
    return response.change(
      context: {_noteKey: _archiveNote(channel, startUtc, durationMinutes)},
    );
  }

  String _archiveNote(
    MockChannel channel,
    DateTime startUtc,
    int? durationMinutes,
  ) {
    final local = serverTimeString(startUtc.millisecondsSinceEpoch);
    final epg = channel.xmltvId == null
        ? null
        : catalog.epgChannelById(channel.xmltvId!);
    if (epg == null) {
      return 'archive start $local (+03:00); channel has no guide';
    }
    final generator = EpgGenerator(rich: catalog.scale == MockScale.small);
    final ms = startUtc.millisecondsSinceEpoch;
    String? match;
    generator.forEach(epg, ms - 60000, ms + 60000, (p) {
      if ((p.startMs - ms).abs() <= 60000) match ??= p.title;
    });
    final duration = durationMinutes == null ? '' : ', $durationMinutes min';
    return match == null
        ? 'archive start $local (+03:00)$duration does not match a programme start'
        : 'archive start $local (+03:00)$duration matches "$match"';
  }

  // ------------------------------------------------------------- flussonic

  static final _fsRange = RegExp(
    r'^(?:index|video|archive|mono)-(\d+)-(\d+)\.(m3u8|ts)$',
  );
  static final _fsAbs = RegExp(r'^timeshift_abs-(\d+)\.ts$');
  static final _fsRel = RegExp(r'^timeshift_rel-(\d+)\.ts$');

  Future<Response> _flussonic(Request request, String name, String file) async {
    final channelName = _decode(name);
    final id = channelName.startsWith('ch')
        ? int.tryParse(channelName.substring(2))
        : null;
    final channel = id == null ? null : catalog.channelById(id);
    if (channel == null) {
      return textResponse(404, 'Unknown flussonic stream: $channelName');
    }
    final f = _decode(file);
    if (f == 'mpegts') {
      return _liveChannel(request, id, 'ts', viaPath: '/live/carina/test123/');
    }
    if (f == 'index.m3u8' || f == 'video.m3u8' || f == 'mono.m3u8') {
      return media.hlsPlaylist();
    }
    final abs = _fsAbs.firstMatch(f);
    if (abs != null) {
      final utc = int.parse(abs.group(1)!);
      return _archive(
        request,
        channel,
        DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true),
        null,
      );
    }
    final rel = _fsRel.firstMatch(f);
    if (rel != null) {
      final back = int.parse(rel.group(1)!);
      return _archive(
        request,
        channel,
        _clock().toUtc().subtract(Duration(seconds: back)),
        null,
      );
    }
    final range = _fsRange.firstMatch(f);
    if (range != null) {
      final utc = int.parse(range.group(1)!);
      final seconds = int.parse(range.group(2)!);
      if (range.group(3) == 'ts') {
        return _archive(
          request,
          channel,
          DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true),
          seconds ~/ 60,
        );
      }
      final segment = '/fs/$channelName/archive-$utc-$seconds.ts';
      return Response.ok(
        '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-PLAYLIST-TYPE:VOD\n'
        '#EXT-X-TARGETDURATION:$seconds\n#EXT-X-MEDIA-SEQUENCE:0\n'
        '#EXTINF:$seconds.0,\n$segment\n#EXT-X-ENDLIST\n',
        headers: {'content-type': 'application/vnd.apple.mpegurl'},
      );
    }
    return textResponse(404, 'Unknown flussonic path: $f');
  }

  // --------------------------------------------------------------- failure

  Future<Response> _failure(Request request) async {
    final segments = request.url.pathSegments;
    final kind = segments.length > 1 ? segments[1] : '';
    final rest = segments.length > 2 ? segments.sublist(2).join('/') : '';
    final isApi = rest.endsWith('player_api.php');
    Request inner() => request.change(path: 'fail/$kind/');
    if (rest.isEmpty &&
        (kind == 'slow' || kind == 'emptysection' || kind == 'redirect')) {
      return textResponse(
        404,
        'Add the endpoint after /fail/$kind/ (for example /fail/$kind/player_api.php).',
      );
    }
    switch (kind) {
      case 'empty':
        return Response.ok(
          const <int>[],
          headers: {
            'content-type': 'text/html; charset=UTF-8',
            'content-length': '0',
          },
        );
      case 'html':
        return Response.ok(
          _htmlErrorPage,
          headers: {'content-type': 'text/html; charset=UTF-8'},
        );
      case 'slow':
        await Future<void>.delayed(slowDelay);
        if (_closed) return textResponse(503, 'Server stopping');
        return _router.call(inner());
      case '401':
        if (isApi) {
          return Response(
            401,
            body: '{"user_info":{"auth":0}}',
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return textResponse(401, 'Unauthorized');
      case 'notm3u':
        return Response.ok(
          _notM3u,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      case 'badxml':
        return Response.ok(
          await _truncatedXml(request),
          headers: {'content-type': 'application/xml; charset=utf-8'},
        );
      case 'emptysection':
        return _router.call(inner().change(context: {_emptySectionsKey: true}));
      case 'redirect':
        final query = request.url.hasQuery ? '?${request.url.query}' : '';
        return Response.found('/$rest$query');
      case '500':
        return textResponse(500, 'Internal Server Error (deliberate)');
      default:
        return textResponse(
          404,
          'Unknown failure kind "$kind". Available: ${_failureKinds.join(', ')}',
        );
    }
  }

  static const _htmlErrorPage = '''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Service Temporarily Unavailable</title></head>
<body>
<center><h1>503 Service Temporarily Unavailable</h1></center>
<p>The panel is under maintenance. Please try again later.</p>
<hr><center>nginx</center>
</body>
</html>
''';

  static const _notM3u =
      '''Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Bu bir çalma listesi değil; rastgele bir metin dosyası.
<<< 4f2a 91be 77c0 >>>
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
{"status": "maintenance", "retry_after": 3600}
''';

  Future<String> _truncatedXml(Request request) async {
    final b = StringBuffer();
    await for (final chunk in xmltvStream(
      catalog: catalog,
      origin: _origin(request),
      now: _clock(),
      chunkSize: 8192,
    )) {
      b.write(utf8.decode(chunk, allowMalformed: true));
      final text = b.toString();
      final first = text.indexOf('<programme ');
      if (first >= 0 && text.length - first > 4000) break;
    }
    final s = b.toString();
    final first = s.indexOf('<programme ');
    if (first < 0) return s.substring(0, s.length ~/ 2);
    // Cut in the middle of the tenth programme element.
    var cut = first;
    for (var i = 0; i < 9; i++) {
      final next = s.indexOf('<programme ', cut + 1);
      if (next < 0) break;
      cut = next;
    }
    return s.substring(0, cut + 37);
  }

  // ----------------------------------------------------------- diagnostics

  Response _health(Request request) {
    final mediaStatus = <String, bool>{
      for (final f in MockMedia.allFiles) f: media.file(f).existsSync(),
    };
    final imageDir = Directory(media.imageDir);
    final images = <String, int>{
      'poster': 0,
      'backdrop': 0,
      'logo': 0,
      'still': 0,
    };
    if (imageDir.existsSync()) {
      for (final e in imageDir.listSync()) {
        final name = e.uri.pathSegments.isEmpty ? '' : e.uri.pathSegments.last;
        for (final key in images.keys.toList()) {
          if (name.startsWith('${key}_')) images[key] = images[key]! + 1;
        }
      }
    }
    final hls = media.hlsStatus();
    return _json({
      'ok': true,
      'scale': catalog.scale.name,
      'base_url': baseUrl,
      'uptime_seconds': DateTime.now().difference(_startedAt).inSeconds,
      'counts': {
        'live': catalog.channels.length,
        'vod': catalog.movies.length,
        'series': catalog.series.length,
        'episodes': catalog.episodeCount,
        'live_categories': catalog.liveCategories.length,
        'vod_categories': catalog.vodCategories.length,
        'series_categories': catalog.seriesCategories.length,
        'epg_channels': catalog.epgChannels.length,
      },
      'media_dir': media.mediaDir,
      'media': mediaStatus,
      'images': images,
      'hls': {
        'path': hls.path,
        'exists': hls.exists,
        'running': hls.fresh,
        'age_seconds': hls.ageSeconds,
      },
      'requests_logged': _log.length,
    });
  }

  Response _requests(Request request) {
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '');
    final all = _log.toList();
    final list = limit == null || limit >= all.length
        ? all
        : all.sublist(all.length - limit);
    return _json({
      'count': _log.length,
      'requests': [for (final r in list) r.toJson()],
    });
  }
}
