# Changelog: develop vs main (v1.0.1+3)

All changes on the `develop` branch since branching from `main` at `v1.0.1+3`.
Version bumped to `v1.0.1+4` on develop.

---

## Features

### First-Launch Tutorial (6 slides)
- Added a bilingual onboarding tutorial (Arabic + English) shown on first launch only
- 6 slides: App Intro, Members, Alerts, Tracking, Dashboard Customization, Goals & Calculations
- Skippable with "Skip" button; preference stored in SharedPreferences so it only shows once
- Files: `tutorial_screen.dart`, `assets/tutorial/slide_1..6_*.png`

### Hide/Show Assets Toggle
- Eye icon button on the Assets tab and the Home (Overview) tab
- When hidden, all monetary values are masked with `••••••`:
  - Assets tab: current value, purchase cost, profit/loss, return %, per-asset values
  - Assets tab: weight-by-karat breakdown and total equivalent 21K grams
  - Home tab: asset summary (current value, purchase cost, profit/loss, equivalent grams)
  - Home tab: zakat amounts (due, threshold)
- Preference persisted via SharedPreferences (`_assetsHidden`)

### 2.5g Ingot Weight Option
- Added `2.5g` entry to the `_ingotSizes` map in the savings/assets section
- Appears between 1g and 5g in the ingot weight picker

### USD/EGP Rate Fix
- Flutter app now scrapes the USD/EGP rate directly from eDahab (primary gold price source) alongside gold prices
- Falls back to `open.er-api.com` only if eDahab rate is unavailable
- Ensures the displayed dollar rate matches the actual market rate used for gold pricing

## Bug Fixes

### Calculator Uses Sell Rate (not Buy)
- The Gold Calculator in the savings/goals section now uses `sell_price` instead of `buy_price`
- Only affects the calculator panel; no other section calculations are changed

### Keyboard Spacing in Calculator
- Reduced `scrollPadding` on calculator text fields to `80px` (from Flutter's default `200px`)
- Eliminates the excessive empty gap between the focused input field and the keyboard

### Calculator Icon & Dropdown Padding
- Added `tilePadding` to the calculator `ExpansionTile` for better icon/title breathing room
- Increased inner content padding (16 to 20px) and field column gaps (10 to 12px)
- Added explicit `contentPadding` on the karat dropdown for visual alignment

### Member Name Not Showing in Gold Chip
- Fixed race condition where `_selectedMemberId` could reference a deleted/non-existent member
- `_load()` now validates `_selectedMemberId` against the actual members list before using it
- Falls back to default member, then first member if current selection is invalid
- `_memberDialog` (add mode) now auto-selects the newly created member and sets it as default when it's the first member

## UI Improvements

### Member Selector Redesign (Option 3)
- Gold chip is now **always visible** in the AppBar (no more disappearing)
- When a member is selected: shows name + person icon + dropdown chevron
- When no member exists: shows dashed-border "Add member" placeholder with person_add icon
- Add-member icon always visible in AppBar actions (not just when list is empty)
- Member count badge (gold circle) appears on the add icon when 2+ members exist
- Larger text (12px to 13px) for better readability

## Files Changed (vs main)

| File | Change |
|------|--------|
| `flutter-app/lib/app.dart` | Tutorial integration (SharedPreferences flag, TutorialScreen routing) |
| `flutter-app/lib/screens/dashboard_screen.dart` | 2.5g ingot, hide/show toggle, calculator sell rate, keyboard padding, UI spacing, member selector redesign, member selection bug fix |
| `flutter-app/lib/screens/tutorial_screen.dart` | New file: tutorial PageView with 6 slides |
| `flutter-app/lib/services/gold_scraper.dart` | USD/EGP rate scraping from eDahab |
| `flutter-app/lib/services/api_service.dart` | Use scraped USD/EGP rate before fallback |
| `flutter-app/lib/theme/app_themes.dart` | Calculator tile padding adjustments |
| `flutter-app/pubspec.yaml` | Version bump to 1.0.1+4, added `assets/tutorial/` |
| `flutter-app/assets/tutorial/*.png` | 6 tutorial slide images |

## Commits (oldest to newest)

1. `3628820` — feat(develop): implement all pending notes (v1.0.1+4)
2. `58356f2` — feat(toggle): extend hide/show to home summary, grams, and zakat
3. `1a8bd39` — fix(toggle+tutorial): mask grams in assets tab, update to 6 new slides
4. `9fd7cb9` — feat(tutorial): redesign slides 5-6 to match dark+gold style of 1-4
5. `274485f` — fix(ui): clean input labels and calculator padding
6. `0efdae7` — fix(calculator): use sell rate, reduce keyboard gap, revert labels
7. `39df389` — fix(member): redesign selector chip, fix name not showing bug
