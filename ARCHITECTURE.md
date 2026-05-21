# InstaGold Architecture

> **Last updated: May 2026**
>
> Read this file first. It is the single source of truth for how the system works.
> If this file says something, trust it. If code disagrees, this file wins (and file a fix).

---

## System Overview

InstaGold is a gold price tracker and family asset manager for the Egyptian market. It has three components in a monorepo:

```
Gold/
  scraper-service/     # Node.js — dormant (scraping merged into main-backend)
  main-backend/        # Node.js — API, scraping, FCM push, price alerts (LIVE on Oracle Cloud)
  flutter-app/         # Flutter — mobile app (Android + iOS)
```

**Current production state (May 2026):**

| Component | Where it runs | Status |
|---|---|---|
| `scraper-service` | NOT deployed (merged into main-backend) | Dormant |
| `main-backend` | **Oracle Cloud** (`https://207.127.99.147.nip.io`) | LIVE |
| `flutter-app` | Google Play (production) + iOS sideload | LIVE |

---

## Backend Hosting — Oracle Cloud

| Detail | Value |
|---|---|
| **URL** | `https://207.127.99.147.nip.io` |
| **VM** | VM.Standard.E2.1.Micro (Always Free) |
| **Region** | Saudi Arabia West (Jeddah) — `me-jeddah-1` |
| **IP** | `207.127.99.147` |
| **OS** | Ubuntu 22.04 |
| **HTTPS** | Caddy + Let's Encrypt (auto-renewing) |
| **Process Manager** | PM2 (systemd auto-start) |
| **SSH** | `ssh ubuntu@207.127.99.147` |
| **Code path** | `/home/ubuntu/Gold/main-backend/` |
| **Env file** | `/home/ubuntu/Gold/main-backend/.env` |

### Ports
- 22 (SSH), 80 (HTTP→HTTPS redirect), 443 (HTTPS)
- Port 3000 closed externally — Express only via Caddy localhost

### Deploying updates
```bash
ssh ubuntu@207.127.99.147 "cd /home/ubuntu/Gold && git pull origin develop && cd main-backend && npm install --production && pm2 restart instagold-backend"
```

### Previous hosting
- Railway (`backend-production-c042.up.railway.app`) — trial expired May 2026, migrated to Oracle Cloud

---

## How Prices Work (IMPORTANT)

There are TWO independent price pipelines. Understand both:

### Pipeline 1: Mobile on-device scraping (primary for display)
The Flutter app scrapes prices directly from eDahab on the device itself:
1. `GoldScraper` (in `lib/services/gold_scraper.dart`) fetches `edahabapp.com`
2. Falls back to Telegram channel `t.me/s/eDahabApp` if website fails
3. Stores in local SQLite `GoldPriceCache`
4. Dashboard reads from local SQLite — no backend needed
5. Also scrapes USD/EGP rate from edahabapp.com (fallback: `open.er-api.com`)

### Pipeline 2: Backend price sync (used for FCM and alerts)
The Oracle Cloud backend scrapes prices directly (merged scraper):
1. `scraperClient.js` scrapes `edahabapp.com` directly using cheerio
2. Runs every 10 min (`PRICE_SYNC_CRON=*/10 * * * *`)
3. Stores in its own `GoldPriceCache` (SQLite on VM at `/data/main.db`)
4. Used by the FCM slot scheduler and price alert checker
5. Price validation: karats > 500 EGP, gold pound > 1000, ounce 500-15000 USD

**Both pipelines scrape the same source but run independently.**

---

## Notifications (CRITICAL — read carefully)

### FCM Push Notifications (ACTIVE)
FCM is **live and delivering** slot notifications via Oracle Cloud. This is the PRIMARY notification path.

**How it works:**
1. On first app launch, `push_notifications_service.dart` registers the device with the backend (`POST /api/devices`) including FCM token, locale, and build number
2. Backend scheduler (`notificationsScheduler.js`) runs every 5 min (cron `*/5 * * * *`, tz `Africa/Cairo`)
3. At each of the four Cairo slots (07:00, 11:00, 15:00, 19:00), the scheduler finds all eligible devices and sends FCM push with sell prices for 21K, 24K, Ounce
4. Each device's `last_sent_slot` is tracked to prevent re-delivery

**Backend env vars:**
- `FCM_SUMMARIES_ENABLED=true` (currently ON)
- `MIN_FCM_CLIENT_BUILD=3` (devices with build >= 3 receive pushes)

**Flutter config:**
- `apiBaseUrl` in `lib/config.dart` defaults to `https://207.127.99.147.nip.io`
- `isFcmActive()` reads a `SharedPreferences` flag set by backend registration response

### Local Notifications (FALLBACK)
When FCM is active, Android local notifications self-disable via `isFcmActive()` guard.
- `price_watcher.dart` (Android WorkManager): checks `isFcmActive()` before firing
- `dashboard_screen.dart::_maybeFireForegroundNotification`: uses same guard
- iOS: background-fetch only, no foreground banners until Apple Developer account obtained

