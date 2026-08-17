import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/services/dio_client.dart';
import 'package:jekyllpress/core/services/github_oauth_service.dart';
import 'package:jekyllpress/core/services/secure_storage_service.dart';

import 'fakes.dart';

const _clientId = 'Iv1.abc123';
const _deviceCode = 'dev_code_123';

/// GitHubOAuthService over a scripted adapter (github.com host)
GitHubOAuthService _service(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'https://github.com'));
  dio.httpClientAdapter = FakeHttpAdapter(handler);
  return GitHubOAuthService(dio: dio);
}

ResponseBody _json(Map<String, dynamic> body, [int status = 200]) {
  return jsonResponse(jsonEncode(body), status);
}

/// One canned response per poll, in order; extra polls repeat the last
ResponseBody Function(RequestOptions) _script(
  List<Map<String, dynamic>> bodies, {
  List<RequestOptions>? seen,
}) {
  var call = 0;
  return (options) {
    seen?.add(options);
    final body = bodies[call < bodies.length ? call : bodies.length - 1];
    call++;
    return _json(body);
  };
}

Future<DeviceFlowResult> _poll(
  GitHubOAuthService service, {
  int interval = 5,
  int expiresIn = 900,
  bool Function()? isCancelled,
  List<Duration>? waits,
}) {
  return service.pollForToken(
    clientId: _clientId,
    deviceCode: _deviceCode,
    interval: interval,
    expiresIn: expiresIn,
    isCancelled: isCancelled,
    wait: (delay) async => waits?.add(delay),
  );
}

