# Two-App Architecture Design

## 1) Scraper Service (Micro-App)

### Responsibilities

- Fetch local gold prices from eDahab-like public HTML pages every 10 minutes.
- Parse buy/sell prices for 24k/21k/18k/14k, gold pound, and ounce.
- Persist snapshots in `ScrapedPrices`.
- Expose latest snapshot via authenticated endpoint `/api/gold-prices`.
- Log scraping/API activity in `scraper.log` and DB `LogEntries`.

### Runtime

- Node.js + Express
- `node-schedule` for cron scheduler (`*/10 * * * *`)
- `axios` + `cheerio` parser
- SQLite for local persistence (replaceable by PostgreSQL in production)

### API Contract

- **GET** `/api/gold-prices`
  - Header: `x-api-key`
  - Returns latest grouped prices
  - 401 if key missing/invalid

### Failure Handling

- On scrape failure, keep last successful snapshot available.
- Write error logs with stack/message.
- Return 404 if no snapshot exists yet.

### Telegram Fallback

- If the primary eDahab website scrape returns empty or fails, the scraper automatically falls back to the public Telegram channel web preview at `https://t.me/s/eDahabApp`.
- The Telegram source provides prices for 24k/21k/18k, gold pound, and ounce in a consistent emoji-delimited text format.
- Limitation: Telegram posts contain a single price per karat (no separate buy/sell); both are set to the same value.
- The `source` field in the response indicates which source was used: `edahab-web` or `telegram-edahab`.

---

## 2) Main App Backend

### Responsibilities

- Fetch from scraper API every hour (or on-demand).
- Cache latest prices in `GoldPriceCache`.
- Keep all business calculations dependent on cache only (no direct scrape in app backend):
  - Current asset values
  - Profit/loss
  - Purchase goal target/remaining
  - Zakat
- Track all business and API events in `LogEntries` and `app.log`.

### Core Services

- **PriceService**
  - `syncFromScraper()` hourly and manual endpoint
  - writes normalized rows to `GoldPriceCache`
- **AssetSummaryService**
  - member totals by karat + total current value/purchase/profit
- **GoalService**
  - computes target from cached price by karat and desired grams
- **ZakatService**
  - converts mixed karats to 24k equivalent, checks 85g threshold, applies 2.5%

### Key Endpoints

- `GET /api/prices/current`
- `POST /api/prices/sync`
- `GET /api/members`
- `POST /api/members`
- `GET /api/members/:memberId/assets`
- `POST /api/members/:memberId/assets`
- `PUT /api/assets/:assetId`
- `DELETE /api/assets/:assetId`
- `GET /api/members/:memberId/savings`
- `POST /api/members/:memberId/savings`
- `PUT /api/savings/:savingId` (update amount)
- `DELETE /api/savings/:savingId`
- `GET /api/members/:memberId/assets-summary`
- `POST /api/goals/calculate`
- `GET /api/members/:memberId/goals`
- `PUT /api/goals/:goalId/saved`
- `GET /api/members/:memberId/zakat`
- `GET /api/companies`
- `POST /api/companies`

### Fallback Pattern

If scraper unavailable:

1. Serve last `GoldPriceCache`.
2. Optionally use global API fallback source.
3. Log source value (`scraper-service` vs `fallback-global`).

---

## 3) Flutter Frontend

### Screen Map

- Login/Auth (email/password + Google; Apple removed)
- Home dashboard with tabbed layout (overview/assets/savings-goals/more)
- Overview: karat prices in ingot-shaped cards (21k hero), gold pound in coin shape, global ounce in rose-gold coin shape
- Family members list + per-member page (inline edit/delete)
- Assets list with shaped cards per type: ring (oval), necklace (pendant), bracelet (rounded pill), coins (circle), ingot (trapezoid)
- Asset types: Ring, Necklace, Bracelet, Coins, Ingot, Other (jewellery sub-types selectable at creation)
- Savings entries and totals (add amount-only; edit/delete entries)
- Optional **invoice** file per asset (stored locally on device under app documents; included in zip backup)
- Goals with progress bars and saved-amount update
- Zakat calculator page
- Companies page (default + custom create)
- Settings (alerts hourly/six-hour, Arabic/English, dark/light)
- Optional logs viewer for admin/dev

Implementation note:

- Flutter presentation is modularized into separate screen files to keep feature evolution maintainable.
- Firebase bootstrapping uses explicit options in `flutter-app/lib/firebase_options.dart` for web/native startup consistency.
- Web OAuth sign-in uses Firebase popup providers (`GoogleAuthProvider` / `OAuthProvider`) to align with browser flow.
- Web Google auth falls back to redirect when popup flow is blocked/closed by browser policies.

### UI design (InstaGold)

