import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/github_user.dart';
import 'package:jekyllpress/core/providers/auth_provider.dart';
import 'package:jekyllpress/core/services/auth_service.dart';

import 'fakes.dart';

/// AuthService whose checkExistingAuth result is scripted from the test
class FakeAuthService extends AuthService {
  final AuthResult result;

  FakeAuthService(this.result)
      : super(secureStorage: FakeSecureStorage('ghp_token'));

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
  });
}
