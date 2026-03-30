# Flutter App (Gold Family Client)

Flutter front-end for:

- authentication
- live price dashboard from backend cache
- family/member assets
- savings and purchase goals
- zakat calculator
- company list and settings

## Implemented Phase 2 Scaffold

- **Auth:** Firebase (`firebase_auth`) with email/password + Google + Apple
- **Home:** buy/sell prices + gold pound + last update timestamp from backend `GoldPriceCache`
- **Family members:** per-member pages and aggregated totals
- **Assets:** create/edit/delete asset flows wired to backend
- **Savings & goals:** add savings, create goals, and progress bars (saved vs remaining)
- **Zakat:** apply 2.5% if 24k equivalent >= 85g
- **Companies:** list and add custom companies
- **Settings:** local notifications (hourly/six-hour), language, dark/light mode
- **Logs viewer (optional):** admin/dev page reading backend `LogEntries`

## UI Layout

- Tabbed dashboard navigation:
  - Overview
  - Assets
  - Savings/Goals
  - More (companies + settings)
- Active member selector at top controls all member-scoped sections.

## Code Structure

```text
lib/
  main.dart
  app.dart
  l10n.dart
  config.dart
  screens/
    login_screen.dart
    dashboard_screen.dart
  services/
    auth_service.dart
    api_service.dart
    notifications_service.dart
```

## Setup

1. Install Flutter dependencies:

```bash
flutter pub get
```

2. Run app:

```bash
flutter run
```

3. Configure Firebase (required):

- Add FlutterFire configuration files for Android/iOS/macOS:
  - `google-services.json` / `GoogleService-Info.plist`
- Enable providers in Firebase console:
  - Email/Password
  - Google
  - Apple
- Web startup uses `lib/firebase_options.dart` for Firebase initialization.

Auth troubleshooting checklist:

- Firebase Authentication providers must be enabled (`Email/Password`, `Google`, optionally `Apple`).
- Add `localhost` and `127.0.0.1` to Firebase Authentication authorized domains for web sign-in.
- If Google popup is blocked, allow popups for localhost.
- Web Google sign-in now falls back to redirect flow when popup closes/blocks.

If `android/` and `ios/` folders are missing, generate them and copy config files:

```bash
flutter create .
cd ..
./scripts/setup-firebase-files.sh
cd flutter-app
```

4. Connect to backend:

- Add API base URL:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:4200
```

- App sends Firebase ID token as `Authorization: Bearer <token>`.

## Localization

- English and Arabic shipped from day 1 via in-app string map.
- You can later migrate to `.arb` generated localization for larger scale.

## UI Theming

- Theme mode toggle exists in scaffold.
- Expand with branding colors and typography.
