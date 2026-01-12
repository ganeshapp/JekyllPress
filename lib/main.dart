import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/models/app_config.dart';
import 'core/models/blog_post.dart';
import 'core/models/local_draft.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(AppConfigAdapter());
  Hive.registerAdapter(BlogPostAdapter());
  Hive.registerAdapter(LocalDraftAdapter());

  // Open Hive boxes
  await Hive.openBox<AppConfig>('app_config');
  await Hive.openBox<BlogPost>('posts_box');
  await Hive.openBox<String>('local_image_map');
  await Hive.openBox<LocalDraft>('drafts_box');

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1B14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock to portrait mode for optimal UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: JekyllPressApp(),
    ),
  );
}

class JekyllPressApp extends StatelessWidget {
  const JekyllPressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JekyllPress',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}
