import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/services/dio_client.dart';

import 'fakes.dart';

const _okBody = '{"ok": true}';

/// ApiClient over a scripted adapter (interceptors stay active)
ApiClient _client(
  ResponseBody Function(RequestOptions) handler, {
  String? token,
}) {
  final client = ApiClient(secureStorage: FakeSecureStorage(token));
  client.dio.httpClientAdapter = FakeHttpAdapter(handler);
  return client;
}

ResponseBody _rateLimited(
  int status, {
  String? remaining,
  String? retryAfter,
  String? resetEpoch,
}) {
  return ResponseBody.fromString(
    '{"message": "API rate limit exceeded"}',
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (remaining != null) 'x-ratelimit-remaining': [remaining],
      if (retryAfter != null) 'retry-after': [retryAfter],
      if (resetEpoch != null) 'x-ratelimit-reset': [resetEpoch],
    },
  );
}

void main() {
  group('auth interceptor', () {
    test('injects Bearer token from storage', () async {
      RequestOptions? seen;
      final client = _client(
        (options) {
          seen = options;
          return jsonResponse(_okBody, 200);
        },
        token: 'ghp_stored',
      );

      await client.dio.get('/user');

      expect(seen!.headers['Authorization'], 'Bearer ghp_stored');
    });

    test('skips the header when no token is stored', () async {
      RequestOptions? seen;
      final client = _client((options) {
        seen = options;
        return jsonResponse(_okBody, 200);
      });

      await client.dio.get('/user');

      expect(seen!.headers.containsKey('Authorization'), isFalse);
    });

    test('never overwrites an explicit Authorization header', () async {
      RequestOptions? seen;
      final client = _client(
        (options) {
          seen = options;
          return jsonResponse(_okBody, 200);
        },
        token: 'ghp_stored',
      );

      await client.dio.get(
        '/user',
        options: Options(headers: {'Authorization': 'Bearer ghp_candidate'}),
      );

      expect(seen!.headers['Authorization'], 'Bearer ghp_candidate');
    });

    test('sets the GitHub API base headers', () async {
      RequestOptions? seen;
      final client = _client((options) {
        seen = options;
        return jsonResponse(_okBody, 200);
      });

      await client.dio.get('/user');

      expect(seen!.uri.host, 'api.github.com');
      expect(seen!.headers['Accept'], 'application/vnd.github+json');
      expect(seen!.headers['X-GitHub-Api-Version'], '2022-11-28');
    });
  });

  group('401 handling', () {
    test('401 fires onUnauthorized', () async {
      var fired = 0;
      final client = _client(
        (_) => jsonResponse('{"message": "Bad credentials"}', 401),
        token: 'ghp_revoked',
      );
      client.onUnauthorized = () => fired++;

      await expectLater(client.dio.get('/user'), throwsA(isA<DioException>()));

      expect(fired, 1);
    });

    test('401 with skipUnauthorizedHandler does NOT fire (no auth loop)',
        () async {
      var fired = 0;
      final client = _client(
        (_) => jsonResponse('{"message": "Bad credentials"}', 401),
        token: 'ghp_revoked',
      );
      client.onUnauthorized = () => fired++;

      await expectLater(
        client.dio.get(
          '/user',
          options: Options(extra: {ApiClient.skipUnauthorizedHandler: true}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(fired, 0);
    });

    test('non-401 errors do not fire onUnauthorized', () async {
      var fired = 0;
      final client = _client(
        (_) => jsonResponse('{"message": "Not Found"}', 404),
        token: 'ghp_token',
      );
      client.onUnauthorized = () => fired++;

      await expectLater(client.dio.get('/x'), throwsA(isA<DioException>()));

      expect(fired, 0);
    });
  });

  group('rate-limit handling', () {
    Future<DioException> requestError(ApiClient client) async {
      try {
        await client.dio.get('/user');
        fail('expected a DioException');
      } on DioException catch (e) {
        return e;
      }
    }

    test('403 with X-RateLimit-Remaining: 0 becomes a rate-limit error',
        () async {
      final reset = DateTime.now().add(const Duration(minutes: 5));
      final client = _client(
        (_) => _rateLimited(
          403,
          remaining: '0',
          resetEpoch: '${reset.millisecondsSinceEpoch ~/ 1000}',
        ),
        token: 'ghp_token',
      );

      final e = await requestError(client);

      expect(ApiClient.isRateLimit(e), isTrue);
      expect(ApiClient.friendlyError(e),
          'GitHub rate limit exceeded - try again in 5m');
    });

    test('429 with Retry-After becomes a rate-limit error (rounded up)',
        () async {
      final client = _client(
        (_) => _rateLimited(429, retryAfter: '90'),
        token: 'ghp_token',
      );

      final e = await requestError(client);

      expect(ApiClient.isRateLimit(e), isTrue);
      expect(ApiClient.friendlyError(e),
          'GitHub rate limit exceeded - try again in 2m');
    });

    test('rate limit with no reset info suggests 1m', () async {
      final client = _client(
        (_) => _rateLimited(403, remaining: '0'),
        token: 'ghp_token',
      );

      final e = await requestError(client);

      expect(ApiClient.friendlyError(e),
          'GitHub rate limit exceeded - try again in 1m');
    });

    test('rate-limited 401-free requests do not fire onUnauthorized',
        () async {
      var fired = 0;
      final client = _client(
        (_) => _rateLimited(403, remaining: '0'),
        token: 'ghp_token',
      );
      client.onUnauthorized = () => fired++;

      await requestError(client);

      expect(fired, 0);
    });

    test('plain 403 (real permission error) is NOT a rate limit', () async {
      final client = _client(
        (_) => _rateLimited(403, remaining: '42'),
        token: 'ghp_token',
      );

      final e = await requestError(client);

      expect(ApiClient.isRateLimit(e), isFalse);
      expect(ApiClient.friendlyError(e),
          'GitHub error (403): API rate limit exceeded');
    });
  });

  group('friendlyError', () {
    RequestOptions options() => RequestOptions(path: '/user');

    test('timeouts map to a connection message', () {
      final e = DioException(
        requestOptions: options(),
        type: DioExceptionType.receiveTimeout,
      );
      expect(ApiClient.friendlyError(e),
          'Connection timed out. Please check your internet.');
    });

    test('connection errors map to no-internet', () {
      final e = DioException.connectionError(
        requestOptions: options(),
        reason: 'offline',
      );
      expect(ApiClient.friendlyError(e), 'No internet connection');
    });

    test('401 maps to a sign-in-again message', () {
      final e = DioException(
        requestOptions: options(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options(), statusCode: 401),
      );
      expect(ApiClient.friendlyError(e),
          'Authentication failed - sign in again');
    });

    test('other responses include the GitHub message', () {
      final e = DioException(
        requestOptions: options(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options(),
          statusCode: 422,
          data: {'message': 'Validation Failed'},
        ),
      );
      expect(
          ApiClient.friendlyError(e), 'GitHub error (422): Validation Failed');
    });
  });

  group('authHeaders', () {
    test('returns Bearer header when a token is stored', () async {
      final client = ApiClient(secureStorage: FakeSecureStorage('ghp_token'));
      expect(await client.authHeaders(), {
        'Authorization': 'Bearer ghp_token',
      });
    });

    test('returns null when logged out', () async {
      final client = ApiClient(secureStorage: FakeSecureStorage());
      expect(await client.authHeaders(), isNull);
    });
  });

  group('ApiException', () {
    test('toString is exactly the message (verbatim in catch-alls)', () {
      expect(
        const ApiException('GitHub rate limit exceeded - try again in 3m')
            .toString(),
        'GitHub rate limit exceeded - try again in 3m',
      );
    });
  });
}
