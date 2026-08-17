import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/services/auth_service.dart';

import 'fakes.dart';

const _userJson = '{"id": 1, "login": "gapp", "name": "Gapp", '
    '"avatar_url": "https://example.com/a.png", "email": null}';

void main() {
  group('checkExistingAuth', () {
    test('no stored token returns AuthFailure (login screen path)', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage(),
        dio: dioWithResponse((_) => jsonResponse(_userJson, 200)),
      );

      expect(await service.checkExistingAuth(), isA<AuthFailure>());
    });

    test('stored token + 200 returns AuthSuccess with user', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_token'),
        dio: dioWithResponse((_) => jsonResponse(_userJson, 200)),
      );

      final result = await service.checkExistingAuth();
      expect(result, isA<AuthSuccess>());
      expect((result as AuthSuccess).user.login, 'gapp');
    });

    test('stored token + 401 returns AuthFailure (revoked token)', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_revoked'),
        dio: dioWithResponse(
          (_) => jsonResponse('{"message": "Bad credentials"}', 401),
        ),
      );

      expect(await service.checkExistingAuth(), isA<AuthFailure>());
    });

    test('stored token + connection error returns AuthOffline', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_token'),
        dio: dioWithError(
          (options) => DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
        ),
      );

      expect(await service.checkExistingAuth(), isA<AuthOffline>());
    });

    test('stored token + connection timeout returns AuthOffline', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_token'),
        dio: dioWithError(
          (options) => DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      expect(await service.checkExistingAuth(), isA<AuthOffline>());
    });

    test('stored token + receive timeout returns AuthOffline', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_token'),
        dio: dioWithError(
          (options) => DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
      );

      expect(await service.checkExistingAuth(), isA<AuthOffline>());
    });

    test('stored token + SocketException (unknown) returns AuthOffline',
        () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_token'),
        dio: dioWithError((_) => const SocketException('unreachable')),
      );

      expect(await service.checkExistingAuth(), isA<AuthOffline>());
    });

    test('stored token + 403 (rate limit) does NOT log the user out',
        () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_token'),
        dio: dioWithResponse(
          (_) => jsonResponse('{"message": "rate limited"}', 403),
        ),
      );

      expect(await service.checkExistingAuth(), isA<AuthOffline>());
    });

    test('stored token + 500 does NOT log the user out', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage('ghp_token'),
        dio: dioWithResponse((_) => jsonResponse('{}', 500)),
      );

      expect(await service.checkExistingAuth(), isA<AuthOffline>());
    });
  });

  group('validateToken (interactive login stays strict)', () {
    test('connection error returns AuthFailure, never AuthOffline', () async {
      final service = AuthService(
        secureStorage: FakeSecureStorage(),
        dio: dioWithError(
          (options) => DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
        ),
      );

      expect(await service.validateToken('ghp_token'), isA<AuthFailure>());
    });

    test('valid token saves it and returns AuthSuccess', () async {
      final storage = FakeSecureStorage();
      final service = AuthService(
        secureStorage: storage,
        dio: dioWithResponse((_) => jsonResponse(_userJson, 200)),
      );

      expect(await service.validateToken('ghp_new'), isA<AuthSuccess>());
      expect(storage.token, 'ghp_new');
    });
  });
}
