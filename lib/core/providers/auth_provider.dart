import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/github_user.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';

part 'auth_provider.g.dart';

/// Provider for SecureStorageService
@riverpod
SecureStorageService secureStorage(Ref ref) {
  return SecureStorageService();
}

/// Provider for AuthService
@riverpod
AuthService authService(Ref ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthService(secureStorage: secureStorage);
}

/// State for authentication
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final GitHubUser user;
  const AuthAuthenticated(this.user);
}

/// A stored token exists but GitHub is unreachable (offline launch,
/// flaky network, GitHub outage). The user proceeds with cached data.
class AuthOfflineAuthenticated extends AuthState {
  const AuthOfflineAuthenticated();
}

class AuthUnauthenticated extends AuthState {
  final String? message;
  const AuthUnauthenticated([this.message]);
}

/// Notifier for managing auth state
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Check for existing auth on startup. Scheduled as a microtask so the
    // state writes aren't clobbered by build()'s own return value.
    Future.microtask(() async {
      try {
        await _checkExistingAuth();
      } catch (_) {
        // Provider was disposed before the check completed
      }
    });
    return const AuthLoading();
  }

  Future<void> _checkExistingAuth() async {
    final authService = ref.read(authServiceProvider);
    final result = await authService.checkExistingAuth();

    state = switch (result) {
      AuthSuccess(user: final user) => AuthAuthenticated(user),
      // Stored token but GitHub unreachable: stay in, use cached data
      AuthOffline() => const AuthOfflineAuthenticated(),
      AuthFailure() => const AuthUnauthenticated(),
    };
  }

  Future<bool> login(String token) async {
    state = const AuthLoading();
    final authService = ref.read(authServiceProvider);
    final result = await authService.validateToken(token);

    switch (result) {
      case AuthSuccess(user: final user):
        state = AuthAuthenticated(user);
        return true;
      case AuthOffline():
        // validateToken never returns this, but handle it defensively
        state = const AuthUnauthenticated('No internet connection');
        return false;
      case AuthFailure(message: final message):
        state = AuthUnauthenticated(message);
        return false;
    }
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    state = const AuthUnauthenticated();
  }
}
