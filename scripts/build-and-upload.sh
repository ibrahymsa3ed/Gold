#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building InstaGold.apk (flavor prod, Play-ready when signed) ==="
cd "$ROOT/flutter-app"
flutter build apk --release \
  --flavor prod \
  --dart-define=INSTAGOLD_FLAVOR=prod
cp build/app/outputs/flutter-apk/app-prod-release.apk "$ROOT/InstaGold.apk"
echo "APK ready at $ROOT/InstaGold.apk"

echo ""
echo "=== Uploading to Google Drive ==="
python3 "$SCRIPT_DIR/upload_apk.py"

echo ""
echo "=== Done ==="
