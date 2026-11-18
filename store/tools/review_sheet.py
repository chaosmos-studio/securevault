"""Lays every captured screen and the store listing's pictures out on one sheet.

Usage, from the repo root:
  python3 store/tools/review_sheet.py <raw_dir>

where <raw_dir> holds the captures from test/capture/capture_screens_test.dart.
Writes docs/redesign/review-1.1.0.jpg.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from draw import INK, MUTED, PAPER, ROOT, drop, font, label, masked, rgba

OUT = ROOT / "docs/redesign/review-1.1.0.jpg"
STORE = ROOT / "assets/store"


def fit(path, width):
    img = Image.open(path).convert("RGBA")
    return img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)


def main():
    shots = sorted(Path(sys.argv[1]).glob("*.png"))
    store_shots = sorted((STORE / "screenshots/phone").glob("*.png"))
    cols, tw, gap, margin = 8, 270, 24, 60
    th = round(tw * 2412 / 1084)
    w = margin * 2 + cols * tw + (cols - 1) * gap
    rows = math.ceil(len(shots) / cols)
    grid_h = rows * (th + 52)
    sw = (w - margin * 2 - gap * (len(store_shots) - 1)) // len(store_shots)
    sh = round(sw * 1920 / 1080)
    h = 150 + 60 + grid_h + 90 + 560 + 60 + sh + 80

    canvas = Image.new("RGBA", (w, h), rgba(PAPER))
    d = ImageDraw.Draw(canvas)
    d.text((margin, 50), "SecureVault 1.1.0 for review", font=font("semibold", 52), fill=INK)
    d.text((margin, 116), "Every screen as the app draws it at phone size, then the store listing's pictures.",
           font=font("regular", 24), fill=MUTED)

    y = 190
    d.text((margin, y), "Every screen", font=font("semibold", 34), fill=INK)
    y += 60
    for i, path in enumerate(shots):
        x = margin + (i % cols) * (tw + gap)
        yy = y + (i // cols) * (th + 52)
        drop(canvas, fit(path, tw), x, yy, r=6, opacity=40)
        label(d, x, yy + th + 10, path.stem, size=17, fill=INK, centre_w=tw)
    y += grid_h + 30

    d.text((margin, y), "Store listing", font=font("semibold", 34), fill=INK)
    y += 60
    feature = fit(STORE / "feature_graphic_1024x500.png", 1024)
    drop(canvas, feature, margin, y, r=10, opacity=50)
    label(d, margin, y + 508, "Feature graphic, 1024 x 500", size=17, centre_w=1024)
    icon = masked(fit(STORE / "play_store_icon_512.png", 440), "play")
    drop(canvas, icon, margin + 1024 + 60, y + 30, r=10, opacity=50)
    label(d, margin + 1024 + 60, y + 478, "Store icon, 512 px", size=17, centre_w=440)
    y += 560 + 40
    for i, path in enumerate(store_shots):
        x = margin + i * (sw + gap)
        drop(canvas, fit(path, sw), x, y, r=8, opacity=50)
        label(d, x, y + sh + 10, path.stem, size=17, fill=INK, centre_w=sw)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT, quality=88, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({w}x{h})")


if __name__ == "__main__":
    main()
