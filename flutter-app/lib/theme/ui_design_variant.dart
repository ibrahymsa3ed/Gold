/// Visual design for the app shell (theme + section cards).
///
/// **Rollback without git:** set [kUiDesignVariant] to [UiDesignVariant.classic],
/// save, and hot-restart / rebuild. See repo-root `ROLLBACK_UI.md`.
enum UiDesignVariant {
  /// Previous look: amber `ThemeData` seed only (minimal customization).
  classic,

  /// Refined look: gold-tinted Material 3, softer cards, spacing tweaks.
  refined,
}

/// Change this one line to roll back UI refinements.
const UiDesignVariant kUiDesignVariant = UiDesignVariant.refined;
