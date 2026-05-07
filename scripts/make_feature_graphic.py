#!/usr/bin/env python3
"""Generate Play Store feature graphic (1024×500) for InstaGold."""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
import os, math


def ar(text):
    """Reshape + BiDi so PIL renders Arabic correctly left-to-right visually."""
    return get_display(arabic_reshaper.reshape(text))

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'play-store-assets')
ICON_SRC = os.path.join(os.path.dirname(__file__), '..', 'ig_app_icon', 'source', 'icon-1024.png')

W, H = 1024, 500

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def make_feature_graphic():
    img = Image.new('RGB', (W, H), '#0a0a0a')
    draw = ImageDraw.Draw(img)

    # Gold radial glow in the top-right quadrant
    glow = Image.new('RGB', (W, H), '#0a0a0a')
    gd = ImageDraw.Draw(glow)
    for r in range(420, 0, -1):
        t = r / 420
        # Fade from gold-brown to transparent dark
        rv = int(180 * (1 - t))
        gv = int(130 * (1 - t))
        bv = int(20 * (1 - t))
        cx, cy = W - 200, 100
        gd.ellipse([cx - r, cy - r, cx + r, cy + r],
                   fill=(max(10, rv), max(10, gv), max(10, bv)))
    img = Image.blend(img, glow, 0.55)
    draw = ImageDraw.Draw(img)

    # Subtle horizontal gold rule
    gold1 = hex_to_rgb('#C9973A')
    gold2 = hex_to_rgb('#F5D078')
    for x in range(W):
        t = x / W
        r2 = int(gold1[0] * (1-t) + gold2[0] * t)
        g2 = int(gold1[1] * (1-t) + gold2[1] * t)
        b2 = int(gold1[2] * (1-t) + gold2[2] * t)
        draw.line([(x, H//2 + 2), (x, H//2 + 4)], fill=(r2, g2, b2))

    # Load and place app icon (right half, centered vertically)
    icon = Image.open(ICON_SRC).convert('RGBA')
    icon_size = 320
    icon = icon.resize((icon_size, icon_size), Image.LANCZOS)

    icon_x = W - icon_size - 80
    icon_y = (H - icon_size) // 2

    # Soft shadow behind icon
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([icon_x + 20, icon_y + 20, icon_x + icon_size - 20, icon_y + icon_size - 20],
               fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    img.paste(shadow.convert('RGB'), mask=shadow.split()[3])

    img.paste(icon, (icon_x, icon_y), icon)

    # Text on the left side
    # Try to load a system Arabic/sans font; fallback to default
    font_path_candidates = [
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Helvetica.ttc',
        '/Library/Fonts/Arial.ttf',
    ]
    font_large = None
    font_small = None
    for fp in font_path_candidates:
        if os.path.exists(fp):
            try:
                font_large = ImageFont.truetype(fp, 72)
                font_medium = ImageFont.truetype(fp, 40)
                font_small = ImageFont.truetype(fp, 28)
                break
            except Exception:
                pass
    if font_large is None:
        font_large = ImageFont.load_default()
        font_medium = font_large
        font_small = font_large

    # App name
    text_x = 64
    name_y = 140
    draw.text((text_x, name_y), 'InstaGold', font=font_large, fill='#F5D078')

    # Gold divider line
    draw.line([(text_x, name_y + 90), (text_x + 320, name_y + 90)],
              fill='#C9973A', width=2)

    # Tagline English
    draw.text((text_x, name_y + 108), 'Live Gold Prices · Egypt', font=font_medium, fill='#CCCCCC')

    # Tagline Arabic (reshaped for proper RTL rendering)
    draw.text((text_x, name_y + 160), ar('أسعار الذهب اللحظية'), font=font_medium, fill='#AAAAAA')

    # Feature bullets (ASCII-safe stars)
    bullets = ['*  21K . 24K . 18K . 14K', '*  Gold Ounce . Gold Pound', '*  Savings & Goals Tracker']
    for i, b in enumerate(bullets):
        draw.text((text_x, name_y + 220 + i * 36), b, font=font_small, fill='#999999')

    img = img.convert('RGB')
    out_path = os.path.join(OUT_DIR, 'feature-graphic-1024x500.png')
    img.save(out_path, 'PNG', optimize=True)
    print(f'Saved feature graphic: {out_path} ({W}x{H})')

if __name__ == '__main__':
    make_feature_graphic()
