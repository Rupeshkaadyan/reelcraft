#!/usr/bin/env python3
"""Creates demo media and seeds the simulator app container so screenshots show real content."""
import json
import os
import shutil
import subprocess
import sys
import uuid
from datetime import datetime, timedelta, timezone

BUNDLE = "com.reelcraft.app"
DEVICE = sys.argv[1] if len(sys.argv) > 1 else "booted"
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = "/tmp/reelcraft-seed"
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def run(cmd):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        print("command failed:", " ".join(cmd))
        print(result.stdout.decode()[-1500:])
        sys.exit(1)
    return result.stdout.decode()


def hex_rgb(value):
    value = value.replace("0x", "")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def make_backdrop(name, c0, c1, label, variant):
    """Draws an original poster frame for the demo clip."""
    from PIL import Image, ImageDraw, ImageFilter, ImageFont

    width, height = 1080, 1920
    top, bottom = hex_rgb(c0), hex_rgb(c1)
    img = Image.new("RGB", (width, height), bottom)
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / (height - 1)
        ease = t * t * (3 - 2 * t)
        draw.line([(0, y), (width, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * ease) for i in range(3)))

    art = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ad = ImageDraw.Draw(art)
    if variant == 0:
        for i in range(7):
            r = 90 + i * 46
            ad.ellipse([width * 0.18 - r, height * 0.34 - r, width * 0.18 + r, height * 0.34 + r], outline=(255, 255, 255, 46), width=6)
        ad.ellipse([width * 0.72, height * 0.18, width * 1.05, height * 0.62], fill=(255, 255, 255, 26))
    elif variant == 1:
        ad.polygon([(0, height * 0.7), (width, height * 0.42), (width, height), (0, height)], fill=(0, 0, 0, 90))
        ad.ellipse([width * 0.5, height * 0.5, width * 1.1, height * 1.05], fill=(255, 255, 255, 30))
    else:
        for i in range(6):
            y = height * 0.2 + i * 120
            ad.rounded_rectangle([width * 0.1, y, width * 0.9, y + 74], radius=37, outline=(255, 255, 255, 40), width=5)
        ad.ellipse([width * 0.3, height * 0.55, width * 0.7, height * 0.85], fill=(255, 255, 255, 32))
    art = art.filter(ImageFilter.GaussianBlur(3))
    img = Image.alpha_composite(img.convert("RGBA"), art)
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype(FONT, 92)
        small = ImageFont.truetype(FONT, 40)
    except Exception:
        font = small = ImageFont.load_default()
    box = draw.textbbox((0, 0), label, font=font)
    draw.text(((width - (box[2] - box[0])) / 2, height * 0.44), label, font=font, fill=(255, 255, 255, 255))
    sub = "Reelcraft demo media"
    box2 = draw.textbbox((0, 0), sub, font=small)
    draw.text(((width - (box2[2] - box2[0])) / 2, height * 0.44 + 130), sub, font=small, fill=(255, 255, 255, 190))

    frame = os.path.join(STAGE, name + "-frame.png")
    img.convert("RGB").save(frame)
    return frame


def make_clip(name, seconds, c0, c1, label, tone, variant):
    os.makedirs(STAGE, exist_ok=True)
    frame = make_backdrop(name, c0, c1, label, variant)
    path = os.path.join(STAGE, name + ".mp4")
    run([
        "ffmpeg", "-y",
        "-loop", "1", "-framerate", "30", "-i", frame,
        "-f", "lavfi", "-i", f"sine=frequency={tone}:duration={seconds}",
        "-t", str(seconds),
        "-filter:a", "volume=0.25",
        "-vf", "format=yuv420p",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "veryfast", "-crf", "26",
        "-c:a", "aac", "-shortest", path,
    ])
    thumb = os.path.join(STAGE, name + ".jpg")
    run(["ffmpeg", "-y", "-i", path, "-ss", "0.3", "-frames:v", "1", "-vf", "scale=480:-2", thumb])
    return path, thumb


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def clip_json(file_name, thumb_name, duration, w, h):
    return {
        "id": str(uuid.uuid4()).upper(),
        "fileName": file_name,
        "sourceDuration": duration,
        "trimStart": 0,
        "trimEnd": duration,
        "speed": 1,
        "volume": 1,
        "isMuted": False,
        "filter": "none",
        "hasAudio": True,
        "hasVideo": True,
        "thumbnailName": thumb_name,
        "sourceWidth": w,
        "sourceHeight": h,
    }


