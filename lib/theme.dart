import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

// ─── APP THEME VARIANT ──────────────────────────────────────────

enum AppThemeVariant { neon, ocean, sunset, aurora, midnight, forest }

// ─── THEME HELPERS FOR MODALS ─────────────────────────────────────

Color getModalBackground(WidgetRef ref) {
  final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
  final appTheme = ref.read(appThemeProvider);
  return isDark
      ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
      : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
}

Color getModalTextColor(WidgetRef ref) {
  final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
  return isDark ? Colors.white : const Color(0xFF0D1E30);
}

Color getModalTextSecondaryColor(WidgetRef ref) {
  final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
  return isDark ? Colors.white54 : const Color(0xFF546E7A);
}

Color getModalBorderColor(WidgetRef ref) {
  final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
  return isDark ? Colors.white10 : Colors.black12;
}

Color getModalPrimaryColor(WidgetRef ref) {
  final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
  final appTheme = ref.read(appThemeProvider);
  return AppThemes.primaryColor(appTheme, isDark);
}

// ─── SNACKBAR HELPERS ────────────────────────────────────────────

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}

// ─── THEME FACTORY ────────────────────────────────────────────────────

class AppThemes {
  static Color primaryColor(AppThemeVariant variant, bool isDark) {
    switch (variant) {
      case AppThemeVariant.neon:
        return isDark ? const Color(0xFF00D97E) : const Color(0xFF00A85E);
      case AppThemeVariant.ocean:
        return isDark ? const Color(0xFF29B6F6) : const Color(0xFF0288D1);
      case AppThemeVariant.sunset:
        return isDark ? const Color(0xFFFF7043) : const Color(0xFFE64A19);
      case AppThemeVariant.aurora:
        return isDark ? const Color(0xFF9C6FFF) : const Color(0xFF7B61FF);
      case AppThemeVariant.midnight:
        return isDark ? Colors.white : const Color(0xFF0D1E30);
      case AppThemeVariant.forest:
        return isDark ? const Color(0xFF66BB6A) : const Color(0xFF388E3C);
    }
  }

  static Color secondaryColor(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.neon:
        return const Color(0xFF0066FF);
      case AppThemeVariant.ocean:
        return const Color(0xFF00BCD4);
      case AppThemeVariant.sunset:
        return const Color(0xFFFFB74D);
      case AppThemeVariant.aurora:
        return const Color(0xFF00BCD4);
      case AppThemeVariant.midnight:
        return const Color(0xFF546E7A);
      case AppThemeVariant.forest:
        return const Color(0xFF8BC34A);
    }
  }

  static String label(AppThemeVariant v) {
    switch (v) {
      case AppThemeVariant.neon:
        return 'Neon Verde';
      case AppThemeVariant.ocean:
        return 'Ocean Azul';
      case AppThemeVariant.sunset:
        return 'Sunset Naranja';
      case AppThemeVariant.aurora:
        return 'Aurora Púrpura';
      case AppThemeVariant.midnight:
        return 'Midnight';
      case AppThemeVariant.forest:
        return 'Forest Verde';
    }
  }

  static List<Color> gradientColors(AppThemeVariant v) {
    switch (v) {
      case AppThemeVariant.neon:
        return [const Color(0xFF00D97E), const Color(0xFF0066FF)];
      case AppThemeVariant.ocean:
        return [const Color(0xFF29B6F6), const Color(0xFF006994)];
      case AppThemeVariant.sunset:
        return [const Color(0xFFFF7043), const Color(0xFFFFB74D)];
      case AppThemeVariant.aurora:
        return [const Color(0xFF9C6FFF), const Color(0xFF00BCD4)];
      case AppThemeVariant.midnight:
        return [const Color(0xFF546E7A), Colors.white];
      case AppThemeVariant.forest:
        return [const Color(0xFF66BB6A), const Color(0xFF8BC34A)];
    }
  }

  static ThemeData getTheme(AppThemeVariant variant, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = primaryColor(variant, isDark);
    final secondary = secondaryColor(variant);

    if (isDark) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071520),
        primaryColor: primary,
        colorScheme: ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: const Color(0xFF0D1E30),
          error: const Color(0xFFFF3B5C),
        ),
        cardColor: const Color(0xFF0D1E30),
        dividerColor: Colors.white10,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1E30),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
          headlineMedium: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
          headlineSmall: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 15),
          bodyMedium: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        primaryColor: primary,
        colorScheme: ColorScheme.light(
          primary: primary,
          secondary: secondary,
          surface: Colors.white,
          error: const Color(0xFFFF3B5C),
        ),
        cardColor: Colors.white,
        dividerColor: Colors.black12,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0D1E30),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              color: Color(0xFF0D1E30),
              fontWeight: FontWeight.bold,
              fontSize: 28),
          headlineMedium: TextStyle(
              color: Color(0xFF0D1E30),
              fontWeight: FontWeight.bold,
              fontSize: 22),
          headlineSmall: TextStyle(
              color: Color(0xFF0D1E30),
              fontWeight: FontWeight.w600,
              fontSize: 18),
          bodyLarge: TextStyle(color: Color(0xFF0D1E30), fontSize: 15),
          bodyMedium: TextStyle(color: Color(0xFF546E7A), fontSize: 13),
        ),
      );
    }
  }
}

// ─── LEGACY ThemeMode1 (kept for compatibility with other screens) ──────────

class ThemeMode1 {
  static const Color deepBlue = Color(0xFF071520);
  static const Color cardDark = Color(0xFF0D1E30);
  static const Color cardMid = Color(0xFF0F2235);
  static const Color neon = Color(0xFF00D97E);
  static const Color neonBlue = Color(0xFF0066FF);
  static const Color neonPurple = Color(0xFF7B61FF);
  static const Color danger = Color(0xFFFF3B5C);
  static const Color warning = Color(0xFFFFB800);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color border = Color(0x1AFFFFFF);

  static const LinearGradient neonGradient = LinearGradient(
    colors: [neon, neonBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData get dark =>
      AppThemes.getTheme(AppThemeVariant.neon, Brightness.dark);
  static ThemeData get light =>
      AppThemes.getTheme(AppThemeVariant.neon, Brightness.light);
}
