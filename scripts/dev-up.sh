#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cleanup() {
  if [[ -n "${SCRAPER_PID:-}" ]]; then kill "${SCRAPER_PID}" >/dev/null 2>&1 || true; fi
  if [[ -n "${BACKEND_PID:-}" ]]; then kill "${BACKEND_PID}" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT INT TERM

cd "${ROOT_DIR}/scraper-service"
npm start &
SCRAPER_PID=$!

cd "${ROOT_DIR}/main-backend"
npm start &
BACKEND_PID=$!

echo "Scraper PID: ${SCRAPER_PID}"
echo "Backend PID: ${BACKEND_PID}"
echo "Both services are running. Press Ctrl+C to stop."

wait