**If the backend goes down**, `isFcmActive()` returns false, and local notifications auto-activate as fallback.

### Notification Channels (Android)
- `price_updates` (Importance.high) — daily slot summaries
- `price_alerts` (Importance.max) — threshold alerts, breaks through DND

### Price Threshold Alerts (ACTIVE via backend)
Users create alerts in `PriceAlertsScreen` (bell icon):
1. Flutter calls `POST /api/alerts` on backend
2. Alert stored in backend `PriceAlerts` table
3. On every price sync, backend runs `checkPriceAlerts()`
4. If threshold crossed, backend sends FCM push on `price_alerts` channel
5. Alert auto-deactivates after triggering (one-shot)

---

## Data Access Rules

| Mode | Price source | CRUD (members, assets, savings, goals) | Price alerts | FCM registration |
|---|---|---|---|---|
| **Mobile** | Local `GoldScraper` + SQLite | Local SQLite | HTTP to backend | HTTP to backend |
| **Web** | HTTP to `main-backend` | HTTP to `main-backend` | HTTP to `main-backend` | N/A |

---

## Main Backend (Oracle Cloud)

### Key Endpoints
- `GET /health` — returns `{"ok":true,"service":"main-backend"}`
- `GET /api/prices/current` — latest cached prices (auth required)
- `POST /api/prices/sync` — trigger price sync + alert check
- `POST /api/devices` — FCM device registration
- `PUT /api/devices/:deviceId` — update device
- `GET /api/alerts` — list user's price alerts
- `POST /api/alerts` — create alert
- `PUT /api/alerts/:id` — update alert
- `DELETE /api/alerts/:id` — delete alert
- All CRUD for members, assets, savings, goals, companies, zakat

### Database Tables (SQLite)
Users, FamilyMembers, Companies, Assets, Savings, PurchaseGoals, GoldPriceCache, LogEntries, UserSettings, Devices, PriceAlerts

### Environment Variables
```
PORT=3000
FIREBASE_PROJECT_ID=goldcalculate
FCM_SUMMARIES_ENABLED=true
MIN_FCM_CLIENT_BUILD=3
RENDER_EXTERNAL_URL=https://207.127.99.147.nip.io
FIREBASE_SERVICE_ACCOUNT_JSON=<full JSON string>
```

---

## Flutter App

### App Identity
- Name: **InstaGold**
- Android package: `com.ibrahym.goldfamily`
- iOS bundle: `com.ibrahym.goldtracker`
- Firebase project: `goldcalculate`

### Key Features
- Real-time gold price tracking (eDahab scraping)
- Family member management with gold asset tracking
- Price alerts (FCM-powered)
- Gold calculator with manufacturing costs and taxes
- Savings goals with shared pool
- First-launch tutorial (6 slides)
- Hide/show assets toggle for privacy
- 2.5g ingot weight option
- Home screen widgets (iOS + Android)
- Zakat calculator
- Backup/restore with Google Drive

### Screen Map
- Login/Auth (email/password + Google)
- Home dashboard (tabbed: overview / assets / savings-goals / more)
- Price alerts screen (bell icon in AppBar)
- Member selector (subtitle under InstaGold wordmark)
- Assets with invoice attachment
- Savings + Goals (shared pool model)
- Gold Calculator panel (uses sell rate)
- Zakat calculator
- Settings (theme, locale, notification toggle)
- First-launch tutorial

### UI Design
- Premium luxury dark-first. Base `#0B0B0D`, gold accent `#D4AF37`
- `PremiumBackground` widget: wave patterns + radial glow
- Glassmorphism bottom nav, gold gradient price cards
- Sell-only in notifications and widgets; buy+sell in dashboard
- Never use "الحية" or "اللحظية" in any string

---

## Play Store

- **Status**: Production access applied (May 21, 2026)
- **Package**: `com.ibrahym.goldfamily`
- **Latest version**: `1.0.2+7` (AAB: `instagold-1.0.2+7.aab`)
- **Play Console**: https://play.google.com/console/u/0/developers/6183037720371974289/app/4972005972149303949
- **Play signing SHA-1**: `F3:13:36:92:3D:FD:83:F9:33:87:D1:30:EF:44:52:E1:70:36:95:B4` (in Firebase)
- **Ads**: disabled (`kAdsEnabled = false`)
- **Store assets**: `play-store-assets/` folder

---

## Repository
- Monorepo: `scraper-service/`, `main-backend/`, `flutter-app/`
- Git remote: `github.com/ibrahymsa3ed/Gold`
- Branches: `main` (production), `develop` (development) — currently in sync
- `InstaGold.apk` and `InstaGold.aab` at repo root are gitignored

---

## Accounts & Services
| Service | Details |
|---|---|
| Firebase | Project `goldcalculate` — Auth, FCM |
| Google Play | Developer ID `6183037720371974289` |
| Oracle Cloud | Tenancy `ibrahymsaaeed`, region `me-jeddah-1` |
| GitHub | `ibrahymsa3ed/Gold` |
| ExchangeRate-API | USD/EGP fallback (free tier, 1h cache) |
