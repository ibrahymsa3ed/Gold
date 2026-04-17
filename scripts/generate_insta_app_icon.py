#!/usr/bin/env python3
"""Generate InstaGold app icon master (1024x1024) and notification silhouette (512x512).

Uses the existing ig_logo_mark.png alpha channel as the shape source,
applies a gold gradient + bevel + shadow on a dark background.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT_W = OUT_H = 1024
BG = (11, 11, 13)  # #0B0B0D
C_HI = (232, 205, 90)   # #E8CD5A
C_MID = (212, 175, 55)   # #D4AF37
C_LO = (184, 150, 46)    # #B8962E

ROOT = Path(__file__).resolve().parents[1]
LOGO_SRC = ROOT / "flutter-app" / "assets" / "icons" / "ig_logo_mark.png"
OUT_MASTER = ROOT / "flutter-app" / "assets" / "icons" / "ig_icon_master.png"
OUT_NOTIF = ROOT / "flutter-app" / "assets" / "icons" / "ig_notification_master.png"


def _gold_gradient(w: int, h: int) -> Image.Image:
    """Create a diagonal gold gradient image."""
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x * 0.38 + y * 0.62) / float(w + h)
            t = max(0.0, min(1.0, t))
            if t < 0.5:
                u = t / 0.5
                r = int(C_HI[0] * (1 - u) + C_MID[0] * u)
                g = int(C_HI[1] * (1 - u) + C_MID[1] * u)
                b = int(C_HI[2] * (1 - u) + C_MID[2] * u)
            else:
                u = (t - 0.5) / 0.5
                r = int(C_MID[0] * (1 - u) + C_LO[0] * u)
                g = int(C_MID[1] * (1 - u) + C_LO[1] * u)
                b = int(C_MID[2] * (1 - u) + C_LO[2] * u)
            px[x, y] = (r, g, b)
    return img


def _extract_mask(target_w: int, target_h: int, fill: float = 0.82) -> Image.Image:
    """Extract the IG shape from the source logo's alpha channel and scale to fill."""
    logo = Image.open(LOGO_SRC).convert("RGBA")
    alpha = logo.split()[3]

    # Remove ghost pixels (alpha 1-20) that form a faint rectangle in the source
    alpha = alpha.point(lambda p: p if p > 20 else 0)

    # Crop to content bounds (non-transparent area)
    bbox = alpha.getbbox()
    if not bbox:
        raise ValueError("Logo has no visible content")
    cropped = alpha.crop(bbox)

    # Scale to fill target canvas
    cw, ch = cropped.size
    target = int(min(target_w, target_h) * fill)
    scale = target / float(max(cw, ch))
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    scaled = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    # Optically center on canvas
    # The iG monogram has visual weight shifted right (the G extends further)
    # and upward, so we nudge the position to compensate
    out = Image.new("L", (target_w, target_h), 0)
    ox = (target_w - nw) // 2
    oy = (target_h - nh) // 2
    out.paste(scaled, (ox, oy))
    return out


def _bevel_tint(base: Image.Image, mask: Image.Image) -> Image.Image:
    """Add subtle bevel/depth to the letter edges."""
    er = mask
    for _ in range(3):
        er = er.filter(ImageFilter.MinFilter(3))
    dl = mask
    for _ in range(3):
        dl = dl.filter(ImageFilter.MaxFilter(3))
    inner = ImageChops.subtract(mask, er)
    outer = ImageChops.subtract(dl, mask)
    hi = Image.new("RGB", mask.size, (250, 235, 170))
    lo = Image.new("RGB", mask.size, (130, 100, 30))
    edge_up = Image.composite(hi, base, inner)
    edge_lo = Image.composite(lo, edge_up, outer)
    return Image.blend(base, edge_lo, 0.25)


def generate_colored_master() -> Image.Image:
    """Generate the colored app icon master and return the mask for reuse."""
    mask = _extract_mask(OUT_W, OUT_H, fill=0.88)

    gold = _gold_gradient(OUT_W, OUT_H)

    # Drop shadow
    shadow = Image.new("L", (OUT_W, OUT_H), 0)
    shadow.paste(mask, (6, 8))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=14))
    shadow_alpha = shadow.point(lambda p: int(p * 0.45))
    base_rgb = Image.new("RGB", (OUT_W, OUT_H), BG)
    shadow_tint = Image.new("RGB", (OUT_W, OUT_H), (4, 4, 5))
    with_shadow = Image.composite(shadow_tint, base_rgb, shadow_alpha)

    # Composite gold letters onto shadowed background
    colored = Image.composite(gold, with_shadow, mask)
    colored = _bevel_tint(colored, mask)

    # Apply a gentle top-left to bottom-right lighting variation on the letters
    light = Image.new("L", (OUT_W, OUT_H), 0)
    lpx = light.load()
    for y in range(OUT_H):
        for x in range(OUT_W):
            # Brighter at top-left, darker at bottom-right
            t = 1.0 - (x * 0.5 + y * 0.5) / float(OUT_W + OUT_H)
            lpx[x, y] = int(t * 40)
    light_rgb = Image.merge("RGB", [light, light, light])
    out_rgb = Image.composite(
        ImageChops.add(colored, light_rgb),
        colored,
        mask,
    )

    OUT_MASTER.parent.mkdir(parents=True, exist_ok=True)
    out_rgb.save(str(OUT_MASTER), format="PNG", optimize=True)
    print(f"Colored master: {OUT_MASTER}")
    return mask


def generate_notification_silhouette(mask_1024: Image.Image):
    """Generate white silhouette for Android notifications (512x512, transparent bg)."""
    mask_512 = mask_1024.resize((512, 512), Image.Resampling.LANCZOS)
    clean = mask_512.point(lambda p: 255 if p > 64 else 0)

    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    white = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    out = Image.composite(white, out, clean)

    OUT_NOTIF.parent.mkdir(parents=True, exist_ok=True)
    out.save(str(OUT_NOTIF), format="PNG", optimize=True)
    print(f"Notification silhouette: {OUT_NOTIF}")


def main():
    if not LOGO_SRC.exists():
        print(f"ERROR: Source logo not found at {LOGO_SRC}")
        return
    mask = generate_colored_master()
    generate_notification_silhouette(mask)


if __name__ == "__main__":
    main()
