#!/usr/bin/env python3
"""Composes App Store screenshots at 1320x2868: brand header above a framed device capture."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "Marketing/screens-max")
ICON = os.path.join(HERE, "Marketing/icon-512.png")
OUT = os.path.join(HERE, "Marketing/appstore")
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"

CANVAS = (1320, 2868)
EMBER = (255, 92, 56)
INK = (247, 247, 245)
MUTED = (154, 154, 165)

SHOTS = [
    ("projects", "Every cut in one place", "Drafts, imports and finished videos"),
    ("editor", "Frame-accurate timeline", "Trim, split and retime to the frame"),
    ("discover", "Start from a look", "Templates with grade, type and sound"),
    ("ideas", "Catch ideas early", "Stickies that turn into projects"),
    ("insights", "Know your habits", "On-device stats, no account needed"),
]


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def text_width(draw, text, f):
    box = draw.textbbox((0, 0), text, font=f)
    return box[2] - box[0]


def center_text(draw, text, y, f, fill, width):
    draw.text(((width - text_width(draw, text, f)) / 2, y), text, font=f, fill=fill)


def background():
    img = Image.new("RGB", CANVAS, (8, 8, 11))
    px = img.load()
    top, bottom = (20, 20, 27), (7, 7, 10)
    for y in range(CANVAS[1]):
        t = y / (CANVAS[1] - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(CANVAS[0]):
            px[x, y] = color
    glow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([CANVAS[0] * 0.45, -CANVAS[0] * 0.35, CANVAS[0] * 1.4, CANVAS[0] * 0.55], fill=EMBER + (40,))
    glow = glow.filter(ImageFilter.GaussianBlur(190))
    return Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")


def header(canvas, headline, tagline):
    draw = ImageDraw.Draw(canvas, "RGBA")
    width = CANVAS[0]

    # Brand lockup with the app mark.
    if os.path.exists(ICON):
        mark = Image.open(ICON).convert("RGBA").resize((58, 58), Image.LANCZOS)
        mask = Image.new("L", (58, 58), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, 57, 57], radius=14, fill=255)
        canvas.paste(mark, (width // 2 - 168, 62), mask)

    brand_font = font(FONT_BOLD, 27)
    draw.text((width // 2 - 96, 76), "REELCRAFT", font=brand_font, fill=INK + (235,))

    title_font = font(FONT_BOLD, 86)
    title_y = 158
    if text_width(draw, headline, title_font) > width - 140:
        title_font = font(FONT_BOLD, 72)
    center_text(draw, headline, title_y, title_font, INK + (255,), width)

    tag_font = font(FONT_REG, 33)
    center_text(draw, tagline, title_y + 112, tag_font, MUTED + (255,), width)

    accent_font = font(FONT_BOLD, 26)
    label = "NO WATERMARK  ·  4K EXPORT"
    lw = text_width(draw, label, accent_font)
    draw.text(((width - lw) / 2, title_y + 168), label, font=accent_font, fill=EMBER + (255,))


def frame(canvas, shot):
    width, height = CANVAS
    top = 420
    available_h = height - top - 54
    available_w = width - 196
    scale = min(available_w / shot.width, available_h / shot.height)
    shot_w, shot_h = int(shot.width * scale), int(shot.height * scale)
    scaled = shot.resize((shot_w, shot_h), Image.LANCZOS)

    radius = 46
    mask = Image.new("L", (shot_w, shot_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot_w - 1, shot_h - 1], radius=radius, fill=255)

    x = (width - shot_w) // 2
    y = top + (available_h - shot_h) // 2

    shadow = Image.new("RGBA", (shot_w + 80, shot_h + 80), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([40, 40, shot_w + 40, shot_h + 40], radius=radius, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas.paste(shadow, (x - 40, y - 34), shadow)

    canvas.paste(scaled, (x, y), mask)

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rounded_rectangle([x, y, x + shot_w - 1, y + shot_h - 1], radius=radius, outline=(255, 255, 255, 34), width=2)


def main():
    os.makedirs(OUT, exist_ok=True)
    for index, (name, headline, tagline) in enumerate(SHOTS, start=1):
        src_path = os.path.join(SRC, name + ".png")
        if not os.path.exists(src_path):
            print("missing", src_path)
            continue
        canvas = background()
        header(canvas, headline, tagline)
        frame(canvas, Image.open(src_path).convert("RGB"))
        out_path = os.path.join(OUT, f"{index:02d}-{name}.png")
        canvas.save(out_path, "PNG")
        print(os.path.relpath(out_path, HERE), canvas.size)


if __name__ == "__main__":
    main()
