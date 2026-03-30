# Gold Scraper Service

Microservice that scrapes Egypt local gold prices from eDahab-like public pages every 10 minutes, stores snapshots, and exposes the latest data via authenticated REST API.

Part of the single `Gold` monorepo.

## Features

- Scheduled scraping every 10 minutes (`node-schedule` + cron expression)
- HTML fetching with `axios` and parsing with `cheerio`
- SQLite persistence for:
  - `ScrapedPrices` table
  - `LogEntries` table
- API key protection for `/api/gold-prices`
- Audit logs to file (`logs/scraper.log`) and DB (`LogEntries`)

## Data Model

### `ScrapedPrices`

- `id` (PK)
- `snapshot_id` (group rows from same scrape run)
- `carat` (`24k`, `21k`, `18k`, `14k`, `gold_pound_8g`, `ounce`)
- `buy_price`
- `sell_price`
- `currency`
- `updated_at`

### `LogEntries`

- `id` (PK)
- `source`
- `level`
- `action`
- `details`
- `created_at`

## API

### `GET /api/gold-prices`

Headers:

- `x-api-key: <SCRAPER_API_KEY>`

Response example:

```json
{
  "updated_at": "2026-03-30T10:00:01.120Z",
  "prices": {
    "24k": { "buy_price": 5134, "sell_price": 5110, "currency": "EGP" },
    "21k": { "buy_price": 4492, "sell_price": 4472, "currency": "EGP" },
    "18k": { "buy_price": 3849, "sell_price": 3832, "currency": "EGP" },
    "14k": { "buy_price": 2995, "sell_price": 2980, "currency": "EGP" },
    "gold_pound_8g": { "buy_price": 35936, "sell_price": 35936, "currency": "EGP" },
    "ounce": { "buy_price": 3111, "sell_price": 3111, "currency": "USD" }
  }
}
```

## Setup

1. Install dependencies:

```bash
npm install
```

2. Copy env file:

```bash
cp .env.example .env
```

3. Update values in `.env`, especially `SCRAPER_API_KEY`.
   - Use the same value as `main-backend/.env` (`SCRAPER_API_KEY`).

4. Start service:

```bash
npm start
```

## Running Every 10 Minutes

By default, cron is configured as:

- `SCRAPE_CRON=*/10 * * * *`

You can override in `.env`.

If you prefer OS cron instead of in-app scheduler, disable schedule and run:

```cron
*/10 * * * * cd /path/to/scraper-service && /usr/bin/node src/index.js >> logs/scraper.log 2>&1
```

## Security Notes

- Use a long random `SCRAPER_API_KEY`.
- Restrict network access to scraper service (private VPC, reverse proxy allowlist, etc.).
- Consider rate limiting if public exposure is required.
