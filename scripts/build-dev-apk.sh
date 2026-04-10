#!/usr/bin/env bash
# Build internal/testing APK → repo root InstaGold-dev.apk (dev flavor, test ads).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building InstaGold-dev.apk (flavor dev) ==="
cd "$ROOT/flutter-app"
flutter build apk --release \
  --flavor dev \
  --dart-define=INSTAGOLD_FLAVOR=dev

cp build/app/outputs/flutter-apk/app-dev-release.apk "$ROOT/InstaGold-dev.apk"
echo "APK ready at $ROOT/InstaGold-dev.apk"
