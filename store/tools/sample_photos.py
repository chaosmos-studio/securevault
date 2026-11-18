"""Draws photo-like scenes to fill a demo vault for store screenshots and tests.

Usage: python3 store/tools/sample_photos.py <out_dir> [size]
"""

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def vertical(size, stops):
    """A sky or sea: colour stops as (position 0..1, (r, g, b))."""
    t = np.linspace(0.0, 1.0, size)[:, None]
    out = np.zeros((size, 3))
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        mask = (t >= p0) & (t <= p1)
        k = np.clip((t - p0) / max(p1 - p0, 1e-6), 0, 1)
        blend = np.array(c0) * (1 - k) + np.array(c1) * k
        out = np.where(mask, blend, out)
    img = np.repeat(out[:, None, :], size, axis=1)
    return Image.fromarray(img.astype(np.uint8), "RGB")


def ridge(draw, size, base, amp, freq, phase, colour, rng):
    pts = [(0, size)]
    for x in range(0, size + 8, 8):
        y = base + amp * math.sin(x / size * freq * math.pi + phase)
        y += amp * 0.35 * math.sin(x / size * freq * 3.1 * math.pi + phase * 2)
        y += rng.uniform(-amp * 0.05, amp * 0.05)
        pts.append((x, y))
    pts.append((size, size))
    draw.polygon(pts, fill=colour)


def grain(img, rng, amount=6):
    arr = np.asarray(img).astype(np.int16)
    noise = np.random.default_rng(rng.randint(0, 9999)).normal(0, amount, arr.shape)
    return Image.fromarray(np.clip(arr + noise, 0, 255).astype(np.uint8), "RGB")


