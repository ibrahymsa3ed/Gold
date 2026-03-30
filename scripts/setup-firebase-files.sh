#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${ROOT_DIR}/flutter-app"

ANDROID_TARGET="${FLUTTER_DIR}/android/app/google-services.json"
IOS_TARGET="${FLUTTER_DIR}/ios/Runner/GoogleService-Info.plist"

ANDROID_SOURCE="${ROOT_DIR}/google-services.json"
IOS_SOURCE="${ROOT_DIR}/GoogleService-Info.plist"

echo "Preparing Firebase files for Flutter app..."

if [[ ! -d "${FLUTTER_DIR}" ]]; then
  echo "ERROR: flutter-app folder not found at ${FLUTTER_DIR}"
  exit 1
fi

if [[ ! -f "${ANDROID_SOURCE}" ]]; then
  echo "ERROR: Missing source file ${ANDROID_SOURCE}"
  exit 1
fi

if [[ ! -f "${IOS_SOURCE}" ]]; then
  echo "ERROR: Missing source file ${IOS_SOURCE}"
  exit 1
fi

if [[ ! -d "${FLUTTER_DIR}/android/app" || ! -d "${FLUTTER_DIR}/ios/Runner" ]]; then
  echo "ERROR: Flutter platform folders not found."
  echo "Run this first:"
  echo "  cd \"${FLUTTER_DIR}\" && flutter create ."
  exit 1
fi

cp "${ANDROID_SOURCE}" "${ANDROID_TARGET}"
cp "${IOS_SOURCE}" "${IOS_TARGET}"

echo "Copied:"
echo "  ${ANDROID_SOURCE} -> ${ANDROID_TARGET}"
echo "  ${IOS_SOURCE} -> ${IOS_TARGET}"
echo "Done."
