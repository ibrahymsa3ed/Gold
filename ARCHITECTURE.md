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
- Native cold-start auth restore first uses Firebase's persisted user, then silently restores Google Sign-In and rehydrates Firebase when needed so Google auth and Drive access survive full app restarts.

### UI design (InstaGold)

- **Theme:** Premium luxury dark-first design. Dark mode uses layered near-black base (`#0B0B0D`/`#0E0E10`) with subtle gradient transitions — never flat. Light mode retains warm cream surfaces (`#F7F2E8`). Gold accent palette: `#D4AF37` primary, `#C9A227` deep, `#E8CD5A` light, `#B8962E` muted.
- **Background:** Subtle abstract wave patterns painted via `CustomPaint` at very low opacity, with soft radial highlights behind key areas (headers, cards). Creates depth without clutter.
- **IG Logo:** Uses the provided IG image as a transparent cropped asset (`assets/icons/ig_logo_mark.png`) through `IgLogo`. The square background is removed so the mark sits directly on the screen background; light mode applies a darker gold tone for readability. Used in app bar, splash screen, empty states, and launcher assets.
- **Launcher icons:** Generated from two master assets: `ig_icon_master.png` (1024x1024 colored, dark bg) and `ig_notification_master.png` (512x512 white silhouette, transparent bg). Run `python3 scripts/generate_insta_app_icon.py` (repo root) to regenerate masters from `ig_logo_mark.png`, then `python3 flutter-app/scripts/generate_app_icons.py` to derive iOS icon, Android adaptive foreground, and 5-density notification silhouettes. After that, run `flutter pub run flutter_launcher_icons` and lock `android:inset="0%"` in `mipmap-anydpi-v26/ic_launcher.xml`.
- **Price Cards:** 150px hero cards with 4-stop gold gradient, glow box shadows, label badges, and value chips. Default order: 21K (hero), 24K (hero), 14K+18K (paired), Pound+Ounce (paired). Press-and-hold drag-reorderable via `SliverReorderableList`.
- **Navigation:** Floating glassmorphism pill-shaped bottom nav bar with backdrop blur, dark glass surface in dark mode, gold accent indicators, and subtle gold border.
- **Section Cards:** Premium dark card surface (`#1A1816`), gold accent gradient bar, `borderRadius: 22`, soft glow shadows, and `w800` typography.
- **Asset Cards:** Karat badge chips, inner financial detail cards, gold circle icons with gradient/shadow, profit/loss with trend indicators.
- **Brand header:** `InstaGoldWordmark` provides the premium in-app title lockup. The app-bar brand is tappable and returns to the Home tab; member switching remains on the separate member chip.
- **Login:** Gradient background, larger transparent IG mark, premium `InstaGoldWordmark`, refined input fields.
- **Notifications:** Scheduled price alerts via `flutter_local_notifications` + `timezone`. Android 13+ permission requests for `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`. Android notifications use `@drawable/ic_stat_notification` (white silhouette) for the status bar icon and `@mipmap/ic_launcher` as `largeIcon` for the expanded view, with `Color(0xFFD4AF37)` gold tint. A "Send Test Notification" button in Settings fires an immediate notification for debugging. Foreground price-change detection in `_load()` compares new prices against `pw_last_*` SharedPreferences keys and fires a notification on actual change. See `MIUI_NOTIFICATIONS.md` for Xiaomi/Redmi whitelist steps.
- **Background price watcher (Android):** `lib/services/price_watcher.dart` registers a periodic `workmanager` task that fetches prices via `GoldScraper`, compares against the last persisted values in `SharedPreferences`, fires a notification only when 21K/24K/ounce actually changed, and pushes the new prices to the iOS widget shared store via `home_widget`. Initialized from `main.dart` on Android only.
- **iOS Home Widget:** `ios/InstaGoldWidget/` is a WidgetKit extension (small + medium families) that reads gold prices from a shared App Group `group.com.ibrahym.goldtracker` (`UserDefaults`). The Flutter app writes 21K/24K/ounce values via the `home_widget` package whenever the dashboard loads or the background watcher detects a change. Bundle id: `com.ibrahym.goldtracker.InstaGoldWidget`. The widget target is added to `Runner.xcodeproj` via `ios/scripts/add_widget_target.rb` and embedded into the Runner app as an app extension.
- **Ads:** `google_mobile_ads` with a bottom **banner** on the main dashboard (above the bottom nav). `MobileAds.instance.initialize()` runs in `main.dart` (non-web). Ad unit IDs come from `lib/config/ad_config.dart`.
- **Android flavors:** `dev` and `prod` (same `applicationId`). `dev` shows launcher name **InstaGold Dev**; `prod` shows **InstaGold**. Build with `--flavor dev|prod` and matching `--dart-define=INSTAGOLD_FLAVOR=dev|prod`.
- **Release signing:** `android/key.properties` (gitignored) points to the upload keystore; if missing, release APKs/AABs use debug signing (development only). See `android/key.properties.example`.
- **Play Store prep without a developer account:** phased checklist in `PLAY_STORE_PREP.md`; owner-only steps in `YOUR_ACTIONS_BEFORE_PLAY.md`.
- **Privacy policy (draft):** `docs/PRIVACY_POLICY_TEMPLATE.md`.
- `classic` rollback preserved via `kUiDesignVariant` in `flutter-app/lib/theme/ui_design_variant.dart` (see `ROLLBACK_UI.md`).
- Gap info: full-width tinted card (green/red matching alarm direction) below prices with EGP gap value centred, jeweler's dollar on left, premium % and official rate on right; tapping opens explanation dialog.

### Reusable UI widgets (new)

| Widget | File | Purpose |
|--------|------|---------|
| `IgLogo` | `lib/widgets/ig_logo.dart` | Transparent IG image wrapper with light-mode tone adjustment |
| `InstaGoldWordmark` | `lib/widgets/ig_logo.dart` | Reusable premium title lockup for app bar and login |
| `IgLogoAnimated` | `lib/widgets/ig_logo.dart` | Animated fade+scale variant for splash |
| `PremiumBackground` | `lib/widgets/premium_background.dart` | Layered dark gradient with wave patterns and radial glow highlights |

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
