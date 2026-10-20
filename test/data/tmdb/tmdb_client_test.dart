import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/tmdb/tmdb_client.dart';
import 'package:carina/data/tmdb/tmdb_models.dart';

import '../net/test_http_server.dart';

const apiKey = '0123456789abcdef0123456789abcdef';
const token =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJrYW5hbC10ZXN0In0.c2lnbmF0dXJlLXBhcnQtMTIz';

void main() {
  late TestHttpServer server;

  setUp(() async {
    server = await TestHttpServer.start();
    server.route('/3/configuration', (r) {
      final ok =
          r.uri.queryParameters['api_key'] == apiKey ||
          r.headers.value('authorization') == 'Bearer $token';
      return ok
          ? sendJson(r, {
              'images': {'base_url': 'http://image.tmdb.org/t/p/'},
            })
          : sendJson(r, {'status_code': 7}, status: 401);
    });
  });

  tearDown(() => server.close());

  TmdbClient client(String credential) => TmdbClient(
    createDio(retryDelay: const Duration(milliseconds: 5)),
    credential,
    baseUrl: server.url('/3'),
    rateLimitRetryCap: const Duration(milliseconds: 50),
  );

  test('detects API keys and read access tokens', () {
    expect(TmdbClient.authModeOf(apiKey), TmdbAuthMode.apiKey);
    expect(TmdbClient.authModeOf(' $token '), TmdbAuthMode.bearer);
    expect(TmdbClient.authModeOf('short.jwt.like'), TmdbAuthMode.apiKey);
  });

  test(
    'API key goes in the query, token in the Authorization header',
    () async {
      expect(await client(apiKey).test(), TmdbKeyStatus.ok);
      final keyRequest = server.requests.last;
      expect(keyRequest.uri.queryParameters['api_key'], apiKey);
      expect(keyRequest.headers.containsKey('authorization'), isFalse);

      expect(await client(token).test(), TmdbKeyStatus.ok);
      final tokenRequest = server.requests.last;
      expect(tokenRequest.uri.queryParameters.containsKey('api_key'), isFalse);
      expect(tokenRequest.headers['authorization'], 'Bearer $token');
    },
  );

  test('test() reports invalid and unreachable', () async {
    expect(
      await client('ffffffffffffffffffffffffffffffff').test(),
      TmdbKeyStatus.invalid,
    );
    final closed = TmdbClient(
      createDio(retries: 0),
      apiKey,
      baseUrl: 'http://127.0.0.1:${await closedPort()}/3',
    );
    expect(await closed.test(), TmdbKeyStatus.unreachable);
    server.route('/3/configuration', (r) => sendText(r, 'oops', status: 500));
    expect(await client(apiKey).test(), TmdbKeyStatus.unreachable);
  });

  test('details requests append images, credits, ratings and videos', () async {
    server.route('/3/movie/42', (r) => sendJson(r, {'id': 42, 'title': 'X'}));
    server.route('/3/tv/7', (r) => sendJson(r, {'id': 7, 'name': 'Y'}));
    final c = client(apiKey);
    expect(
      (await c.movie(
        42,
        language: 'tr-TR',
        imageLanguages: 'tr,en,null',
      ))['id'],
      42,
    );
    final q = server.requestsTo('/3/movie/42').single.uri.queryParameters;
    expect(q['language'], 'tr-TR');
    expect(q['append_to_response'], 'images,credits,release_dates,videos');
    expect(q['include_image_language'], 'tr,en,null');
    await c.tv(7, language: 'en-US', imageLanguages: 'en,null');
    final t = server.requestsTo('/3/tv/7').single.uri.queryParameters;
    expect(t['append_to_response'], 'images,credits,content_ratings,videos');
  });

  test('search and trending parameters', () async {
    server.route('/3/search/movie', (r) => sendJson(r, {'results': []}));
    server.route('/3/search/tv', (r) => sendJson(r, {'results': []}));
    server.route('/3/trending/tv/week', (r) => sendJson(r, {'results': []}));
    final c = client(token);
    await c.search(TmdbKind.movie, 'Kış Uykusu', year: 2014, language: 'tr-TR');
    final m = server.requestsTo('/3/search/movie').single.uri.queryParameters;
    expect(m['query'], 'Kış Uykusu');
    expect(m['year'], '2014');
    expect(m['include_adult'], 'false');
    await c.search(TmdbKind.tv, 'Sıcak Kafa', year: 2022, language: 'tr-TR');
    final t = server.requestsTo('/3/search/tv').single.uri.queryParameters;
    expect(t['first_air_date_year'], '2022');
    await c.trending(TmdbKind.tv, language: 'en-US');
    expect(server.requestsTo('/3/trending/tv/week'), hasLength(1));
  });

  test('errors map to kinds and never contain the credential', () async {
    server.route(
      '/3/movie/1',
      (r) => sendJson(r, {'status_code': 34}, status: 404),
    );
    server.route('/3/movie/2', (r) => sendText(r, '<html>nope</html>'));
    final c = client(apiKey);
    await expectLater(
      c.movie(1, language: 'en', imageLanguages: 'en,null'),
      throwsA(
        isA<TmdbException>()
            .having((e) => e.kind, 'kind', TmdbErrorKind.notFound)
            .having((e) => e.toString(), 'text', isNot(contains(apiKey))),
      ),
    );
    await expectLater(
      c.movie(2, language: 'en', imageLanguages: 'en,null'),
      throwsA(
        isA<TmdbException>().having(
          (e) => e.kind,
          'kind',
          TmdbErrorKind.unparseable,
        ),
      ),
    );
    final closed = TmdbClient(
      createDio(retries: 0),
      apiKey,
      baseUrl: 'http://127.0.0.1:${await closedPort()}/3',
    );
    await expectLater(
      closed.get('/configuration'),
      throwsA(
        isA<TmdbException>()
            .having((e) => e.kind, 'kind', TmdbErrorKind.network)
            .having((e) => e.toString(), 'text', isNot(contains(apiKey))),
      ),
    );
    expect(c.toString(), isNot(contains(apiKey)));
  });

  test('429 is retried once after Retry-After', () async {
    var calls = 0;
    server.route('/3/movie/5', (r) async {
      calls++;
      if (calls == 1) {
        r.response.headers.set('retry-after', '1');
        return sendJson(r, {'status_code': 25}, status: 429);
      }
      return sendJson(r, {'id': 5});
    });
    final c = client(apiKey);
    expect((await c.movie(5, language: 'en', imageLanguages: 'en'))['id'], 5);
    expect(calls, 2);

    server.route('/3/movie/6', (r) => sendJson(r, {}, status: 429));
    await expectLater(
      c.movie(6, language: 'en', imageLanguages: 'en'),
      throwsA(
        isA<TmdbException>().having(
          (e) => e.kind,
          'kind',
          TmdbErrorKind.rateLimited,
        ),
      ),
    );
    expect(server.requestsTo('/3/movie/6'), hasLength(2));
  });
}
