import '../../net/mask.dart';

/// Xtream login. [server] is the base exactly as entered: scheme + host +
/// port, e.g. `https://domain.com:8080` (URL builders only trim whitespace
/// and trailing slashes).
class XtreamCredentials {
  const XtreamCredentials(this.server, this.username, this.password);

  final String server;
  final String username;
  final String password;

  /// [server] without surrounding whitespace and trailing slashes.
  String get baseUrl => normalizeXtreamServer(server);

  @override
  bool operator ==(Object other) =>
      other is XtreamCredentials &&
      other.server == server &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(server, username, password);

  /// Never prints the credentials.
  @override
  String toString() => 'XtreamCredentials(${maskServer(server)})';
}

/// Trims [server] and removes trailing slashes.
String normalizeXtreamServer(String server) {
  var s = server.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
