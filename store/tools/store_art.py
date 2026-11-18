"""Composes SecureVault's Play Store screenshots and feature graphic from real
screen captures (test/capture/capture_screens_test.dart).

Usage, from the repo root:
  python3 store/tools/sample_photos.py <photos>
  SV_CAPTURE_OUT=<raw> SV_PHOTOS=<photos> flutter test test/capture/capture_screens_test.dart
  python3 store/tools/store_art.py <raw>

Writes assets/store/: screenshots/phone/NN_name.png (1080x1920) and the 1024x500
feature graphic. store/tools/icons.py writes the 512 icon beside them.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from icons import spiral_edges

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/store"
FONTS = ROOT / "assets/fonts"

JADE = (24, 84, 58)
TAIL = (33, 101, 71)
INK = (255, 255, 255)
SUB = (200, 228, 210)
BEZEL = (14, 17, 16)

SHOTS = [
    {"name": "01_disguise", "layout": "pair", "raws": ["10-calculator", "50-vault-photos"],
     "head": "Looks like a calculator.", "sub": "Type your PIN, then =, and your vault opens."},
    {"name": "02_disguises", "layout": "grid",
     "raws": ["10-calculator", "20-notes", "30-clock", "40-moodspace"],
     "labels": ["Calculator", "Notes", "Clock", "MoodSpace"],
     "head": "Pick its disguise.", "sub": "Each one works like the real app."},
    {"name": "03_photos", "layout": "screen", "raw": "50-vault-photos",
     "head": "Your photos, out of sight.", "sub": "Photos and videos, encrypted on your phone."},
    {"name": "04_notes", "layout": "screen", "raw": "53-vault-notes",
     "head": "Notes only you can read.", "sub": "Pin them, tag them, find them fast."},
    {"name": "05_second_vault", "layout": "screen", "raw": "58-vault-vaults", "width": 900,
     "head": "A second vault to show.", "sub": "Another PIN opens a vault of harmless things."},
    {"name": "06_setup", "layout": "screen", "raw": "05-setup-practice-calculator",
     "head": "Set up in a minute.", "sub": "Choose a disguise and a PIN, then try it once."},
]


def font(weight, size):
    name = {"semibold": "RedHatText-SemiBold.otf", "medium": "RedHatText-Medium.otf",
            "regular": "RedHatText-Regular.otf"}[weight]
    return ImageFont.truetype(str(FONTS / name), size)


def wrap(draw, text, fnt, width):
    """One line if it fits, else the two-line split with the most even lines."""
    if draw.textlength(text, font=fnt) <= width:
        return [text]
    words = text.split()
    splits = [(" ".join(words[:i]), " ".join(words[i:])) for i in range(1, len(words))]
    fitting = [s for s in splits if max(draw.textlength(l, font=fnt) for l in s) <= width]
    return list(min(fitting or splits, key=lambda s: max(draw.textlength(l, font=fnt) for l in s)))


def tail(canvas, centre, radius):
    """The chameleon's tail from the app icon, as one quiet spiral behind the phones.

    It starts off the right edge, so only its curl shows.
    """
    ss = 2
    b, k = math.log(2.4) / (2 * math.pi), 0.36
    a1 = math.log(0.12) / b
    outer, inner, mid = spiral_edges((centre[0] * ss, centre[1] * ss), 0, radius * ss, b, k, a1)
    mask = Image.new("L", (canvas.width * ss, canvas.height * ss), 0)
    d = ImageDraw.Draw(mask)
    d.polygon(outer + inner[::-1], fill=255)
    tx, ty, tr = mid[-1]
    cap = tr * k / 2
    d.ellipse([tx - cap, ty - cap, tx + cap, ty + cap], fill=255)
    shape = Image.new("RGBA", canvas.size, TAIL + (255,))
    shape.putalpha(mask.resize(canvas.size, Image.LANCZOS))
    canvas.alpha_composite(shape)


def phone(raw, width):
    """A capture in a plain dark phone body with rounded corners and a soft shadow."""
    screen = Image.open(raw).convert("RGB")
    scale = width / screen.width
    screen = screen.resize((width, round(screen.height * scale)), Image.LANCZOS)
    bezel = max(8, round(width * 0.022))
    radius = round(width * 0.11)
    body = Image.new("RGBA", (screen.width + 2 * bezel, screen.height + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=radius, fill=BEZEL)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen.width - 1, screen.height - 1],
                                           radius=radius - bezel, fill=255)
    body.paste(screen, (bezel, bezel), mask)
    pad = round(width * 0.12)
    shadowed = Image.new("RGBA", (body.width + 2 * pad, body.height + 2 * pad), (0, 0, 0, 0))
    shade = Image.new("L", body.size, 0)
    ImageDraw.Draw(shade).rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=radius, fill=120)
    sh = Image.new("RGBA", shadowed.size, (0, 0, 0, 0))
    sh.paste((6, 24, 20, 255), (pad, pad + round(width * 0.03)), shade)
    sh = sh.filter(ImageFilter.GaussianBlur(width * 0.04))
    shadowed.alpha_composite(sh)
    shadowed.alpha_composite(body, (pad, pad))
    return shadowed, pad


def place(canvas, img, x, y, angle=0):
    if angle:
        img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
    canvas.alpha_composite(img, (round(x - img.width / 2), round(y)))


def caption(canvas, head, sub, top=130):
    d = ImageDraw.Draw(canvas)
    hf, sf = font("semibold", 82), font("regular", 42)
    y = top
    for line in wrap(d, head, hf, 920):
        w = d.textlength(line, font=hf)
        d.text(((canvas.width - w) / 2, y), line, font=hf, fill=INK)
        y += 96
    y += 18
    for line in wrap(d, sub, sf, 900):
        w = d.textlength(line, font=sf)
        d.text(((canvas.width - w) / 2, y), line, font=sf, fill=SUB)
        y += 56
    return y


def shot(spec, raw_dir):
    canvas = Image.new("RGBA", (1080, 1920), JADE + (255,))
    tail(canvas, (520, 1300), 640)
    below = caption(canvas, spec["head"], spec["sub"])
    raw = lambda name: raw_dir / f"{name}.png"
    if spec["layout"] == "screen":
        img, pad = phone(raw(spec["raw"]), spec.get("width", 720))
        place(canvas, img, 540, below + 40 - pad)
    elif spec["layout"] == "pair":
        back, pad = phone(raw(spec["raws"][1]), 600)
        front, _ = phone(raw(spec["raws"][0]), 640)
        place(canvas, back, 700, below + 30 - pad, angle=-6)
        place(canvas, front, 400, below + 110 - pad, angle=4)
    elif spec["layout"] == "grid":
        d = ImageDraw.Draw(canvas)
        lf = font("medium", 38)
        for i, (name, label) in enumerate(zip(spec["raws"], spec["labels"])):
            img, pad = phone(raw(name), 380)
            cx = 290 + (i % 2) * 500
            y = below + 10 + (i // 2) * 700
            canvas.alpha_composite(img.crop((0, 0, img.width, pad + 600)), (round(cx - img.width / 2), y - pad))
            w = d.textlength(label, font=lf)
            d.text((cx - w / 2, y + 615), label, font=lf, fill=INK)
    return canvas.convert("RGB")


def feature(raw_dir):
    canvas = Image.new("RGBA", (1024, 500), JADE + (255,))
    tail(canvas, (790, 270), 300)
    d = ImageDraw.Draw(canvas)
    icon = Image.open(ROOT / "assets/icons/vault_icon.png").convert("RGBA").resize((112, 112), Image.LANCZOS)
    canvas.alpha_composite(icon, (64, 92))
    d.text((64, 222), "SecureVault", font=font("semibold", 68), fill=INK)
    tf = font("regular", 30)
    for i, line in enumerate(["A private vault that looks", "like an everyday app"]):
        d.text((66, 312 + i * 40), line, font=tf, fill=SUB)
    back, pad = phone(raw_dir / "50-vault-photos.png", 250)
    front, _ = phone(raw_dir / "10-calculator.png", 270)
    place(canvas, back, 860, 40 - pad, angle=-6)
    place(canvas, front, 700, 70 - pad, angle=5)
    return canvas.convert("RGB")


def main():
    raw_dir = Path(sys.argv[1])
    phone_dir = OUT / "screenshots/phone"
    phone_dir.mkdir(parents=True, exist_ok=True)
    for spec in SHOTS:
        shot(spec, raw_dir).save(phone_dir / f"{spec['name']}.png", optimize=True)
    feature(raw_dir).save(OUT / "feature_graphic_1024x500.png", optimize=True)


if __name__ == "__main__":
    main()
