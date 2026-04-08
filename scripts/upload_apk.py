#!/usr/bin/env python3
"""Upload InstaGold.apk to Google Drive using rclone.

Requires rclone with a 'gdrive:' remote configured.
Uploads to 'gdrive:InstaGold Releases/InstaGold.apk'.

Usage:
    python3 scripts/upload_apk.py                # upload existing APK
    python3 scripts/upload_apk.py --build         # build first, then upload
"""

import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APK_PATH = os.path.join(ROOT, "InstaGold.apk")
DRIVE_FOLDER = "gdrive:InstaGold Releases"
DRIVE_DEST = f"{DRIVE_FOLDER}/InstaGold.apk"


def build_apk():
    flutter_dir = os.path.join(ROOT, "flutter-app")
    print("=== Building release APK ===")
    result = subprocess.run(
        ["flutter", "build", "apk", "--release"],
        cwd=flutter_dir,
    )
    if result.returncode != 0:
        sys.exit(1)
    src = os.path.join(flutter_dir, "build", "app", "outputs", "flutter-apk", "app-release.apk")
    subprocess.run(["cp", src, APK_PATH])
    print(f"APK ready at {APK_PATH}")


def upload_apk():
    size_mb = os.path.getsize(APK_PATH) / (1024 * 1024)
    print(f"\n=== Uploading InstaGold.apk ({size_mb:.1f} MB) to Google Drive ===")

    result = subprocess.run(
        ["rclone", "mkdir", DRIVE_FOLDER],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"ERROR creating folder: {result.stderr}")
        sys.exit(1)

    result = subprocess.run(
        ["rclone", "copyto", APK_PATH, DRIVE_DEST, "--progress"],
    )
    if result.returncode != 0:
        print("ERROR: Upload failed")
        sys.exit(1)

    result = subprocess.run(
        ["rclone", "link", DRIVE_DEST],
        capture_output=True, text=True,
    )
    link = result.stdout.strip() if result.returncode == 0 else "(link generation not supported by remote)"

    print(f"\nUploaded successfully!")
    print(f"Location: {DRIVE_DEST}")
    print(f"Link:     {link}")


def main():
    parser = argparse.ArgumentParser(description="Upload InstaGold APK to Google Drive")
    parser.add_argument("--build", action="store_true", help="Build APK before uploading")
    args = parser.parse_args()

    if args.build:
        build_apk()

    if not os.path.exists(APK_PATH):
        print(f"ERROR: {APK_PATH} not found. Build first with --build flag.")
        sys.exit(1)

    upload_apk()


if __name__ == "__main__":
    main()
