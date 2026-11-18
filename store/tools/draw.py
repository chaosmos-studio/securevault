"""Vector drawing for SecureVault's icons, with Pillow and numpy.

Shapes are masks of one 108 dp adaptive icon layer, drawn at 16 px per dp and
scaled down, with coordinates in dp from the layer's centre. Fills are solid
colours or gradients.
"""

from functools import reduce
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]

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


def union(*ms):
    return reduce(ImageChops.lighter, ms)


def inter(*ms):
    return reduce(ImageChops.multiply, ms)


def minus(a, b):
    return ImageChops.subtract(a, b)


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
