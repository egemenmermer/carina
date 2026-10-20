import 'package:dio/dio.dart';

import '../source_exception.dart';
import 'xtream_client.dart';
import 'xtream_credentials.dart';
import 'xtream_models.dart';

export '../../net/url_check.dart'
    show UrlCheckResult, UrlContentKind, checkUrlReachable, sniffContentKind;

/// Result of [checkXtreamServer] for the add-playlist wizard.
///
/// The UI formats the summary, e.g. "Server reachable · account active ·
/// expires 2027-03-01 · 1 connection", from the structured fields. A green
/// check does not guarantee that the import will succeed.
class XtreamCheckResult {
  const XtreamCheckResult({
    required this.ok,
    this.error,
    this.statusCode,
    this.message,
    this.account,
  });

  /// Server reachable, credentials accepted, account active.
  final bool ok;

  /// Why the check failed: unreachable, timeout, cancelled, unauthorized,
  /// forbidden, notFound, http, emptyBody, unparseable or accountInactive.
  final SourceErrorKind? error;
  final int? statusCode;

  /// Developer detail, never with credentials.
  final String? message;

  /// Present when the server answered with account data (also for
  /// [SourceErrorKind.accountInactive], so the UI can show the status and
  /// expiry date).
  final XtreamAccount? account;

  /// The server answered HTTP (even with an error status or bad body).
  bool get reachable =>
      ok ||
      (error != SourceErrorKind.unreachable &&
          error != SourceErrorKind.timeout &&
          error != SourceErrorKind.cancelled);

  bool get accountActive => account?.isActive ?? false;

  /// As delivered (`Active`, `Expired`…).
  String? get status => account?.status;

  /// Null = never expires (or unknown).
  DateTime? get expiresAt => account?.expDate;
  int? get maxConnections => account?.maxConnections;
  int? get activeConnections => account?.activeCons;
  bool get isTrial => account?.userInfo.isTrial ?? false;
  List<String> get allowedOutputFormats =>
      account?.allowedOutputFormats ?? const [];

  @override
  String toString() =>
      'XtreamCheckResult(ok: $ok, error: ${error?.name}, status: $status, '
      'expires: $expiresAt, maxConnections: $maxConnections)';
}

/// Live check of an Xtream login: one `player_api.php` call with at most one
/// retry. Never throws.
Future<XtreamCheckResult> checkXtreamServer(
  Dio dio,
  XtreamCredentials credentials, {
  CancelToken? cancelToken,
}) async {
  final client = XtreamClient(dio, credentials, retries: 1);
  try {
    final account = await client.accountInfo(cancelToken: cancelToken);
    if (!account.userInfo.auth) {
      return XtreamCheckResult(
        ok: false,
        error: SourceErrorKind.unauthorized,
        message: 'user_info.auth is 0',
        account: account,
      );
    }
    if (!account.isActive) {
      return XtreamCheckResult(
        ok: false,
        error: SourceErrorKind.accountInactive,
        message: 'Account status: ${account.status ?? 'unknown'}',
        account: account,
      );
    }
    return XtreamCheckResult(ok: true, account: account);
  } on SourceException catch (e) {
    return XtreamCheckResult(
      ok: false,
      error: e.kind,
      statusCode: e.statusCode,
      message: e.message,
    );
  } on Object catch (e) {
    return XtreamCheckResult(
      ok: false,
      error: SourceErrorKind.unreachable,
      message: 'Check failed (${e.runtimeType})',
    );
  }
}
