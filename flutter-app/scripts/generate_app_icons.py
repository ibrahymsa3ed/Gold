#!/usr/bin/env python3
"""Derive all platform-specific icon assets from the two master PNGs.

Inputs (must already exist):
  assets/icons/ig_icon_master.png        — 1024x1024, colored, dark bg
  assets/icons/ig_notification_master.png — 512x512, white on transparent

Outputs:
  assets/icons/ig_icon_ios.png            — 1024x1024 RGB for iOS (no alpha)
  assets/icons/ig_icon_foreground.png     — 1024x1024 RGBA for Android adaptive
  android/app/src/main/res/drawable-mdpi/ic_stat_notification.png    — 24x24
  android/app/src/main/res/drawable-hdpi/ic_stat_notification.png    — 36x36
  android/app/src/main/res/drawable-xhdpi/ic_stat_notification.png   — 48x48
  android/app/src/main/res/drawable-xxhdpi/ic_stat_notification.png  — 72x72
  android/app/src/main/res/drawable-xxxhdpi/ic_stat_notification.png — 96x96
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]  # flutter-app/
ICONS = ROOT / "assets" / "icons"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

MASTER_COLOR = ICONS / "ig_icon_master.png"
MASTER_NOTIF = ICONS / "ig_notification_master.png"

BG = (11, 11, 13)

NOTIF_DENSITIES = {
    "drawable-mdpi": 24,
    "drawable-hdpi": 36,
    "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72,
    "drawable-xxxhdpi": 96,
}


def generate_ios_icon():
    """iOS app icon: 1024x1024 RGB, no alpha channel."""
    img = Image.open(MASTER_COLOR).convert("RGB")
    out = ICONS / "ig_icon_ios.png"
    img.save(str(out), format="PNG", optimize=True)
    print(f"  iOS icon: {out}")


def generate_android_foreground():
    """Android adaptive icon foreground: extract logo from master onto transparent bg."""
    master = Image.open(MASTER_COLOR).convert("RGBA")

    # Extract the logo from the dark background
    # Pixels that differ significantly from BG are part of the logo
    r, g, b, a = master.split()
    out_img = Image.new("RGBA", master.size, (0, 0, 0, 0))

    px_master = master.load()
    px_out = out_img.load()
    w, h = master.size

    for y in range(h):
        for x in range(w):
            cr, cg, cb, ca = px_master[x, y]
            dr = abs(cr - BG[0])
            dg = abs(cg - BG[1])
            db = abs(cb - BG[2])
            dist = dr + dg + db
            if dist > 30:
                alpha = min(255, int(dist * 3))
                px_out[x, y] = (cr, cg, cb, alpha)

    out = ICONS / "ig_icon_foreground.png"
    out_img.save(str(out), format="PNG", optimize=True)
    print(f"  Android foreground: {out}")


def generate_notification_icons():
    """Generate white notification silhouette at all Android density sizes."""
    src = Image.open(MASTER_NOTIF).convert("RGBA")

    for density, size in NOTIF_DENSITIES.items():
        folder = RES / density
        folder.mkdir(parents=True, exist_ok=True)
        resized = src.resize((size, size), Image.Resampling.LANCZOS)
        out = folder / "ic_stat_notification.png"
        resized.save(str(out), format="PNG", optimize=True)
        print(f"  {density}: {out}")


def main():
    for f in (MASTER_COLOR, MASTER_NOTIF):
        if not f.exists():
            print(f"ERROR: Master not found: {f}")
            return

    print("Generating platform icons from masters...")
    generate_ios_icon()
    generate_android_foreground()
    generate_notification_icons()
    print("\nDone. Next steps:")
    print("  1. Run: flutter pub run flutter_launcher_icons")
    print("  2. Lock android:inset='0%' in ic_launcher.xml")


if __name__ == "__main__":
    main()
