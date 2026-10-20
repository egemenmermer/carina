import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'tmdb_models.dart';

/// Thin TMDb v3 API client.
///
/// The credential is either a v3 API key (sent as the `api_key` query
/// parameter) or a v4 read access token (a JWT, sent as
/// `Authorization: Bearer …`); see [authModeOf]. Responses are decoded
/// JSON maps. Failures throw [TmdbException]; neither messages nor
/// exceptions contain the credential or request URLs.
class TmdbClient {
  TmdbClient(
    this._dio,
    String credential, {
    this.baseUrl = defaultBaseUrl,
    this.rateLimitRetryCap = const Duration(seconds: 2),
  }) : _credential = credential.trim(),
       authMode = authModeOf(credential);

  static const String defaultBaseUrl = 'https://api.themoviedb.org/3';

  final Dio _dio;
  final String _credential;

  /// API root without a trailing slash.
  final String baseUrl;

  /// Longest wait honoured for a 429 `Retry-After` before the one retry.
  final Duration rateLimitRetryCap;
  final TmdbAuthMode authMode;

  /// v4 read access tokens are JWTs (`eyJ…`, three dot-separated parts);
  /// anything else is treated as a v3 API key.
  static TmdbAuthMode authModeOf(String credential) {
    final c = credential.trim();
    final jwtLike = c.startsWith('eyJ') || c.split('.').length == 3;
    return jwtLike && c.length > 40 ? TmdbAuthMode.bearer : TmdbAuthMode.apiKey;
  }

  /// Checks the credential with `GET /configuration`.
  Future<TmdbKeyStatus> test() async {
    try {
      await get('/configuration');
      return TmdbKeyStatus.ok;
    } on TmdbException catch (e) {
      return e.kind == TmdbErrorKind.unauthorized
          ? TmdbKeyStatus.invalid
          : TmdbKeyStatus.unreachable;
    }
  }

  /// `GET /movie/{id}` with appended images, credits, release dates and
  /// videos.
  Future<Map<String, Object?>> movie(
    int id, {
    required String language,
    required String imageLanguages,
  }) => get(
    '/movie/$id',
    params: {
      'language': language,
      'append_to_response': 'images,credits,release_dates,videos',
      'include_image_language': imageLanguages,
    },
  );

  /// `GET /tv/{id}` with appended images, credits, content ratings and
  /// videos.
  Future<Map<String, Object?>> tv(
    int id, {
    required String language,
    required String imageLanguages,
  }) => get(
    '/tv/$id',
    params: {
      'language': language,
      'append_to_response': 'images,credits,content_ratings,videos',
      'include_image_language': imageLanguages,
    },
  );

  /// `GET /search/movie` (or `/search/tv`) for [query], optionally one
  /// year (`year` / `first_air_date_year`).
  Future<Map<String, Object?>> search(
    TmdbKind kind,
    String query, {
    int? year,
    required String language,
  }) => get(
    '/search/${kind.path}',
    params: {
      'query': query,
      'language': language,
      'include_adult': 'false',
      if (year != null)
        kind == TmdbKind.movie ? 'year' : 'first_air_date_year': '$year',
    },
  );

  /// `GET /trending/{movie|tv}/week`.
  Future<Map<String, Object?>> trending(
    TmdbKind kind, {
    required String language,
  }) => get('/trending/${kind.path}/week', params: {'language': language});

  /// `GET {baseUrl}{path}` with the credential applied. One retry after a
  /// 429 (waiting `Retry-After`, capped by [rateLimitRetryCap]).
  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String> params = const {},
    CancelToken? cancelToken,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final Response<List<int>> response;
      try {
        response = await _dio.get<List<int>>(
          '$baseUrl$path',
          queryParameters: {
            ...params,
            if (authMode == TmdbAuthMode.apiKey) 'api_key': _credential,
          },
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Accept': 'application/json',
              if (authMode == TmdbAuthMode.bearer)
                'Authorization': 'Bearer $_credential',
            },
          ),
        );
      } on DioException catch (e) {
        // Never surface the DioException: its text includes the request
        // URL and therefore the api_key.
        throw TmdbException(
          TmdbErrorKind.network,
          message: 'Request failed (${e.type.name})',
        );
      }
      final status = response.statusCode ?? 0;
      if (status == 429 && attempt == 0) {
        await Future<void>.delayed(_retryAfter(response));
        continue;
      }
      if (status < 200 || status >= 300) {
        throw TmdbException(
          switch (status) {
            401 => TmdbErrorKind.unauthorized,
            404 => TmdbErrorKind.notFound,
            429 => TmdbErrorKind.rateLimited,
            _ => TmdbErrorKind.http,
          },
          statusCode: status,
          message: 'HTTP $status for ${_safePath(path)}',
        );
      }
      try {
        final decoded = jsonDecode(utf8.decode(response.data ?? const []));
        if (decoded is Map<String, Object?>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry('$k', v));
        }
      } on FormatException {
        // fall through
      }
      throw TmdbException(
        TmdbErrorKind.unparseable,
        statusCode: status,
        message: 'Invalid JSON for ${_safePath(path)}',
      );
    }
  }

  Duration _retryAfter(Response<Object?> response) {
    final header = response.headers.value('retry-after');
    final seconds = int.tryParse(header ?? '') ?? 1;
    final wait = Duration(seconds: seconds < 0 ? 0 : seconds);
    return wait > rateLimitRetryCap ? rateLimitRetryCap : wait;
  }

  static String _safePath(String path) {
    final q = path.indexOf('?');
    return q < 0 ? path : path.substring(0, q);
  }

  @override
  String toString() => 'TmdbClient(${authMode.name})';
}
