#!/usr/bin/env python3
"""InstaGold onboarding tutorial mockups — 4 slides, bilingual split layout."""

from PIL import Image, ImageDraw, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'tutorial-mockups')
ICON_SRC = os.path.join(os.path.dirname(__file__), '..', 'ig_app_icon', 'source', 'icon-1024.png')
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 1080, 2200

BG       = (11,  11,  13)
SURFACE  = (26,  25,  30)
SURFACE2 = (38,  36,  44)
GOLD1    = (212, 175,  55)
GOLD2    = (180, 148,  40)
GOLD_L   = (235, 208,  95)
GOLD_DIM = (120,  95,  25)
WHITE    = (255, 255, 255)
GREY     = (165, 165, 172)
GREY2    = ( 90,  90,  98)
GREEN    = ( 72, 199, 130)
RED      = (220,  75,  75)

FONT_PATHS = [
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
]

def _font(size):
    for fp in FONT_PATHS:
        if os.path.exists(fp):
            try: return ImageFont.truetype(fp, size)
            except: pass
    return ImageFont.load_default()

def ar(t):
    return get_display(arabic_reshaper.reshape(t))

def tc(draw, y, text, font, color, x0=0, x1=W):
    bb = draw.textbbox((0,0), text, font=font)
    x = x0 + (x1 - x0 - (bb[2]-bb[0])) // 2
    draw.text((x, y), text, font=font, fill=color)

def rr(draw, xy, r, fill):
    draw.rounded_rectangle(xy, radius=r, fill=fill)

TOTAL = 4

def base():
    img = Image.new('RGB', (W, H), BG)
    draw = ImageDraw.Draw(img)
    return img, draw

