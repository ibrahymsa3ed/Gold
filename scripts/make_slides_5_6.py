#!/usr/bin/env python3
"""Generate tutorial slides 5 & 6 matching the rich dark+gold style of slides 1-4."""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
import os, math

def ar(text):
    return get_display(arabic_reshaper.reshape(text))

W, H = 1080, 1920
GOLD = '#D4B254'
GOLD_LIGHT = '#F5D078'
GOLD_DIM = '#8B7635'
BG = '#0D0B08'
TEXT_WHITE = '#E8E0D0'
TEXT_DIM = '#9A8E7A'
OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'flutter-app', 'assets', 'tutorial')

def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def load_font(size):
    for fp in [
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/Library/Fonts/Arial.ttf',
    ]:
        if os.path.exists(fp):
            return ImageFont.truetype(fp, size)
    return ImageFont.load_default()

def load_font_regular(size):
    for fp in [
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/Library/Fonts/Arial.ttf',
    ]:
        if os.path.exists(fp):
            return ImageFont.truetype(fp, size)
    return ImageFont.load_default()

def draw_gold_glow(img, cx, cy, radius=400, intensity=0.5):
    glow = Image.new('RGB', (W, H), BG)
    gd = ImageDraw.Draw(glow)
    for r in range(radius, 0, -2):
        t = r / radius
        rv = int(120 * (1 - t))
        gv = int(90 * (1 - t))
        bv = int(15 * (1 - t))
        bg = hex_rgb(BG)
        gd.ellipse([cx - r, cy - r, cx + r, cy + r],
                    fill=(max(bg[0], rv), max(bg[1], gv), max(bg[2], bv)))
    return Image.blend(img, glow, intensity)

def draw_decorative_border(draw, margin=40, corner=20):
    g = hex_rgb(GOLD_DIM)
    c = (g[0], g[1], g[2], 80)
    for offset in [0, 2]:
        m = margin + offset
        draw.rounded_rectangle(
            [m, m + 120, W - m, H - m - 120],
            radius=corner,
            outline=hex_rgb(GOLD_DIM) if offset == 0 else hex_rgb('#4A3F2A'),
            width=1
        )

def draw_gold_line(draw, y, x1=200, x2=880):
    gold1 = hex_rgb(GOLD_DIM)
    gold2 = hex_rgb(GOLD)
    length = x2 - x1
    for x in range(x1, x2):
        t = abs((x - x1) / length - 0.5) * 2
        r = int(gold2[0] * (1 - t) + gold1[0] * t)
        g = int(gold2[1] * (1 - t) + gold1[1] * t)
        b = int(gold2[2] * (1 - t) + gold1[2] * t)
        a = int(180 * (1 - t))
        draw.point((x, y), fill=(r, g, b))

def draw_icon_grid(draw, cx, cy, size=80):
    """Draw a simple 2x2 grid icon representing dashboard cards."""
    gap = 8
    cell = (size - gap) // 2
    g = hex_rgb(GOLD)
    for row in range(2):
        for col in range(2):
            x = cx - size // 2 + col * (cell + gap)
            y = cy - size // 2 + row * (cell + gap)
            draw.rounded_rectangle([x, y, x + cell, y + cell], radius=6,
                                    outline=g, width=2)
    inner = cell // 3
    x0 = cx - size // 2
    y0 = cy - size // 2
    draw.rounded_rectangle([x0 + 4, y0 + 4, x0 + cell - 4, y0 + cell - 4],
                            radius=3, fill=hex_rgb(GOLD_DIM))

def draw_target_icon(draw, cx, cy, size=80):
    """Draw a simple target/goal icon with rings and checkmark."""
    g = hex_rgb(GOLD)
    gd = hex_rgb(GOLD_DIM)
    for r_frac, color, w in [(1.0, g, 2), (0.7, gd, 2), (0.4, g, 2)]:
        r = int(size * r_frac / 2)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=w)
    ir = size // 8
    draw.ellipse([cx - ir, cy - ir, cx + ir, cy + ir], fill=g)

