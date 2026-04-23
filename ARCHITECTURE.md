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
- Firebase bootstrapping uses explicit options in `flutter-app/lib/firebase_options.dart` for web/native startup consistency. Android `appId` is the real per-platform value `1:190629243449:android:8ac3acfec1971309e6bbe8` for package `com.ibrahym.goldfamily` (was previously a copy-paste of the web `appId`).
- Firebase Cloud Messaging (FCM) is wired on Android via `com.google.gms.google-services` Gradle plugin (project- and app-level in `flutter-app/android/build.gradle.kts` and `flutter-app/android/app/build.gradle.kts`) plus `flutter-app/android/app/google-services.json`. Flutter side uses `firebase_messaging` and `package_info_plus`. iOS APNs upload is pending; iOS push will follow.
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
- **Notifications:** Scheduled price alerts via `flutter_local_notifications` + `timezone`. Android 13+ permission requests for `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`. Android notifications use `@drawable/ic_stat_notification` (white silhouette) for the status bar icon and `@mipmap/ic_launcher` as `largeIcon` for the expanded view, with `Color(0xFFD4AF37)` gold tint. The Android manifest declares FCM defaults (`com.google.firebase.messaging.default_notification_icon` → `ic_stat_notification`, `default_notification_color` → `notification_gold`, `default_notification_channel_id` → `price_updates`) so server-driven push retains the same look when the app is killed. iOS notification banners auto-derive their icon from the app icon set (no explicit wiring needed). See `MIUI_NOTIFICATIONS.md` for Xiaomi/Redmi whitelist steps.
- **Sell-only feed for banners + widget:** Push notification banners (current local + future FCM), and the iOS home-screen widget, render **sell prices only** for 21K, 24K, and ounce. The in-app dashboard continues to render both buy and sell columns separately. The sell-only constraint is enforced where data leaves the dashboard for the widget/notification surface — `lib/services/price_watcher.dart::_loadFreshPrices`, `lib/services/ios_background_fetch.dart::_runFetch`, and `lib/screens/dashboard_screen.dart::_afterPricesLoaded` all read `sell_price` for 21K/24K (ounce was already sell). `NotificationsService.buildPriceBody` is a pure renderer; the sell semantics live entirely in those three call sites.
- **Background price watcher (Android):** `lib/services/price_watcher.dart` registers a periodic `workmanager` task that fetches prices via `GoldScraper`, writes the latest sell prices to the `home_widget` shared store (feeds both the Android and iOS home-screen widgets), and fires a local notification if the current time falls within one of the four Cairo fixed slots (07:00, 11:00, 15:00, 19:00 ±30 min, quiet hours 23:00–07:00). Slot-deduplication via `SharedPreferences` (`pw_last_slot`) prevents repeated delivery within the same slot. Initialized from `main.dart` on Android only.
- **Local fixed-slot notifications (active — no server required):** Both platforms fire price summary notifications at four fixed Cairo times: **07:00, 11:00, 15:00, 19:00 (Africa/Cairo, DST-safe via `timezone` package)**. Each slot has a 30-minute acceptance window. A slot key (e.g. `2026-04-21#11`) is persisted to `SharedPreferences` so a slot is never delivered twice, even if the app wakes multiple times within the window. Quiet hours (23:00–07:00 Cairo) are enforced. Sell prices only (21K, 24K, ounce) are shown in the notification body. **Android** fires from two paths: (1) `lib/services/price_watcher.dart` (WorkManager background task) and (2) `lib/screens/dashboard_screen.dart::_maybeFireForegroundNotification` (when app is open). **iOS** fires best-effort from `lib/services/ios_background_fetch.dart` via the `background_fetch` plugin — delivery depends on iOS granting background-app-refresh budget; it still uses a 1-hour interval and fires within that interval if a valid slot is active.
- **FCM push summaries (wired, dormant — requires hosted backend):** `lib/services/push_notifications_service.dart` is the Flutter-side FCM registration client. It requests notification permission on first dashboard build, fetches the FCM token, generates a stable `device_id`, and calls `POST /api/devices` on the configured backend URL (defaults to `localhost:4200`). This call **silently fails on all physical devices** because no backend is currently hosted. The backend scheduler (`main-backend/src/notificationsScheduler.js`) is kill-switched by default (`FCM_SUMMARIES_ENABLED=false`, `MIN_FCM_CLIENT_BUILD=999999`) and requires a running `main-backend` instance on a reachable server. The FCM background message handler (`firebaseMessagingBackgroundHandler`) is registered in `main.dart` and the Firebase Messaging SDK is fully initialized — enabling FCM in the future only requires: (1) hosting `main-backend`, (2) setting `API_BASE_URL` at build time, and (3) flipping the two env flags. The Settings section exposes a "Price summaries" toggle that attempts to call `PUT /api/devices/:device_id` (also fails silently without backend). Locale changes propagate to the App Group for the iOS widget regardless of whether the backend call succeeds. **Dead code safe to remove later:** `ApiService.removeDevice()`, `ApiService.sendTestPush()`, `PushNotificationsService.sendTest()`, `PushNotificationsService.isFcmActive()`, `PushNotificationsService.fcmActive`, `NotificationsService.schedulePriceNotifications()`, `NotificationsService.cancelAll()`, l10n keys `send_test_notification`/`test_notification_sent`/`test_notification_failed`.
- **FCM double-notification guard:** When FCM is active (backend is live and `isFcmActive()` returns true), both `price_watcher.dart` and `dashboard_screen.dart::_maybeFireForegroundNotification` mark the current slot in `SharedPreferences` and skip firing a local notification. This prevents the user from receiving the same slot summary twice (once from FCM, once from the local WorkManager task).
- **Notification channels (Android, Apr 2026):** Two separate channels are registered on first launch via `AndroidFlutterLocalNotificationsPlugin.createNotificationChannel`:
  - `price_updates` (`Importance.high`) — the four daily slot price summaries; users can mute this channel in Android settings without losing price-alert notifications.
  - `price_alerts` (`Importance.max`) — reserved for future threshold alerts ("Gold hit 6000 EGP!"); always breaks through Do Not Disturb. The `showPriceAlertNotification()` stub in `notifications_service.dart` is ready to be wired to business logic when threshold alerts are implemented.
