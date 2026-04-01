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

Notes:

- Member-scoped endpoints enforce ownership (data isolation per authenticated user).

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