def main():
    container = run(["xcrun", "simctl", "get_app_container", DEVICE, BUNDLE, "data"]).strip()
    documents = os.path.join(container, "Documents")
    media_dir = os.path.join(documents, "Media")
    thumbs_dir = os.path.join(documents, "Thumbs")
    for path in (media_dir, thumbs_dir):
        os.makedirs(path, exist_ok=True)

    # Keep the seeded library clean so screenshots are reproducible.
    for directory in (media_dir, thumbs_dir):
        for name in os.listdir(directory):
            os.remove(os.path.join(directory, name))

    definitions = [
        ("street-food", 6.0, "0x2b1206", "0xff8a3d", "Market run", 220, 0),
        ("sunset-drive", 7.5, "0x120a2b", "0xff4d8d", "Sunset drive", 174, 1),
        ("coffee-pour", 5.0, "0x062026", "0x3dd6c8", "Morning pour", 261, 2),
    ]

    seeds = []
    for name, seconds, c0, c1, label, tone, variant in definitions:
        video, thumb = make_clip(name, seconds, c0, c1, label, tone, variant)
        file_name = name + ".mp4"
        thumb_name = name + ".jpg"
        shutil.copyfile(video, os.path.join(media_dir, file_name))
        shutil.copyfile(thumb, os.path.join(thumbs_dir, thumb_name))
        seeds.append(clip_json(file_name, thumb_name, seconds, 1080, 1920))

    now = datetime.now(timezone.utc)

    featured = {
        "id": str(uuid.uuid4()).upper(),
        "name": "Market run",
        "createdAt": iso(now - timedelta(hours=3)),
        "updatedAt": iso(now - timedelta(minutes=24)),
        "aspect": "vertical",
        "clips": seeds,
        "overlays": [
            {
                "id": str(uuid.uuid4()).upper(),
                "text": "Three days in Bangkok",
                "start": 0,
                "duration": 3,
                "position": "top",
                "style": "headline",
                "colorHex": 16448245,
                "isCaption": False,
            },
            {
                "id": str(uuid.uuid4()).upper(),
                "text": "the noodles were unreal",
                "start": 2.4,
                "duration": 3.2,
                "position": "bottom",
                "style": "caption",
                "colorHex": 16448245,
                "isCaption": True,
            },
        ],
        "music": "drift",
        "musicVolume": 0.32,
        "exportCount": 2,
        "lastExportAt": iso(now - timedelta(hours=20)),
    }
    featured["clips"][0]["filter"] = "ember"
    featured["clips"][1]["filter"] = "vivid"
    featured["clips"][1]["speed"] = 1.5
    featured["clips"][2]["filter"] = "fade"

    draft = {
        "id": str(uuid.uuid4()).upper(),
        "name": "Coffee pour",
        "createdAt": iso(now - timedelta(days=1)),
        "updatedAt": iso(now - timedelta(hours=9)),
        "aspect": "portrait",
        "clips": [seeds[2]],
        "overlays": [],
        "music": "hush",
        "musicVolume": 0.4,
        "exportCount": 0,
        "lastExportAt": None,
    }

    empty = {
        "id": str(uuid.uuid4()).upper(),
        "name": "Launch teaser",
        "createdAt": iso(now - timedelta(days=2)),
        "updatedAt": iso(now - timedelta(days=1, hours=4)),
        "aspect": "square",
        "clips": [],
        "overlays": [],
        "music": "none",
        "musicVolume": 0.35,
        "exportCount": 0,
        "lastExportAt": None,
    }

    with open(os.path.join(documents, "projects.json"), "w") as f:
        json.dump([featured, draft, empty], f, indent=2)

    ideas = [
        ("Hook idea: start on the wok fire, then the receipt", 1, False),
        ("Series: 60-second city guides, one per week", 2, False),
        ("Try the ember grade on the night market b-roll", 0, False),
        ("Ask Marco for the drone shots of the bay", 3, True),
        ("Caption style: bold, bottom, one line only", 4, False),
    ]
    idea_rows = []
    for index, (text, color, done) in enumerate(ideas):
        idea_rows.append({
            "id": str(uuid.uuid4()).upper(),
            "text": text,
            "createdAt": iso(now - timedelta(days=index, hours=index * 2)),
            "colorIndex": color,
            "isDone": done,
        })
    with open(os.path.join(documents, "ideas.json"), "w") as f:
        json.dump(idea_rows, f, indent=2)

    exports = []
    for offset, count in enumerate([0, 1, 0, 2, 1, 3, 1]):
        for _ in range(count):
            exports.append({
                "id": str(uuid.uuid4()).upper(),
                "projectName": "Market run",
                "date": iso(now - timedelta(days=6 - offset, hours=2)),
                "duration": 18.0,
                "resolution": "1080p HD",
            })
    with open(os.path.join(documents, "exports.json"), "w") as f:
        json.dump(exports, f, indent=2)

    print("seeded", container)
    print("projects: 3, clips:", len(seeds), "ideas:", len(idea_rows), "exports:", len(exports))


if __name__ == "__main__":
    main()
