import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/providers/auth_provider.dart';
import 'package:jekyllpress/core/theme/app_theme.dart';
import 'package:jekyllpress/features/auth/presentation/login_screen.dart';
import 'package:jekyllpress/l10n/l10n.dart';

import 'fakes.dart';

/// AuthNotifier stub: signed out, no ApiClient wiring, no startup
/// auth check (nothing touches platform channels or the network)
class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthUnauthenticated();
}

void main() {
  testWidgets('login screen renders its core affordances', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          authNotifierProvider.overrideWith(_SignedOutAuthNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    // Let the entrance animation and the stored-client-id lookup settle
    await tester.pumpAndSettle();

    // Branding
    expect(find.text('JekyllPress'), findsOneWidget);

    // Primary auth path: Device Flow sign-in
    expect(find.text('Sign in with GitHub'), findsOneWidget);

    // Secondary auth path: PAT entry, collapsed behind a toggle
    final patToggle = find.text('Use a Personal Access Token instead');
    expect(patToggle, findsOneWidget);
    expect(find.text('Personal Access Token'), findsNothing);

    await tester.tap(patToggle);
    await tester.pumpAndSettle();

    expect(find.text('Personal Access Token'), findsOneWidget);
    expect(find.text('Connect with token'), findsOneWidget);
  });
}
