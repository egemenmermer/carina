/// Credential masking for log lines and for any UI that shows a URL.
///
/// See docs/ARCHITECTURE.md section 2.2. Example:
/// `http://domain.com:8080/live/carina/secret/1001.ts` →
/// `http://dom***:8080/live/ka***/***/1001.ts`.
///
/// None of these functions throw. Input that does not look like a URL is still
/// masked as well as possible, and over-masking is preferred to leaking.
library;

/// Query parameter names whose value is replaced by `***` when the
/// (lowercased) name contains one of these fragments: `username`, `user`,
/// `password`, `pass`, `pwd`, `token`, `access_token`, `auth`, `key`, `apikey`,
/// `api_key`, `secret`…
const List<String> _sensitiveParamFragments = [
  'user',
  'pass',
  'pwd',
  'token',
  'secret',
  'auth',
  'key',
];

/// Path keywords followed by `/<username>/<password>/` in Xtream URLs.
const Set<String> _credentialPathKeywords = {
  'live',
  'movie',
  'series',
  'timeshift',
};

/// Splits a URL into its parts. Every group is optional, so the pattern
/// matches any input.
final RegExp _urlParts = RegExp(
  r'^(?<scheme>[A-Za-z][A-Za-z0-9+.\-]*://)?'
  r'(?:(?<userinfo>[^/?#]*)@)?'
  r'(?<host>\[[^\]]*\]|[^:/?#]*)'
  r'(?<port>:[^/?#]*)?'
  r'(?<path>[^?#]*)'
  r'(?:\?(?<query>[^#]*))?'
  r'(?:#(?<fragment>.*))?$',
  dotAll: true,
);

/// `/<user>/<pass>/<id>[.ext]` — the short Xtream live form without `/live/`.
/// A Kodi-style `|User-Agent=…` suffix is allowed.
final RegExp _shortStreamFile = RegExp(r'^\d+(?:\.[A-Za-z0-9]+)?(?:\|.*)?$');

final RegExp _embeddedUrl = RegExp(
  r'''[A-Za-z][A-Za-z0-9+.\-]*://[^\s"'<>]+''',
);

final RegExp _credentialPair = RegExp(
  r'''\b([A-Za-z_\-]*(?:user|pass|pwd|token|secret|auth|key)[A-Za-z_\-]*)=([^&\s"'<>]+)''',
  caseSensitive: false,
);

final RegExp _digits = RegExp(r'^\d*$');

/// Masks credentials in [url]:
///
/// - the host is cut after 3 characters (`dom***`), the port is kept;
/// - `user:pass@` userinfo becomes `***@`;
/// - `/live|movie|series|timeshift/<user>/<pass>/` path credentials become
///   `/<us>***/***/` (the first two characters of the username are kept when
///   it has at least 4 characters), as does the short `/<user>/<pass>/<id>`
///   form;
/// - query parameters such as `username`, `password`, `token` and `key`
///   become `name=***`.
String maskUrl(String url) {
  final m = _urlParts.firstMatch(url);
  if (m == null) return '***';
  final out = StringBuffer();
  final scheme = m.namedGroup('scheme');
  if (scheme != null) out.write(scheme);
  final userinfo = m.namedGroup('userinfo');
  if (userinfo != null) out.write(userinfo.isEmpty ? '@' : '***@');
  out
    ..write(_maskHost(m.namedGroup('host') ?? ''))
    ..write(_maskPort(m.namedGroup('port')))
    ..write(_maskPath(m.namedGroup('path') ?? ''));
  final query = m.namedGroup('query');
  if (query != null) {
    out
      ..write('?')
      ..write(_maskQuery(query));
  }
  final fragment = m.namedGroup('fragment');
  if (fragment != null) {
    out
      ..write('#')
      ..write(_maskQuery(fragment));
  }
  return out.toString();
}

/// Masks an Xtream server base such as `https://domain.com:8080` →
/// `https://dom***:8080`. A query string or fragment is dropped.
String maskServer(String server) {
  final m = _urlParts.firstMatch(server.trim());
  if (m == null) return '***';
  final out = StringBuffer();
  final scheme = m.namedGroup('scheme');
  if (scheme != null) out.write(scheme);
  final userinfo = m.namedGroup('userinfo');
  if (userinfo != null) out.write(userinfo.isEmpty ? '@' : '***@');
  out
    ..write(_maskHost(m.namedGroup('host') ?? ''))
    ..write(_maskPort(m.namedGroup('port')))
    ..write(_maskPath(m.namedGroup('path') ?? ''));
  return out.toString();
}

/// Masks every URL embedded in free text (log lines, exception messages) and
/// any stray `password=…`-style pair outside a URL.
String maskText(String text) {
  final withUrls = text.replaceAllMapped(_embeddedUrl, (m) => maskUrl(m[0]!));
  return withUrls.replaceAllMapped(
    _credentialPair,
    (m) => m[2] == '***' ? m[0]! : '${m[1]}=***',
  );
}

String _maskHost(String host) {
  if (host.isEmpty) return host;
  if (host.startsWith('[')) {
    final end = host.endsWith(']') ? host.length - 1 : host.length;
    return '[${_prefix(host.substring(1, end), 3)}***]';
  }
  return '${_prefix(host, 3)}***';
}

String _maskPort(String? port) {
  if (port == null) return '';
  return _digits.hasMatch(port.substring(1)) ? port : ':***';
}

String _maskPath(String path) {
  if (path.isEmpty || !path.contains('/')) return path;
  final segments = path.split('/');
  var masked = false;
  for (var i = 0; i < segments.length; i++) {
    if (i + 2 < segments.length &&
        _credentialPathKeywords.contains(segments[i].toLowerCase())) {
      segments[i + 1] = _maskUser(segments[i + 1]);
      segments[i + 2] = '***';
      i += 2;
      masked = true;
    }
  }
  if (!masked &&
      segments.length == 4 &&
      segments[0].isEmpty &&
      segments[1].isNotEmpty &&
      segments[2].isNotEmpty &&
      _shortStreamFile.hasMatch(segments[3])) {
    segments[1] = _maskUser(segments[1]);
    segments[2] = '***';
  }
  return segments.join('/');
}

String _maskUser(String segment) {
  String decoded;
  try {
    decoded = Uri.decodeComponent(segment);
  } on Object {
    decoded = segment;
  }
  if (decoded.runes.length < 4) return '***';
  return '${Uri.encodeComponent(_prefix(decoded, 2))}***';
}

String _maskQuery(String query) {
  if (query.isEmpty || !query.contains('=')) return query;
  return query
      .split('&')
      .map((part) {
        final eq = part.indexOf('=');
        if (eq < 0) return part;
        final name = part.substring(0, eq);
        return _isSensitiveParam(name) ? '$name=***' : part;
      })
      .join('&');
}

bool _isSensitiveParam(String rawName) {
  String name;
  try {
    name = Uri.decodeQueryComponent(rawName);
  } on Object {
    name = rawName;
  }
  name = name.toLowerCase();
  // `&amp;password=` in URLs copied from HTML or M3U files.
  if (name.startsWith('amp;')) name = name.substring(4);
  for (final fragment in _sensitiveParamFragments) {
    if (name.contains(fragment)) return true;
  }
  return false;
}

String _prefix(String s, int count) {
  final runes = s.runes;
  if (runes.length <= count) return s;
  return String.fromCharCodes(runes.take(count));
}
