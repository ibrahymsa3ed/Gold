#!/usr/bin/env bash
# Build Android App Bundle for Google Play (prod flavor). Upload the .aab from:
#   flutter-app/build/app/outputs/bundle/prodRelease/app-prod-release.aab
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building Play Store bundle (prod flavor) ==="
cd "$ROOT/flutter-app"
flutter build appbundle --release \
  --flavor prod \
  --dart-define=INSTAGOLD_FLAVOR=prod

AAB="$ROOT/flutter-app/build/app/outputs/bundle/prodRelease/app-prod-release.aab"
echo ""
echo "AAB ready at:"
echo "  $AAB"
echo "Upload this file in Google Play Console (Production or testing track)."
