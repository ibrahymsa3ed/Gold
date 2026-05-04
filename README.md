# InstaGold — Gold Price Tracker & Family Assets (Egypt)

> **For AI agents (Claude, Cursor, etc.):** Read `ARCHITECTURE.md` first. It has the full system design, what is live, what is dormant, and how notifications work.

## What This Is

A Flutter mobile app for Egyptian families to track live gold prices, manage gold assets, set savings goals, and receive price notifications. The backend runs on Railway and delivers FCM push notifications.

## Repository Structure

```
Gold/
  ARCHITECTURE.md          # FULL system design — read this first
  README.md                # This file — quick start + current status
  .cursor/rules/           # Cursor rules (build steps, no-assumptions, memory)
  scripts/                 # Build, deploy, and utility scripts
  scraper-service/         # Node.js price scraper (dormant — mobile scrapes directly)
  main-backend/            # Node.js API + FCM (LIVE on Railway)
  flutter-app/             # Flutter mobile app (Android + iOS)
```

## Current Production Status (Apr 2026)

| What | Status | Details |
|---|---|---|
| **Backend** | LIVE on Railway | `https://backend-production-c042.up.railway.app` |
| **FCM push notifications** | ACTIVE | Four daily slots (07:00, 11:00, 15:00, 19:00 Cairo) |
| **Price threshold alerts** | ACTIVE | Create via bell icon in app; backend fires FCM when threshold crossed |
| **Local notifications** | FALLBACK | Auto-activate if backend is unreachable |
| **Android app** | Sideloaded | Build + `adb install` |
| **iOS app** | Sideloaded | Build + `devicectl install` (dev signed, 7-day expiry) |
| **Play Store / App Store** | Not yet | Prep docs in `PLAY_STORE_PREP.md` |

## Quick Start

### Flutter app (mobile)
```bash
cd flutter-app
flutter pub get
flutter run --flavor dev --dart-define=INSTAGOLD_FLAVOR=dev
```

### Backend (local development)
```bash
cd main-backend
npm install
npm start        # runs on port 4200
```

### Deploy backend to Railway
```bash
cd main-backend
railway login    # if not authenticated
railway up
```

### Build for production
See `.cursor/rules/build-after-every-edit.mdc` for the full mandatory sequence. Summary:
```bash
# Android APK + AAB.
# This always refreshes repo-root InstaGold.apk and InstaGold.aab.
./scripts/build-prod-release.sh

# iOS
cd flutter-app
flutter build ios --release
```

## How Notifications Work

**Primary path (active):** Railway backend sends FCM push at Cairo slots 07:00/11:00/15:00/19:00. The backend scheduler runs every 5 min, checks the clock, and sends sell prices (21K, 24K, Ounce) to all registered devices.

**Fallback path:** Android uses WorkManager as a fixed-slot fallback when FCM is inactive. iOS has no APNs/FCM yet, so it uses `background_fetch` only: when iOS wakes the app, it refreshes prices/widget data and sends a local notification only if prices changed meaningfully.

**iOS widget freshness:** the iOS widget is updated immediately when the app opens/resumes and whenever iOS grants a background-fetch wake. It is not guaranteed real-time while the app is closed because iOS controls background execution. Opening/resuming the app does not show an iOS notification banner.

**Price alerts:** Users create threshold alerts ("21K above 5000 EGP") via the bell icon. Backend checks on every price sync and sends FCM push when crossed.

**Two Android notification channels:**
- `price_updates` — daily summaries (can be muted)
- `price_alerts` — threshold alerts (max priority, breaks DND)

## Price Source

On mobile, the app scrapes prices directly from eDahab (no backend needed for display):
1. Primary: `edahabapp.com` — full buy/sell per karat
2. Fallback: `t.me/s/eDahabApp` — Telegram web preview

The backend independently syncs prices for FCM delivery and alert checking.

## Key Configuration

| Config | Location | Value |
|---|---|---|
| Backend URL | `flutter-app/lib/config.dart` | `https://backend-production-c042.up.railway.app` |
| Firebase project | `firebase_options.dart` | `goldcalculate` |
| FCM enabled | `main-backend/.env` (Railway) | `FCM_SUMMARIES_ENABLED=true` |
| FCM min build | `main-backend/.env` (Railway) | `MIN_FCM_CLIENT_BUILD=2` |
| Android package | `build.gradle.kts` | `com.ibrahym.goldfamily` |
| iOS bundle | Xcode | `com.ibrahym.goldtracker` |

## Features

- Live gold prices (21K, 24K, 18K, 14K, Pound, Ounce) with buy/sell
- FCM push price summaries at 4 daily Cairo slots
- Price threshold alerts via FCM
- iOS best-effort background-fetch price-change alerts until Apple Developer/APNs is available
- Family member management
- Gold asset tracking with optional invoice attachment
- Savings with shared-pool goal tracking
- Gold calculator (manufacturing price, taxes/tariff, with/without adds) with "Add to Goals" shortcut
- Zakat calculator
- iOS + Android home-screen widgets (sell prices, locale-aware)
- Drag-reorderable price cards (order persists)
- MIUI battery optimization prompt for Xiaomi devices
- Backup/restore (ZIP with optional Google Drive upload)
- Arabic + English with RTL support
- Dark + Light theme

## Documentation

| File | What |
|---|---|
| `ARCHITECTURE.md` | Full system design, notification flow, deployment |
| `.cursor/rules/memory.mdc` | Project memory for AI agents |
| `.cursor/rules/build-after-every-edit.mdc` | Mandatory build steps |
| `.cursor/rules/no-assumptions.mdc` | Rule: verify before acting |
| `PLAY_STORE_PREP.md` | Play Store readiness checklist |
| `YOUR_ACTIONS_BEFORE_PLAY.md` | Owner-only manual steps |
| `MIUI_NOTIFICATIONS.md` | Xiaomi notification whitelist guide |
| `docs/PRIVACY_POLICY_TEMPLATE.md` | Privacy policy draft |

## Git

- Remote: `github.com/ibrahymsa3ed/Gold`
- Branch: `main`
- `InstaGold.apk` / `InstaGold.aab` at repo root are **gitignored**
- Always build Android releases with `./scripts/build-prod-release.sh` so the latest APK is copied to repo root
- Always update `ARCHITECTURE.md` and `README.md` with code changes