- **MIUI / Xiaomi battery optimization prompt (Apr 2026):** On first launch on a Xiaomi or Redmi device (`device_info_plus` manufacturer check), a one-time `AlertDialog` prompts the user to whitelist InstaGold from battery restrictions. Tapping "Open Settings" fires `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` via a `MethodChannel` in `MainActivity.kt` (`com.ibrahym.instagold/settings`) — Android directly presents the system permission dialog. Falls back to the general battery optimization list screen if the direct intent is unavailable. The prompt is shown only once (guarded by `miui_battery_prompt_shown` in `SharedPreferences`). This is the primary fix for WorkManager background tasks being killed on Xiaomi devices.
- **Price card order persistence (Apr 2026):** The drag-reorderable price cards on the home dashboard now persist their order across app restarts. `_loadCardOrder()` reads `price_card_order` (a `List<String>`) from `SharedPreferences` in `initState`; `_saveCardOrder()` writes it immediately after every `onReorder` event. Falls back to the default order (`['21k', '24k', '14k_18k', 'pound_ounce']`) if no saved order exists.
- **iOS Home Widget:** `ios/InstaGoldWidget/` is a WidgetKit extension (small + medium families) that reads gold prices from a shared App Group `group.com.ibrahym.goldtracker` (`UserDefaults`). The Flutter app writes 21K/24K/ounce values via the `home_widget` package whenever the dashboard loads or the background watcher detects a change. The app also writes a `locale` key (`en`/`ar`) so the widget renders karat labels per locale: English shows `21K/24K/Ounce`, Arabic shows `عيار 21/عيار 24/الأونصه` with Western digits. Bundle id: `com.ibrahym.goldtracker.InstaGoldWidget`. The widget target is added to `Runner.xcodeproj` via `ios/scripts/add_widget_target.rb` and embedded into the Runner app as an app extension.
  - **Visual design (Apr 2026 redesign):** A single design-token block (`Tokens` enum in `InstaGoldWidget.swift`) is the source of truth for all colors and gradients — no per-view hex literals. Both light (`#F7F4ED` cream) and dark (`#0B0B0D`) themes are designed in tandem, switched via `@Environment(\.colorScheme)`. Gold value tone is theme-aware (bright `#D4AF37` on dark for AAA contrast, deeper antique `#8A6414` on light for AA contrast on cream); the brand gradient is reserved for the logo mark only, applying the "one flourish per surface" rule. All three karat rows (21K, 24K, Ounce) appear on **both small and medium families** — small no longer hides Ounce. Numbers use `.monospacedDigit()` + locale-formatted thousand separators so width never jitters between updates. The legacy footer "Updated HH:MM" is now a compact capsule pill in the header next to the brand mark. Layout direction is mirrored to RTL for Arabic via `.environment(\.layoutDirection, .rightToLeft)` so labels and prices swap sides naturally.
  - **Logo (Apr 2026 update):** The header brand mark uses `Image("ig_logo_mark")` with `.renderingMode(.template)` and `Tokens.brandGradient` applied via `foregroundStyle` — same gold gradient that was previously applied to the `Text("iG")` placeholder. The PNG imageset (`ig_logo_mark.imageset` at @1x/2x/3x) lives in `ios/InstaGoldWidget/Assets.xcassets/` (the widget extension's own catalog, not `Runner/Assets.xcassets/`).
- **Android Home Widget:** `flutter-app/android/app/src/main/kotlin/com/ibrahym/instagold/InstaGoldWidgetProvider.kt` is an `AppWidgetProvider` (subclass of the `home_widget` plugin's `HomeWidgetProvider`) that renders sell prices for 21K, 24K, and ounce in a single resizable RemoteViews layout (`res/layout/instagold_widget.xml`). The receiver is registered in `AndroidManifest.xml` with both the system `APPWIDGET_UPDATE` action and `es.antonborri.home_widget.action.BACKGROUND` so Flutter's `HomeWidget.updateWidget(...)` calls (already wired in `app.dart`, `dashboard_screen.dart`, `price_watcher.dart`, `ios_background_fetch.dart`) trigger refreshes without going through `requestPinAppWidget`. The widget reads `price_21k/price_24k/price_ounce/updated_at/locale` from the `home_widget` SharedPreferences and reuses the same Western-digit grouping (`5,240`) as the iOS widget. Because RemoteViews cannot fill text with a gradient or use `@Environment(\.colorScheme)`, the Android widget is intentionally **dark-only and one resizable size** for the minimal scope: rounded `#0B0B0D` surface, solid `#D4AF37` gold for prices and brand mark, hairline white-at-8% dividers between rows, time pill in the header. Locale flips both the karat/ounce labels (`عيار 21`, `الأونصه`) and the root layout direction via `RemoteViews.setInt("setLayoutDirection", LayoutDirection.RTL)`. Tap anywhere on the widget opens `MainActivity` via a `PendingIntent.FLAG_IMMUTABLE` activity intent. Widget metadata lives in `res/xml/instagold_widget_info.xml` (default 4x2 cells, `resizeMode="horizontal|vertical"`, `updatePeriodMillis=0` since refreshes are push-driven from Flutter, preview re-uses `@mipmap/ic_launcher`). Light theme, Material You dynamic color, multiple sizes, and a configuration screen are deliberately out of scope for the minimal version.
  - **Logo (Apr 2026 update):** The text `"iG"` brand mark in the widget header has been replaced with `ImageView` (`@drawable/ig_logo_mark`) — a pre-tinted gold (`#D4AF37`) version of the same `ig_logo_mark.png` asset used in the app. Density-specific PNGs live in `res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ig_logo_mark.png` (generated from the master `assets/icons/ig_logo_mark.png` at 24/36/48/72/96 px).
- **Ads:** `google_mobile_ads` with a bottom **banner** on the main dashboard (above the bottom nav). `MobileAds.instance.initialize()` runs in `main.dart` (non-web). Ad unit IDs come from `lib/config/ad_config.dart`.
- **Android flavors:** `dev` and `prod` (same `applicationId`). `dev` shows launcher name **InstaGold Dev**; `prod` shows **InstaGold**. Build with `--flavor dev|prod` and matching `--dart-define=INSTAGOLD_FLAVOR=dev|prod`.
- **Release signing:** `android/key.properties` (gitignored) points to the upload keystore; if missing, release APKs/AABs use debug signing (development only). See `android/key.properties.example`.
- **Play Store prep without a developer account:** phased checklist in `PLAY_STORE_PREP.md`; owner-only steps in `YOUR_ACTIONS_BEFORE_PLAY.md`.
- **Privacy policy (draft):** `docs/PRIVACY_POLICY_TEMPLATE.md`.
- `classic` rollback preserved via `kUiDesignVariant` in `flutter-app/lib/theme/ui_design_variant.dart` (see `ROLLBACK_UI.md`).
- Gap info: full-width tinted card (green/red matching alarm direction) below prices with EGP gap value centred, jeweler's dollar on left, premium % and official rate on right; tapping opens explanation dialog.

### Reusable UI widgets (new)


| Widget              | File                                  | Purpose                                                             |
| ------------------- | ------------------------------------- | ------------------------------------------------------------------- |
| `IgLogo`            | `lib/widgets/ig_logo.dart`            | Transparent IG image wrapper with light-mode tone adjustment        |
| `InstaGoldWordmark` | `lib/widgets/ig_logo.dart`            | Reusable premium title lockup for app bar and login                 |
| `IgLogoAnimated`    | `lib/widgets/ig_logo.dart`            | Animated fade+scale variant for splash                              |
| `PremiumBackground` | `lib/widgets/premium_background.dart` | Layered dark gradient with wave patterns and radial glow highlights |


### Data Access Rules

- **Web mode:** Flutter `kIsWeb` talks to `main-backend` HTTP APIs; backup export builds JSON from those APIs.
- **Mobile mode:** Flutter uses local SQLite (`sqlite`) plus direct eDahab scraping for prices (`GoldScraper`) with automatic Telegram channel fallback — no Node servers required on device.
- **Backup:** `BackupService` writes `instagold_backup.zip` containing `instagold_backup.json` and optional `invoices/`* binaries; restore replays the JSON into SQLite and copies invoice files back. Optional auto-upload to Google Drive via `GoogleDriveService` (stores in "InstaGold Backups" folder).
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