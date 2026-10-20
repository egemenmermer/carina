// Source sniffing: Xtream `get.php` exports and "is this an M3U at all".

/// Xtream credentials found in an M3U export URL
/// (`http://host:port/get.php?username=…&password=…&type=m3u_plus`).
class XtreamExportInfo {
  const XtreamExportInfo({
    required this.server,
    required this.username,
    required this.password,
    this.type,
    this.output,
  });

  /// Scheme + host + port (+ any path before `get.php`), no trailing slash.
  /// Usable as `XtreamCredentials.server`.
  final String server;
  final String username;
  final String password;

  /// `type` query value (`m3u`, `m3u_plus`), when present.
  final String? type;

  /// `output` query value (`ts`, `m3u8`, `hls`), when present.
  final String? output;

  /// Never prints the server or the credentials.
  @override
  String toString() => 'XtreamExportInfo(type: $type, output: $output)';
}

/// Detects an Xtream Codes M3U export (`…/get.php?username=…&password=…`)
/// so the wizard can offer to switch to Xtream. Returns null for any other
/// URL, or when the username or password is missing.
XtreamExportInfo? detectXtreamExport(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
    return null;
  }
  final path = uri.path;
  final lowerPath = path.toLowerCase();
  if (!lowerPath.endsWith('/get.php')) return null;
  final Map<String, String> query;
  try {
    query = {
      for (final e in uri.queryParameters.entries) e.key.toLowerCase(): e.value,
    };
  } on Object {
    // Malformed percent-encoding in the query.
    return null;
  }
  final username = query['username']?.trim() ?? '';
  final password = query['password']?.trim() ?? '';
  if (username.isEmpty || password.isEmpty) return null;
  final prefix = path.substring(0, path.length - '/get.php'.length);
  final type = query['type']?.trim();
  final output = query['output']?.trim();
  return XtreamExportInfo(
    server: '${uri.origin}$prefix',
    username: username,
    password: password,
    type: type == null || type.isEmpty ? null : type,
    output: output == null || output.isEmpty ? null : output,
  );
}

final RegExp _schemeUrl = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*://\S+$');

/// Whether [head] (the first few KB of a response or file) looks like an M3U
/// playlist, to tell playlists apart from HTML error pages, JSON and other
/// text.
///
/// True when the first meaningful line is `#EXTM3U`, when an `#EXTINF` line
/// appears before any non-tag text, or when the first non-tag line is an
/// absolute stream URL (plain URL lists). False for HTML / XML (`<`), JSON
/// (`{`, `[`), empty input and anything else.
bool looksLikeM3u(String head) {
  for (final raw in head.split(RegExp(r'\r\n|\r|\n'))) {
    var line = raw.trim();
    if (line.startsWith('\u00EF\u00BB\u00BF')) line = line.substring(3).trim();
    if (line.isEmpty) continue;
    final upper = line.length > 8
        ? line.substring(0, 8).toUpperCase()
        : line.toUpperCase();
    if (upper.startsWith('#EXTM3U') || upper.startsWith('#EXTINF')) {
      return true;
    }
    if (line.startsWith('#')) {
      // Option lines and comments; keep looking for #EXTINF or a URL.
      continue;
    }
    final first = line.codeUnitAt(0);
    if (first == 0x3C || first == 0x7B || first == 0x5B) return false;
    // A Kodi `|User-Agent=…` suffix may contain spaces; the URL may not.
    final bar = line.indexOf('|');
    return _schemeUrl.hasMatch(bar < 0 ? line : line.substring(0, bar).trim());
  }
  return false;
}
