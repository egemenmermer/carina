// Data types produced by the M3U parser (ARCHITECTURE 2.5).

import 'dart:collection';

/// What an M3U entry points at.
enum M3uKind { live, movie, episode }

const Map<String, String> _noStrings = <String, String>{};

/// Playlist-wide values from the `#EXTM3U` line. They are the defaults for
/// every entry; an entry's own attribute wins.
class M3uHeader {
  const M3uHeader({
    this.tvgUrls = const <String>[],
    this.tvgShift,
    this.catchup,
    this.catchupDays,
    this.catchupSource,
    this.userAgent,
    this.attrs = _noStrings,
  });

  /// Rebuilds a header stored with [toJson] (`playlists.m3u_header_json`).
  factory M3uHeader.fromJson(Map<String, Object?> json) {
    final urls = json['tvgUrls'];
    final attrs = json['attrs'];
    final shift = json['tvgShift'];
    final days = json['catchupDays'];
    return M3uHeader(
      tvgUrls: urls is List
          ? List.unmodifiable(urls.whereType<String>())
          : const <String>[],
      tvgShift: shift is num ? shift.toDouble() : null,
      catchup: json['catchup'] as String?,
      catchupDays: days is num ? days.toInt() : null,
      catchupSource: json['catchupSource'] as String?,
      userAgent: json['userAgent'] as String?,
      attrs: attrs is Map
          ? UnmodifiableMapView({
              for (final e in attrs.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            })
          : _noStrings,
    );
  }

  /// A header with no values (playlist without `#EXTM3U` attributes).
  static const M3uHeader empty = M3uHeader();

  /// EPG (XMLTV) URLs from `url-tvg`, `x-tvg-url` and `tvg-url`, split on
  /// commas, trimmed, in file order, without duplicates.
  final List<String> tvgUrls;

  /// EPG time shift in hours (`tvg-shift`); may be fractional or negative.
  final double? tvgShift;

  /// Catch-up mode (`catchup`, alias `catchup-type`), trimmed and
  /// lower-cased; null when missing or switched off (`none`, `disabled`…).
  final String? catchup;

  /// Archive window in days (`catchup-days`, else `timeshift`, else
  /// `tvg-rec`).
  final int? catchupDays;

  /// Catch-up URL template (`catchup-source`).
  final String? catchupSource;

  /// `http-user-agent` / `user-agent`, sent with every stream request.
  final String? userAgent;

  /// Every attribute on the line. Keys are lower-cased; the first occurrence
  /// of a key wins.
  final Map<String, String> attrs;

  bool get isEmpty =>
      attrs.isEmpty &&
      tvgUrls.isEmpty &&
      tvgShift == null &&
      catchup == null &&
      catchupDays == null &&
      catchupSource == null &&
      userAgent == null;

  /// Merges a later `#EXTM3U` line (concatenated playlists): EPG URLs are
  /// unioned; other values of [later] win when present.
  M3uHeader mergedWith(M3uHeader later) {
    final urls = <String>{...tvgUrls, ...later.tvgUrls};
    return M3uHeader(
      tvgUrls: List.unmodifiable(urls),
      tvgShift: later.tvgShift ?? tvgShift,
      catchup: later.catchup ?? catchup,
      catchupDays: later.catchupDays ?? catchupDays,
      catchupSource: later.catchupSource ?? catchupSource,
      userAgent: later.userAgent ?? userAgent,
      attrs: UnmodifiableMapView({...attrs, ...later.attrs}),
    );
  }

  Map<String, Object?> toJson() => {
    'tvgUrls': tvgUrls,
    'tvgShift': tvgShift,
    'catchup': catchup,
    'catchupDays': catchupDays,
    'catchupSource': catchupSource,
    'userAgent': userAgent,
    'attrs': attrs,
  };

  @override
  String toString() =>
      'M3uHeader(epgUrls: ${tvgUrls.length}, tvgShift: $tvgShift, '
      'catchup: $catchup, catchupDays: $catchupDays)';
}

/// One playable item of an M3U playlist. Immutable.
///
/// Effective values already include the `#EXTM3U` header defaults, so a
/// consumer never has to merge them again.
class M3uEntry {
  const M3uEntry({
    required this.name,
    required this.url,
    this.duration = -1,
    this.attrs = _noStrings,
    this.tvgId,
    this.tvgName,
    this.tvgLogo,
    this.tvgChno,
    this.group,
    this.tvgShift,
    this.catchup,
    this.catchupDays,
    this.catchupSource,
    this.timeshift,
    this.userAgent,
    this.referrer,
    this.headers = _noStrings,
    this.unsupported = false,
    this.kind = M3uKind.live,
    this.seriesName,
    this.season,
    this.episode,
    this.episodeTitle,
  });

