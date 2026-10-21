/// The tiny HTTP server behind "Add from phone": the TV serves one mobile
/// page and accepts one playlist from it. No Flutter widgets in here, so it
/// is unit-tested with real sockets on loopback.
///
/// Safety model (the wire is plain HTTP on the home network, so the token is
/// the only secret):
/// - the server is bound to the given LAN address only, on a random port,
///   and every path carries a random one-time token;
/// - it lives until the first accepted submission, [close], or [lifetime];
/// - request bodies are capped; credentials are never logged.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/foundation.dart';

import 'package:carina/data/db/database.dart' show PlaylistType;
import 'package:carina/data/sources/m3u/m3u_detect.dart'
    show detectXtreamExport;
import 'package:carina/features/playlists/data/wizard_form.dart';

/// How long the server accepts a submission.
const Duration phoneSetupLifetime = Duration(minutes: 10);

/// The largest request body accepted (a form of a few short fields).
const int phoneSetupMaxBodyBytes = 16 * 1024;

/// The longest value of one field.
const int phoneSetupMaxFieldLength = 2048;

/// What the UI needs from a running server (a fake in widget tests).
abstract interface class PhoneSetupHandle {
  /// The address the phone opens (and the QR code carries).
  Uri get url;

  /// Stops the server. Safe to call twice.
  Future<void> close();
}

/// Serves [page] on `/<token>` and takes the playlist POSTed to the same
/// path as JSON:
/// `{"type": "xtream" | "m3u", "name", "server", "username", "password",
/// "playlistUrl", "epgUrl"}` (strings; all but `type` optional).
///
/// The fields go through the wizard's own [WizardValues.validate]. Problems
/// answer `422 {"ok": false, "errors": {"<field>": "<problem>"}}` and the
/// server stays open for another try; a valid form answers `200
/// {"ok": true}`, calls `onSubmitted` once and shuts the server down. Every
/// request after that gets 410.
class PhoneSetupServer implements PhoneSetupHandle {
  PhoneSetupServer._(
    this._server,
    this.token,
    this._page,
    this._onSubmitted,
    this._onExpired,
    this._maxBodyBytes,
    Duration lifetime,
  ) {
    // Read now: a closed HttpServer no longer knows its address.
    url;
    _timer = Timer(lifetime, _expire);
    _server.listen(_handle, onError: (Object _) {}, cancelOnError: false);
  }

  /// Binds [address] on a random free port.
  static Future<PhoneSetupServer> start({
    required InternetAddress address,
    required String page,
    required void Function(WizardValues values) onSubmitted,
    void Function()? onExpired,
    Duration lifetime = phoneSetupLifetime,
    int maxBodyBytes = phoneSetupMaxBodyBytes,
    Random? random,
  }) async {
    final server = await HttpServer.bind(address, 0);
    return PhoneSetupServer._(
      server,
      generateToken(random),
      page,
      onSubmitted,
      onExpired,
      maxBodyBytes,
      lifetime,
    );
  }

  /// 128 random bits, URL-safe.
  static String generateToken([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  final HttpServer _server;
  final String token;
  final String _page;
  final void Function(WizardValues values) _onSubmitted;
  final void Function()? _onExpired;
  final int _maxBodyBytes;
  late final Timer _timer;
  bool _accepted = false;
  bool _closed = false;

  @override
  late final Uri url = Uri(
    scheme: 'http',
    host: _server.address.address,
    port: _server.port,
    path: '/$token',
  );

  bool get isClosed => _closed;

  /// Whether a submission was accepted.
  bool get accepted => _accepted;

  /// Stops listening and drops open connections. Safe to call twice.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    await _server.close(force: true);
  }

  void _expire() {
    if (_closed) return;
    unawaited(close());
    _onExpired?.call();
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      await _route(request);
    } on Object catch (error) {
      // Never log the request: it can carry credentials.
      debugPrint('Add from phone request failed: ${error.runtimeType}');
      await _reply(request, HttpStatus.internalServerError, '');
    }
  }

