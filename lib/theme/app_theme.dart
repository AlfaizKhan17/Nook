import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nook uses an Apple-inspired visual language: quiet surfaces, clear type
/// hierarchy, generous spacing, restrained accent color and subtle separators.
class AppColors {
  static const accent = Color(0xFF007AFF);
  static const accentDark = Color(0xFF0A84FF);
  static const ink = Color(0xFF1C1C1E);
  static const secondaryText = Color(0xFF6E6E73);
  static const canvas = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const separator = Color(0xFFE5E5EA);
  static const darkCanvas = Color(0xFF000000);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkElevated = Color(0xFF2C2C2E);
  static const lost = Color(0xFFFF453A);
  static const found = Color(0xFF30D158);

  // Compatibility aliases retained for existing widgets.
  static const lime = accent;
  static const charcoal = ink;
  static const graphite = darkSurface;
  static const cardDark = darkElevated;
  static const mutedDark = Color(0xFFAEAEB2);
  static const lostBg = Color(0xFF482B2D);
  static const foundBg = Color(0xFF2C4228);
  static const green = accent;
  static const darkGreen = ink;
  static const cream = canvas;
  static const softCream = surface;
  static const mint = Color(0xFFE5F1FF);
  static const text = ink;
  static const muted = secondaryText;
  static const border = separator;
}

class AppThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
  static const _key = 'nook_theme_mode';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = prefs.getString(_key) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value == ThemeMode.dark ? 'dark' : 'light');
  }
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.darkCanvas : AppColors.canvas;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final elevated = isDark ? AppColors.darkElevated : AppColors.surface;
    final foreground = isDark ? Colors.white : AppColors.ink;
    final secondary = isDark ? AppColors.mutedDark : AppColors.secondaryText;
    final separator = isDark ? const Color(0xFF38383A) : AppColors.separator;
    final accent = isDark ? AppColors.accentDark : AppColors.accent;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accent.withValues(alpha: .14),
      onPrimaryContainer: foreground,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accent.withValues(alpha: .12),
      onSecondaryContainer: foreground,
      tertiary: isDark ? const Color(0xFF64D2FF) : const Color(0xFF007AFF),
      onTertiary: Colors.white,
      tertiaryContainer: accent.withValues(alpha: .10),
      onTertiaryContainer: foreground,
      error: isDark ? AppColors.lost : const Color(0xFFD70015),
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF5A1D1D) : const Color(0xFFFFE5E3),
      onErrorContainer: foreground,
      surface: surface,
      onSurface: foreground,
      surfaceContainerHighest: elevated,
      onSurfaceVariant: secondary,
      outline: separator,
      outlineVariant: separator,
      shadow: Colors.black.withValues(alpha: isDark ? .35 : .06),
      scrim: Colors.black54,
      inverseSurface: isDark ? Colors.white : AppColors.ink,
      onInverseSurface: isDark ? AppColors.ink : Colors.white,
      inversePrimary: isDark ? AppColors.accent : AppColors.accentDark,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
      fontFamily: '.SF Pro Text',
    ).copyWith(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.1, color: foreground),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.7, color: foreground),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.5, color: foreground),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.25, color: foreground),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: foreground),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: foreground),
      bodyLarge: TextStyle(fontSize: 15, height: 1.4, color: foreground),
      bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: secondary),
      bodySmall: TextStyle(fontSize: 11, height: 1.35, color: secondary),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: foreground),
      ),
      dividerTheme: DividerThemeData(color: separator, thickness: .7, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(fontSize: 14, color: secondary),
        labelStyle: TextStyle(fontSize: 14, color: secondary),
        prefixIconColor: secondary,
        suffixIconColor: secondary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accent, width: 1.4)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.error, width: 1.4)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: separator, width: .7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, 46),
          side: BorderSide(color: separator),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: .12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 10,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? accent : secondary,
        )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      dividerColor: separator,
    );
  }
}
