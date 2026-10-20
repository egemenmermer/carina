/// Turns channels, movies, episodes and catch-up programmes into playable URLs
/// with their HTTP headers.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../net/mask.dart';
import '../settings/settings_store.dart';
import '../sources/catchup/catchup.dart'
    show buildCatchupUrl, xtreamTimeshiftMinutes;
import '../sources/m3u/m3u_models.dart' show M3uHeader;
import '../sources/xtream/xtream_models.dart' show XtreamAccount;
import '../sources/xtream/xtream_urls.dart' show XtreamUrls, pickLiveExt;
import 'playlist_repository.dart';

/// The User-Agent of the "VLC" setting.
const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

/// A URL ready for the player. Credentials are part of [url]; log and show
/// [maskedUrl] only.
@immutable
class ResolvedStream {
  ResolvedStream({
    required this.url,
    Map<String, String> headers = const {},
    this.userAgent,
    this.referer,
    required this.isLive,
  }) : headers = Map.unmodifiable(headers),
       maskedUrl = maskUrl(url);

  final String url;

  /// Extra request headers (never `User-Agent` / `Referer`; those are
  /// [userAgent] and [referer]).
  final Map<String, String> headers;

  /// Null = the engine's default agent.
  final String? userAgent;
  final String? referer;

  /// Live TV (reconnects, live buffering). False for VOD and catch-up.
  final bool isLive;
  final String maskedUrl;

  @override
  bool operator ==(Object other) =>
      other is ResolvedStream &&
      other.url == url &&
      other.userAgent == userAgent &&
      other.referer == referer &&
      other.isLive == isLive &&
      _mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(url, userAgent, referer, isLive);

  /// Never prints the credentials.
  @override
  String toString() =>
      'ResolvedStream($maskedUrl${isLive ? ', live' : ''}'
      '${userAgent != null ? ', ua: $userAgent' : ''})';
}

/// Why a stream cannot be resolved.
enum StreamResolveError {
  /// The playlist no longer exists.
  playlistNotFound,

  /// Xtream server, username or password is missing.
  missingCredentials,

  /// An M3U item without a URL.
  noStreamUrl,

  /// DRM-protected entry (shown, but not playable).
  unsupported,

  /// The channel has no catch-up, or its catch-up template cannot be built.
  noCatchup,
}

class StreamResolveException implements Exception {
  const StreamResolveException(this.error, [this.message]);

  final StreamResolveError error;
  final String? message;

  @override
  String toString() =>
      'StreamResolveException(${error.name}'
      '${message == null ? '' : ', $message'})';
}

