#!/usr/bin/env bash
# Build final Android prod artifacts and copy the latest outputs to repo root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building InstaGold prod release APK ==="
cd "$ROOT/flutter-app"
flutter build apk --release \
  --flavor prod \
  --dart-define=INSTAGOLD_FLAVOR=prod

cp build/app/outputs/flutter-apk/app-prod-release.apk "$ROOT/InstaGold.apk"
echo "APK copied to $ROOT/InstaGold.apk"

echo ""
echo "=== Building InstaGold prod release AAB ==="
flutter build appbundle --release \
  --flavor prod \
  --dart-define=INSTAGOLD_FLAVOR=prod

cp build/app/outputs/bundle/prodRelease/app-prod-release.aab "$ROOT/InstaGold.aab"
echo "AAB copied to $ROOT/InstaGold.aab"

echo ""
echo "=== Done ==="
