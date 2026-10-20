/// Why talking to a playlist source failed. The wizard and the import flow map
/// these to user-facing messages.
enum SourceErrorKind {
  /// DNS failure, connection refused, TLS error, no route.
  unreachable,

  /// The request timed out.
  timeout,

  /// HTTP 401, or Xtream `user_info.auth == 0`.
  unauthorized,

  /// HTTP 403.
  forbidden,

  /// Xtream account status is Expired / Banned / Disabled.
  accountInactive,

  /// HTTP 404.
  notFound,

  /// Any other non-2xx status.
  http,

  /// 2xx with an empty body.
  emptyBody,

  /// The body is not what we expected (HTML page, not JSON, not M3U, bad XML).
  unparseable,

  /// The import succeeded but the section has no items.
  sectionEmpty,

  /// The user cancelled.
  cancelled,
}

class SourceException implements Exception {
  const SourceException(this.kind, {this.statusCode, this.message, this.url});

  final SourceErrorKind kind;
  final int? statusCode;

  /// Developer-facing detail. Never contains credentials.
  final String? message;

  /// Masked URL (see maskUrl in data/net/mask.dart).
  final String? url;

  @override
  String toString() =>
      'SourceException(${kind.name}'
      '${statusCode != null ? ', $statusCode' : ''}'
      '${message != null ? ', $message' : ''})';
}
