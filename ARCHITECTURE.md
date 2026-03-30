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

- Login/Auth (email/password + Google + Apple)
- Home dashboard with tabbed layout (overview/assets/savings-goals/more)
- Family members list + per-member page
- Assets list with create/edit/delete forms
- Savings entries and totals
- Goals with progress bars and saved-amount update
- Zakat calculator page
- Companies page (default + custom create)
- Settings (alerts hourly/six-hour, Arabic/English, dark/light)
- Optional logs viewer for admin/dev

### Data Access Rules

- Flutter talks only to main backend.
- Main backend talks to scraper service.
- No direct eDahab call from Flutter or main backend.

---

## 4) Security and Ops

- Shared API key between main backend and scraper (`SCRAPER_API_KEY`) using `x-api-key` header.
- Keep secrets in `.env` and GitHub repo secrets.
- Run behind reverse proxy with HTTPS.
- Use GitHub Actions for CI and deployment workflows.

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
- Keep architecture and README docs synchronized with each substantive code change.