void main() {
  group('startDeviceFlow', () {
    test('parses the device code response and sends the right request',
        () async {
      RequestOptions? seenOptions;
      final service = _service((options) {
        seenOptions = options;
        return _json({
          'device_code': _deviceCode,
          'user_code': 'ABCD-1234',
          'verification_uri': 'https://github.com/login/device',
          'expires_in': 899,
          'interval': 5,
        });
      });

      final code = await service.startDeviceFlow(_clientId);

      expect(code.deviceCode, _deviceCode);
      expect(code.userCode, 'ABCD-1234');
      expect(code.verificationUri, 'https://github.com/login/device');
      expect(code.expiresIn, 899);
      expect(code.interval, 5);
      expect(seenOptions!.path, '/login/device/code');
      expect(seenOptions!.data, {'client_id': _clientId});
      expect(seenOptions!.headers['Accept'], 'application/json');
      expect(seenOptions!.contentType,
          startsWith(Headers.formUrlEncodedContentType));
    });

    test('fills sensible defaults when optional fields are missing',
        () async {
      final service = _service((_) => _json({
            'device_code': _deviceCode,
            'user_code': 'ABCD-1234',
          }));

      final code = await service.startDeviceFlow(_clientId);

      expect(code.verificationUri, 'https://github.com/login/device');
      expect(code.expiresIn, 900);
      expect(code.interval, 5);
    });

    test('surfaces the OAuth error description as an ApiException',
        () async {
      final service = _service((_) => _json({
            'error': 'device_flow_disabled',
            'error_description': 'Device Flow must be explicitly enabled.',
          }, 400));

      await expectLater(
        service.startDeviceFlow(_clientId),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Device Flow must be explicitly enabled.')),
      );
    });

    test('maps a 404 (unknown client id) to a clear message', () async {
      final service =
          _service((_) => jsonResponse('{"message": "Not Found"}', 404));

      await expectLater(
        service.startDeviceFlow(_clientId),
        throwsA(isA<ApiException>().having(
            (e) => e.message,
            'message',
            'GitHub does not recognize this Client ID - '
                'check it and try again')),
      );
    });
  });

  group('pollForToken outcome mapping', () {
    test('authorization_pending keeps polling until success', () async {
      final seen = <RequestOptions>[];
      final waits = <Duration>[];
      final service = _service(_script([
        {'error': 'authorization_pending'},
        {'error': 'authorization_pending'},
        {
          'access_token': 'ghu_access',
          'refresh_token': 'ghr_refresh',
          'expires_in': 28800,
          'token_type': 'bearer',
        },
      ], seen: seen));

      final result = await _poll(service, waits: waits);

      expect(result, isA<DeviceFlowSuccess>());
      final tokens = (result as DeviceFlowSuccess).tokens;
      expect(tokens.accessToken, 'ghu_access');
      expect(tokens.refreshToken, 'ghr_refresh');
      expect(tokens.expiresInSeconds, 28800);
      expect(seen, hasLength(3));
      // Waits the interval before every poll, including the first
      expect(waits, everyElement(const Duration(seconds: 5)));
      expect(waits, hasLength(3));
      expect(seen.first.path, '/login/oauth/access_token');
      expect(seen.first.data, {
        'client_id': _clientId,
        'device_code': _deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      });
    });

    test('OAuth App success (no refresh token) parses with nulls', () async {
      final service = _service(_script([
        {'access_token': 'gho_access', 'token_type': 'bearer', 'scope': ''},
      ]));

      final result = await _poll(service);

      final tokens = (result as DeviceFlowSuccess).tokens;
      expect(tokens.accessToken, 'gho_access');
      expect(tokens.refreshToken, isNull);
      expect(tokens.expiresInSeconds, isNull);
    });

    test('slow_down adds 5s to the interval each time', () async {
      final waits = <Duration>[];
      final service = _service(_script([
        {'error': 'slow_down'},
        {'error': 'slow_down'},
        {'access_token': 'ghu_access'},
      ]));

      final result = await _poll(service, waits: waits);

      expect(result, isA<DeviceFlowSuccess>());
      expect(waits, const [
        Duration(seconds: 5),
        Duration(seconds: 10),
        Duration(seconds: 15),
      ]);
    });

    test('expired_token maps to DeviceFlowExpired', () async {
      final service = _service(_script([
        {'error': 'expired_token'},
      ]));

      expect(await _poll(service), isA<DeviceFlowExpired>());
    });

    test('access_denied maps to DeviceFlowDenied', () async {
      final service = _service(_script([
        {'error': 'access_denied'},
      ]));

      expect(await _poll(service), isA<DeviceFlowDenied>());
    });

    test('device_flow_disabled maps to DeviceFlowDisabled', () async {
      final service = _service(_script([
        {'error': 'device_flow_disabled'},
      ]));

      expect(await _poll(service), isA<DeviceFlowDisabled>());
    });

    test('unknown OAuth error maps to DeviceFlowFailure with the '
        'description', () async {
      final service = _service(_script([
        {
          'error': 'incorrect_device_code',
          'error_description': 'The device_code provided is not valid.',
        },
      ]));

      final result = await _poll(service);

      expect(result, isA<DeviceFlowFailure>());
      expect((result as DeviceFlowFailure).message,
          'The device_code provided is not valid.');
    });

    test('gives up with DeviceFlowExpired once expiresIn is spent',
        () async {
      final seen = <RequestOptions>[];
      final service = _service(_script([
        {'error': 'authorization_pending'},
      ], seen: seen));

      final result = await _poll(service, interval: 5, expiresIn: 8);

      expect(result, isA<DeviceFlowExpired>());
      // 8s budget at 5s per poll = exactly two polls before giving up
      expect(seen, hasLength(2));
    });

    test('cancellation stops before the first poll', () async {
      final seen = <RequestOptions>[];
      final service = _service(_script([
        {'error': 'authorization_pending'},
      ], seen: seen));

      final result = await _poll(service, isCancelled: () => true);

      expect(result, isA<DeviceFlowCancelled>());
      expect(seen, isEmpty);
    });

    test('cancellation mid-flow stops after the current poll', () async {
      final seen = <RequestOptions>[];
      var cancelled = false;
      final service = _service((options) {
        seen.add(options);
        cancelled = true; // The user taps cancel while a poll is in flight
        return _json({'error': 'authorization_pending'});
      });

      final result = await _poll(service, isCancelled: () => cancelled);

      expect(result, isA<DeviceFlowCancelled>());
      expect(seen, hasLength(1));
    });

    test('a network error maps to DeviceFlowFailure', () async {
      final service = _service((_) => _json(const {}, 500));

      final result = await _poll(service);

      expect(result, isA<DeviceFlowFailure>());
      expect((result as DeviceFlowFailure).message, 'GitHub error (500)');
    });
  });

  group('refreshAccessToken', () {
    test('returns the rotated access + refresh pair', () async {
      RequestOptions? seenOptions;
      final service = _service((options) {
        seenOptions = options;
        return _json({
          'access_token': 'ghu_new',
          'refresh_token': 'ghr_new',
          'expires_in': 28800,
        });
      });

      final tokens = await service.refreshAccessToken(
        clientId: _clientId,
        refreshToken: 'ghr_old',
      );

      expect(tokens.accessToken, 'ghu_new');
      expect(tokens.refreshToken, 'ghr_new');
      expect(tokens.expiresInSeconds, 28800);
      expect(seenOptions!.path, '/login/oauth/access_token');
      expect(seenOptions!.data, {
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': 'ghr_old',
      });
    });

    test('a 200 with an OAuth error body throws OAuthRefreshDenied',
        () async {
      final service = _service((_) => _json({
            'error': 'bad_refresh_token',
            'error_description': 'The refresh token passed is incorrect.',
          }));

      await expectLater(
        service.refreshAccessToken(
            clientId: _clientId, refreshToken: 'ghr_burned'),
        throwsA(isA<OAuthRefreshDenied>().having((e) => e.message, 'message',
            'The refresh token passed is incorrect.')),
      );
    });

    test('a 4xx with an OAuth error body throws OAuthRefreshDenied',
        () async {
      final service = _service(
          (_) => _json({'error': 'incorrect_client_credentials'}, 400));

      await expectLater(
        service.refreshAccessToken(
            clientId: _clientId, refreshToken: 'ghr_old'),
        throwsA(isA<OAuthRefreshDenied>()),
      );
    });

    test('a 5xx stays a DioException (transient, not a dead session)',
        () async {
      final service = _service((_) => _json(const {}, 500));

      await expectLater(
        service.refreshAccessToken(
            clientId: _clientId, refreshToken: 'ghr_old'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiClient device-token auto-refresh', () {
    /// Device-flow session whose access token expires within the leeway
    FakeSecureStorage expiringStorage() => FakeSecureStorage('ghu_old')
      ..authMethod = AuthMethods.device
      ..clientId = _clientId
      ..refreshToken = 'ghr_old'
      ..accessTokenExpiry =
          DateTime.now().add(const Duration(minutes: 2));

    /// ApiClient whose api.github.com responses echo OK and whose
    /// github.com (OAuth) responses come from [oauthHandler]
    (ApiClient, List<RequestOptions>) client(
      FakeSecureStorage storage,
      ResponseBody Function(RequestOptions) oauthHandler,
    ) {
      final oauthDio = Dio(BaseOptions(baseUrl: 'https://github.com'));
      oauthDio.httpClientAdapter = FakeHttpAdapter(oauthHandler);
      final apiClient = ApiClient(
        secureStorage: storage,
        oauthService: GitHubOAuthService(dio: oauthDio),
      );
      final apiRequests = <RequestOptions>[];
      apiClient.dio.httpClientAdapter = FakeHttpAdapter((options) {
        apiRequests.add(options);
        return jsonResponse('{"ok": true}', 200);
      });
      return (apiClient, apiRequests);
    }

    ResponseBody rotatedTokens(RequestOptions _) => _json({
          'access_token': 'ghu_new',
          'refresh_token': 'ghr_new',
          'expires_in': 28800,
        });

    test('refreshes before the request and uses the new token', () async {
      final storage = expiringStorage();
      final (apiClient, apiRequests) = client(storage, rotatedTokens);

      await apiClient.dio.get('/user');

      expect(apiRequests.single.headers['Authorization'], 'Bearer ghu_new');
      expect(storage.token, 'ghu_new');
      expect(storage.refreshToken, 'ghr_new');
      expect(storage.authMethod, AuthMethods.device);
      final expiresIn = storage.accessTokenExpiry!
          .difference(DateTime.now())
          .inMinutes;
      expect(expiresIn, inInclusiveRange(8 * 60 - 2, 8 * 60));
    });

    test('rotation writes the new refresh token BEFORE the access token '
        '(single-use refresh survives a crash mid-update)', () async {
      final storage = expiringStorage();
      final (apiClient, _) = client(storage, rotatedTokens);

      await apiClient.dio.get('/user');

      expect(storage.writeLog,
          ['refreshToken', 'accessTokenExpiry', 'token', 'authMethod']);
    });

    test('single-flight: concurrent requests share one refresh', () async {
      final storage = expiringStorage();
      var refreshCalls = 0;
      final (apiClient, apiRequests) = client(storage, (options) {
        refreshCalls++;
        return rotatedTokens(options);
      });

      await Future.wait([
        apiClient.dio.get('/user'),
        apiClient.dio.get('/user/repos'),
        apiClient.dio.get('/rate_limit'),
      ]);

      expect(refreshCalls, 1);
      expect(apiRequests, hasLength(3));
      for (final request in apiRequests) {
        expect(request.headers['Authorization'], 'Bearer ghu_new');
      }
    });

    test('keeps the old refresh token when the response omits one',
        () async {
      final storage = expiringStorage();
      final (apiClient, _) = client(
        storage,
        (_) => _json({'access_token': 'ghu_new'}),
      );

      await apiClient.dio.get('/user');

      expect(storage.token, 'ghu_new');
      expect(storage.refreshToken, 'ghr_old');
    });

    test('a denied refresh fires onUnauthorized (logout path) and the '
        'request proceeds with the old token', () async {
      final storage = expiringStorage();
      var unauthorized = 0;
      final (apiClient, apiRequests) = client(
        storage,
        (_) => _json({'error': 'bad_refresh_token'}),
      );
      apiClient.onUnauthorized = () => unauthorized++;

      await apiClient.dio.get('/user');

      expect(unauthorized, 1);
      expect(apiRequests.single.headers['Authorization'], 'Bearer ghu_old');
      expect(storage.token, 'ghu_old');
    });

    test('a transient refresh failure keeps the session (no logout, old '
        'token used)', () async {
      final storage = expiringStorage();
      var unauthorized = 0;
      final (apiClient, apiRequests) =
          client(storage, (_) => _json(const {}, 500));
      apiClient.onUnauthorized = () => unauthorized++;

      await apiClient.dio.get('/user');

      expect(unauthorized, 0);
      expect(apiRequests.single.headers['Authorization'], 'Bearer ghu_old');
    });

    test('does not refresh when the token is still fresh', () async {
      final storage = expiringStorage()
        ..accessTokenExpiry = DateTime.now().add(const Duration(hours: 1));
      var refreshCalls = 0;
      final (apiClient, apiRequests) = client(storage, (options) {
        refreshCalls++;
        return rotatedTokens(options);
      });

      await apiClient.dio.get('/user');

      expect(refreshCalls, 0);
      expect(apiRequests.single.headers['Authorization'], 'Bearer ghu_old');
    });

    test('does not refresh OAuth-App sessions (no expiry stored)',
        () async {
      final storage = expiringStorage()
        ..refreshToken = null
        ..accessTokenExpiry = null;
      var refreshCalls = 0;
      final (apiClient, _) = client(storage, (options) {
        refreshCalls++;
        return rotatedTokens(options);
      });

      await apiClient.dio.get('/user');

      expect(refreshCalls, 0);
    });

    test('does not refresh PAT sessions', () async {
      final storage = expiringStorage()..authMethod = AuthMethods.pat;
      var refreshCalls = 0;
      final (apiClient, _) = client(storage, (options) {
        refreshCalls++;
        return rotatedTokens(options);
      });

      await apiClient.dio.get('/user');

      expect(refreshCalls, 0);
    });

    test('does not refresh for requests carrying an explicit '
        'Authorization header (login validation)', () async {
      final storage = expiringStorage();
      var refreshCalls = 0;
      final (apiClient, apiRequests) = client(storage, (options) {
        refreshCalls++;
        return rotatedTokens(options);
      });

      await apiClient.dio.get(
        '/user',
        options: Options(headers: {'Authorization': 'Bearer candidate'}),
      );

      expect(refreshCalls, 0);
      expect(
          apiRequests.single.headers['Authorization'], 'Bearer candidate');
    });
  });

  group('logout storage clearing', () {
    test('deleteToken clears the device-flow session but keeps the client '
        'id for one-tap re-login', () async {
      final storage = FakeSecureStorage('ghu_token')
        ..authMethod = AuthMethods.device
        ..clientId = _clientId
        ..refreshToken = 'ghr_token'
        ..accessTokenExpiry = DateTime.now();

      await storage.deleteToken();

      expect(storage.token, isNull);
      expect(storage.authMethod, isNull);
      expect(storage.refreshToken, isNull);
      expect(storage.accessTokenExpiry, isNull);
      expect(storage.clientId, _clientId);
    });
  });
}
