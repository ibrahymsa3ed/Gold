# Gold Platform / InstaGold (Egypt Market + Family Assets)

The Flutter client is branded **InstaGold** (launcher name and in-app title). This repository is structured as two backend-facing apps plus Flutter client:

- `scraper-service/` - scrapes public local gold pages every 10 minutes and serves authenticated prices API
- `main-backend/` - consumes scraper API, caches prices, computes assets/goals/zakat, serves app APIs
- `flutter-app/` - mobile UI for families to track gold assets and goals

## Repository Structure

```text
Gold/
  ARCHITECTURE.md
  README.md
  .github/workflows/ci.yml
  .cursor/rules/docs-and-readme-sync.mdc
  scripts/deploy.sh
  scripts/dev-up.sh
  scraper-service/
  main-backend/
  flutter-app/
```

## High-Level Flow

1. `scraper-service` fetches and parses prices from eDahab-like pages.
2. Scraper stores snapshots in `ScrapedPrices` and logs in `LogEntries` + `scraper.log`.
3. `main-backend` syncs prices hourly (or on-demand) from scraper `/api/gold-prices`.
4. Main backend stores `GoldPriceCache` and uses it for all calculations.
5. Flutter reads only from `main-backend`.

### Price Source Cascade (Mobile)

On mobile, `GoldScraper` tries sources in order:
1. **eDahab website** (`edahabapp.com`) — full buy/sell per karat
2. **Telegram channel** (`t.me/s/eDahabApp`) — public web preview, single price per karat

The `source` field in the response indicates which was used.

## Security Model

- Scraper API protected with `x-api-key`.
- Main backend sends `x-api-key` using the same `SCRAPER_API_KEY` value from environment.
- Keep services private behind reverse proxy/VPN in production.
- Firebase service/account files are kept out of git via `.gitignore`.

## Suggested Production Stack

- Runtime: Docker containers for scraper + main backend
- DB: PostgreSQL (replace sqlite for production)
- Jobs: in-app cron or external scheduler (GitHub Actions/CronJob)
- Logs: structured logging + central sink (Loki/ELK/CloudWatch)

## Quick Start

### 1) Scraper service

```bash
cd scraper-service
npm install
npm start
```

### 2) Main backend

```bash
cd main-backend
npm install
npm start
```

### 3) Flutter app

```bash
cd flutter-app
flutter pub get
flutter run
```

### Local backend stack (both services)

```bash
./scripts/dev-up.sh
```

### Firebase files helper

After creating Flutter platform folders, copy Firebase files from repo root to Flutter targets:

```bash
cd flutter-app
flutter create .
cd ..
./scripts/setup-firebase-files.sh
```

## GitHub Repository

Target repository: [ibrahymsa3ed/Gold](https://github.com/ibrahymsa3ed/Gold)

This link currently shows an empty repository, so push your local code after setup.

### Deployment script (single repo)

Monorepo push to one GitHub repository:

```bash
GITHUB_REPO=git@github.com:ibrahymsa3ed/Gold.git \
./scripts/deploy.sh "feat: bootstrap gold architecture"
```

## Documentation Sync Policy

- `ARCHITECTURE.md` and relevant README files are updated with every substantive code/config change.

## UI (InstaGold)

### Current design

Premium gold-themed design with rich palette (`#B5973F` primary / `#D4B254` accent). Default theme is **light** with warm cream surfaces (`#F7F2E8`).

- **App Icon:** Dark luxurious gold coin (gold pound style) with "IG" monogram, dotted rim, radial gradient shine.
- **Price Cards:** 150px hero cards with 4-stop gold gradient, glow shadows, Buy/Sell chips; drag-reorderable.
- **Navigation:** Floating glassmorphism pill-shaped bottom bar with backdrop blur.
- **Cards:** `borderRadius: 20-22`, gold accent gradient bars, depth shadows, `w800` typography.
- **Assets:** Karat badge chips, inner financial detail cards, gold gradient circle icons.
- **Jeweler's Dollar Gap:** Full-width tinted card (green/red) with EGP gap value centred; tapping opens explanation dialog.
- **Notifications:** Scheduled price alerts via `flutter_local_notifications` with Android 13+ permission handling.

### Rollback

- **To roll back** without Git: set `kUiDesignVariant` to `UiDesignVariant.classic` in `flutter-app/lib/theme/ui_design_variant.dart` — this restores the old amber Material 2 look. See `ROLLBACK_UI.md` in the repo root.
- Theme code: `flutter-app/lib/theme/app_themes.dart`
- Dashboard: `flutter-app/lib/screens/dashboard_screen.dart`

### Android-first preview

```bash
cd flutter-app && flutter run -d android
```

### Build APK

```bash
cd flutter-app && flutter build apk --release
cp flutter-app/build/app/outputs/flutter-apk/app-release.apk InstaGold.apk
```

### Build + Upload to Google Drive

```bash
./scripts/build-and-upload.sh
```

Or upload an existing APK:

```bash
python3 scripts/upload_apk.py
```

Requires `rclone` with a `gdrive:` remote configured. APK is uploaded to `gdrive:InstaGold Releases/InstaGold.apk` with a shareable link.

## Current Phase-2 Status

- Firebase login + backend token verification are wired.
- Flutter dashboard (**InstaGold**) supports member selection, asset CRUD (optional invoice attachment on mobile), savings add/edit/delete, goals with progress, zakat view, and company management.
- **Backup/restore:** Mobile exports a `.zip` (`instagold_backup.json` plus `invoices/` files). Import the same file on any device (Android ↔ iOS works; JSON schema is platform-neutral). Web can export JSON-only zip via the share sheet; full restore from file is mobile-only. **Google Drive upload** available as a one-tap option in the backup section (stores in "InstaGold Backups" folder).
- UI is polished into tabbed sections for better navigation and readability.
- Flutter codebase is split into `app.dart`, `screens/`, and `services/` for easier maintenance.
- Firebase initialization uses `flutter-app/lib/firebase_options.dart` so web/native startup works reliably.
- Web Google sign-in uses Firebase popup flow with clearer error messages for Firebase config issues.
- Web auth includes popup-to-redirect fallback to handle popup auto-close/browser policy issues.

## CI/CD Suggestion

- Add GitHub Actions for:
  - Node install + lint/test for scraper and backend
  - Flutter analyze/test/build
  - Optional deploy steps to server/container registry

Starter workflow included at `.github/workflows/ci.yml`.
