# Rolling back the InstaGold UI refresh

The updated look (Material 3, gold seed, card shape, spacing) is controlled by **one constant**.

## Fast rollback (no Git)

1. Open [`flutter-app/lib/theme/ui_design_variant.dart`](flutter-app/lib/theme/ui_design_variant.dart).
2. Change:
   ```dart
   const UiDesignVariant kUiDesignVariant = UiDesignVariant.refined;
   ```
   to:
   ```dart
   const UiDesignVariant kUiDesignVariant = UiDesignVariant.classic;
   ```
3. Hot restart the app (or rebuild the APK).

`classic` restores the previous **amber-only** `ThemeData` (Material 2 style) and the older section-card padding behavior.

## Rollback with Git

If you committed the theme work:

```bash
git checkout HEAD -- flutter-app/lib/theme/ flutter-app/lib/app.dart flutter-app/lib/screens/dashboard_screen.dart
```

Or revert the specific commit that introduced the UI change.

## Files involved

| File | Role |
|------|------|
| `flutter-app/lib/theme/ui_design_variant.dart` | **Switch** (`classic` vs `refined`) |
| `flutter-app/lib/theme/app_themes.dart` | Theme definitions for both variants |
| `flutter-app/lib/app.dart` | Applies `instaGoldLightTheme` / `instaGoldDarkTheme` |
| `flutter-app/lib/screens/dashboard_screen.dart` | Section cards + shell padding when `refined` |
