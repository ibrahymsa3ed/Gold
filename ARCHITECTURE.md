# InstaGold Architecture

> **Last updated: Apr 2026**
>
> Read this file first. It is the single source of truth for how the system works.
> If this file says something, trust it. If code disagrees, this file wins (and file a fix).

---

## System Overview

InstaGold is a gold price tracker and family asset manager for the Egyptian market. It has three components in a monorepo:

```
Gold/
  scraper-service/     # Node.js — scrapes eDahab prices
  main-backend/        # Node.js — API, FCM push, price alerts (LIVE on Railway)
  flutter-app/         # Flutter — mobile app (Android + iOS)
```

**Current production state (Apr 2026):**

| Component | Where it runs | Status |
|---|---|---|
| `scraper-service` | NOT deployed (mobile app scrapes directly) | Dormant |
| `main-backend` | **Railway** (`https://backend-production-c042.up.railway.app`) | LIVE |
| `flutter-app` | User devices (Android + iOS sideload) | LIVE |

---

## How Prices Work (IMPORTANT)

There are TWO independent price pipelines. Understand both:

### Pipeline 1: Mobile on-device scraping (primary for display)
The Flutter app scrapes prices directly from eDahab on the device itself:
1. `GoldScraper` (in `lib/services/gold_scraper.dart`) fetches `edahabapp.com`
2. Falls back to Telegram channel `t.me/s/eDahabApp` if website fails
3. Stores in local SQLite `GoldPriceCache`
4. Dashboard reads from local SQLite — no backend needed

### Pipeline 2: Backend price sync (used for FCM and alerts)
The Railway backend syncs prices independently:
1. Backend calls scraper API every 10 min (`PRICE_SYNC_CRON=*/10 * * * *`)
2. Stores in its own `GoldPriceCache` (Railway SQLite)
3. Used by the FCM slot scheduler and price alert checker

**Both pipelines scrape the same source but run independently.**

---

## Notifications (CRITICAL — read carefully)

### FCM Push Notifications (ACTIVE)
FCM is **live and delivering** slot notifications via Railway. This is the PRIMARY notification path.

**How it works:**
1. On first app launch, `push_notifications_service.dart` registers the device with the backend (`POST /api/devices`) including FCM token, locale, and build number
2. Backend scheduler (`notificationsScheduler.js`) runs every 5 min (cron `*/5 * * * *`, tz `Africa/Cairo`)
3. At each of the four Cairo slots (07:00, 11:00, 15:00, 19:00), the scheduler finds all eligible devices and sends FCM push with sell prices for 21K, 24K, Ounce
4. Each device's `last_sent_slot` is tracked to prevent re-delivery

**Backend env vars (Railway):**
- `FCM_SUMMARIES_ENABLED=true` (currently ON)
- `MIN_FCM_CLIENT_BUILD=2` (devices with build >= 2 receive pushes)

**Flutter config:**
- `apiBaseUrl` in `lib/config.dart` defaults to `https://backend-production-c042.up.railway.app`
- `isFcmActive()` in `push_notifications_service.dart` reads a `SharedPreferences` flag set by the backend registration response

### Local Notifications (FALLBACK)
When FCM is active, local notifications self-disable via the `isFcmActive()` guard. They exist as a safety net:
- `price_watcher.dart` (Android WorkManager): checks `isFcmActive()` before firing — if true, marks slot and skips
- `dashboard_screen.dart::_maybeFireForegroundNotification`: same guard
- `ios_background_fetch.dart`: iOS best-effort (1-hour interval)

**If the Railway backend goes down**, `isFcmActive()` returns false (registration fails), and local notifications auto-activate as fallback. No code change needed.

### Notification Channels (Android)
Two channels registered in `notifications_service.dart`:
- `price_updates` (Importance.high) — daily slot summaries, user can mute
- `price_alerts` (Importance.max) — threshold alerts, breaks through DND

### Price Threshold Alerts (ACTIVE via backend)
Users create alerts in `PriceAlertsScreen` (bell icon in dashboard AppBar):
1. Flutter calls `POST /api/alerts` on Railway backend
2. Alert stored in backend `PriceAlerts` table
3. On every price sync (`POST /api/prices/sync`), backend runs `checkPriceAlerts()`
4. If a threshold is crossed, backend sends FCM push on `price_alerts` channel
5. Alert auto-deactivates after triggering (one-shot)

