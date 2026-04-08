#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building InstaGold APK ==="
cd "$ROOT/flutter-app"
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/InstaGold.apk"
echo "APK ready at $ROOT/InstaGold.apk"

echo ""
echo "=== Uploading to Google Drive ==="
python3 "$SCRIPT_DIR/upload_apk.py"

echo ""
echo "=== Done ==="
