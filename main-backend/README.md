# Main Backend (InstaGold / Gold Platform)

Main API layer for users, family members, assets, savings, purchase goals, and cached gold prices consumed by Flutter.

Part of the single `Gold` monorepo.

## Architecture Responsibilities

- Pull prices from scraper API (`/api/gold-prices`) every hour
- Cache latest values in `GoldPriceCache`
- Use cached prices for all calculations:
  - asset current value
  - profit/loss
  - purchase goals progress
  - zakat estimate
- Log actions/errors to:
  - DB table: `LogEntries`
  - file: `logs/app.log`

## Tables

Reused / pre-existing:

- `Users`
- `FamilyMembers`
- `Assets`
- `Companies`
- `Savings`
- `PurchaseGoals`
- `LogEntries`

Added:

- `GoldPriceCache`
- `Devices` — one row per `(user_id, device_id)`. Stores `fcm_token`,
  `platform`, `locale`, `summaries_enabled`, `build_number`, and
  `last_sent_slot` (Cairo slot key like `2026-04-19#11`). `fcm_token` is
  intentionally not `UNIQUE`; collisions on token rotation or user switch
  are resolved atomically by `registerDevice` in
  [`src/notificationsService.js`](src/notificationsService.js). Indexed by
  `user_id`, `summaries_enabled`, and `fcm_token`.

## Core Endpoints

- `POST /api/auth/session` - verifies Firebase token and creates/returns user session row
- `GET /api/me` - current user profile and settings
- `PUT /api/me/settings` - locale/theme/notification interval
- `GET /api/prices/current` - latest cached prices
- `POST /api/prices/sync` - force sync from scraper service
- `GET /api/members` - list family members for logged-in user
- `POST /api/members` - create family member
- `GET /api/members/:memberId/assets` - list assets
- `POST /api/members/:memberId/assets` - create asset
- `PUT /api/assets/:assetId` - update asset
- `DELETE /api/assets/:assetId` - delete asset
- `GET /api/members/:memberId/savings` - savings history and total
- `POST /api/members/:memberId/savings` - add saving entry
- `GET /api/members/:memberId/assets-summary` - aggregated totals for assets page header
- `POST /api/goals/calculate` - compute and save target/saved/remaining for purchase goal
- `GET /api/members/:memberId/goals` - list goals
- `PUT /api/goals/:goalId/saved` - update goal saved amount and remaining amount
- `GET /api/members/:memberId/zakat` - 2.5% when 24k equivalent weight >= 85g
- `GET /api/companies` - list companies
- `POST /api/companies` - add custom company
- `GET /api/logs` - latest log entries for admin/dev viewer

FCM device registration (push notifications):

- `POST /api/devices` - register or upsert this device for the authenticated
  user. Body: `{ device_id, platform: 'ios'|'android', fcm_token, locale, build_number }`.
  Atomically prunes any other row holding the same `fcm_token` to avoid
  duplicate sends across user/device transitions. Response includes the row
  augmented with `fcm_summaries_active: boolean` — `true` iff the server
  will actually deliver slot pushes to this device today (i.e.
  `FCM_SUMMARIES_ENABLED && build_number >= MIN_FCM_CLIENT_BUILD &&
  summaries_enabled = 1`). Clients persist this flag and use it to suppress
  their own local notification firing so users never get double notifications
  during/after the rollout.
- `PUT /api/devices/:device_id` - update `fcm_token`, `locale`,
  `summaries_enabled`, or `build_number`. Token rotation re-runs the dedup
  step and preserves `last_sent_slot` so a refresh inside an active slot
  never causes a re-send. Response also carries `fcm_summaries_active`.
- `DELETE /api/devices/:device_id` - unregister.
- `POST /api/devices/:device_id/test` - owner-only test push (uses latest
  cached prices, ignores `last_sent_slot`). Powers the in-app "Send test
  notification" button.

Notes:

- Member-scoped endpoints enforce ownership (data isolation per authenticated user).
- `Devices` endpoints scope by `req.user.id`; cross-user access returns 404.

## Setup

1. Install dependencies:

```bash
npm install
```

2. Environment setup:

```bash
cp .env.example .env
```

3. Configure:

- `SCRAPER_API_URL`
- `SCRAPER_API_KEY` (must match `scraper-service/.env`)
- `PRICE_SYNC_CRON` (default hourly)
- `BYPASS_AUTH=true` for local dev without Firebase setup
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_PATH` (optional but recommended in backend environments)
- `FCM_SUMMARIES_ENABLED` (default `false`) — master kill switch for the
  fixed-time push scheduler. Even when on, no device receives a push until
  its installed app reports `build_number >= MIN_FCM_CLIENT_BUILD`.
- `MIN_FCM_CLIENT_BUILD` (default `999999`) — per-device build gate. Set
  this **above** any released build number until Phase 2 ships, then bump
  it to the first release that includes the FCM push client.
- `FCM_SWEEP_CRON` (default `*/5 * * * *`) — sweep tick frequency.
- `FCM_TIMEZONE` (default `Africa/Cairo`) — timezone for fixed slots
  (07:00, 11:00, 15:00, 19:00). DST is handled by luxon.
- `FCM_SLOT_WINDOW_MINUTES` (default `30`) — how long a slot stays live
  after its start.
- `FCM_STALE_CACHE_MINUTES` (default `30`) — if the cached price is older
  than this when a slot is live, the scheduler re-syncs once and skips the
  tick if still stale (next 5-min tick will retry until the slot window
  expires). We never deliver stale prices.

4. Run:

```bash
npm start
```

## Suggested Migration/Seed Strategy

- Use your preferred migration tool (Prisma/Knex/TypeORM) to manage schema in production.
- Seed `Companies` with common issuers (e.g., BTC) and allow custom entries from app UI.

## Fallback Strategy

When scraper is unavailable:

1. Continue serving latest `GoldPriceCache` entry.
2. Optionally integrate a global market API as fallback source.
3. Mark source in `GoldPriceCache.source` (`scraper-service` or `fallback-global`).

## Logging Policy

Record in `LogEntries` + `app.log`:

- asset create/update/delete
- savings updates
- goal calculation
- scraper sync success/failure
- API errors and auth failures

## Firebase Auth Contract

- Send Firebase ID token in header:
  - `Authorization: Bearer <idToken>`
- In `BYPASS_AUTH=true`, backend auto-uses a local dev user to simplify local testing.
