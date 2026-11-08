import 'package:flutter/material.dart';

/// Tokens del design system del front web (`src/styles.css`, variables `--fs-*`).
class FsColors {
  FsColors._();

  static const primary = Color(0xFF1A9150);
  static const primaryDark = Color(0xFF14723F);
  static const primaryLight = Color(0xFFE6F4EC);

  static const bg = Color(0xFFF4F6F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8E4);
  static const borderStrong = Color(0xFFC8D5CC);

  static const text = Color(0xFF111B17);
  static const textSecondary = Color(0xFF4A5E55);
  static const textMuted = Color(0xFF7D9189);

  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFFBEB);
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFF0FDF4);
  static const info = Color(0xFF2563EB);
  static const infoBg = Color(0xFFEFF6FF);
}

class FsRadius {
  FsRadius._();
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 20.0;
}

class FsSpace {
  FsSpace._();
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

/// Estado visual compartido (ok / warn / crit / off) usado en sensores, alertas y badges.
enum FsStatus { ok, warn, crit, off }

extension FsStatusColors on FsStatus {
  Color get color => switch (this) {
    FsStatus.ok => FsColors.success,
    FsStatus.warn => FsColors.warning,
    FsStatus.crit => FsColors.danger,
    FsStatus.off => FsColors.textMuted,
  };

  Color get background => switch (this) {
    FsStatus.ok => FsColors.successBg,
    FsStatus.warn => FsColors.warningBg,
    FsStatus.crit => FsColors.dangerBg,
    FsStatus.off => FsColors.bg,
  };
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FsColors.primary,
        primary: FsColors.primary,
        surface: FsColors.surface,
        error: FsColors.danger,
      ),
      scaffoldBackgroundColor: FsColors.bg,
    );
    final text = base.textTheme.apply(bodyColor: FsColors.text, displayColor: FsColors.text);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(FsRadius.md));

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: FsColors.surface,
        foregroundColor: FsColors.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: FsColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FsRadius.lg),
          side: const BorderSide(color: FsColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FsColors.primary,
          minimumSize: const Size(0, 48),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FsColors.primaryDark,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: FsColors.borderStrong),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: FsColors.primaryDark, shape: rounded),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FsColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FsRadius.md),
          borderSide: const BorderSide(color: FsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FsRadius.md),
          borderSide: const BorderSide(color: FsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FsRadius.md),
          borderSide: const BorderSide(color: FsColors.primary, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: FsColors.primaryLight,
        side: const BorderSide(color: FsColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FsColors.surface,
        indicatorColor: FsColors.primaryLight,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FsRadius.md)),
      ),
    );
  }
}