- **Theme:** Rich gold palette (`#B5973F` primary, `#D4B254` accent) with warm cream surfaces (`#F7F2E8` light, deep amber `#1A1714` dark). Default mode is **light**.
- **App Icon:** Dark luxurious gold coin (gold pound style) with "IG" monogram, rim detailing, radial gold gradient shine, and dark background.
- **Price Cards:** 150px hero cards with 4-stop gold gradient, glow box shadows, label badges, and value chips (no Buy/Sell labels). Default order: 21K (hero), 24K (hero), 14K+18K (paired), Pound+Ounce (paired). Press-and-hold drag-reorderable via `SliverReorderableList`.
- **Navigation:** Floating glassmorphism pill-shaped bottom nav bar with backdrop blur and gold accent indicators.
- **Section Cards:** Gold accent gradient bar, `borderRadius: 22`, depth shadows, and `w800` typography.
- **Asset Cards:** Karat badge chips, inner financial detail cards, gold circle icons with gradient/shadow, profit/loss with trend indicators.
- **Login:** Gradient background, 88px brand icon with 4-stop gold glow, 32px title, refined input fields.
- **Notifications:** Scheduled price notifications via `flutter_local_notifications` + `timezone`. Android 13+ permission requests for `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`.
- **Ads:** `google_mobile_ads` with a bottom **banner** on the main dashboard (above the bottom nav). `MobileAds.instance.initialize()` runs in `main.dart` (non-web). Ad unit IDs come from `lib/config/ad_config.dart` (dev uses Google test banner; prod uses `--dart-define=ADMOB_BANNER_PROD` or defaults until set). Android **AdMob App ID** is injected per flavor via `manifestPlaceholders["admobAppId"]` in `android/app/build.gradle.kts`.
- **Android flavors:** `dev` and `prod` (same `applicationId`). `dev` shows launcher name **InstaGold Dev**; `prod` shows **InstaGold**. Build with `--flavor dev|prod` and matching `--dart-define=INSTAGOLD_FLAVOR=dev|prod`. Root APK outputs: `InstaGold-dev.apk` (dev), `InstaGold.apk` (prod). Play uploads use **AAB**: `flutter build appbundle --flavor prod` → `app-prod-release.aab`.
- **Release signing:** `android/key.properties` (gitignored) points to the upload keystore; if missing, release APKs/AABs use debug signing (development only). See `android/key.properties.example`.
- **Play Store prep without a developer account:** phased checklist in `PLAY_STORE_PREP.md`; owner-only steps (keystore, `key.properties`, Firebase fingerprints, AdMob) in `YOUR_ACTIONS_BEFORE_PLAY.md`. Use `scripts/print-release-signing-fingerprints.sh` to print release SHA-1/SHA-256 for Firebase.
- `classic` rollback preserved via `kUiDesignVariant` in `flutter-app/lib/theme/ui_design_variant.dart` (see `ROLLBACK_UI.md`).
- Gap info: full-width tinted card (green/red matching alarm direction) below prices with EGP gap value centred, jeweler's dollar on left, premium % and official rate on right; tapping opens explanation dialog.

### Data Access Rules

- **Web mode:** Flutter `kIsWeb` talks to `main-backend` HTTP APIs; backup export builds JSON from those APIs.
- **Mobile mode:** Flutter uses local SQLite (`sqlite`) plus direct eDahab scraping for prices (`GoldScraper`) with automatic Telegram channel fallback — no Node servers required on device.
- **Backup:** `BackupService` writes `instagold_backup.zip` containing `instagold_backup.json` and optional `invoices/*` binaries; restore replays the JSON into SQLite and copies invoice files back. Optional auto-upload to Google Drive via `GoogleDriveService` (stores in "InstaGold Backups" folder).
- When both backends are used (dev), main backend talks to scraper service for price cache.

---

## 4) Security and Ops

- Shared API key between main backend and scraper (`SCRAPER_API_KEY`) using `x-api-key` header.
- Keep secrets in `.env` and GitHub repo secrets.
- Run behind reverse proxy with HTTPS.
---

## 5) Deployment Topology (Recommended)

- `scraper-service`: container + private internal endpoint
- `main-backend`: container + public API endpoint
- `flutter-app`: mobile distribution (App Store/Play Store)
- DB: managed PostgreSQL
- Logs: centralized aggregator

## 6) Repository Strategy

- Use a single monorepo (`Gold`) for `scraper-service`, `main-backend`, and `flutter-app`.
- Deploy/push from root via monorepo mode in `scripts/deploy.sh`.
- Run scraper and main backend together with `scripts/dev-up.sh` for local development.
- Use `scripts/setup-firebase-files.sh` to copy Firebase config files into Flutter platform folders.
- Keep architecture and README docs synchronized with each substantive code change.
