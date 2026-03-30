# Gold Platform Architecture (Egypt Market + Family Assets)

This repository is structured as two backend-facing apps plus Flutter client:

- `scraper-service/` - scrapes public local gold pages every 10 minutes and serves authenticated prices API
- `main-backend/` - consumes scraper API, caches prices, computes assets/goals/zakat, serves app APIs
- `flutter-app/` - mobile UI for families to track gold assets and goals

## Repository Structure

```text
Gold/
  ARCHITECTURE.md
  README.md
  .github/workflows/ci.yml
  .cursor/rules/docs-and-readme-sync.mdc
  scripts/deploy.sh
  scripts/dev-up.sh
  scraper-service/
  main-backend/
  flutter-app/
```

## High-Level Flow

1. `scraper-service` fetches and parses prices from eDahab-like pages.
2. Scraper stores snapshots in `ScrapedPrices` and logs in `LogEntries` + `scraper.log`.
3. `main-backend` syncs prices hourly (or on-demand) from scraper `/api/gold-prices`.
4. Main backend stores `GoldPriceCache` and uses it for all calculations.
5. Flutter reads only from `main-backend`.

## Security Model

- Scraper API protected with `x-api-key`.
- Main backend sends `x-api-key` using the same `SCRAPER_API_KEY` value from environment.
- Keep services private behind reverse proxy/VPN in production.
- Firebase service/account files are kept out of git via `.gitignore`.

## Suggested Production Stack

- Runtime: Docker containers for scraper + main backend
- DB: PostgreSQL (replace sqlite for production)
- Jobs: in-app cron or external scheduler (GitHub Actions/CronJob)
- Logs: structured logging + central sink (Loki/ELK/CloudWatch)

## Quick Start

### 1) Scraper service

```bash
cd scraper-service
npm install
npm start
```

### 2) Main backend

```bash
cd main-backend
npm install
npm start
```

### 3) Flutter app

```bash
cd flutter-app
flutter pub get
flutter run
```

### Local backend stack (both services)

```bash
./scripts/dev-up.sh
```

### Firebase files helper

After creating Flutter platform folders, copy Firebase files from repo root to Flutter targets:

```bash
cd flutter-app
flutter create .
cd ..
./scripts/setup-firebase-files.sh
```

## GitHub Repository

Target repository: [ibrahymsa3ed/Gold](https://github.com/ibrahymsa3ed/Gold)

This link currently shows an empty repository, so push your local code after setup.

### Deployment script (single repo)

Monorepo push to one GitHub repository:

```bash
GITHUB_REPO=git@github.com:ibrahymsa3ed/Gold.git \
./scripts/deploy.sh "feat: bootstrap gold architecture"
```

## Documentation Sync Policy

- `ARCHITECTURE.md` and relevant README files are updated with every substantive code/config change.

## Current Phase-2 Status

- Firebase login + backend token verification are wired.
- Flutter dashboard supports member selection, asset CRUD, savings entries, goals with progress, zakat view, and company management.
- UI is polished into tabbed sections for better navigation and readability.
- Flutter codebase is split into `app.dart`, `screens/`, and `services/` for easier maintenance.

## CI/CD Suggestion

- Add GitHub Actions for:
  - Node install + lint/test for scraper and backend
  - Flutter analyze/test/build
  - Optional deploy steps to server/container registry

Starter workflow included at `.github/workflows/ci.yml`.
