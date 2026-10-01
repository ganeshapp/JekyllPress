import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/models/app_config.dart';
import 'core/models/blog_post.dart';
import 'core/models/local_draft.dart';
import 'core/platform.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_wrapper.dart';
import 'l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage (== Hive.initFlutter() on Android)
  Hive.init((await appDataDir()).path);

  // Register Hive adapters
  Hive.registerAdapter(AppConfigAdapter());
  Hive.registerAdapter(BlogPostAdapter());
  Hive.registerAdapter(LocalDraftAdapter());

  // Open Hive boxes
  await Hive.openBox<AppConfig>('app_config');
  await Hive.openBox<BlogPost>('posts_box');
  await Hive.openBox<String>('local_image_map');
  await Hive.openBox<LocalDraft>('drafts_box');
  // Offline publish queue - plain-map entries, no TypeAdapter
  await Hive.openBox<Map>('publish_queue');
  // App-level settings (theme mode override)
  await Hive.openBox<String>('app_settings');

  runApp(
    const ProviderScope(
      child: JekyllPressApp(),
    ),
  );
}

class JekyllPressApp extends ConsumerWidget {
  const JekyllPressApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // Keep the status/navigation bars legible in whichever theme is
      // active (system bars follow the resolved scheme, not a constant)
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme;
        final iconBrightness = scheme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarColor: scheme.surface,
            systemNavigationBarIconBrightness: iconBrightness,
          ),
          // Desktop: keep lines readable in a wide window
          child: isDesktop
              ? ColoredBox(
                  color: scheme.surface,
                  child: Center(child: SizedBox(width: 900, child: child)))
              : child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthWrapper(),
    );
  }
}
