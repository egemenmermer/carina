// Line-by-line M3U / M3U8 parser.

import 'dart:collection';
import 'dart:convert';

import 'm3u_attributes.dart';
import 'm3u_classify.dart';
import 'm3u_models.dart';

/// Parses a whole playlist held in memory. Never throws; problems are
/// reported in [M3uParseResult.warnings]. For large inputs prefer
/// `parseM3uInIsolate` or `parseM3uStream`.
M3uParseResult parseM3u(String text) {
  final entries = <M3uEntry>[];
  final parser = M3uLineParser(entries.add);
  for (final line in LineSplitter.split(text)) {
    parser.addLine(line);
  }
  parser.close();
  return parser.result(entries);
}

const Map<String, String> _noStrings = <String, String>{};

/// Catch-up values that switch catch-up off instead of naming a mode.
const Set<String> _catchupOff = {'none', 'disabled', 'off', 'false', 'no', '0'};

/// Kodi `|option=value` keys that are player options, not HTTP headers.
const Set<String> _kodiPipeOptions = {
  'seekable',
  'verifypeer',
  'noshout',
  'failonerror',
  'connection-timeout',
  'redirect-limit',
  'active-remote',
};

/// DRM properties: the entry needs a license server, which mpv cannot use.
const Set<String> _drmKodiProps = {
  'inputstream.adaptive.license_key',
  'inputstream.adaptive.license_type',
  'inputstream.adaptive.drm_legacy',
  'inputstream.adaptive.drm',
};

class _PendingInfo {
  _PendingInfo(this.line, this.duration, this.attrs, this.displayName);

  final int line;
  final int duration;
  final Map<String, String> attrs;
  final String? displayName;
}

/// Incremental parser: feed it lines with [addLine] (any terminator already
/// removed), then call [close]. Each completed entry is passed to the
/// callback as soon as its URL line arrives.
///
/// Rules:
/// - BOM, surrounding whitespace and blank lines are ignored; `#EXTM3U` is
///   optional.
/// - `#EXTINF` describes the next URL line. Option lines (`#EXTVLCOPT`,
///   `#EXTHTTP`, `#KODIPROP`) apply to the next URL line wherever they appear
///   before it (also before `#EXTINF`).
/// - `#EXTGRP:` sets the fallback group for all following entries until the
///   next `#EXTGRP:` (Kodi behavior); `group-title` wins over it.
/// - A URL line without a preceding `#EXTINF` becomes an entry of its own,
///   named after the URL's file name (plain URL lists, extra URLs).
/// - Any other `#` line is a comment.
class M3uLineParser {
  M3uLineParser(this._onEntry);

  final void Function(M3uEntry entry) _onEntry;
  final List<String> _warnings = <String>[];
  int _droppedWarnings = 0;

  M3uHeader _header = M3uHeader.empty;
  bool _sawHeader = false;
  bool _sawHls = false;
  bool _closed = false;
  int _line = 0;
  int _entryCount = 0;

  _PendingInfo? _info;
  String? _group;
  Map<String, String>? _optHeaders;
  bool _optUnsupported = false;

  /// The playlist header (merged across `#EXTM3U` lines seen so far).
  M3uHeader get header => _header;

  /// Number of entries emitted so far.
  int get entryCount => _entryCount;

  /// Warnings so far, with a summary line when some were dropped.
  List<String> get warnings => List.unmodifiable([
    ..._warnings,
    if (_droppedWarnings > 0) '... and $_droppedWarnings more warnings',
  ]);

  /// Builds the final result; call after [close].
  M3uParseResult result(List<M3uEntry> entries) => M3uParseResult(
    header: _header,
    entries: List.unmodifiable(entries),
    warnings: warnings,
  );

