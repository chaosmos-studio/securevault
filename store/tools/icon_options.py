"""Draws six icon directions for SecureVault and lays them out on one sheet.

Each direction is an adaptive icon: background, foreground and monochrome
layers of 108 dp, of which launchers show the middle 72 dp.

Usage, from the repo root:
  python3 store/tools/icon_options.py [previews_dir]

Writes docs/redesign/icon-options.png, and each direction's 512 icon and
layers into previews_dir when one is given.
"""

import math
import sys
from functools import reduce
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "assets/fonts"
SHEET = ROOT / "docs/redesign/icon-options.png"

S = 1728  # one 108 dp layer, 16 px per dp
DP = S / 108
_ys, _xs = np.mgrid[0:S, 0:S].astype(np.float32)
GX = (_xs + 0.5 - S / 2) / DP
GY = (_ys + 0.5 - S / 2) / DP
del _xs, _ys


# Geometry, in dp from the layer's centre.

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


def paint(layer, mask, fill, opacity=1.0):
    src = Image.new("RGBA", (S, S), rgba(fill)) if isinstance(fill, tuple) else fill.copy()
    a = ImageChops.multiply(src.getchannel("A"), mask)
    if opacity < 1:
        a = a.point(lambda v: round(v * opacity))
    src.putalpha(a)
    layer.alpha_composite(src)


def shadow(layer, mask, dx, dy, r, color, opacity):
    paint(layer, blur(shift(mask, dx, dy), r), color, opacity)


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


# The small sunset photo several directions keep inside them.

SKY = [(0, (255, 228, 180)), (0.55, (247, 160, 118)), (1, (226, 102, 112))]
SUN = (255, 246, 224)
FAR = (184, 96, 122)
NEAR = (92, 52, 90)


def hills(box):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0

    def P(u, v):
        return (x0 + u * w, y0 + v * h)

    far = path(P(-0.1, 0.7), (P(0.15, 0.58), P(0.35, 0.5), P(0.55, 0.6)),
               (P(0.72, 0.68), P(0.9, 0.6), P(1.1, 0.64)), P(1.1, 1.1), P(-0.1, 1.1))
    near = path(P(-0.1, 0.84), (P(0.2, 0.72), P(0.5, 0.7), P(0.72, 0.79)),
                (P(0.85, 0.84), P(0.95, 0.85), P(1.1, 0.82)), P(1.1, 1.1), P(-0.1, 1.1))
    return poly(far), poly(near)


def photo(lay, clip, box, sun=(0.64, 0.4), sun_r=0.15):
    x0, y0, x1, y1 = box
    paint(lay, clip, linear(SKY, (0, y0), (0, y1)))
    if sun_r:
        r = sun_r * min(x1 - x0, y1 - y0)
        paint(lay, inter(clip, ellipse((x0 + sun[0] * (x1 - x0), y0 + sun[1] * (y1 - y0)), r)), SUN)
    far, near = hills(box)
    paint(lay, inter(clip, far), FAR)
    paint(lay, inter(clip, near), NEAR)


