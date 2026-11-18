"""Vector drawing for SecureVault's icons and store art, with Pillow and numpy.

Shapes are masks of one 108 dp adaptive icon layer, drawn at 16 px per dp and
scaled down, with coordinates in dp from the layer's centre. Fills are solid
colours or gradients. The sheet helpers lay icons out the way launchers show
them.
"""

import math
from functools import reduce
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "assets/fonts"

S = 1728  # one 108 dp layer, 16 px per dp
DP = S / 108
_ys, _xs = np.mgrid[0:S, 0:S].astype(np.float32)
GX = (_xs + 0.5 - S / 2) / DP
GY = (_ys + 0.5 - S / 2) / DP
del _xs, _ys


# Geometry.

def px(p):
    return (S / 2 + p[0] * DP, S / 2 + p[1] * DP)


def bezier(p0, c0, c1, p1, n=40):
    pts = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * c0[0] + 3 * u * t * t * c1[0] + t ** 3 * p1[0],
                    u ** 3 * p0[1] + 3 * u * u * t * c0[1] + 3 * u * t * t * c1[1] + t ** 3 * p1[1]))
    return pts


def path(start, *segments):
    """An outline: each segment is a point (a line to it) or (c0, c1, p) (a curve to p)."""
    pts = [start]
    for seg in segments:
        if isinstance(seg[0], tuple):
            pts += bezier(pts[-1], *seg)
        else:
            pts.append(seg)
    return pts


def reflect(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)
    fx, fy = a[0] + t * dx, a[1] + t * dy
    return (2 * fx - p[0], 2 * fy - p[1])


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# Masks: L images of one layer.

def blank(v=0):
    return Image.new("L", (S, S), v)


def poly(pts):
    m = blank()
    ImageDraw.Draw(m).polygon([px(p) for p in pts], fill=255)
    return m


def ellipse(c, rx, ry=None):
    ry = rx if ry is None else ry
    m = blank()
    ImageDraw.Draw(m).ellipse([*px((c[0] - rx, c[1] - ry)), *px((c[0] + rx, c[1] + ry))], fill=255)
    return m


def ring(c, r_out, r_in, ry_out=None, ry_in=None):
    return minus(ellipse(c, r_out, ry_out), ellipse(c, r_in, ry_in))


def rrect(x0, y0, x1, y1, r):
    m = blank()
    ImageDraw.Draw(m).rounded_rectangle([*px((x0, y0)), *px((x1, y1))], radius=r * DP, fill=255)
    return m


def stroke(pts, width):
    m = blank()
    d = ImageDraw.Draw(m)
    q = [px(p) for p in pts]
    d.line(q, fill=255, width=round(width * DP), joint="curve")
    r = width * DP / 2
    for x, y in q:  # wide joints between short segments leave specks without these
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m


def ribbon(pts, widths):
    """A band along pts whose width changes point by point, with a round tip."""
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        h = widths[i] / 2
        left.append((x + nx * h, y + ny * h))
        right.append((x - nx * h, y - ny * h))
    return union(poly(left + right[::-1]), ellipse(pts[-1], widths[-1] / 2))


def union(*ms):
    return reduce(ImageChops.lighter, ms)


def inter(*ms):
    return reduce(ImageChops.multiply, ms)


def minus(a, b):
    return ImageChops.subtract(a, b)


def shift(m, dx, dy):
    out = blank()
    out.paste(m, (round(dx * DP), round(dy * DP)))
    return out


def blur(m, r):
    return m.filter(ImageFilter.GaussianBlur(r * DP))


def soften(m, r):
    """The mask with its corners rounded by about r dp."""
    return blur(m, r).point(lambda v: max(0, min(255, (v - 128) * 8 + 128)))


# Fills.

def rgba(c):
    return tuple(c) + (255,) if len(c) == 3 else tuple(c)


def ramp(t, stops):
    pos = [p for p, _ in stops]
    cols = np.array([rgba(c) for _, c in stops], np.float32)
    out = np.stack([np.interp(t, pos, cols[:, k]) for k in range(4)], axis=-1)
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA")


def linear(stops, p0, p1):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    t = ((GX - p0[0]) * dx + (GY - p0[1]) * dy) / (dx * dx + dy * dy)
    return ramp(np.clip(t, 0, 1), stops)


def radial(stops, c, r, ry=None):
    ry = r if ry is None else ry
    return ramp(np.clip(np.hypot((GX - c[0]) / r, (GY - c[1]) / ry), 0, 1), stops)