**Alert CRUD is HTTP-only** — goes through Railway backend, NOT local SQLite.
Files: `lib/screens/price_alerts_screen.dart`, `lib/services/api_service.dart` (getPriceAlerts, createPriceAlert, updatePriceAlert, deletePriceAlert)

---

## Data Access Rules

| Mode | Price source | CRUD (members, assets, savings, goals) | Price alerts | FCM registration |
|---|---|---|---|---|
| **Mobile** | Local `GoldScraper` + SQLite | Local SQLite | HTTP to Railway backend | HTTP to Railway backend |
| **Web** | HTTP to `main-backend` | HTTP to `main-backend` | HTTP to `main-backend` | N/A |

**Key insight:** On mobile, most data is local SQLite. But price alerts and FCM device registration go through the Railway backend via HTTP. If the backend is down, alerts fail gracefully (empty list, save error shown in SnackBar), and FCM registration silently fails (local notifications take over).

---

## 1) Scraper Service

### Status: NOT deployed (dormant)
The mobile app scrapes directly via `GoldScraper`. This service exists for the backend's use.

- Node.js + Express, port 4100
- Scrapes eDahab every 10 min, falls back to Telegram
- API: `GET /api/gold-prices` (requires `x-api-key` header)
- The Railway backend's `SCRAPER_API_URL` points to `http://localhost:4100` in `.env` but this is for local dev; Railway has its own scraping or the sync may fail silently (backend serves last cache)

---

## 2) Main Backend (Railway)

### Status: LIVE at `https://backend-production-c042.up.railway.app`
Deploy via: `cd main-backend && railway up`

### Key Endpoints
- `GET /health` — returns `{"ok":true,"service":"main-backend"}`
- `GET /api/prices/current` — latest cached prices (auth required)
- `POST /api/prices/sync` — trigger price sync + alert check
- `POST /api/devices` — FCM device registration
- `PUT /api/devices/:deviceId` — update device (locale, summaries toggle)
- `GET /api/alerts` — list user's price alerts
- `POST /api/alerts` — create alert (karat, target_price, direction)
- `PUT /api/alerts/:id` — update alert (active toggle)
- `DELETE /api/alerts/:id` — delete alert
- All CRUD for members, assets, savings, goals, companies, zakat

### Database Tables (SQLite on Railway)
Users, FamilyMembers, Companies, Assets, Savings, PurchaseGoals, GoldPriceCache, LogEntries, UserSettings, **Devices**, **PriceAlerts**

### FCM Scheduler
- File: `src/notificationsScheduler.js`
- Cron: `*/5 * * * *` (Africa/Cairo)
- Slots: 07:00, 11:00, 15:00, 19:00 with 30-min window
- Sends sell prices only (21K, 24K, Ounce) via `firebase-admin` FCM
- Tracks `last_sent_slot` per device to prevent duplicate delivery

### Price Alert Checker
- File: `src/notificationsService.js` — `checkPriceAlerts()`
- Hooked into `POST /api/prices/sync`
- Compares active alerts against latest sell prices
- Fires FCM on `price_alerts` channel when threshold crossed
- Deactivates alert after trigger

### Environment Variables (Railway)
```
PORT=4200
SCRAPER_API_URL=http://localhost:4100/api/gold-prices
SCRAPER_API_KEY=gold_app_secret_ibrahym_2026
PRICE_SYNC_CRON=*/10 * * * *
BYPASS_AUTH=true
FIREBASE_PROJECT_ID=goldcalculate
FIREBASE_SERVICE_ACCOUNT_PATH=../goldcalculate-firebase-adminsdk-fbsvc-178cde1243.json
FCM_SUMMARIES_ENABLED=true
MIN_FCM_CLIENT_BUILD=2
```

---

## 3) Flutter App

### App Identity
- Name: **InstaGold**
- Android package: `com.ibrahym.goldfamily`
- Android namespace: `com.ibrahym.instagold`
- iOS bundle: `com.ibrahym.goldtracker`
- Firebase project: `goldcalculate`

### Screen Map
- Login/Auth (email/password + Google)
- Home dashboard (tabbed: overview / assets / savings-goals / more)
- Price alerts screen (bell icon in AppBar)
- Family members list + per-member page
- Assets with invoice attachment
- Savings + Goals (shared pool: total savings auto-subtract from all goals)
- Gold Calculator panel (expansion tile between savings and goals; inputs: karat, weight, manufacturing/g, tax%; outputs: price without adds, total adds, price with adds; "Add to Goals" creates goal with chosen price)
- Zakat calculator
- Companies
- Settings (theme, locale, notification toggle)

