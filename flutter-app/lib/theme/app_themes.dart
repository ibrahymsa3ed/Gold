import 'dart:ui';

import 'package:flutter/material.dart';

import 'ui_design_variant.dart';

const Color kGoldPrimary = Color(0xFFB5973F);
const Color kGoldDark = Color(0xFFD4B254);
const Color kGoldDeep = Color(0xFF8B7332);
const Color kCreamLight = Color(0xFFF3EDE0);
const Color kCreamWarm = Color(0xFFEDE5D3);

ThemeData instaGoldLightTheme(UiDesignVariant variant) {
  if (variant == UiDesignVariant.classic) {
    return ThemeData(
      useMaterial3: false,
      colorSchemeSeed: Colors.amber,
      brightness: Brightness.light,
    );
  }

  final cs = ColorScheme.fromSeed(
    seedColor: kGoldPrimary,
    brightness: Brightness.light,
    surfaceTint: Colors.transparent,
    surface: const Color(0xFFF7F2E8),
    primary: const Color(0xFFB5973F),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFF0E5C9),
    secondary: const Color(0xFF8B7332),
    tertiary: const Color(0xFFC9A64A),
  );

  return _buildTheme(cs);
}

ThemeData instaGoldDarkTheme(UiDesignVariant variant) {
  if (variant == UiDesignVariant.classic) {
    return ThemeData(
      useMaterial3: false,
      colorSchemeSeed: Colors.amber,
      brightness: Brightness.dark,
    );
  }

  final cs = ColorScheme.fromSeed(
    seedColor: kGoldDark,
    brightness: Brightness.dark,
    surfaceTint: Colors.transparent,
    surface: const Color(0xFF141210),
    primary: const Color(0xFFD4B254),
    onPrimary: const Color(0xFF1A1508),
    primaryContainer: const Color(0xFF2E2714),
    secondary: const Color(0xFFBFA764),
    tertiary: const Color(0xFFE0C45C),
  );

  return _buildTheme(cs);
}

ThemeData _buildTheme(ColorScheme cs) {
  final isDark = cs.brightness == Brightness.dark;
  final goldAccent = isDark ? kGoldDark : kGoldPrimary;

  final cardColor = isDark ? const Color(0xFF1E1B16) : Colors.white;
  final cardShadow = isDark
      ? Colors.black.withValues(alpha: 0.4)
      : const Color(0xFFB5973F).withValues(alpha: 0.08);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    visualDensity: VisualDensity.standard,
    dividerTheme: DividerThemeData(
      thickness: 0.5,
      space: 0.5,
      color: cs.outlineVariant.withValues(alpha: 0.15),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: cardShadow,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : goldAccent.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      color: cardColor,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: cs.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 70,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark
          ? const Color(0xFF1A1714).withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.92),
      indicatorColor: goldAccent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.2,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? goldAccent : cs.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: selected ? 26 : 24,
          color: selected ? goldAccent : cs.onSurfaceVariant,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: goldAccent.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: goldAccent, width: 1.5),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1B16) : const Color(0xFFF5F0E5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      isDense: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: goldAccent,
        foregroundColor: isDark ? const Color(0xFF1A1508) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: goldAccent.withValues(alpha: 0.25), width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: goldAccent.withValues(alpha: 0.15), width: 0.5),
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF2E2714) : const Color(0xFFF5F0E5),
    ),
    dialogTheme: DialogThemeData(
      elevation: 8,
      shadowColor: isDark ? Colors.black54 : goldAccent.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF1E1B16) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF1A1714) : Colors.white,
      elevation: 8,
      shadowColor: isDark ? Colors.black54 : goldAccent.withValues(alpha: 0.15),
    ),
    listTileTheme: const ListTileThemeData(
      dense: false,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(horizontal: 4),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: goldAccent,
      linearTrackColor: goldAccent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      linearMinHeight: 6,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: goldAccent,
      foregroundColor: isDark ? const Color(0xFF1A1508) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
