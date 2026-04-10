#!/usr/bin/env bash
# Print SHA-1 and SHA-256 for Firebase "SHA certificate fingerprints".
# Usage: ./scripts/print-release-signing-fingerprints.sh <path-to-keystore> <alias>
# Example: ./scripts/print-release-signing-fingerprints.sh flutter-app/android/upload-keystore.jks upload
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <path-to-keystore.jks> <key-alias>"
  echo ""
  echo "Example from repo root:"
  echo "  $0 flutter-app/android/upload-keystore.jks upload"
  echo ""
  echo "You will be prompted for the keystore password."
  exit 1
fi

KEYSTORE="$1"
ALIAS="$2"

if [[ ! -f "$KEYSTORE" ]]; then
  echo "ERROR: Keystore not found: $KEYSTORE"
  echo "If you are not at repo root, use an absolute path or path relative to your cwd."
  exit 1
fi

echo "=== Keystore: $KEYSTORE  alias: $ALIAS ==="
echo "Paste SHA1 and SHA256 into Firebase Console → Project settings → Your Android app."
echo ""

keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS"
