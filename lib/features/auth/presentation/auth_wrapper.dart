import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../config/presentation/config_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import 'login_screen.dart';

/// Wrapper that manages the app navigation flow:
/// 1. Login -> 2. Config (if not set) -> 3. Dashboard
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final configState = ref.watch(configNotifierProvider);

    // First check auth state
    return switch (authState) {
      AuthInitial() => const _SplashScreen(),
      AuthLoading() => const _SplashScreen(),
      AuthUnauthenticated() => const LoginScreen(),
      AuthAuthenticated() => _handleAuthenticatedState(configState),
    };
  }

  Widget _handleAuthenticatedState(ConfigState configState) {
    // User is authenticated, now check config
    return switch (configState) {
      ConfigInitial() => const _SplashScreen(),
      ConfigLoading() => const _SplashScreen(),
      ConfigNotSet() => const ConfigScreen(),
      ConfigLoaded() => const DashboardScreen(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B14),
              Color(0xFF0A1910),
              Color(0xFF0D1B14),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 64,
                color: Color(0xFFE8A87C),
              ),
              SizedBox(height: 24),
              Text(
                'JekyllPress',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF5F5F0),
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFE8A87C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
