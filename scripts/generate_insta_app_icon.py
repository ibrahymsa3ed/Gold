#!/usr/bin/env python3
"""Process the new ChatGPT-generated IG icon into all required master assets.

Reads the source screenshot, extracts the rounded-square icon region,
produces:
  1. ig_icon_master.png   — 1024x1024 RGB (full icon with dark bg)
  2. ig_logo_mark.png     — 1024x1024 RGBA (gold letters on transparent bg)
  3. ig_notification_master.png — 512x512 RGBA (white silhouette on transparent)
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".cursor" / "projects" / "Users-ibrahym-Documents-PETLAB-Gold" / "assets" / "Screenshot_2026-04-17_at_16.34.25-096cd05c-359f-4717-bb43-69f6b52ccaba.png"

# Alternative: check workspace assets folder
if not SOURCE.exists():
    SOURCE = Path("/Users/ibrahym/.cursor/projects/Users-ibrahym-Documents-PETLAB-Gold/assets/Screenshot_2026-04-17_at_16.34.25-096cd05c-359f-4717-bb43-69f6b52ccaba.png")

ICONS = ROOT / "flutter-app" / "assets" / "icons"
OUT_MASTER = ICONS / "ig_icon_master.png"
OUT_LOGO = ICONS / "ig_logo_mark.png"
OUT_NOTIF = ICONS / "ig_notification_master.png"

# The outer background color of the screenshot (outside the rounded square)
OUTER_BG = np.array([22, 19, 18])


def _find_icon_region(img: Image.Image) -> tuple[int, int, int, int]:
    """Find the bounding box of the rounded-square icon within the screenshot.
    
    Strategy: the icon interior is either darker or has gold colors,
    while the outer area is a uniform ~(22,19,18). Find where the content
    differs significantly from the outer bg.
    """
    arr = np.array(img.convert("RGB"))
    h, w, _ = arr.shape

    diff = np.abs(arr.astype(int) - OUTER_BG.astype(int)).sum(axis=2)
    # Threshold: pixels that differ from outer bg by more than 15 total
    mask = diff > 15

    rows_any = np.any(mask, axis=1)
    cols_any = np.any(mask, axis=0)

    y_indices = np.where(rows_any)[0]
    x_indices = np.where(cols_any)[0]

    if len(y_indices) == 0 or len(x_indices) == 0:
        raise ValueError("Could not find icon region")

    top = int(y_indices[0])
    bottom = int(y_indices[-1])
    left = int(x_indices[0])
    right = int(x_indices[-1])

    return (left, top, right + 1, bottom + 1)


def _extract_logo_transparent(icon_1024: Image.Image) -> Image.Image:
    """Extract the gold IG monogram from the icon, removing the dark bg.
    
    The icon has a subtle gradient dark background (brightness 30-110).
    Gold letter pixels have brightness > 200 AND strong warmth (R-B > 30).
    Diamond sparkle pixels are very bright (> 500) regardless of warmth.
    """
    arr = np.array(icon_1024.convert("RGB")).astype(float)
    h, w, _ = arr.shape

    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    brightness = r + g + b   # max 765
    warmth = r - b            # gold has high warmth

    alpha = np.zeros((h, w), dtype=float)

    # Core gold: bright and warm
    core_gold = (brightness > 200) & (warmth > 30)
    alpha[core_gold] = 255.0

    # Soft gold edges: moderate brightness with some warmth — anti-aliased edges
    soft_gold = (brightness > 140) & (warmth > 15) & ~core_gold
    soft_alpha = np.clip((brightness - 140) / 60.0 * 255.0, 0, 255)
    alpha[soft_gold] = soft_alpha[soft_gold]

    # Diamond sparkle: very bright, any warmth (white/near-white highlights)
    sparkle = (brightness > 500)
    alpha[sparkle] = 255.0

    # Soft sparkle halo
    sparkle_soft = (brightness > 350) & ~sparkle & ~core_gold & ~soft_gold
    sparkle_alpha = np.clip((brightness - 350) / 150.0 * 255.0, 0, 200)
    alpha[sparkle_soft] = np.maximum(alpha[sparkle_soft], sparkle_alpha[sparkle_soft])

    alpha = alpha.astype(np.uint8)

    rgb = icon_1024.convert("RGB")
    out = Image.merge("RGBA", (*rgb.split(), Image.fromarray(alpha)))

    return out


def _generate_notification_silhouette(logo: Image.Image) -> Image.Image:
    """Create a white silhouette from the transparent logo for notifications."""
    alpha = np.array(logo.split()[3])
    # Clean threshold for crisp silhouette
    clean = (alpha > 64).astype(np.uint8) * 255

    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Resize alpha to 512
    alpha_img = Image.fromarray(clean).resize((512, 512), Image.Resampling.LANCZOS)
    alpha_final = np.array(alpha_img)
    alpha_final = (alpha_final > 128).astype(np.uint8) * 255

    white = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    mask = Image.fromarray(alpha_final)
    out = Image.composite(white, out, mask)
    return out


def main():
    if not SOURCE.exists():
        print(f"ERROR: Source image not found at {SOURCE}")
        return

    print(f"Source: {SOURCE}")
    src = Image.open(SOURCE)
    print(f"  Size: {src.size}, Mode: {src.mode}")

    # Step 1: Find and crop the icon region
    bbox = _find_icon_region(src)
    print(f"  Icon region: {bbox}")
    icon_crop = src.crop(bbox).convert("RGB")
    print(f"  Cropped: {icon_crop.size}")

    # Make it square (take the larger dimension)
    cw, ch = icon_crop.size
    sq = max(cw, ch)
    square = Image.new("RGB", (sq, sq), (11, 11, 13))
    ox = (sq - cw) // 2
    oy = (sq - ch) // 2
    square.paste(icon_crop, (ox, oy))

    # Resize to 1024x1024
    icon_1024 = square.resize((1024, 1024), Image.Resampling.LANCZOS)

    ICONS.mkdir(parents=True, exist_ok=True)
    icon_1024.save(str(OUT_MASTER), format="PNG", optimize=True)
    print(f"  Master icon: {OUT_MASTER}")

    # Step 2: Extract transparent logo
    logo = _extract_logo_transparent(icon_1024)
    logo.save(str(OUT_LOGO), format="PNG", optimize=True)
    print(f"  Logo mark: {OUT_LOGO}")

    # Step 3: Generate notification silhouette
    notif = _generate_notification_silhouette(logo)
    notif.save(str(OUT_NOTIF), format="PNG", optimize=True)
    print(f"  Notification: {OUT_NOTIF}")

    print("\nDone! Next: run flutter-app/scripts/generate_app_icons.py")


if __name__ == "__main__":
    main()