/// Builds [ResolvedStream]s.
///
/// * Xtream: URLs from the stored credentials ([XtreamUrls]); live streams
///   use the `liveOutputFormat` setting limited to the account's
///   `allowed_output_formats` ([pickLiveExt]); a usable `direct_source`
///   wins; catch-up is the `/timeshift/` URL in the server's time
///   (`serverUtcOffset`), with [catchupFallback] for `timeshift.php`.
/// * M3U: the stored `streamUrl` with the entry headers; catch-up via
///   [buildCatchupUrl] with the entry's mode and source (the `#EXTM3U`
///   header defaults when the entry has none).
/// * User-Agent: entry header > playlist custom agent > the `userAgentMode`
///   setting (`default` → null so the engine default applies, `vlc` →
///   [vlcUserAgent], `custom` → `userAgentCustom`). Referer: entry header >
///   the `referer` setting.
class StreamUrlResolver {
  StreamUrlResolver(
    this._playlists,
    this._settings, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PlaylistRepository _playlists;
  final SettingsStore _settings;
  final DateTime Function() _clock;

  /// A live channel.
  Future<ResolvedStream> live(int playlistId, ChannelRow channel) async {
    if (channel.unsupported) {
      throw const StreamResolveException(StreamResolveError.unsupported);
    }
    final ctx = await _context(playlistId);
    if (ctx.isXtream) {
      final urls = await _xtreamUrls(playlistId);
      final preferred = _settings.get(
        PlaylistSettings.liveOutputFormat,
        playlistId: playlistId,
      );
      final ext = pickLiveExt(
        ctx.account?.allowedOutputFormats ?? const [],
        preferred: preferred,
      );
      return _resolved(
        ctx,
        urls.live(
          channel.providerId,
          ext: ext,
          directSource: channel.directSource,
        ),
        channel.headersJson,
        isLive: true,
      );
    }
    return _resolved(
      ctx,
      _m3uUrl(channel.streamUrl),
      channel.headersJson,
      isLive: true,
    );
  }

  /// A movie.
  Future<ResolvedStream> movie(int playlistId, MovieRow movie) async {
    final ctx = await _context(playlistId);
    if (ctx.isXtream) {
      final urls = await _xtreamUrls(playlistId);
      return _resolved(
        ctx,
        urls.movie(
          movie.providerId,
          movie.containerExt ?? 'mp4',
          directSource: movie.directSource,
        ),
        movie.headersJson,
        isLive: false,
      );
    }
    return _resolved(
      ctx,
      _m3uUrl(movie.streamUrl),
      movie.headersJson,
      isLive: false,
    );
  }

  /// A series episode. (Episodes store no per-entry headers; the playlist
  /// and setting agents apply.)
  Future<ResolvedStream> episode(int playlistId, EpisodeRow episode) async {
    final ctx = await _context(playlistId);
    if (ctx.isXtream) {
      final urls = await _xtreamUrls(playlistId);
      return _resolved(
        ctx,
        urls.episode(
          episode.providerId,
          episode.containerExt ?? 'mp4',
          directSource: episode.directSource,
        ),
        null,
        isLive: false,
      );
    }
    return _resolved(ctx, _m3uUrl(episode.streamUrl), null, isLive: false);
  }

  /// Catch-up of the programme [startUtc]…[endUtc] (times as stored, with
  /// the EPG time shift applied). Throws [StreamResolveError.noCatchup]
  /// when the channel has no archive or no usable template.
  Future<ResolvedStream> catchup(
    int playlistId,
    ChannelRow channel,
    DateTime startUtc,
    DateTime endUtc,
  ) async {
    final ctx = await _context(playlistId);
    if (ctx.isXtream) {
      if (channel.archiveDays <= 0) {
        throw const StreamResolveException(StreamResolveError.noCatchup);
      }
      final urls = await _xtreamUrls(playlistId);
      return _resolved(
        ctx,
        urls.timeshift(
          channel.providerId,
          startUtc.toUtc(),
          xtreamTimeshiftMinutes(startUtc, endUtc),
          serverOffset: ctx.serverOffset,
        ),
        channel.headersJson,
        isLive: false,
      );
    }
    final streamUrl = _m3uUrl(channel.streamUrl);
    final header = ctx.header;
    final mode = channel.catchupType ?? header?.catchup;
    final source = channel.catchupSource ?? header?.catchupSource;
    final url = buildCatchupUrl(
      streamUrl: streamUrl,
      mode: mode ?? '',
      source: source,
      startUtc: startUtc.toUtc(),
      endUtc: endUtc.toUtc(),
      nowUtc: _clock().toUtc(),
      channelName: channel.name,
      serverOffset: ctx.serverOffset,
    );
    if (url == null) {
      throw StreamResolveException(
        StreamResolveError.noCatchup,
        'mode: ${mode ?? 'none'}',
      );
    }
    return _resolved(ctx, url, channel.headersJson, isLive: false);
  }

  /// The Xtream `streaming/timeshift.php` alternative to [catchup] (for a
  /// retry when the primary URL fails); null for M3U playlists.
  Future<ResolvedStream?> catchupFallback(
    int playlistId,
    ChannelRow channel,
    DateTime startUtc,
    DateTime endUtc,
  ) async {
    final ctx = await _context(playlistId);
    if (!ctx.isXtream || channel.archiveDays <= 0) return null;
    final urls = await _xtreamUrls(playlistId);
    return _resolved(
      ctx,
      urls.timeshiftFallback(
        channel.providerId,
        startUtc.toUtc(),
        xtreamTimeshiftMinutes(startUtc, endUtc),
        serverOffset: ctx.serverOffset,
      ),
      channel.headersJson,
      isLive: false,
    );
  }

  // -------------------------------------------------------------------------

  Future<_Context> _context(int playlistId) async {
    final row = await _playlists.get(playlistId);
    if (row == null) {
      throw const StreamResolveException(StreamResolveError.playlistNotFound);
    }
    return _Context(
      row,
      _playlists.account(row),
      row.type == PlaylistType.xtream ? null : _playlists.m3uHeader(row),
    );
  }

  Future<XtreamUrls> _xtreamUrls(int playlistId) async {
    final creds = await _playlists.xtreamCredentials(playlistId);
    if (creds == null) {
      throw const StreamResolveException(StreamResolveError.missingCredentials);
    }
    return XtreamUrls.fromCredentials(creds);
  }

  static String _m3uUrl(String? url) {
    final u = url?.trim();
    if (u == null || u.isEmpty) {
      throw const StreamResolveException(StreamResolveError.noStreamUrl);
    }
    return u;
  }

  ResolvedStream _resolved(
    _Context ctx,
    String url,
    String? headersJson, {
    required bool isLive,
  }) {
    final playlistId = ctx.row.id;
    final entry = _parseHeaders(headersJson);
    String? entryAgent;
    String? entryReferer;
    final headers = <String, String>{};
    entry.forEach((name, value) {
      switch (name.toLowerCase()) {
        case 'user-agent':
          entryAgent = value;
        case 'referer' || 'referrer':
          entryReferer = value;
        default:
          headers[name] = value;
      }
    });
    return ResolvedStream(
      url: url,
      headers: headers,
      userAgent:
          _nonBlank(entryAgent) ??
          _nonBlank(ctx.row.userAgent) ??
          _settingAgent(playlistId),
      referer:
          _nonBlank(entryReferer) ??
          _nonBlank(
            _settings.get(PlaylistSettings.referer, playlistId: playlistId),
          ),
      isLive: isLive,
    );
  }

  String? _settingAgent(int playlistId) {
    switch (_settings.get(
      PlaylistSettings.userAgentMode,
      playlistId: playlistId,
    )) {
      case 'vlc':
        return vlcUserAgent;
      case 'custom':
        return _nonBlank(
          _settings.get(
            PlaylistSettings.userAgentCustom,
            playlistId: playlistId,
          ),
        );
      default:
        return null;
    }
  }
}

class _Context {
  _Context(this.row, this.account, this.header);

  final PlaylistRow row;
  final XtreamAccount? account;
  final M3uHeader? header;

  bool get isXtream => row.type == PlaylistType.xtream;
  Duration get serverOffset => account?.serverUtcOffset ?? Duration.zero;
}

/// `{"User-Agent": "…", "Referer": "…"}`; anything else (or invalid JSON)
/// gives no headers.
Map<String, String> _parseHeaders(String? json) {
  if (json == null || json.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        if (e.key is String && e.value != null && '${e.value}'.isNotEmpty)
          e.key as String: '${e.value}',
    };
  } on FormatException {
    return const {};
  }
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final streamUrlResolverProvider = Provider<StreamUrlResolver>(
  (ref) => StreamUrlResolver(
    ref.watch(playlistRepositoryProvider),
    ref.watch(settingsStoreProvider),
  ),
);