  Future<void> _route(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.length != 1 || !_tokenMatches(segments.single)) {
      return _reply(request, HttpStatus.notFound, '');
    }
    if (_accepted) return _reply(request, HttpStatus.gone, '');
    switch (request.method) {
      case 'GET':
        return _reply(
          request,
          HttpStatus.ok,
          _page,
          contentType: ContentType.html,
          page: true,
        );
      case 'POST':
        return _submit(request);
      default:
        return _reply(request, HttpStatus.methodNotAllowed, '');
    }
  }

  /// Compares without stopping at the first different character.
  bool _tokenMatches(String candidate) {
    if (candidate.length != token.length) return false;
    var diff = 0;
    for (var i = 0; i < token.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ token.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _submit(HttpRequest request) async {
    final mime = request.headers.contentType?.mimeType;
    if (mime != 'application/json') {
      return _reply(request, HttpStatus.unsupportedMediaType, '');
    }
    final declared = request.contentLength;
    if (declared > _maxBodyBytes) {
      return _reply(request, HttpStatus.requestEntityTooLarge, '');
    }
    final body = BytesBuilder(copy: false);
    await for (final chunk in request) {
      body.add(chunk);
      if (body.length > _maxBodyBytes) {
        return _reply(request, HttpStatus.requestEntityTooLarge, '');
      }
    }
    final values = _parse(body.takeBytes());
    if (values == null) return _reply(request, HttpStatus.badRequest, '');
    final problems = values.validate();
    if (problems.isNotEmpty) {
      return _reply(
        request,
        HttpStatus.unprocessableEntity,
        jsonEncode({
          'ok': false,
          'errors': {
            for (final e in problems.entries) e.key.name: e.value.name,
          },
        }),
        contentType: ContentType.json,
      );
    }
    // Everything up to here is synchronous per request, so two racing posts
    // cannot both get through.
    if (_accepted || _closed) return _reply(request, HttpStatus.gone, '');
    _accepted = true;
    _timer.cancel();
    _onSubmitted(values);
    await _reply(
      request,
      HttpStatus.ok,
      jsonEncode({'ok': true}),
      contentType: ContentType.json,
    );
    // The response is flushed: the phone has its confirmation.
    unawaited(close());
  }

  /// The wizard values of a request body, or null when it is not the
  /// expected JSON.
  WizardValues? _parse(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final fields = json;
    String? text(String key) {
      final value = fields[key];
      if (value == null) return '';
      if (value is! String || value.length > phoneSetupMaxFieldLength) {
        return null;
      }
      return value;
    }

    final type = switch (fields['type']) {
      'xtream' => PlaylistType.xtream,
      'm3u' => PlaylistType.m3u,
      _ => null,
    };
    final name = text('name');
    var server = text('server');
    var username = text('username');
    var password = text('password');
    final playlistUrl = text('playlistUrl');
    final epgUrl = text('epgUrl');
    if (type == null ||
        name == null ||
        server == null ||
        username == null ||
        password == null ||
        playlistUrl == null ||
        epgUrl == null) {
      return null;
    }
    if (type == PlaylistType.xtream) {
      // A `get.php?username=…&password=…` link in Server fills all three
      // fields, as in the wizard.
      final export = detectXtreamExport(server);
      if (export != null) {
        server = export.server;
        username = export.username;
        password = export.password;
      }
    }
    return WizardValues(
      type: type,
      name: name.trim().isEmpty
          ? defaultPlaylistName(type, server: server, playlistUrl: playlistUrl)
          : name,
      server: type == PlaylistType.xtream ? server : '',
      username: type == PlaylistType.xtream ? username : '',
      password: type == PlaylistType.xtream ? password : '',
      playlistUrl: type == PlaylistType.m3u ? playlistUrl : '',
      epgText: epgUrl,
    );
  }

  Future<void> _reply(
    HttpRequest request,
    int status,
    String body, {
    ContentType? contentType,
    bool page = false,
  }) async {
    final response = request.response
      ..statusCode = status
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('Referrer-Policy', 'no-referrer')
      ..headers.set('X-Content-Type-Options', 'nosniff');
    if (contentType != null) response.headers.contentType = contentType;
    if (page) {
      response.headers.set(
        'Content-Security-Policy',
        "default-src 'none'; style-src 'unsafe-inline'; "
            "script-src 'unsafe-inline'; connect-src 'self'; "
            "base-uri 'none'; form-action 'none'",
      );
    }
    response.write(body);
    await response.close();
  }
}