  void addLine(String raw) {
    _line++;
    var line = raw.trim();
    if (_line == 1 && line.startsWith('\u00EF\u00BB\u00BF')) {
      // A UTF-8 BOM that was decoded as Latin-1.
      line = line.substring(3).trim();
    }
    if (line.isEmpty) return;
    if (line.codeUnitAt(0) == 0x23) {
      _onTag(line);
    } else {
      _onUrl(line);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    final info = _info;
    if (info != null) {
      _warn('Line ${info.line}: #EXTINF without a URL at the end; skipped');
      _info = null;
    }
    if (!_sawHeader && _entryCount > 0) {
      _warnings.insert(0, 'No #EXTM3U header; parsed anyway');
    }
  }

  void _warn(String message) {
    if (_warnings.length < maxM3uWarnings) {
      _warnings.add(message);
    } else {
      _droppedWarnings++;
    }
  }

  void _onTag(String line) {
    if (_hasPrefix(line, '#EXTINF')) {
      _onExtinf(line);
    } else if (_hasPrefix(line, '#EXTM3U')) {
      if (line.length == 7 || isM3uSpace(line.codeUnitAt(7))) _onHeader(line);
    } else if (_hasPrefix(line, '#EXTGRP:')) {
      final g = line.substring(8).trim();
      _group = g.isEmpty ? null : g;
    } else if (_hasPrefix(line, '#EXTVLCOPT:')) {
      _onVlcOpt(line.substring(11));
    } else if (_hasPrefix(line, '#EXTHTTP:')) {
      _onHttp(line.substring(9));
    } else if (_hasPrefix(line, '#KODIPROP:')) {
      _onKodiProp(line.substring(10));
    } else if (_hasPrefix(line, '#EXT-X-')) {
      if (!_sawHls) {
        _sawHls = true;
        _warn(
          'Line $_line: HLS tag found; this looks like a single HLS stream, '
          'not a channel list',
        );
      }
    }
  }

  void _onHeader(String line) {
    final h = _headerFromPairs(
      scanM3uAttributes(line, 7, stopAtComma: false).pairs,
    );
    if (!_sawHeader) {
      _sawHeader = true;
      _header = h;
    } else {
      _header = _header.mergedWith(h);
      _warn('Line $_line: another #EXTM3U line; its values apply below it');
    }
  }

  void _onExtinf(String line) {
    final previous = _info;
    if (previous != null) {
      _warn('Line ${previous.line}: #EXTINF without a URL; skipped');
    }
    final n = line.length;
    var i = 7;
    if (i < n && line.codeUnitAt(i) == 0x3A) i++;
    while (i < n && isM3uSpace(line.codeUnitAt(i))) {
      i++;
    }
    var duration = -1;
    final numberStart = i;
    if (i < n && (line.codeUnitAt(i) == 0x2D || line.codeUnitAt(i) == 0x2B)) {
      i++;
    }
    final digitsStart = i;
    while (i < n && _isDigit(line.codeUnitAt(i))) {
      i++;
    }
    if (i > digitsStart) {
      duration = int.tryParse(line.substring(numberStart, i)) ?? -1;
      if (i < n && line.codeUnitAt(i) == 0x2E) {
        i++;
        while (i < n && _isDigit(line.codeUnitAt(i))) {
          i++;
        }
      }
    } else {
      i = numberStart;
    }
    final scan = scanM3uAttributes(line, i);
    final attrs = <String, String>{};
    for (final (key, value) in scan.pairs) {
      attrs[key] ??= value;
    }
    String? name;
    if (scan.nameStart >= 0) name = _nonEmpty(line.substring(scan.nameStart));
    name ??= _nonEmpty(scan.bareText);
    _info = _PendingInfo(_line, duration, attrs, name);
  }

  void _onVlcOpt(String rest) {
    final eq = rest.indexOf('=');
    if (eq <= 0) return;
    final value = _unquote(rest.substring(eq + 1).trim());
    if (value.isEmpty) return;
    switch (rest.substring(0, eq).trim().toLowerCase()) {
      case 'http-user-agent':
        _setOptHeader('User-Agent', value);
      case 'http-referrer' || 'http-referer':
        _setOptHeader('Referer', value);
      case 'http-origin':
        _setOptHeader('Origin', value);
    }
  }

  void _onHttp(String rest) {
    Object? decoded;
    try {
      decoded = jsonDecode(rest.trim());
    } on FormatException {
      _warn('Line $_line: #EXTHTTP is not valid JSON; ignored');
      return;
    }
    if (decoded is! Map) {
      _warn('Line $_line: #EXTHTTP is not a JSON object; ignored');
      return;
    }
    for (final MapEntry(:key, :value) in decoded.entries) {
      if (key is! String || key.trim().isEmpty || value == null) continue;
      final text = (value is String ? value : '$value').trim();
      if (text.isNotEmpty) _setOptHeader(_canonicalHeader(key), text);
    }
  }

  void _onKodiProp(String rest) {
    final eq = rest.indexOf('=');
    if (eq <= 0) return;
    final key = rest.substring(0, eq).trim().toLowerCase();
    if (_drmKodiProps.contains(key) && rest.substring(eq + 1).trim() != '') {
      _optUnsupported = true;
    }
  }

  void _setOptHeader(String name, String value) {
    (_optHeaders ??= <String, String>{})[name] = value;
  }

  void _onUrl(String line) {
    final info = _info;
    _info = null;

    var url = line;
    Map<String, String>? pipeHeaders;
    final bar = line.indexOf('|');
    if (bar > 0) {
      final suffix = line.substring(bar + 1);
      if (suffix.contains('=')) {
        url = line.substring(0, bar).trim();
        pipeHeaders = _parsePipe(suffix);
      }
    }

    final attrs = info?.attrs ?? _noStrings;
    final defaults = _header;

    final headers = <String, String>{};
    final defaultUa = defaults.userAgent;
    if (defaultUa != null) headers['User-Agent'] = defaultUa;
    final attrUa =
        _nonEmpty(attrs['user-agent']) ?? _nonEmpty(attrs['http-user-agent']);
    if (attrUa != null) headers['User-Agent'] = attrUa;
    final attrReferrer =
        _nonEmpty(attrs['http-referrer']) ??
        _nonEmpty(attrs['http-referer']) ??
        _nonEmpty(attrs['referrer']) ??
        _nonEmpty(attrs['referer']);
    if (attrReferrer != null) headers['Referer'] = attrReferrer;
    final options = _optHeaders;
    if (options != null) headers.addAll(options);
    if (pipeHeaders != null) headers.addAll(pipeHeaders);

    final tvgId = _nonEmpty(attrs['tvg-id']);
    final tvgName = _nonEmpty(attrs['tvg-name']);
    final timeshift = _parseIntLoose(attrs['timeshift']);
    final catchupDays =
        _parseIntLoose(attrs['catchup-days']) ??
        _positive(timeshift) ??
        _positive(_parseIntLoose(attrs['tvg-rec'])) ??
        defaults.catchupDays;
    final catchupSource =
        _nonEmpty(attrs['catchup-source']) ?? defaults.catchupSource;
    final declared =
        _lowerOrNull(attrs['catchup']) ??
        _lowerOrNull(attrs['catchup-type']) ??
        defaults.catchup;
    final String? catchup;
    if (declared != null) {
      catchup = _catchupOff.contains(declared) ? null : declared;
    } else if (catchupSource != null) {
      catchup = 'default';
    } else if ((catchupDays ?? 0) > 0) {
      catchup = 'shift';
    } else {
      catchup = null;
    }

    final name = info?.displayName ?? tvgName ?? tvgId ?? _nameFromUrl(url);
    final duration = info?.duration ?? -1;
    final kind = classifyM3u(url, duration);
    M3uSeriesMarker? series;
    if (kind == M3uKind.episode) {
      series =
          parseSeriesMarker(name) ??
          (tvgName != null ? parseSeriesMarker(tvgName) : null);
    }

    final entry = M3uEntry(
      duration: duration,
      name: name,
      url: url,
      attrs: attrs.isEmpty ? _noStrings : UnmodifiableMapView(attrs),
      tvgId: tvgId,
      tvgName: tvgName,
      tvgLogo: _nonEmpty(attrs['tvg-logo']) ?? _nonEmpty(attrs['logo']),
      tvgChno:
          _parseIntLoose(attrs['tvg-chno']) ??
          _parseIntLoose(attrs['channel-number']),
      group: _nonEmpty(attrs['group-title']) ?? _group,
      tvgShift: _parseDouble(attrs['tvg-shift']) ?? defaults.tvgShift,
      catchup: catchup,
      catchupDays: catchupDays,
      catchupSource: catchupSource,
      timeshift: timeshift,
      userAgent: headers['User-Agent'],
      referrer: headers['Referer'],
      headers: headers.isEmpty ? _noStrings : UnmodifiableMapView(headers),
      unsupported: _optUnsupported,
      kind: kind,
      seriesName: kind == M3uKind.episode ? (series?.seriesName ?? name) : null,
      season: series?.season,
      episode: series?.episode,
      episodeTitle: series?.episodeTitle,
    );
    _optHeaders = null;
    _optUnsupported = false;
    _entryCount++;
    _onEntry(entry);
  }
}

M3uHeader _headerFromPairs(List<(String, String)> pairs) {
  if (pairs.isEmpty) return M3uHeader.empty;
  final attrs = <String, String>{};
  final urls = <String>{};
  for (final (key, value) in pairs) {
    attrs[key] ??= value;
    if (key == 'url-tvg' || key == 'x-tvg-url' || key == 'tvg-url') {
      for (final part in value.split(',')) {
        final url = part.trim();
        if (url.isNotEmpty) urls.add(url);
      }
    }
  }
  final declared =
      _lowerOrNull(attrs['catchup']) ?? _lowerOrNull(attrs['catchup-type']);
  return M3uHeader(
    tvgUrls: List.unmodifiable(urls),
    tvgShift: _parseDouble(attrs['tvg-shift']),
    catchup: declared != null && _catchupOff.contains(declared)
        ? null
        : declared,
    catchupDays:
        _parseIntLoose(attrs['catchup-days']) ??
        _positive(_parseIntLoose(attrs['timeshift'])) ??
        _positive(_parseIntLoose(attrs['tvg-rec'])),
    catchupSource: _nonEmpty(attrs['catchup-source']),
    userAgent:
        _nonEmpty(attrs['http-user-agent']) ?? _nonEmpty(attrs['user-agent']),
    attrs: UnmodifiableMapView(attrs),
  );
}

/// Kodi style `User-Agent=a%20b&Referer=c` suffix → headers.
Map<String, String> _parsePipe(String suffix) {
  final out = <String, String>{};
  for (final part in suffix.split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final key = part.substring(0, eq).trim();
    if (key.isEmpty || _kodiPipeOptions.contains(key.toLowerCase())) continue;
    final value = _decodeComponent(part.substring(eq + 1).trim());
    if (value.isNotEmpty) out[_canonicalHeader(key)] = value;
  }
  return out;
}

String _decodeComponent(String s) {
  if (!s.contains('%')) return s;
  try {
    return Uri.decodeComponent(s);
  } on Object {
    return s;
  }
}

/// `user-agent` → `User-Agent`, `referrer` → `Referer`.
String _canonicalHeader(String name) {
  final lower = name.trim().toLowerCase();
  if (lower == 'referrer') return 'Referer';
  return lower
      .split('-')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join('-');
}

final RegExp _shortExtension = RegExp(r'^[A-Za-z0-9]{1,5}$');

/// Best-effort name for a URL line without `#EXTINF`.
String _nameFromUrl(String url) {
  var end = url.length;
  final q = url.indexOf('?');
  if (q >= 0) end = q;
  final h = url.indexOf('#');
  if (h >= 0 && h < end) end = h;
  final segments = url
      .substring(0, end)
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return url;
  var last = segments.last;
  final dot = last.lastIndexOf('.');
  if (dot > 0 && _shortExtension.hasMatch(last.substring(dot + 1))) {
    last = last.substring(0, dot);
  }
  last = _decodeComponent(last).trim();
  return last.isEmpty ? url : last;
}

bool _hasPrefix(String s, String upperPrefix) {
  if (s.length < upperPrefix.length) return false;
  for (var i = 0; i < upperPrefix.length; i++) {
    var c = s.codeUnitAt(i);
    if (c >= 0x61 && c <= 0x7A) c -= 0x20;
    if (c != upperPrefix.codeUnitAt(i)) return false;
  }
  return true;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

String? _nonEmpty(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

String? _lowerOrNull(String? s) => _nonEmpty(s)?.toLowerCase();

String _unquote(String s) {
  if (s.length >= 2) {
    final first = s.codeUnitAt(0);
    if ((first == 0x22 || first == 0x27) &&
        s.codeUnitAt(s.length - 1) == first) {
      return s.substring(1, s.length - 1).trim();
    }
  }
  return s;
}

int? _positive(int? v) => v != null && v > 0 ? v : null;

/// Leading integer of [s] (`5.1` → 5, `+3` → 3, `7 days` → 7).
int? _parseIntLoose(String? s) {
  if (s == null) return null;
  final t = s.trim();
  var i = 0;
  if (i < t.length && (t.codeUnitAt(i) == 0x2D || t.codeUnitAt(i) == 0x2B)) {
    i++;
  }
  final digits = i;
  while (i < t.length && _isDigit(t.codeUnitAt(i))) {
    i++;
  }
  if (i == digits) return null;
  return int.tryParse(t.substring(0, i));
}

/// Hours like `2`, `-1.5`, `+3`, `1,5`.
double? _parseDouble(String? s) {
  final t = _nonEmpty(s);
  if (t == null) return null;
  final v = double.tryParse(t.replaceAll(',', '.'));
  return v == null || v.isNaN || v.isInfinite ? null : v;
}