def paint(lay, mask, fill, opacity=1.0):
    src = Image.new("RGBA", (S, S), rgba(fill)) if isinstance(fill, tuple) else fill.copy()
    a = ImageChops.multiply(src.getchannel("A"), mask)
    if opacity < 1:
        a = a.point(lambda v: round(v * opacity))
    src.putalpha(a)
    lay.alpha_composite(src)


def shadow(lay, mask, dx, dy, r, color, opacity):
    paint(lay, blur(shift(mask, dx, dy), r), color, opacity)


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def flat(color):
    lay = layer()
    paint(lay, blank(255), color)
    return lay


# Icons at launcher and store sizes.

INSET = round(S * 18 / 108)


def visible(img, size):
    """The middle 72 dp that launchers show, at size px."""
    return img.crop((INSET, INSET, S - INSET, S - INSET)).resize((size, size), Image.LANCZOS)


def full_icon(bg, fg, size):
    whole = bg.copy()
    whole.alpha_composite(fg)
    return visible(whole, size)


def shape_mask(kind, size):
    big = size * 4
    if kind == "round":
        m = Image.new("L", (big, big), 0)
        ImageDraw.Draw(m).ellipse([0, 0, big - 1, big - 1], fill=255)
    elif kind == "squircle":
        u = (np.arange(big, dtype=np.float32) + 0.5) / big * 2 - 1
        x, y = np.meshgrid(u, u)
        m = Image.fromarray(((np.abs(x) ** 5 + np.abs(y) ** 5) <= 1).astype(np.uint8) * 255, "L")
    else:
        m = Image.new("L", (big, big), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.2, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def masked(img, kind):
    out = img.convert("RGBA")
    out.putalpha(ImageChops.multiply(out.getchannel("A"), shape_mask(kind, img.width)))
    return out


def themed(mono, size, back, ink):
    tile = Image.new("RGBA", (size, size), rgba(back))
    glyph = Image.new("RGBA", (size, size), rgba(ink))
    glyph.putalpha(visible(mono, size))
    tile.alpha_composite(glyph)
    return masked(tile, "round")


# Sheets.

PAPER = (244, 242, 238)
INK = (28, 28, 30)
MUTED = (110, 108, 104)
THEME_LIGHT = ((214, 227, 255), (26, 58, 105))
THEME_DARK = ((42, 50, 66), (207, 224, 255))
WALL_LIGHT = [(0, (250, 232, 214)), (1, (210, 226, 242))]
WALL_DARK = [(0, (34, 40, 60)), (1, (12, 14, 22))]


def font(weight, size):
    name = {"semibold": "RedHatText-SemiBold.otf", "medium": "RedHatText-Medium.otf",
            "regular": "RedHatText-Regular.otf"}[weight]
    return ImageFont.truetype(str(FONTS / name), size)


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=fnt) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def drop(canvas, img, x, y, r=10, opacity=60):
    sh = Image.new("RGBA", (img.width + 4 * r, img.height + 4 * r), (0, 0, 0, 0))
    a = Image.new("L", sh.size, 0)
    a.paste(img.getchannel("A").point(lambda v: v * opacity // 255), (2 * r, 2 * r))
    sh.putalpha(a.filter(ImageFilter.GaussianBlur(r)))
    canvas.alpha_composite(sh, (x - 2 * r, y - 2 * r + r // 2))
    canvas.alpha_composite(img, (x, y))


def label(draw, x, y, text, size=17, fill=MUTED, centre_w=None, weight="regular"):
    fnt = font(weight, size)
    if centre_w:
        x += (centre_w - draw.textlength(text, font=fnt)) / 2
    draw.text((x, y), text, font=fnt, fill=fill)


def wallpaper(w, h, stops, radius=14):
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    wall = ramp(t, stops)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    wall.putalpha(m)
    return wall


def home_row(canvas, x, y, icons, dark, size=48, gap=28, pad=22):
    """Icons at launcher size with their names, in a row on a wallpaper."""
    cell = size + gap
    w = pad * 2 + cell * len(icons) - gap
    h = size + 62
    canvas.alpha_composite(wallpaper(w, h, WALL_DARK if dark else WALL_LIGHT), (x, y))
    d = ImageDraw.Draw(canvas)
    fnt = font("regular", 12)
    for k, (icon, name) in enumerate(icons):
        ix = x + pad + k * cell
        canvas.alpha_composite(icon, (ix, y + 18))
        tw = d.textlength(name, font=fnt)
        d.text((ix + (size - tw) / 2, y + 18 + size + 8), name, font=fnt,
               fill=(255, 255, 255) if dark else (40, 40, 44))
    return w, h