def sunset(size, rng):
    img = vertical(size, [(0, (58, 44, 96)), (0.45, (238, 128, 82)), (0.55, (250, 196, 120)),
                          (0.56, (64, 70, 110)), (1, (22, 28, 52))])
    d = ImageDraw.Draw(img)
    r = size * 0.09
    d.ellipse([size * 0.5 - r, size * 0.5 - r, size * 0.5 + r, size * 0.5 + r], fill=(255, 220, 160))
    for i in range(40):
        y = size * 0.57 + i * size * 0.011
        w = size * (0.05 + 0.25 * rng.random()) * (1 - i / 50)
        d.line([size * 0.5 - w, y, size * 0.5 + w, y], fill=(250, 190, 130), width=max(1, size // 300))
    img = img.filter(ImageFilter.GaussianBlur(size / 400))
    return grain(img, rng)


def mountains(size, rng):
    img = vertical(size, [(0, (186, 205, 222)), (0.6, (236, 232, 226)), (1, (210, 214, 218))])
    d = ImageDraw.Draw(img)
    layers = [(0.42, (150, 166, 186)), (0.52, (112, 128, 150)), (0.63, (78, 92, 112)), (0.76, (44, 54, 68))]
    for i, (base, colour) in enumerate(layers):
        ridge(d, size, size * base, size * (0.12 - i * 0.02), 2 + i, rng.uniform(0, 6), colour, rng)
    img = img.filter(ImageFilter.GaussianBlur(size / 700))
    return grain(img, rng)


def city(size, rng):
    img = vertical(size, [(0, (10, 16, 40)), (0.7, (40, 48, 92)), (1, (16, 18, 30))])
    d = ImageDraw.Draw(img)
    for _ in range(140):
        x, y = rng.uniform(0, size), rng.uniform(0, size * 0.5)
        d.point((x, y), fill=(220, 225, 255))
    x = 0
    while x < size:
        w = rng.uniform(size * 0.05, size * 0.12)
        h = rng.uniform(size * 0.2, size * 0.55)
        top = size - h
        d.rectangle([x, top, x + w, size], fill=(14, 16, 26))
        for wy in np.arange(top + 8, size, size * 0.025):
            for wx in np.arange(x + 5, x + w - 6, size * 0.02):
                if rng.random() < 0.35:
                    warm = rng.choice([(255, 206, 120), (255, 236, 180), (180, 210, 255)])
                    d.rectangle([wx, wy, wx + size * 0.008, wy + size * 0.012], fill=warm)
        x += w + rng.uniform(0, size * 0.01)
    return grain(img, rng, 4)


def forest(size, rng):
    img = vertical(size, [(0, (214, 228, 214)), (0.5, (176, 200, 176)), (1, (60, 84, 62))])
    d = ImageDraw.Draw(img)
    for layer, colour in enumerate([(128, 160, 132), (88, 122, 94), (52, 82, 60), (28, 50, 36)]):
        base = size * (0.45 + layer * 0.13)
        for _ in range(26):
            x = rng.uniform(-size * 0.05, size * 1.05)
            h = rng.uniform(size * 0.15, size * 0.32)
            w = h * 0.38
            d.polygon([(x, base - h), (x - w, base + size * 0.04), (x + w, base + size * 0.04)], fill=colour)
        d.rectangle([0, base + size * 0.03, size, size], fill=colour)
    img = img.filter(ImageFilter.GaussianBlur(size / 900))
    return grain(img, rng)


def dunes(size, rng):
    img = vertical(size, [(0, (120, 170, 214)), (0.45, (238, 214, 178)), (1, (200, 130, 76))])
    d = ImageDraw.Draw(img)
    for i, colour in enumerate([(232, 176, 116), (214, 150, 92), (190, 120, 70), (160, 94, 52)]):
        ridge(d, size, size * (0.5 + i * 0.12), size * 0.06, 1.3 + i * 0.4, rng.uniform(0, 6), colour, rng)
    img = img.filter(ImageFilter.GaussianBlur(size / 600))
    return grain(img, rng)


def bokeh(size, rng, ground=(24, 40, 30), hues=((255, 170, 190), (255, 220, 140), (190, 230, 160))):
    img = Image.new("RGB", (size, size), ground)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(46):
        r = rng.uniform(size * 0.03, size * 0.11)
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        c = rng.choice(hues)
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (rng.randint(60, 150),))
    layer = layer.filter(ImageFilter.GaussianBlur(size / 90))
    img.paste(layer, (0, 0), layer)
    return grain(img, rng)


def lake(size, rng):
    sky = vertical(size, [(0, (250, 214, 186)), (0.5, (236, 168, 150)), (1, (120, 100, 140))])
    img = sky.copy()
    d = ImageDraw.Draw(img)
    ridge(d, size, size * 0.42, size * 0.07, 2.2, rng.uniform(0, 6), (92, 78, 112), rng)
    top = img.crop((0, 0, size, size // 2))
    img.paste(top.transpose(Image.Transpose.FLIP_TOP_BOTTOM).filter(ImageFilter.GaussianBlur(size / 300)),
              (0, size // 2))
    d = ImageDraw.Draw(img)
    for i in range(30):
        y = size * 0.52 + i * size * 0.016
        d.line([0, y, size, y], fill=(255, 255, 255), width=1)
    return grain(img.filter(ImageFilter.GaussianBlur(size / 1200)), rng)


def aurora(size, rng):
    img = vertical(size, [(0, (6, 14, 30)), (1, (20, 40, 60))])
    band = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(band)
    for k in range(3):
        phase = rng.uniform(0, 6)
        for x in range(0, size, 3):
            y = size * (0.3 + k * 0.08) + size * 0.08 * math.sin(x / size * 3 + phase)
            d.line([x, y, x, y + size * (0.12 + 0.06 * k)], fill=(80, 255, 170, 34), width=3)
    band = band.filter(ImageFilter.GaussianBlur(size / 60))
    img.paste(band, (0, 0), band)
    d = ImageDraw.Draw(img)
    ridge(d, size, size * 0.8, size * 0.04, 3, rng.uniform(0, 6), (6, 10, 16), rng)
    for _ in range(120):
        d.point((rng.uniform(0, size), rng.uniform(0, size * 0.6)), fill=(230, 240, 255))
    return grain(img, rng, 4)


def beach(size, rng):
    img = Image.new("RGB", (size, size), (236, 218, 186))
    d = ImageDraw.Draw(img)
    pts = [(0, 0), (size, 0)]
    for y in range(0, size + 8, 8):
        pts.append((size * 0.55 + size * 0.08 * math.sin(y / size * 5 + 1), y))
    pts.append((size, size))
    d.polygon([(0, 0)] + [(x, y) for (x, y) in pts[2:]] + [(0, size)], fill=(236, 218, 186))
    water = [(x + size * 0.0, y) for (x, y) in pts[2:]]
    d.polygon([(size, 0)] + water + [(size, size)], fill=(64, 178, 190))
    d.line(water, fill=(250, 250, 245), width=size // 60)
    return grain(img.filter(ImageFilter.GaussianBlur(size / 500)), rng)


SCENES = [sunset, mountains, city, forest, dunes, lake, aurora, beach,
          lambda s, r: bokeh(s, r),
          lambda s, r: bokeh(s, r, ground=(36, 24, 40), hues=((255, 196, 120), (255, 140, 120), (250, 230, 200)))]


def main():
    out = Path(sys.argv[1])
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 720
    out.mkdir(parents=True, exist_ok=True)
    for i, scene in enumerate(SCENES):
        rng = random.Random(1000 + i)
        scene(size, rng).save(out / f"photo_{i:02d}.jpg", quality=88)


if __name__ == "__main__":
    main()