### Key Services
| Service | File | Purpose |
|---|---|---|
| `ApiService` | `lib/services/api_service.dart` | Dual-mode: SQLite on mobile, HTTP on web. Price alerts always HTTP. |
| `GoldScraper` | `lib/services/gold_scraper.dart` | On-device price scraping (eDahab + Telegram fallback) |
| `PushNotificationsService` | `lib/services/push_notifications_service.dart` | FCM token management, device registration with backend |
| `NotificationsService` | `lib/services/notifications_service.dart` | Local notification display, channel registration |
| `PriceWatcher` | `lib/services/price_watcher.dart` | Android WorkManager background task |
| `BackupService` | `lib/services/backup_service.dart` | ZIP backup/restore with optional Google Drive upload |

### MIUI Battery Optimization
On first launch on Xiaomi/Redmi devices, a one-time dialog prompts the user to whitelist InstaGold from battery restrictions. Uses `device_info_plus` for manufacturer detection, `MethodChannel` (`com.ibrahym.instagold/settings`) to `MainActivity.kt` which fires `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.

### Price Card Order
Drag-reorderable cards persist order to `SharedPreferences` (`price_card_order` key). Default: `['21k', '24k', '14k_18k', 'pound_ounce']`.

### Savings/Goals — Decimal Weight & Manufacturing Price
- All weight fields (assets + goals) accept decimal input (`numberWithOptions(decimal:true)`).
- `PurchaseGoals` table has `manufacturing_price_g REAL DEFAULT 0` column (added in DB migration v4).
- Goal add/edit dialogs expose an optional manufacturing price field (مصنعية).
- `createGoal` accepts `manufacturingPriceG` and `overrideTargetPrice` params; when `overrideTargetPrice` is set the standard weight×price formula is bypassed.

### Gold Calculator Panel
- `ExpansionTile` placed between savings and goals sections in the Savings/Goals tab.
- Inputs: karat, weight (g), manufacturing EGP/g, taxes/tariff % (default 10).
- Live output: price without adds, total adds (mfg + tax), price with adds.
- "Add to Goals" button opens a dialog to choose which price to use as goal target; on confirm calls `createGoal` with `overrideTargetPrice`.

### Home Widgets
- **iOS:** WidgetKit extension `ios/InstaGoldWidget/` — reads from App Group `group.com.ibrahym.goldtracker`
- **Android:** `InstaGoldWidgetProvider` (Kotlin) — reads from `home_widget` SharedPreferences
- Both show sell prices for 21K, 24K, Ounce with locale-aware labels and RTL support

### UI Design
- Premium luxury dark-first. Base `#0B0B0D`, gold accent `#D4AF37`
- `PremiumBackground` widget: wave patterns + radial glow
- Glassmorphism bottom nav, gold gradient price cards, 150px heroes
- Sell-only in notifications and widgets; buy+sell in dashboard

---

## 4) Deployment

### Railway Backend
```bash
cd main-backend && railway login && railway up
```
Project: `instagold`, environment: `production`, service: `backend`

### Flutter Builds
See `.cursor/rules/build-after-every-edit.mdc` for the full mandatory build sequence.

```bash
# Android
./scripts/build-prod-release.sh
# Outputs are copied to repo root:
#   InstaGold.apk
#   InstaGold.aab

# iOS
cd flutter-app
flutter build ios --release
xcrun devicectl device install app --device <DEVICE_ID> build/ios/iphoneos/Runner.app
```

### iOS Device Install
For new devices: build with `xcodebuild -destination 'id=<DEVICE_ID>' -allowProvisioningUpdates` first to register the device in the provisioning profile, then install with `devicectl`.

Each new device also needs **Developer Mode** enabled: Settings > Privacy & Security > Developer Mode > ON (device restarts).

---

## 5) Repository
- Monorepo: `scraper-service/`, `main-backend/`, `flutter-app/`
- Git remote: `github.com/ibrahymsa3ed/Gold` (branch: `main`)
- `InstaGold.apk` and `InstaGold.aab` at repo root are gitignored (large binaries)
- Android prod releases must be built with `./scripts/build-prod-release.sh` so the latest APK is copied to repo root
- Always update `ARCHITECTURE.md` and `README.md` with code changes