def peaks(box, sun=(0.72, 0.3), sun_r=0.13):
    """The photo mark in one colour: a sun over two peaks. Rolling hills alone read as a smile."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0

    def P(u, v):
        return (x0 + u * w, y0 + v * h)

    big = poly([P(-0.08, 1.1), P(0.34, 0.4), P(0.8, 1.1)])
    small = poly([P(0.42, 1.1), P(0.7, 0.62), P(1.1, 1.1)])
    mark = union(soften(union(big, small), 0.05 * min(w, h)),
                 ellipse(P(*sun), sun_r * min(w, h)))
    return mark


def photo_mono(clip, box, **kw):
    return inter(clip, peaks(box, **kw))


# The six directions. Each returns (background, foreground, monochrome).

def lift_the_corner():
    bg = layer()
    paint(bg, blank(255), linear([(0, (60, 72, 134)), (1, (32, 40, 86))], (0, -54), (0, 54)))

    h = 22.5
    a, b, c = (-2, h), (h, -5), (h, h)
    tip = reflect(c, a, b)
    card = rrect(-h, -h, h, h, 3.2)
    beyond = poly([a, (a[0], 60), (60, 60), (60, b[1]), b])
    under = inter(card, beyond)
    face = minus(card, beyond)
    bow = 1.6
    nx, ny = (b[1] - a[1]), -(b[0] - a[0])
    n = math.hypot(nx, ny)
    nx, ny = nx / n * bow, ny / n * bow
    outline = path(
        a,
        (lerp(a, tip, 0.35), (lerp(a, tip, 0.75)[0] - nx, lerp(a, tip, 0.75)[1] - ny), tip),
        ((lerp(tip, b, 0.25)[0] - nx, lerp(tip, b, 0.25)[1] - ny), lerp(tip, b, 0.65), b))
    flap = soften(poly(outline), 1.2)
    flap = union(flap, inter(poly([a, b, (b[0] - 4, b[1] - 4), (a[0] - 4, a[1] - 4)]), poly(path(
        a, lerp(a, tip, 0.5), lerp(b, tip, 0.5), b))))
    fold_mid = lerp(a, b, 0.5)

    fg = layer()
    shadow(fg, card, 0, 1.8, 2.6, (8, 12, 40), 0.5)
    photo(fg, under, (a[0], b[1], h, h), sun=(0.66, 0.5), sun_r=0.13)
    paint(fg, face, linear([(0, (252, 249, 242)), (1, (236, 229, 214))], (-h, -h), (h, h)))
    shadow(fg, inter(flap, blank(255)), 0.9, 1.3, 1.6, (70, 52, 30), 0.35)
    paint(fg, flap, linear([(0, (214, 204, 186)), (0.55, (246, 241, 230)), (1, (255, 253, 248))],
                           fold_mid, tip))

    gap = union(stroke(outline + [a], 2.8), flap)
    mono = union(minus(face, gap), flap,
                 photo_mono(minus(under, gap), (a[0], b[1], h, h), sun=(0.8, 0.52), sun_r=0.11))
    return bg, fg, mono


BRASS = [(0, (255, 234, 166)), (0.45, (228, 178, 86)), (1, (146, 96, 36))]
BRASS_IN = [(0, (140, 92, 34)), (0.6, (214, 164, 76)), (1, (250, 220, 150))]


def locket():
    bg = layer()
    paint(bg, blank(255), radial([(0, (104, 52, 98)), (1, (40, 18, 46))], (-16, -20), 84))

    hc, hrx, hry = (5, 3), 15.5, 19.5
    lc, lrx, lry = (-18, 3), 7.2, 19.5
    bc = (hc[0], hc[1] - hry - 2.6)
    holder = ellipse(hc, hrx, hry)
    lid = ellipse(lc, lrx, lry)
    bail = ring(bc, 4.2, 2.3)
    hinge = rrect(-12.2, hc[1] - 6, -9.6, hc[1] + 6, 1.1)
    window = ellipse(hc, hrx - 3.6, hry - 3.6)
    pbox = (hc[0] - hrx + 3.6, hc[1] - hry + 3.6, hc[0] + hrx - 3.6, hc[1] + hry - 3.6)

    fg = layer()
    shadow(fg, union(holder, lid, bail), 0, 2, 2.8, (16, 4, 20), 0.55)
    paint(fg, bail, linear(BRASS, (bc[0] - 4, bc[1] - 4), (bc[0] + 4, bc[1] + 4)))
    paint(fg, lid, linear(BRASS, (lc[0] - lrx, lc[1] - lry), (lc[0] + lrx, lc[1] + lry)))
    paint(fg, ellipse(lc, lrx - 1.8, lry - 2.4),
          linear(BRASS_IN, (lc[0] - lrx, lc[1] - lry), (lc[0] + lrx, lc[1] + lry)))
    paint(fg, ring(lc, lrx - 3.4, lrx - 4.1, lry - 5, lry - 5.7), (150, 98, 38), 0.8)
    paint(fg, hinge, linear([(0, (176, 120, 46)), (1, (110, 70, 24))], (-12, 0), (-9.6, 0)))
    paint(fg, holder, linear(BRASS, (hc[0] - hrx, hc[1] - hry), (hc[0] + hrx, hc[1] + hry)))
    paint(fg, ellipse(hc, hrx - 2.3, hry - 2.3),
          linear(BRASS_IN, (hc[0] - hrx, hc[1] - hry), (hc[0] + hrx, hc[1] + hry)))
    photo(fg, window, pbox, sun=(0.6, 0.4), sun_r=0.17)
    glint = poly([(hc[0] - 14, hc[1] - 2), (hc[0] - 4, hc[1] - 18), (hc[0] + 1, hc[1] - 18),
                  (hc[0] - 9, hc[1] - 2)])
    paint(fg, inter(window, blur(glint, 0.8)), (255, 255, 255), 0.22)

    gap = ring(hc, hrx - 2.2, hrx - 3.6, hry - 2.2, hry - 3.6)
    mono = union(minus(holder, union(gap, window)), photo_mono(ellipse(hc, hrx - 4.6, hry - 4.6), pbox,
                                                               sun=(0.64, 0.3), sun_r=0.13),
                 minus(lid, ring(lc, lrx - 2.6, lrx - 3.8, lry - 3.6, lry - 4.8)), bail, hinge)
    return bg, fg, mono


def the_ninth_key():
    bg = layer()
    paint(bg, blank(255), linear([(0, (250, 251, 252)), (1, (230, 234, 240))], (0, -54), (0, 54)))

    gap, r = 16.5, 6.7
    fg = layer()
    mono = blank()
    for i in range(3):
        for j in range(3):
            c = ((j - 1) * gap, (i - 1) * gap)
            key = ellipse(c, r)
            if (i, j) == (2, 2):
                paint(fg, blur(ellipse(c, r + 1.2), 2.4), (246, 140, 100), 0.6)
                shadow(fg, key, 0, 0.8, 1, (120, 50, 40), 0.25)
                box = (c[0] - r, c[1] - r, c[0] + r, c[1] + r)
                photo(fg, key, box, sun=(0.58, 0.36), sun_r=0.2)
                inner = (c[0] - r + 1.2, c[1] - r + 1.6, c[0] + r - 1.2, c[1] + r - 0.6)
                mono = union(mono, ring(c, r, r - 1.3), photo_mono(ellipse(c, r - 2.2), inner, sun_r=0.17))
            else:
                shadow(fg, key, 0, 0.7, 0.9, (60, 70, 92), 0.22)
                paint(fg, key, linear([(0, (208, 215, 226)), (1, (182, 191, 206))],
                                      (c[0], c[1] - r), (c[0], c[1] + r)))
                mono = union(mono, ellipse(c, 4.4))
    return bg, fg, mono


WAX = [(0, (214, 86, 70)), (0.5, (162, 42, 36)), (1, (100, 22, 24))]


def sealed():
    bg = layer()
    paint(bg, blank(255), linear([(0, (238, 227, 205)), (1, (220, 202, 172))], (0, -54), (0, 54)))
    flap = poly([(-60, -60), (60, -60), (60, -44), (0, 4), (-60, -44)])
    paint(bg, minus(blur(shift(flap, 0, 1.4), 1.3), flap), (120, 88, 48), 0.4)
    paint(bg, flap, linear([(0, (244, 236, 218)), (1, (232, 218, 192))], (0, -40), (0, 4)))

    c = (0, 4)
    outline = []
    for k in range(360):
        t = k / 360 * 2 * math.pi
        r = 18.2 + 1.0 * math.sin(5 * t + 0.3) + 0.7 * math.sin(9 * t + 1.7) + 0.45 * math.sin(14 * t + 0.9)
        outline.append((c[0] + r * math.cos(t), c[1] + r * math.sin(t)))
    blob = poly(outline)
    disc = ellipse(c, 12.4)
    lip = ring(c, 14.2, 12.4)
    ebox = (c[0] - 8, c[1] - 7.5, c[0] + 8, c[1] + 6)
    emblem = inter(rrect(ebox[0], ebox[1] - 2, ebox[2], ebox[3], 0.6), peaks(ebox, sun_r=0.15))

    fg = layer()
    shadow(fg, blob, 0.4, 1.8, 2.2, (80, 40, 12), 0.5)
    paint(fg, blob, linear(WAX, (c[0] - 14, c[1] - 16), (c[0] + 14, c[1] + 16)))
    paint(fg, lip, linear([(0, (236, 120, 100)), (1, (128, 30, 28))], (c[0] - 10, c[1] - 10),
                          (c[0] + 10, c[1] + 10)))
    paint(fg, disc, linear([(0, (116, 26, 26)), (1, (178, 52, 44))], (c[0] - 9, c[1] - 9),
                           (c[0] + 9, c[1] + 9)))
    paint(fg, shift(emblem, 0.5, 0.6), (96, 18, 20), 0.8)
    paint(fg, emblem, linear([(0, (226, 104, 86)), (1, (184, 58, 48))], (c[0], c[1] - 8), (c[0], c[1] + 8)))
    paint(fg, inter(blob, blur(ellipse((c[0] - 9, c[1] - 10), 4), 2.2)), (255, 210, 190), 0.35)

    mono = minus(blob, union(ring(c, 13.6, 12.4), emblem))
    return bg, fg, mono


def eclipse():
    bg = layer()
    paint(bg, blank(255), radial([(0, (38, 44, 92)), (1, (10, 13, 32))], (4, 4), 76))

    sc, R = (0, 0), 18
    mc, Rm = (-1.9, -1.8), 15.2
    disc = ellipse(sc, R)
    moon = ellipse(mc, Rm)
    off = math.hypot(mc[0] - sc[0], mc[1] - sc[1])
    ux, uy = (sc[0] - mc[0]) / off, (sc[1] - mc[1]) / off
    mid = (R + Rm - off) / 2
    bead = (sc[0] + ux * mid, sc[1] + uy * mid)

    fg = layer()
    paint(fg, blank(255), radial([(0, (255, 204, 146, 210)), (0.5, (255, 156, 112, 90)),
                                  (1, (255, 120, 100, 0))], sc, 34))
    photo(fg, disc, (sc[0] - R, sc[1] - R, sc[0] + R, sc[1] + R), sun_r=0)
    paint(fg, moon, radial([(0, (26, 30, 64)), (1, (13, 16, 38))], mc, Rm))
    paint(fg, blur(ellipse(bead, 4), 3), (255, 236, 200), 0.55)
    paint(fg, blur(ellipse(bead, 1.6), 0.9), (255, 252, 240), 1.0)

    mono = minus(disc, moon)
    return bg, fg, mono


def chameleon():
    bg = layer()
    paint(bg, blank(255), linear([(0, (242, 245, 228)), (1, (222, 233, 200))], (0, -54), (0, 54)))

    dx, dy = 2, -3
    def P(x, y):
        return (x + dx, y + dy)

    body = poly(path(
        P(24, -2),
        (P(21, -9), P(15, -16), P(8, -19.5)),
        (P(6.5, -17), P(5, -14.5), P(3.5, -12.5)),
        (P(-1, -17), P(-12, -17.5), P(-17.5, -8)),
        (P(-20, -3.5), P(-21, 1), P(-20.5, 6)),
        P(-12, 8),
        (P(-6, 11), P(6, 10), P(12, 5.5)),
        (P(16, 4), P(21, 1.5), P(24, -2))))
    centre, turns = P(-11.5, 13.5), 1.35
    start = P(-17, 3)
    a0 = math.atan2(start[1] - centre[1], start[0] - centre[0])
    r0 = math.hypot(start[0] - centre[0], start[1] - centre[1])
    steps = 140
    spiral, widths = [], []
    for k in range(steps + 1):
        t = k / steps
        a = a0 - t * turns * 2 * math.pi
        r = r0 + (2.6 - r0) * t
        spiral.append((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a)))
        widths.append(7 + (1.6 - 7) * t ** 0.85)
    tail = ribbon(spiral, widths)
    silhouette = soften(union(body, tail), 0.5)
    front_leg = stroke([P(6, 7.5), P(8, 13), P(11.5, 13.5)], 2.6)
    back_leg = stroke([P(-5, 9), P(-4, 14), P(-0.5, 14.5)], 2.6)
    legs = union(front_leg, back_leg)
    eye_c, pupil_c = P(12.4, -6.6), P(13.7, -6.9)
    eye = ellipse(eye_c, 5.2)
    mouth = stroke(path(P(23.4, -1.6), (P(21, -0.4), P(18.5, 0.4), P(15.5, 0.6))), 0.9)
    bands = union(*[poly([P(x, -20), P(x + 3, -20), P(x - 3, 12), P(x - 6, 12)]) for x in (-7, 0)])

    fg = layer()
    paint(fg, front_leg, (58, 124, 68))
    paint(fg, silhouette, radial([(0, (214, 228, 186)), (0.3, (172, 207, 142)), (0.46, (108, 174, 102)),
                                  (0.72, (62, 148, 80)), (1, (40, 128, 68))], centre, 36))
    paint(fg, minus(back_leg, body), (58, 124, 68))
    paint(fg, inter(body, bands), (255, 255, 255), 0.14)
    paint(fg, inter(body, blur(ellipse(P(0, 10), 16, 3.6), 1.2)), (232, 244, 200), 0.5)
    paint(fg, mouth, (34, 86, 46), 0.7)
    paint(fg, ring(eye_c, 5.6, 5.2), (34, 92, 48), 0.6)
    paint(fg, eye, radial([(0, (196, 226, 150)), (1, (98, 166, 88))], P(11.6, -7.6), 6))
    paint(fg, ellipse(pupil_c, 1.9), (24, 36, 26))
    paint(fg, ellipse(P(13.1, -7.6), 0.6), (255, 255, 255), 0.9)

    mono = union(minus(union(silhouette, legs), union(ellipse(eye_c, 4.4), mouth)), ellipse(pupil_c, 2.2))
    return bg, fg, mono


DIRECTIONS = [
    ("Lift the corner", "An ordinary card on the screen. Lift one corner and your photos are underneath.",
     lift_the_corner),
    ("Locket", "The oldest way to keep a private photo close: a locket only you open.", locket),
    ("The ninth key", "A keypad like any other, except the = key opens onto your photos.", the_ninth_key),
    ("Sealed", "A wax seal on an envelope. What is inside stays closed until you open it.", sealed),
    ("Eclipse", "Something bright, kept almost entirely out of view, with only a ring of light showing.",
     eclipse),
    ("Chameleon", "The animal that hides by looking like what is around it, as the app does.", chameleon),
]


# Rendering at launcher and store sizes.

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


# The comparison sheet.

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


def label(draw, x, y, text, size=17, fill=MUTED, centre_w=None):
    fnt = font("regular", size)
    if centre_w:
        x += (centre_w - draw.textlength(text, font=fnt)) / 2
    draw.text((x, y), text, font=fnt, fill=fill)


def wallpaper(w, h, stops):
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    return ramp(t, stops)


def launcher(canvas, x, y, w, h, icon, dark):
    wall = wallpaper(w, h, WALL_DARK if dark else WALL_LIGHT)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=14, fill=255)
    wall.putalpha(m)
    canvas.alpha_composite(wall, (x, y))
    ix = x + (w - 48) // 2
    iy = y + 22
    canvas.alpha_composite(masked(icon, "round"), (ix, iy))
    d = ImageDraw.Draw(canvas)
    fnt = font("regular", 13)
    text = "SecureVault"
    d.text((x + (w - d.textlength(text, font=fnt)) / 2, iy + 56), text, font=fnt,
           fill=(255, 255, 255) if dark else (40, 40, 44))


def cell(canvas, x, y, number, title, idea, bg, fg, mono):
    d = ImageDraw.Draw(canvas)
    d.text((x, y), f"{number}  {title}", font=font("semibold", 36), fill=INK)
    ty = y + 52
    for line in wrap(d, idea, font("regular", 22), 760):
        d.text((x, ty), line, font=font("regular", 22), fill=MUTED)
        ty += 30

    top = y + 124
    store = full_icon(bg, fg, 512)
    drop(canvas, masked(store, "play"), x, top, r=14, opacity=70)
    label(d, x, top + 520, "512 store icon, as Play rounds it", centre_w=512)

    small = full_icon(bg, fg, 104)
    col = x + 548
    for k, (img, text) in enumerate([(masked(small, "round"), "Round"),
                                     (masked(small, "squircle"), "Squircle"),
                                     (themed(mono, 104, *THEME_LIGHT), "Themed, light"),
                                     (themed(mono, 104, *THEME_DARK), "Themed, dark")]):
        cx = col + (k % 2) * 128
        cy = top + (k // 2) * 140
        drop(canvas, img, cx, cy, r=6, opacity=50)
        label(d, cx - 12, cy + 108, text, size=15, centre_w=128)

    icon48 = full_icon(bg, fg, 48)
    launcher(canvas, col, top + 290, 232, 104, icon48, dark=False)
    launcher(canvas, col, top + 408, 232, 104, icon48, dark=True)
    label(d, col, top + 520, "48 px on two wallpapers", size=15, centre_w=232)


def main():
    previews = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if previews:
        previews.mkdir(parents=True, exist_ok=True)

    cw, ch, gx, gy, margin, head = 800, 700, 64, 40, 72, 170
    w = margin * 2 + cw * 3 + gx * 2
    h = head + margin + ch * 2 + gy
    canvas = Image.new("RGBA", (w, h), rgba(PAPER))
    d = ImageDraw.Draw(canvas)
    d.text((margin, 56), "SecureVault icon directions", font=font("semibold", 52), fill=INK)
    d.text((margin, 124), "Each one as the store icon, in the round and squircle masks, as the themed "
           "monochrome icon, and at 48 px on a light and a dark wallpaper.", font=font("regular", 24), fill=MUTED)

    for k, (title, idea, draw) in enumerate(DIRECTIONS):
        bg, fg, mono = draw()
        x = margin + (k % 3) * (cw + gx)
        y = head + 30 + (k // 3) * (ch + gy)
        cell(canvas, x, y, k + 1, title, idea, bg, fg, mono)
        if previews:
            slug = title.lower().replace(" ", "-")
            full_icon(bg, fg, 512).convert("RGB").save(previews / f"{k + 1}-{slug}-512.png")
            visible(mono, 512).save(previews / f"{k + 1}-{slug}-mono.png")
        print(f"drew {title}")

    SHEET.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(SHEET, optimize=True)
    print(f"wrote {SHEET.relative_to(ROOT)} ({w}x{h})")


if __name__ == "__main__":
    main()