  /// `#EXTINF` duration in whole seconds, as written (decimals truncated).
  /// `-1` when missing or unparseable; `-1` and `0` mean live or unknown.
  final int duration;

  /// Display name (text after the `#EXTINF` comma). Falls back to
  /// `tvg-name`, `tvg-id`, then the URL's file name, so it is never empty.
  final String name;

  /// Stream URL without a Kodi `|header=value` suffix. Relative URLs are kept
  /// as written.
  final String url;

  /// Every `#EXTINF` attribute. Keys are lower-cased; the first occurrence of
  /// a key wins. Values are raw (empty strings kept).
  final Map<String, String> attrs;

  final String? tvgId;
  final String? tvgName;

  /// `tvg-logo` (alias `logo`).
  final String? tvgLogo;

  /// `tvg-chno` (alias `channel-number`); `5.1` is read as 5.
  final int? tvgChno;

  /// `group-title`, else the current `#EXTGRP:` value. May hold several
  /// groups separated by `;` (Kodi); see [groups].
  final String? group;

  /// EPG time shift in hours (entry `tvg-shift`, else the header default).
  final double? tvgShift;

  /// Effective catch-up mode, lower-cased: the entry's `catchup` /
  /// `catchup-type`, else the header's. When neither declares a mode,
  /// `default` is inferred if a catch-up source exists, else `shift` if the
  /// entry has an archive window (SIPTV `timeshift` / `catchup-days`).
  /// Null when there is no catch-up, or when it is switched off
  /// (`none`, `disabled`, `off`, `false`, `no`, `0`). Pass it as the `mode`
  /// of `buildCatchupUrl`.
  final String? catchup;

  /// Archive window in days: entry `catchup-days`, else entry `timeshift`,
  /// else entry `tvg-rec`, else the header default.
  final int? catchupDays;

  /// Catch-up template (entry `catchup-source`, else the header default).
  final String? catchupSource;

  /// Raw `timeshift` attribute (SIPTV archive days), when present.
  final int? timeshift;

  /// Effective `User-Agent` (same value as `headers['User-Agent']`).
  final String? userAgent;

  /// Effective `Referer` (same value as `headers['Referer']`).
  final String? referrer;

  /// Every HTTP request header for the stream, including `User-Agent` and
  /// `Referer` when known. Names are canonical (`User-Agent`, `Referer`,
  /// `X-Forwarded-For`). Sources, lowest to highest priority: header default
  /// user agent, `#EXTINF` attributes, `#EXTVLCOPT` / `#EXTHTTP` lines (file
  /// order), the URL's `|` suffix.
  final Map<String, String> headers;

  /// The entry needs DRM (`#KODIPROP:inputstream.adaptive.license_*` or
  /// `drm*`). Shown, but not playable.
  final bool unsupported;

  final M3uKind kind;

  /// Series name for [M3uKind.episode] entries (marker stripped).
  final String? seriesName;
  final int? season;
  final int? episode;

  /// Text after the `S01E02` marker, when there is any (`Show S01E02 Pilot`).
  final String? episodeTitle;

  /// [group] split on `;`, trimmed, empty parts dropped.
  List<String> get groups {
    final g = group;
    if (g == null) return const <String>[];
    return [
      for (final part in g.split(';'))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// The entry declares catch-up.
  bool get hasCatchup => catchup != null || (catchupDays ?? 0) > 0;

  /// Never prints the URL: it may contain credentials.
  @override
  String toString() =>
      'M3uEntry($name, kind: ${kind.name}, group: $group'
      '${tvgId != null ? ', tvgId: $tvgId' : ''}'
      '${unsupported ? ', unsupported' : ''})';
}

/// Result of a complete parse.
class M3uParseResult {
  const M3uParseResult({
    required this.header,
    required this.entries,
    required this.warnings,
  });

  final M3uHeader header;

  /// Entries in file order.
  final List<M3uEntry> entries;

  /// Developer-facing notes (line numbers and tag names only; never URLs or
  /// credentials). Capped at [maxM3uWarnings] plus one summary line.
  final List<String> warnings;

  @override
  String toString() =>
      'M3uParseResult(${entries.length} entries, ${warnings.length} warnings)';
}

/// Maximum number of individual warnings kept per parse.
const int maxM3uWarnings = 100;
