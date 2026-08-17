import 'package:flutter/material.dart';

/// Semantic colors that don't map onto Material [ColorScheme] roles.
/// Both themes provide a mapping so widgets never hardcode them.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Positive state: saved, uploaded, Jekyll detected
  final Color success;

  /// Cautionary state: format warnings, could-not-verify banners
  final Color warning;

  /// Informational accent: "Editing" badges and similar neutral tags
  final Color info;

  const AppColors({
    required this.success,
    required this.warning,
    required this.info,
  });

  static const dark = AppColors(
    success: Color(0xFF81C784),
    warning: Color(0xFFE8A87C),
    info: Color(0xFF4DB6AC),
  );

  static const light = AppColors(
    success: Color(0xFF2E7D32),
    warning: Color(0xFF8A5A00),
    info: Color(0xFF00695C),
  );

  @override
  AppColors copyWith({Color? success, Color? warning, Color? info}) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Shorthand theme lookups so widgets read
/// `context.colorScheme.primary` instead of hardcoding hex values.
extension AppThemeContext on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

class AppTheme {
  // ------------------------------------------------------------- SCHEMES

  /// The original deep-forest / cream / peach palette. Dark is the
  /// visual baseline - it must look identical to the pre-theming app.
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFE8A87C),
    onPrimary: Color(0xFF0D1B14),
    primaryContainer: Color(0xFF2D4A3E),
    onPrimaryContainer: Color(0xFFF5F5F0),
    secondary: Color(0xFFA8B5A0),
    onSecondary: Color(0xFF0D1B14),
    secondaryContainer: Color(0xFF2D4A3E),
    onSecondaryContainer: Color(0xFFF5F5F0),
    tertiary: Color(0xFFE8D5B5),
    onTertiary: Color(0xFF0D1B14),
    error: Color(0xFFE57373),
    onError: Colors.white,
    surface: Color(0xFF0D1B14),
    onSurface: Color(0xFFF5F5F0),
    onSurfaceVariant: Color(0xFFA8B5A0),
    surfaceContainerLowest: Color(0xFF0A1910),
    surfaceContainerLow: Color(0xFF162A1E),
    surfaceContainer: Color(0xFF162A1E),
    surfaceContainerHigh: Color(0xFF1A2F23),
    surfaceContainerHighest: Color(0xFF2D4A3E),
    outline: Color(0xFF2D4A3E),
    outlineVariant: Color(0xFF2D4A3E),
  );

  /// Light equivalent of the same hues: warm off-white surfaces, deep
  /// green text, the peach primary darkened for contrast.
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF96502A),
    onPrimary: Color(0xFFFFF8F2),
    primaryContainer: Color(0xFFF3DCC6),
    onPrimaryContainer: Color(0xFF4C2A12),
    secondary: Color(0xFF48604F),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFDCE5D8),
    onSecondaryContainer: Color(0xFF1A2F23),
    tertiary: Color(0xFF6C5732),
    onTertiary: Colors.white,
    error: Color(0xFFB3392F),
    onError: Colors.white,
    surface: Color(0xFFFAF7F0),
    onSurface: Color(0xFF1A2F23),
    onSurfaceVariant: Color(0xFF4C5F51),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF3EEE3),
    surfaceContainer: Color(0xFFF1EBDE),
    surfaceContainerHigh: Color(0xFFEBE4D4),
    surfaceContainerHighest: Color(0xFFDFD6C2),
    outline: Color(0xFFB6C0AE),
    outlineVariant: Color(0xFFCBD3C2),
  );

  static ThemeData get darkTheme => _build(_darkScheme, AppColors.dark);
  static ThemeData get lightTheme => _build(_lightScheme, AppColors.light);

  // -------------------------------------------------------------- THEMES

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: scheme.onSurface,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: scheme.onSurfaceVariant,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      extensions: [colors],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        titleTextStyle: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outline.withAlpha(100),
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outline.withAlpha(80),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1,
          ),
        ),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withAlpha(150),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface, fontSize: 14),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        labelStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
        side: BorderSide(color: scheme.outline.withAlpha(80)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      iconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  // ----------------------------------------------------------- DECOR

  /// Full-screen gradient background derived from the active scheme
  static BoxDecoration backgroundGradient(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.surface,
          scheme.surfaceContainerLowest,
          scheme.surface,
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  /// Soft primary-tinted glow behind cards/fields, scheme-derived
  static BoxDecoration cardGlow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: scheme.primary.withAlpha(15),
          blurRadius: 40,
          spreadRadius: 0,
        ),
      ],
    );
  }
}
