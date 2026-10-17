#!/usr/bin/env python3
"""Generate Reelcraft's own icon and marketing art. All art is drawn here."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "Reelcraft/Assets.xcassets/AppIcon.appiconset")
MKT = os.path.join(ROOT, "Marketing")
os.makedirs(ICON_DIR, exist_ok=True)
os.makedirs(MKT, exist_ok=True)

BG_TOP = (23, 23, 31)
BG_BOTTOM = (8, 8, 11)
INK = (247, 247, 245)
EMBER = (255, 92, 56)
MINT = (124, 255, 178)


def gradient(size, top, bottom):
    img = Image.new("RGB", size, bottom)
    px = img.load()
    w, h = size
    for y in range(h):
        t = y / max(1, h - 1)
        ease = t * t * (3 - 2 * t)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * ease) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def draw_mark(canvas, cx, cy, span, frame_color=INK, play_color=EMBER, glow=True):
    """A film frame with a play wedge: the Reelcraft mark."""
    d = ImageDraw.Draw(canvas, "RGBA")
    if glow:
        g = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        r = span * 0.82
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=EMBER + (70,))
        g = g.filter(ImageFilter.GaussianBlur(span * 0.22))
        canvas.alpha_composite(g)
        d = ImageDraw.Draw(canvas, "RGBA")

    w = span
    h = span * 1.16
    left, top = cx - w / 2, cy - h / 2
    radius = span * 0.20
    stroke = max(6, int(span * 0.075))
    # frame
    d.rounded_rectangle(
        [left, top, left + w, top + h],
        radius=radius,
        outline=frame_color + (255,),
        width=stroke,
    )
    # sprocket notches, left and right rails
    notch_w = span * 0.085
    notch_h = span * 0.085
    for i in range(3):
        yy = top + h * (0.24 + i * 0.22)
        d.rounded_rectangle(
            [left + stroke * 0.55, yy, left + stroke * 0.55 + notch_w, yy + notch_h],
            radius=notch_h * 0.35,
            fill=frame_color + (190,),
        )
        d.rounded_rectangle(
            [left + w - stroke * 0.55 - notch_w, yy, left + w - stroke * 0.55, yy + notch_h],
            radius=notch_h * 0.35,
            fill=frame_color + (190,),
        )
    # play wedge
    pw = span * 0.30
    ph = span * 0.34
    px = cx - pw * 0.34
    py = cy
    d.polygon(
        [(px, py - ph / 2), (px + pw, py), (px, py + ph / 2)],
        fill=play_color + (255,),
    )
    # mint tick: the cut
    d.rounded_rectangle(
        [cx + span * 0.24, cy - span * 0.30, cx + span * 0.30, cy + span * 0.16],
        radius=span * 0.03,
        fill=MINT + (255,),
    )


def make_icon(size=1024):
    base = gradient((size, size), BG_TOP, BG_BOTTOM).convert("RGBA")
    # faint concentric rings for depth
    rings = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    for i, r in enumerate((0.86, 0.65, 0.44)):
        rr = size * r
        rd.ellipse(
            [size / 2 - rr, size / 2 - rr, size / 2 + rr, size / 2 + rr],
            outline=(255, 255, 255, 8 + i * 3),
            width=max(1, size // 340),
        )
    base.alpha_composite(rings)
    draw_mark(base, size / 2, size / 2, size * 0.52)
    # subtle vignette
    vig = Image.new("L", (size, size), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-size * 0.15, -size * 0.15, size * 1.15, size * 1.15], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(size * 0.12))
    dark = Image.new("RGBA", (size, size), (0, 0, 0, 105))
    dark.putalpha(Image.eval(vig, lambda v: 255 - v))
    base.alpha_composite(dark)
    # iOS masks the corners itself; keep a square canvas
    return base.convert("RGB")


def make_wallpaper(w=1290, h=2796):
    img = gradient((w, h), (26, 26, 36), (6, 6, 9)).convert("RGBA")
    # ember bloom behind the mark
    bloom = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bloom)
    bd.ellipse([w * 0.05, h * 0.18, w * 0.95, h * 0.62], fill=EMBER + (58,))
    bloom = bloom.filter(ImageFilter.GaussianBlur(180))
    img.alpha_composite(bloom)
    draw_mark(img, w / 2, h * 0.40, w * 0.44)

    d = ImageDraw.Draw(img)
    def font(size, bold=False):
        candidates = [
            "/System/Library/Fonts/Supplemental/Avenir Next.ttc",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
        for c in candidates:
            try:
                return ImageFont.truetype(c, size)
            except Exception:
                continue
        return ImageFont.load_default()

    title = font(112, True)
    sub = font(46)
    small = font(34)
    def center(text, y, f, fill):
        box = d.textbbox((0, 0), text, font=f)
        d.text(((w - (box[2] - box[0])) / 2, y), text, font=f, fill=fill)

    center("Reelcraft", h * 0.55, title, INK + (255,))
    center("Edit like you mean it.", h * 0.60, sub, INK + (190,))
    center("Frame-accurate editing  ·  Built for short-form", h * 0.67, small, (154, 154, 165, 255))

    # footer chips
    chip_text = "NO WATERMARK   ·   UP TO 4K   ·   ON-DEVICE"
    fw = d.textbbox((0, 0), chip_text, font=small)
    cw, ch = fw[2] - fw[0] + 90, 96
    x0, y0 = (w - cw) / 2, h * 0.78
    d.rounded_rectangle([x0, y0, x0 + cw, y0 + ch], radius=ch / 2, fill=(255, 255, 255, 12), outline=(255, 255, 255, 34), width=2)
    d.text((x0 + 45, y0 + 28), chip_text, font=small, fill=INK + (220,))
    return img.convert("RGB")


if __name__ == "__main__":
    icon = make_icon(1024)
    icon.save(os.path.join(ICON_DIR, "AppIcon.png"), "PNG")
    icon.resize((180, 180), Image.LANCZOS).save(os.path.join(MKT, "icon-180.png"), "PNG")
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(MKT, "icon-512.png"), "PNG")

    contents = {
        "images": [
            {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024", "appearances": [{"appearance": "luminosity", "value": "dark"}]},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    make_wallpaper().save(os.path.join(MKT, "wallpaper-1290x2796.png"), "PNG")
    print("assets written")
