import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/theme/app_theme.dart';

/// WCAG 2.1 relative luminance of an opaque colour
double _luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG 2.1 contrast ratio between two opaque colours (1.0 - 21.0)
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppTheme.darkTheme', () {
    test('preserves the original brand palette (visual baseline)', () {
      final scheme = AppTheme.darkTheme.colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFFE8A87C));
      expect(scheme.onPrimary, const Color(0xFF0D1B14));
      expect(scheme.surface, const Color(0xFF0D1B14));
      expect(scheme.surfaceContainer, const Color(0xFF162A1E));
      expect(scheme.surfaceContainerHigh, const Color(0xFF1A2F23));
      expect(scheme.onSurface, const Color(0xFFF5F5F0));
      expect(scheme.onSurfaceVariant, const Color(0xFFA8B5A0));
      expect(scheme.secondary, const Color(0xFFA8B5A0));
      expect(scheme.outline, const Color(0xFF2D4A3E));
      expect(scheme.error, const Color(0xFFE57373));
    });

    test('carries the semantic AppColors extension', () {
      final colors = AppTheme.darkTheme.extension<AppColors>();

      expect(colors, isNotNull);
      expect(colors!.success, const Color(0xFF81C784));
      expect(colors.warning, const Color(0xFFE8A87C));
      expect(colors.info, const Color(0xFF4DB6AC));
    });

    test('text theme colors come from the scheme, not hardcoded values', () {
      final theme = AppTheme.darkTheme;
      final scheme = theme.colorScheme;

      expect(theme.textTheme.displayLarge?.color, scheme.onSurface);
      expect(theme.textTheme.titleLarge?.color, scheme.onSurface);
      expect(theme.textTheme.bodyLarge?.color, scheme.onSurface);
      expect(theme.textTheme.bodyMedium?.color, scheme.onSurfaceVariant);
    });
  });

  group('AppTheme.lightTheme', () {
    test('is a light equivalent of the same hues', () {
      final scheme = AppTheme.lightTheme.colorScheme;

      expect(scheme.brightness, Brightness.light);
      // Deep green text on warm off-white surfaces
      expect(scheme.onSurface, const Color(0xFF1A2F23));
      expect(scheme.surface, const Color(0xFFFAF7F0));
      // Peach primary darkened for contrast
      expect(scheme.primary, const Color(0xFF96502A));
    });

    test('carries a light mapping of the semantic AppColors', () {
      final colors = AppTheme.lightTheme.extension<AppColors>();

      expect(colors, isNotNull);
      expect(colors!.success, isNot(AppColors.dark.success));
      expect(colors.info, isNot(AppColors.dark.info));
    });
  });

  group('themed foreground/background pairing', () {
    test('body text stays legible on the scaffold surface in both themes', () {
      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        final scheme = theme.colorScheme;
        expect(
          _contrast(scheme.onSurface, scheme.surface),
          greaterThan(4.5),
          reason: 'onSurface on surface (${scheme.brightness})',
        );
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThan(3.0),
          reason: 'onSurfaceVariant on surface (${scheme.brightness})',
        );
      }
    });

    // Regression: a SnackBar that overrides `backgroundColor` to `error` or
    // `primary` still gets the theme's default content colour (onSurface),
    // which is unreadable on those fills - most visibly in light mode. Any
    // such call site must set the matching `on` role explicitly.
    test('on-roles beat onSurface on primary/error fills in both themes', () {
      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        final scheme = theme.colorScheme;
        expect(
          theme.snackBarTheme.contentTextStyle?.color,
          scheme.onSurface,
          reason: 'the default snackbar content colour is onSurface',
        );
        expect(
          _contrast(scheme.onError, scheme.error),
          greaterThan(_contrast(scheme.onSurface, scheme.error)),
          reason: 'onError must beat onSurface on error (${scheme.brightness})',
        );
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThan(_contrast(scheme.onSurface, scheme.primary)),
          reason:
              'onPrimary must beat onSurface on primary (${scheme.brightness})',
        );
      }
    });

    // Guards every current and future call site, not just the ones fixed
    test('every SnackBar overriding backgroundColor sets a content colour', () {
      final offenders = <String>[];

      for (final file in Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = file.readAsStringSync();
        for (final match in RegExp(r'\bSnackBar\(').allMatches(src)) {
          // Extract the balanced argument list of this SnackBar(...)
          var depth = 0;
          var end = match.end - 1;
          for (var i = match.end - 1; i < src.length; i++) {
            final c = src[i];
            if (c == '(' || c == '[' || c == '{') depth++;
            if (c == ')' || c == ']' || c == '}') {
              depth--;
              if (depth == 0) {
                end = i;
                break;
              }
            }
          }
          final args = src.substring(match.end, end);
          if (!args.contains('backgroundColor:')) continue;
          if (RegExp(r'color:\s*(context\.colorScheme|scheme)\.on')
              .hasMatch(args)) {
            continue;
          }
          final line = src.substring(0, match.start).split('\n').length;
          offenders.add('${file.path}:$line');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'these SnackBars override backgroundColor but leave the text '
            'at the theme default (onSurface), which is unreadable on an '
            'error/primary fill: $offenders',
      );
    });
  });

  testWidgets('backgroundGradient and cardGlow derive from the active scheme',
      (tester) async {
    late BoxDecoration darkGradient;
    late BoxDecoration darkGlow;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(builder: (context) {
          darkGradient = AppTheme.backgroundGradient(context);
          darkGlow = AppTheme.cardGlow(context);
          return const SizedBox.shrink();
        }),
      ),
    );

    final darkScheme = AppTheme.darkTheme.colorScheme;
    final gradient = darkGradient.gradient as LinearGradient;
    expect(gradient.colors.first, darkScheme.surface);
    expect(gradient.colors[1], darkScheme.surfaceContainerLowest);
    expect(
      darkGlow.boxShadow!.single.color,
      darkScheme.primary.withAlpha(15),
    );

    // Reset the tree so the theme change doesn't lerp through
    // AnimatedTheme (which would capture mid-animation colors)
    await tester.pumpWidget(const SizedBox.shrink());

    late BoxDecoration lightGradient;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(builder: (context) {
          lightGradient = AppTheme.backgroundGradient(context);
          return const SizedBox.shrink();
        }),
      ),
    );
    await tester.pumpAndSettle();

    final lightScheme = AppTheme.lightTheme.colorScheme;
    expect(
      (lightGradient.gradient as LinearGradient).colors.first,
      lightScheme.surface,
    );
  });
}
