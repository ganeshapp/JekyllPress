import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/github_user.dart';
import 'package:jekyllpress/core/providers/auth_provider.dart';
import 'package:jekyllpress/core/services/auth_service.dart';
import 'package:jekyllpress/core/services/dio_client.dart';

import 'fakes.dart';

/// AuthService whose checkExistingAuth result is scripted from the test
class FakeAuthService extends AuthService {
  final AuthResult result;
  final FakeSecureStorage storage;

  FakeAuthService._(this.result, this.storage)
      : super(secureStorage: storage, dio: Dio());

  factory FakeAuthService(AuthResult result, [FakeSecureStorage? storage]) {
    return FakeAuthService._(result, storage ?? FakeSecureStorage('ghp_token'));
  }

  @override
  Future<AuthResult> checkExistingAuth() async => result;
}

const _user = GitHubUser(
  id: 1,
  login: 'gapp',
  avatarUrl: 'https://example.com/a.png',
);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

ProviderContainer _containerWith(AuthResult result) {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(FakeAuthService(result)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(authNotifierProvider, (_, __) {});
  return container;
}

void main() {
  group('AuthNotifier startup', () {
    test('starts in AuthLoading (splash), not clobbered by build', () {
      final container = _containerWith(const AuthOffline());
      expect(container.read(authNotifierProvider), isA<AuthLoading>());
    });

    test('AuthSuccess maps to AuthAuthenticated', () async {
      final container = _containerWith(const AuthSuccess(_user));
      container.read(authNotifierProvider);
      await _settle();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user.login, 'gapp');
    });

    test('AuthOffline maps to AuthOfflineAuthenticated (dashboard, not login)',
        () async {
      final container = _containerWith(const AuthOffline());
      container.read(authNotifierProvider);
      await _settle();

      expect(container.read(authNotifierProvider),
          isA<AuthOfflineAuthenticated>());
    });

    test('AuthFailure maps to AuthUnauthenticated (login screen)', () async {
      final container = _containerWith(const AuthFailure('No token stored'));
      container.read(authNotifierProvider);
      await _settle();

      expect(
          container.read(authNotifierProvider), isA<AuthUnauthenticated>());
    });

    test('build wires the ApiClient 401 callback', () async {
      final container = _containerWith(const AuthSuccess(_user));
      container.read(authNotifierProvider);
      await _settle();

      expect(container.read(apiClientProvider).onUnauthorized, isNotNull);
    });
  });

  group('AuthNotifier.onSessionExpired (401 mid-session)', () {
    test('moves to AuthUnauthenticated with session-expired message '
        'and clears the token', () async {
      final storage = FakeSecureStorage('ghp_revoked');
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(const AuthSuccess(_user), storage),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authNotifierProvider, (_, __) {});
      await _settle();
      expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());

      await container
          .read(authNotifierProvider.notifier)
          .onSessionExpired();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).message,
          'Session expired - sign in again');
      expect(storage.token, isNull);
    });

    test('fires when the ApiClient reports a 401', () async {
      final storage = FakeSecureStorage('ghp_revoked');
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(const AuthSuccess(_user), storage),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authNotifierProvider, (_, __) {});
      await _settle();
      expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());

      container.read(apiClientProvider).onUnauthorized!.call();
      await _settle();

      expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
    });

    test('is a no-op when already unauthenticated (no message overwrite, '
        'no loop)', () async {
      final container =
          _containerWith(const AuthFailure('No token stored'));
      container.read(authNotifierProvider);
      await _settle();

      await container
          .read(authNotifierProvider.notifier)
          .onSessionExpired();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).message, isNull);
    });
  });
}