def make_slide_5():
    """Customize Your Dashboard / خصص لوحة التحكم"""
    img = Image.new('RGB', (W, H), BG)
    img = draw_gold_glow(img, W // 2, 500, radius=500, intensity=0.4)
    draw = ImageDraw.Draw(img)

    draw_decorative_border(draw)

    font_title = load_font(72)
    font_title_ar = load_font(68)
    font_body = load_font_regular(38)
    font_body_ar = load_font_regular(36)
    font_label = load_font(28)
    font_label_ar = load_font_regular(26)

    # Title
    y = 200
    title_en = "Customize Your\nDashboard"
    for i, line in enumerate(title_en.split('\n')):
        bbox = draw.textbbox((0, 0), line, font=font_title)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) // 2, y + i * 85), line, font=font_title, fill=GOLD_LIGHT)
    y += 200

    title_ar = ar("خصص لوحة التحكم")
    bbox = draw.textbbox((0, 0), title_ar, font=font_title_ar)
    tw = bbox[2] - bbox[0]
    draw.text(((W - tw) // 2, y), title_ar, font=font_title_ar, fill=GOLD)
    y += 100

    draw_gold_line(draw, y, 300, 780)
    y += 40

    draw_icon_grid(draw, W // 2, y + 50, size=100)
    y += 160

    steps_en = [
        "Long-press any price card",
        "Drag to your preferred position",
        "Release to save the layout",
    ]
    steps_ar = [
        ar("اضغط مطولاً على أي بطاقة سعر"),
        ar("اسحب إلى الموقع المفضل لديك"),
        ar("اترك البطاقة لحفظ الترتيب"),
    ]

    left_x = 100
    right_x = W - 100
    for i, (en, a) in enumerate(zip(steps_en, steps_ar)):
        step_y = y + i * 130
        num = f"{i + 1}."

        draw.text((left_x, step_y), num, font=font_body, fill=GOLD)
        draw.text((left_x + 50, step_y), en, font=font_body, fill=TEXT_WHITE)

        num_ar = ar(f".{i + 1}")
        bbox_ar = draw.textbbox((0, 0), a, font=font_body_ar)
        tw_ar = bbox_ar[2] - bbox_ar[0]
        bbox_num = draw.textbbox((0, 0), num_ar, font=font_body_ar)
        tw_num = bbox_num[2] - bbox_num[0]
        draw.text((right_x - tw_ar - tw_num - 10, step_y + 50), a, font=font_body_ar, fill=TEXT_WHITE)
        draw.text((right_x - tw_num, step_y + 50), num_ar, font=font_body_ar, fill=GOLD)

        if i < len(steps_en) - 1:
            draw_gold_line(draw, step_y + 110, 150, W - 150)

    y += len(steps_en) * 130 + 60

    tip_en = "Your layout is saved automatically"
    tip_ar = ar("يتم حفظ ترتيبك تلقائياً")
    bbox_en = draw.textbbox((0, 0), tip_en, font=font_label)
    bbox_ar = draw.textbbox((0, 0), tip_ar, font=font_label_ar)
    draw.text(((W - bbox_en[2] + bbox_en[0]) // 2, y), tip_en, font=font_label, fill=TEXT_DIM)
    draw.text(((W - bbox_ar[2] + bbox_ar[0]) // 2, y + 40), tip_ar, font=font_label_ar, fill=TEXT_DIM)

    img.save(os.path.join(OUT_DIR, 'slide_5_dashboard.png'), 'PNG', optimize=True)
    print("Saved slide_5_dashboard.png")


def make_slide_6():
    """Goals & Calculations / الأهداف والحسابات"""
    img = Image.new('RGB', (W, H), BG)
    img = draw_gold_glow(img, W // 2, 500, radius=500, intensity=0.4)
    draw = ImageDraw.Draw(img)

    draw_decorative_border(draw)

    font_title = load_font(72)
    font_title_ar = load_font(68)
    font_body = load_font_regular(38)
    font_body_ar = load_font_regular(36)
    font_label = load_font(28)
    font_label_ar = load_font_regular(26)

    # Title
    y = 200
    title_en = "Goals &\nCalculations"
    for i, line in enumerate(title_en.split('\n')):
        bbox = draw.textbbox((0, 0), line, font=font_title)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) // 2, y + i * 85), line, font=font_title, fill=GOLD_LIGHT)
    y += 200

    title_ar = ar("الأهداف والحسابات")
    bbox = draw.textbbox((0, 0), title_ar, font=font_title_ar)
    tw = bbox[2] - bbox[0]
    draw.text(((W - tw) // 2, y), title_ar, font=font_title_ar, fill=GOLD)
    y += 100

    draw_gold_line(draw, y, 300, 780)
    y += 40

    draw_target_icon(draw, W // 2, y + 50, size=100)
    y += 160

    steps_en = [
        "Set purchase goals",
        "Track savings progress",
        "Gold fee calculator",
    ]
    steps_ar = [
        ar("حدد أهداف الشراء"),
        ar("تتبع تقدم مدخراتك"),
        ar("حاسبة رسوم الذهب"),
    ]

    left_x = 100
    right_x = W - 100
    for i, (en, a) in enumerate(zip(steps_en, steps_ar)):
        step_y = y + i * 130
        num = f"{i + 1}."

        draw.text((left_x, step_y), num, font=font_body, fill=GOLD)
        draw.text((left_x + 50, step_y), en, font=font_body, fill=TEXT_WHITE)

        num_ar = ar(f".{i + 1}")
        bbox_ar = draw.textbbox((0, 0), a, font=font_body_ar)
        tw_ar = bbox_ar[2] - bbox_ar[0]
        bbox_num = draw.textbbox((0, 0), num_ar, font=font_body_ar)
        tw_num = bbox_num[2] - bbox_num[0]
        draw.text((right_x - tw_ar - tw_num - 10, step_y + 50), a, font=font_body_ar, fill=TEXT_WHITE)
        draw.text((right_x - tw_num, step_y + 50), num_ar, font=font_body_ar, fill=GOLD)

        if i < len(steps_en) - 1:
            draw_gold_line(draw, step_y + 110, 150, W - 150)

    y += len(steps_en) * 130 + 60

    # Progress bar mockup
    bar_x = 140
    bar_w = W - 280
    bar_h = 16
    bar_y = y + 20
    draw.rounded_rectangle([bar_x, bar_y, bar_x + bar_w, bar_y + bar_h],
                            radius=8, fill=hex_rgb('#2A2418'))
    fill_w = int(bar_w * 0.65)
    draw.rounded_rectangle([bar_x, bar_y, bar_x + fill_w, bar_y + bar_h],
                            radius=8, fill=hex_rgb(GOLD))

    draw.text((bar_x, bar_y + 25), "65g secured", font=font_label, fill=TEXT_DIM)
    pct = "65%"
    bbox_pct = draw.textbbox((0, 0), pct, font=font_label)
    draw.text((bar_x + bar_w - (bbox_pct[2] - bbox_pct[0]), bar_y + 25), pct,
              font=font_label, fill=GOLD)
    secured_ar = ar("تم تأمين ٦٥ جرام")
    bbox_s = draw.textbbox((0, 0), secured_ar, font=font_label_ar)
    draw.text(((W - bbox_s[2] + bbox_s[0]) // 2, bar_y + 55), secured_ar,
              font=font_label_ar, fill=TEXT_DIM)

    y = bar_y + 110

    tip_en = "Plan, save, and track your gold journey"
    tip_ar = ar("خطط ووفر وتابع رحلتك في الذهب")
    bbox_en = draw.textbbox((0, 0), tip_en, font=font_label)
    bbox_ar = draw.textbbox((0, 0), tip_ar, font=font_label_ar)
    draw.text(((W - bbox_en[2] + bbox_en[0]) // 2, y), tip_en, font=font_label, fill=TEXT_DIM)
    draw.text(((W - bbox_ar[2] + bbox_ar[0]) // 2, y + 40), tip_ar, font=font_label_ar, fill=TEXT_DIM)

    img.save(os.path.join(OUT_DIR, 'slide_6_goals.png'), 'PNG', optimize=True)
    print("Saved slide_6_goals.png")


if __name__ == '__main__':
    make_slide_5()
    make_slide_6()
