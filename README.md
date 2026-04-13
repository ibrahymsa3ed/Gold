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

Premium luxury dark-first design. Dark mode uses layered near-black base (`#0B0B0D`) with subtle gradient transitions, wave patterns, and radial glow highlights — never flat. Gold accent palette: `#D4AF37` primary, `#C9A227` deep, `#B8962E` muted.

- **IG Logo:** Uses the provided IG image as a cleaned transparent asset (`assets/icons/ig_logo_mark.png`) so the mark sits directly on the page background without a visible square. In light mode the mark is toned to a deeper gold for contrast.
- **Background:** `PremiumBackground` widget adds wave patterns and radial gold highlights behind key content areas.
- **Brand Header:** App bar uses a reusable `InstaGoldWordmark` lockup beside the IG mark; tapping the brand returns to the Home tab while the member chip stays as the member-switch action.
- **Price Cards:** 150px hero cards with 4-stop gold gradient, glow shadows, Buy/Sell chips; drag-reorderable.
- **Navigation:** Floating glassmorphism pill-shaped bottom bar with backdrop blur, dark glass surface, gold border.
- **Cards:** Premium dark surface (`#1A1816`), `borderRadius: 20-22`, gold accent gradient bars, soft glow shadows, `w800` typography.
- **Assets:** Karat badge chips, inner financial detail cards, gold gradient circle icons.
- **Jeweler's Dollar Gap:** Full-width tinted card (green/red) with EGP gap value centred; tapping opens explanation dialog.
- **Notifications:** Scheduled price alerts via `flutter_local_notifications` with Android 13+ permission handling.
- **Android branding assets:** Launcher icons are regenerated from the transparent IG mark, and native splash `launch_image` bitmaps are intentionally larger so the logo reads clearly on startup without a boxed background.

### Rollback

- **To roll back** without Git: set `kUiDesignVariant` to `UiDesignVariant.classic` in `flutter-app/lib/theme/ui_design_variant.dart` — this restores the old amber Material 2 look. See `ROLLBACK_UI.md` in the repo root.
- Theme code: `flutter-app/lib/theme/app_themes.dart`
- Dashboard: `flutter-app/lib/screens/dashboard_screen.dart`

### Android-first preview

```bash
cd flutter-app && flutter run -d android --flavor dev --dart-define=INSTAGOLD_FLAVOR=dev
```

### Android builds (flavors)

InstaGold uses Gradle flavors **`dev`** and **`prod`** (same package id `com.ibrahym.goldfamily` so Firebase stays valid).

| Output at repo root | Command |
|---------------------|---------|
| **`InstaGold-dev.apk`** | `./scripts/build-dev-apk.sh` — internal/testing; launcher label **InstaGold Dev**; AdMob **test** IDs (not committed to git; build locally) |
| **`InstaGold.apk`** | `./scripts/build-and-upload.sh` (or manual prod build below) — **InstaGold**; production AdMob IDs when configured |

Manual prod APK:

```bash
cd flutter-app
flutter build apk --release --flavor prod --dart-define=INSTAGOLD_FLAVOR=prod
cp build/app/outputs/flutter-apk/app-prod-release.apk ../InstaGold.apk
```

### Before you have a Play Developer account

You can still prepare signing, AAB builds, AdMob IDs, screenshots, privacy policy text, and Firebase release SHA keys.

- **What you must do yourself (commands + Firebase / AdMob):** **[YOUR_ACTIONS_BEFORE_PLAY.md](YOUR_ACTIONS_BEFORE_PLAY.md)** — includes steps **7–8** (store graphics + privacy policy) after signing is done
- **Privacy policy (live):** **https://ibrahymsa3ed.github.io/instagold-privacy/** (source in public repo `instagold-privacy`)
- **Privacy policy draft (editable):** **[docs/PRIVACY_POLICY_TEMPLATE.md](docs/PRIVACY_POLICY_TEMPLATE.md)** — review, host on HTTPS, then use the URL in Play Console
- **Phased overview:** **[PLAY_STORE_PREP.md](PLAY_STORE_PREP.md)**
- **Helper:** `./scripts/print-release-signing-fingerprints.sh` — prints SHA-1/SHA-256 from your upload keystore for Firebase

### Google Play (AAB)

Upload an **Android App Bundle** to Play Console (not required for sideload APK):

```bash
./scripts/build-play-aab.sh
```

Artifact: `flutter-app/build/app/outputs/bundle/prodRelease/app-prod-release.aab`

### Release signing (Play Store)

1. Create an upload keystore (once), e.g. `flutter-app/android/upload-keystore.jks` (keep private; gitignored).
2. Copy `flutter-app/android/key.properties.example` → `key.properties` and fill passwords/paths.
3. Release builds use that keystore when `key.properties` exists; otherwise they fall back to **debug** signing (fine for local tests only).

### AdMob (production)

- **App ID** placeholders live in `flutter-app/android/app/build.gradle.kts` per flavor (`admobAppId`). Replace the **prod** value with your real AdMob App ID before a public Play release.
- **Banner unit:** pass at build time, e.g.  
  `--dart-define=ADMOB_BANNER_PROD=ca-app-pub-xxx/yyy`  
  or edit defaults in `flutter-app/lib/config/ad_config.dart`.
- Declare ads and related data collection in Play **Data safety** and your privacy policy.

### Build + Upload APK to Google Drive

```bash
./scripts/build-and-upload.sh
```

Or upload an existing **`InstaGold.apk`**:

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
