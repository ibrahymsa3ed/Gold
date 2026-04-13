import 'package:flutter/material.dart';

import 'ui_design_variant.dart';

// ── Gold palette ──
const Color kGoldPrimary = Color(0xFFD4AF37);
const Color kGoldLight = Color(0xFFE8CD5A);
const Color kGoldDeep = Color(0xFFC9A227);
const Color kGoldMuted = Color(0xFFB8962E);

// ── Dark surfaces ──
const Color kDarkBase = Color(0xFF0B0B0D);
const Color kDarkSurface = Color(0xFF131114);
const Color kDarkCard = Color(0xFF1A1816);
const Color kDarkElevated = Color(0xFF211F1B);

// ── Light surfaces ──
const Color kLightBase = Color(0xFFF7F2E8);
const Color kLightCard = Colors.white;

ThemeData instaGoldLightTheme(UiDesignVariant variant) {
  if (variant == UiDesignVariant.classic) {
    return ThemeData(
      useMaterial3: false,
      colorSchemeSeed: Colors.amber,
      brightness: Brightness.light,
    );
  }

  final cs = ColorScheme.fromSeed(
    seedColor: kGoldMuted,
    brightness: Brightness.light,
    surfaceTint: Colors.transparent,
    surface: kLightBase,
    primary: kGoldMuted,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFF0E5C9),
    secondary: const Color(0xFF8B7332),
    tertiary: kGoldDeep,
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
    seedColor: kGoldPrimary,
    brightness: Brightness.dark,
    surfaceTint: Colors.transparent,
    surface: kDarkBase,
    onSurface: const Color(0xFFE8E0D0),
    primary: kGoldPrimary,
    onPrimary: kDarkBase,
    primaryContainer: const Color(0xFF2A2416),
    secondary: kGoldDeep,
    tertiary: kGoldLight,
    outline: const Color(0xFF3A3530),
    outlineVariant: const Color(0xFF2A2520),
  );

  return _buildTheme(cs);
}

ThemeData _buildTheme(ColorScheme cs) {
  final isDark = cs.brightness == Brightness.dark;
  final gold = isDark ? kGoldPrimary : kGoldMuted;

  final cardColor = isDark ? kDarkCard : kLightCard;
  final borderColor = isDark
      ? kGoldPrimary.withValues(alpha: 0.08)
      : gold.withValues(alpha: 0.1);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: isDark ? Colors.transparent : cs.surface,
    visualDensity: VisualDensity.standard,

    dividerTheme: DividerThemeData(
      thickness: 0.5,
      space: 0.5,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : cs.outlineVariant.withValues(alpha: 0.15),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      color: cardColor,
    ),

    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
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
      backgroundColor: Colors.transparent,
      indicatorColor: gold.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.2,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? gold : cs.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: selected ? 26 : 24,
          color: selected ? gold : cs.onSurfaceVariant,
        );
      }),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : gold.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: gold, width: 1.5),
      ),
      filled: true,
      fillColor: isDark ? kDarkElevated : const Color(0xFFF5F0E5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      isDense: false,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: gold,
        foregroundColor: isDark ? kDarkBase : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: isDark ? kDarkElevated : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: gold.withValues(alpha: 0.25), width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : gold.withValues(alpha: 0.15),
        width: 0.5,
      ),
      elevation: 0,
      backgroundColor: isDark ? kDarkElevated : const Color(0xFFF5F0E5),
    ),

    dialogTheme: DialogThemeData(
      elevation: isDark ? 16 : 8,
      shadowColor: isDark ? Colors.black : gold.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? kDarkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? kDarkCard : Colors.white,
      elevation: isDark ? 16 : 8,
      shadowColor: isDark ? Colors.black : gold.withValues(alpha: 0.15),
    ),

    listTileTheme: const ListTileThemeData(
      dense: false,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(horizontal: 4),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: gold,
      linearTrackColor: gold.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      linearMinHeight: 6,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? kDarkElevated : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: isDark ? kDarkBase : Colors.white,
      elevation: isDark ? 8 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
