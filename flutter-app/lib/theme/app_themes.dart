import 'package:flutter/material.dart';

import 'ui_design_variant.dart';

const Color kGoldPrimary = Color(0xFF9E8A4F);
const Color kGoldDark = Color(0xFFBFA764);

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
    surface: const Color(0xFFFAF8F3),
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
  );

  return _buildTheme(cs);
}

ThemeData _buildTheme(ColorScheme cs) {
  final borderColor = cs.outlineVariant.withValues(alpha: 0.18);
  final isDark = cs.brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    visualDensity: VisualDensity.standard,
    dividerTheme: DividerThemeData(
      thickness: 0.5,
      space: 0.5,
      color: cs.outlineVariant.withValues(alpha: 0.2),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      color: isDark ? cs.surfaceContainerLow : Colors.white,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: cs.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 62,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? cs.surface : Colors.white,
      indicatorColor: cs.primaryContainer.withValues(alpha: 0.35),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          letterSpacing: 0.1,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1),
      ),
      filled: true,
      fillColor: isDark ? cs.surfaceContainerHigh : const Color(0xFFF8F6F1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.5),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: borderColor, width: 0.5),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      dense: false,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(horizontal: 4),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: cs.primaryContainer.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