def draw_chrome(draw, idx):
    # Skip
    draw.text((54, 70), ar('تخطي'), font=_font(30), fill=GREY2)
    # Next / Start
    if idx < TOTAL - 1:
        nt = 'Next'
        nb = draw.textbbox((0,0), nt, font=_font(30))
        draw.text((W-54-(nb[2]-nb[0]), 70), nt, font=_font(30), fill=GOLD1)
    else:
        rr(draw, [W//2-200, H-190, W//2+200, H-120], 50, GOLD1)
        bt = ar('ابدأ')
        bb2 = draw.textbbox((0,0), bt, font=_font(38))
        draw.text(((W-(bb2[2]-bb2[0]))//2, H-178), bt, font=_font(38), fill=BG)

    # Dots
    r=9; gap=28; cy=H-100
    start = W//2 - (TOTAL-1)*gap//2
    for i in range(TOTAL):
        x = start + i*gap
        if i == idx:
            rr(draw, [x-r, cy-r//2, x+r*2, cy+r//2], 6, GOLD1)
        else:
            draw.ellipse([x-r//2, cy-r//2, x+r//2, cy+r//2], fill=GREY2)

def divider_v(draw, top, bottom):
    """Vertical gold divider in the center."""
    for y in range(top, bottom):
        t = (y - top) / (bottom - top)
        r = int(GOLD2[0]*(1-t)+GOLD1[0]*t)
        g = int(GOLD2[1]*(1-t)+GOLD1[1]*t)
        b = int(GOLD2[2]*(1-t)+GOLD1[2]*t)
        draw.line([(W//2-1, y), (W//2+1, y)], fill=(r, g, b))

def gold_h_line(draw, y):
    for x in range(60, W-60):
        t = (x-60)/(W-120)
        r = int(GOLD2[0]*(1-t)+GOLD1[0]*t)
        g = int(GOLD2[1]*(1-t)+GOLD1[1]*t)
        b = int(GOLD2[2]*(1-t)+GOLD1[2]*t)
        draw.point((x, y), fill=(r, g, b))

def split_header(draw, ar_title, en_title, y=155):
    """Bold title on each half."""
    tc(draw, y, ar(ar_title), _font(50), GOLD1, x0=W//2, x1=W)
    tc(draw, y, en_title,     _font(50), GOLD1, x0=0,    x1=W//2)

def bullet(draw, x, y, text, font, color=WHITE, rtl=False):
    """Single bullet line."""
    if rtl:
        bb = draw.textbbox((0,0), text, font=font)
        tw = bb[2]-bb[0]
        dot_x = x - 18
        draw.ellipse([dot_x-5, y+9, dot_x+5, y+19], fill=GOLD1)
        draw.text((x - tw - 28, y), text, font=font, fill=color)
    else:
        draw.ellipse([x, y+9, x+10, y+19], fill=GOLD1)
        draw.text((x+20, y), text, font=font, fill=color)

def half_label(draw, text_ar, text_en, y):
    """Small section label on each half."""
    tc(draw, y, ar(text_ar), _font(26), GOLD_DIM, x0=W//2, x1=W)
    tc(draw, y, text_en,     _font(26), GOLD_DIM, x0=0,    x1=W//2)

# ── SLIDE 0 — App overview ───────────────────────────────────────────────────
def slide_00():
    img, draw = base()

    # Logo top center
    icon = Image.open(ICON_SRC).convert('RGBA').resize((180, 180), Image.LANCZOS)
    img.paste(icon, (W//2-90, 130), icon)

    gold_h_line(draw, 340)

    # Title
    tc(draw, 360, 'InstaGold', _font(72), GOLD1)
    gold_h_line(draw, 445)

    divider_v(draw, 460, H-200)

    # Arabic half (right)
    ar_lines = [
        (ar('تطبيق متابعة أسعار الذهب'),    _font(34), WHITE),
        (ar('في مصر'),                       _font(34), WHITE),
        ('',                                 _font(20), WHITE),
        (ar('• أسعار عيار 21 · 24 · 18 · 14'), _font(28), GREY),
        (ar('• الأونصة العالمية والجنيه الذهبي'),_font(28), GREY),
        ('',                                 _font(20), WHITE),
        (ar('• سجّل قطعك الذهبية'),          _font(28), GREY),
        (ar('• تابع قيمتها لحظياً'),         _font(28), GREY),
        ('',                                 _font(20), WHITE),
        (ar('• حاسبة المصنعية والضرائب'),   _font(28), GREY),
        (ar('• تنبيهات عند تحرك السعر'),    _font(28), GREY),
        ('',                                 _font(20), WHITE),
        (ar('• ويدجيت الشاشة الرئيسية'),    _font(28), GREY),
    ]
    cy = 490
    for text, font, color in ar_lines:
        if text:
            bb = draw.textbbox((0,0), text, font=font)
            tw = bb[2]-bb[0]
            draw.text((W-60-tw, cy), text, font=font, fill=color)
        cy += font.size + 8

    # English half (left)
    en_lines = [
        ('Gold price tracker',   _font(34), WHITE),
        ('for Egypt',            _font(34), WHITE),
        ('',                     _font(20), WHITE),
        ('• 21K · 24K · 18K · 14K', _font(28), GREY),
        ('• Ounce & Gold Pound', _font(28), GREY),
        ('',                     _font(20), WHITE),
        ('• Log your gold items',_font(28), GREY),
        ('• Track value live',   _font(28), GREY),
        ('',                     _font(20), WHITE),
        ('• Manufacturing calc', _font(28), GREY),
        ('• Price-move alerts',  _font(28), GREY),
        ('',                     _font(20), WHITE),
        ('• Home screen widget', _font(28), GREY),
    ]
    cy = 490
    for text, font, color in en_lines:
        if text:
            draw.text((60, cy), text, font=font, fill=color)
        cy += font.size + 8

    draw_chrome(draw, 0)
    return img

# ── SLIDE 1 — How to add assets ─────────────────────────────────────────────
def slide_01():
    img, draw = base()
    gold_h_line(draw, 145)
    split_header(draw, 'إضافة قطعة ذهبية', 'Add Gold Asset', y=80)
    gold_h_line(draw, 145)
    divider_v(draw, 155, H-200)

    # Shared visual mockup — mini card in the middle top
    card_y = 170; card_h = 320
    rr(draw, [80, card_y, W-80, card_y+card_h], 20, SURFACE)

    # Simulate the add asset form
    draw.text((W-110, card_y+18), ar('ذهبي'), font=_font(28), fill=GOLD1)
    draw.text((100, card_y+18), 'My Gold', font=_font(28), fill=GOLD1)
    gold_h_line(draw, card_y+58)

    rows = [
        (ar('النوع'),    'Type',    ar('خاتم ▾'),  'Ring ▾'),
        (ar('العيار'),   'Karat',   ar('عيار 21 ▾'),'21K ▾'),
        (ar('الوزن'),    'Weight',  '8.5 g',       '8.5 g'),
    ]
    ry = card_y+75
    for ar_l, en_l, ar_v, en_v in rows:
        rr(draw, [100, ry, W//2-20, ry+52], 10, SURFACE2)
        rr(draw, [W//2+20, ry, W-100, ry+52], 10, SURFACE2)
        # values
        draw.text((W//2+30, ry+12), en_v, font=_font(28), fill=WHITE)
        bb = draw.textbbox((0,0), ar_v, font=_font(28))
        draw.text((W-110-(bb[2]-bb[0]), ry+12), ar_v, font=_font(28), fill=WHITE)
        ry += 72

    # Save button
    rr(draw, [120, card_y+card_h-68, W-120, card_y+card_h-18], 28, GOLD1)
    bt = ar('حفظ  /  Save')
    bb2 = draw.textbbox((0,0), bt, font=_font(28))
    draw.text(((W-(bb2[2]-bb2[0]))//2, card_y+card_h-58), bt, font=_font(28), fill=BG)

    # Steps — Arabic (right half)
    ar_steps = [
        ar('اضغط تبويب "ذهبي"'),
        ar('ثم زر + أعلى اليسار'),
        ar('اختر نوع القطعة'),
        ar('أدخل العيار والوزن'),
        ar('اضغط حفظ'),
    ]
    sy = card_y + card_h + 40
    for i, s in enumerate(ar_steps):
        rr(draw, [W//2+20, sy, W-60, sy+56], 14, SURFACE)
        num = str(i+1)
        draw.ellipse([W//2+30, sy+12, W//2+56, sy+40], fill=GOLD1)
        draw.text((W//2+36, sy+12), num, font=_font(22), fill=BG)
        bb = draw.textbbox((0,0), s, font=_font(26))
        draw.text((W-70-(bb[2]-bb[0]), sy+14), s, font=_font(26), fill=WHITE)
        sy += 72

    # Steps — English (left half)
    en_steps = [
        'Tap "My Gold" tab',
        'Tap + (top left)',
        'Choose item type',
        'Enter karat & weight',
        'Tap Save',
    ]
    sy = card_y + card_h + 40
    for i, s in enumerate(en_steps):
        rr(draw, [60, sy, W//2-20, sy+56], 14, SURFACE)
        draw.ellipse([68, sy+12, 94, sy+40], fill=GOLD1)
        draw.text((74, sy+12), str(i+1), font=_font(22), fill=BG)
        draw.text((104, sy+14), s, font=_font(26), fill=WHITE)
        sy += 72

    draw_chrome(draw, 1)
    return img

# ── SLIDE 2 — How to add alerts ─────────────────────────────────────────────
def slide_02():
    img, draw = base()
    gold_h_line(draw, 145)
    split_header(draw, 'إضافة تنبيه سعر', 'Add Price Alert', y=80)
    gold_h_line(draw, 145)
    divider_v(draw, 155, H-200)

    # Mockup card — alert creation form
    card_y = 170; card_h = 330
    rr(draw, [80, card_y, W-80, card_y+card_h], 20, SURFACE)

    # Header row
    draw.text((W-110, card_y+18), ar('تنبيهات الأسعار'), font=_font(28), fill=GOLD1)
    draw.text((100, card_y+18), 'Price Alerts', font=_font(28), fill=GOLD1)
    gold_h_line(draw, card_y+60)

    # Alert row — green
    rr(draw, [100, card_y+76, W-100, card_y+76+100], 14, SURFACE2)
    draw.rectangle([100, card_y+76, 110, card_y+176], fill=GREEN)
    draw.text((120, card_y+84), ar('عيار 21'), font=_font(26), fill=WHITE)
    draw.text((120, card_y+116), '7,000 EGP', font=_font(38), fill=GREEN)
    ub = draw.textbbox((0,0), ar('فوق السعر الحالي'), font=_font(22))
    draw.text((W-110-(ub[2]-ub[0]), card_y+84), ar('فوق السعر الحالي'), font=_font(22), fill=GREY)

    # Alert row — red
    rr(draw, [100, card_y+190, W-100, card_y+190+100], 14, SURFACE2)
    draw.rectangle([100, card_y+190, 110, card_y+290], fill=RED)
    draw.text((120, card_y+198), ar('عيار 24'), font=_font(26), fill=WHITE)
    draw.text((120, card_y+230), '7,500 EGP', font=_font(38), fill=RED)
    db = draw.textbbox((0,0), ar('تحت السعر الحالي'), font=_font(22))
    draw.text((W-110-(db[2]-db[0]), card_y+198), ar('تحت السعر الحالي'), font=_font(22), fill=GREY)

    # Add button
    rr(draw, [120, card_y+card_h-68, W-120, card_y+card_h-18], 28, GOLD1)
    bt = ar('+ تنبيه جديد  /  New Alert')
    bb2 = draw.textbbox((0,0), bt, font=_font(26))
    draw.text(((W-(bb2[2]-bb2[0]))//2, card_y+card_h-56), bt, font=_font(26), fill=BG)

    # Steps — Arabic (right)
    ar_steps = [
        ar('اضغط أيقونة الجرس 🔔'),
        ar('اضغط "تنبيه جديد"'),
        ar('اختر العيار'),
        ar('اختر فوق أو تحت السعر'),
        ar('أدخل السعر المستهدف'),
        ar('احفظ وستصلك إشعار فوراً'),
    ]
    sy = card_y + card_h + 36
    for i, s in enumerate(ar_steps):
        rr(draw, [W//2+20, sy, W-60, sy+52], 14, SURFACE)
        draw.ellipse([W//2+30, sy+10, W//2+54, sy+36], fill=GOLD1)
        draw.text((W//2+36, sy+10), str(i+1), font=_font(20), fill=BG)
        bb = draw.textbbox((0,0), s, font=_font(24))
        draw.text((W-68-(bb[2]-bb[0]), sy+12), s, font=_font(24), fill=WHITE)
        sy += 64

    # Steps — English (left)
    en_steps = [
        'Tap the bell icon',
        'Tap "New Alert"',
        'Choose karat',
        'Pick above / below',
        'Enter target price',
        'Save — get notified!',
    ]
    sy = card_y + card_h + 36
    for i, s in enumerate(en_steps):
        rr(draw, [60, sy, W//2-20, sy+52], 14, SURFACE)
        draw.ellipse([68, sy+10, 92, sy+36], fill=GOLD1)
        draw.text((74, sy+10), str(i+1), font=_font(20), fill=BG)
        draw.text((102, sy+12), s, font=_font(24), fill=WHITE)
        sy += 64

    draw_chrome(draw, 2)
    return img

# ── SLIDE 3 — How to add members ────────────────────────────────────────────
def slide_03():
    img, draw = base()
    gold_h_line(draw, 145)
    split_header(draw, 'إضافة أفراد العائلة', 'Add Family Members', y=80)
    gold_h_line(draw, 145)
    divider_v(draw, 155, H-200)

    # Mockup card
    card_y = 170; card_h = 300
    rr(draw, [80, card_y, W-80, card_y+card_h], 20, SURFACE)

    # Header
    draw.text((W-110, card_y+18), ar('الأعضاء'), font=_font(28), fill=GOLD1)
    draw.text((100, card_y+18), 'Members', font=_font(28), fill=GOLD1)
    gold_h_line(draw, card_y+60)

    # Member rows
    members = [
        ('أحمد', 'Ahmed',  GOLD1),
        ('سارة', 'Sara',   GOLD_L),
        ('محمود', 'Mahmoud', GOLD_DIM),
    ]
    my = card_y + 76
    for ar_n, en_n, col in members:
        rr(draw, [100, my, W-100, my+64], 14, SURFACE2)
        # Avatar circle
        draw.ellipse([108, my+10, 148, my+50], fill=col)
        ini = en_n[0]
        ib = draw.textbbox((0,0), ini, font=_font(28))
        draw.text((128-(ib[2]-ib[0])//2, my+12), ini, font=_font(28), fill=BG)
        # Names
        draw.text((160, my+8), en_n, font=_font(26), fill=WHITE)
        draw.text((160, my+36), '', font=_font(22), fill=GREY)
        an = ar(ar_n)
        ab = draw.textbbox((0,0), an, font=_font(26))
        draw.text((W-110-(ab[2]-ab[0]), my+8), an, font=_font(26), fill=WHITE)
        my += 74

    # Add member button
    rr(draw, [120, card_y+card_h-68, W-120, card_y+card_h-18], 28, GOLD1)
    bt = ar('+ عضو جديد  /  Add Member')
    bb2 = draw.textbbox((0,0), bt, font=_font(26))
    draw.text(((W-(bb2[2]-bb2[0]))//2, card_y+card_h-56), bt, font=_font(26), fill=BG)

    # Tip box — shared
    tip_y = card_y + card_h + 30
    rr(draw, [80, tip_y, W-80, tip_y+90], 16, SURFACE)
    gold_h_line(draw, tip_y+44)
    tip_ar = ar('كل فرد له محفظة ومدخرات منفصلة')
    tip_en = 'Each member has a separate portfolio'
    ab = draw.textbbox((0,0), tip_ar, font=_font(24))
    draw.text((W-90-(ab[2]-ab[0]), tip_y+8), tip_ar, font=_font(24), fill=GREY)
    draw.text((90, tip_y+8), tip_en, font=_font(24), fill=GREY)
    tip_ar2 = ar('ومتابعة مستقلة')
    tip_en2 = 'and goals tracker'
    ab2 = draw.textbbox((0,0), tip_ar2, font=_font(24))
    draw.text((W-90-(ab2[2]-ab2[0]), tip_y+52), tip_ar2, font=_font(24), fill=GREY)
    draw.text((90, tip_y+52), tip_en2, font=_font(24), fill=GREY)

    # Steps — Arabic (right)
    ar_steps = [
        ar('اضغط اسمك في الهيدر'),
        ar('اضغط أيقونة "+"'),
        ar('أدخل الاسم واحفظ'),
        ar('اضغط على الاسم للتبديل'),
    ]
    sy = tip_y + 120
    for i, s in enumerate(ar_steps):
        rr(draw, [W//2+20, sy, W-60, sy+58], 14, SURFACE)
        draw.ellipse([W//2+30, sy+12, W//2+56, sy+42], fill=GOLD1)
        draw.text((W//2+36, sy+14), str(i+1), font=_font(22), fill=BG)
        bb = draw.textbbox((0,0), s, font=_font(26))
        draw.text((W-68-(bb[2]-bb[0]), sy+14), s, font=_font(26), fill=WHITE)
        sy += 72

    # Steps — English (left)
    en_steps = [
        'Tap your name in header',
        'Tap the + icon',
        'Enter name & save',
        'Tap name to switch',
    ]
    sy = tip_y + 120
    for i, s in enumerate(en_steps):
        rr(draw, [60, sy, W//2-20, sy+58], 14, SURFACE)
        draw.ellipse([68, sy+12, 94, sy+42], fill=GOLD1)
        draw.text((74, sy+14), str(i+1), font=_font(22), fill=BG)
        draw.text((104, sy+14), s, font=_font(26), fill=WHITE)
        sy += 72

    draw_chrome(draw, 3)
    return img


# ── Run ───────────────────────────────────────────────────────────────────────
slides = [
    ('00-welcome',  slide_00),
    ('01-assets',   slide_01),
    ('02-alerts',   slide_02),
    ('03-members',  slide_03),
]

for name, fn in slides:
    img = fn()
    path = os.path.join(OUT_DIR, f'{name}.png')
    img.save(path, 'PNG', optimize=True)
    print(f'Saved {path}')

print(f'\nAll {len(slides)} slides ready in tutorial-mockups/')
