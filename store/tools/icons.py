"""Draws SecureVault's launcher icons: the vault's chameleon and the four disguises.

Each icon is an adaptive icon: a flat background colour, a foreground layer and
a monochrome layer for themed icons, 108 dp with the middle 72 dp shown. The
disguises share one grid, one stroke weight and one corner radius, and stay
plain enough to sit among a phone's own system icons.

Usage, from the repo root:
  python3 store/tools/icons.py            writes the icons into the app
  python3 store/tools/icons.py <dir>      writes previews into <dir> only

Writes the layers and the square icons older Android versions use into
android/app/src/main/res, previews into assets/icons for the app, and the 512 px
store icon into store/.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from draw import (ROOT, blank, ellipse, flat, full_icon, inter, layer, minus, paint, path, poly,
                  radial, ring, rrect, soften, stroke, union, visible)

RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
WHITE = (255, 255, 255)

STROKE = 3.8  # every line in a disguise glyph
CORNER = 4    # every rounded corner in a disguise glyph


def spiral_edges(centre, a0, r0, b, k, a1, n=220):
    """Outer and inner edges of a logarithmic spiral band whose width is k times its radius."""
    outer, inner, mid = [], [], []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        r = r0 * math.exp(b * (a - a0))
        u = (math.cos(a), math.sin(a))
        outer.append((centre[0] + r * (1 + k / 2) * u[0], centre[1] + r * (1 + k / 2) * u[1]))
        inner.append((centre[0] + r * (1 - k / 2) * u[0], centre[1] + r * (1 - k / 2) * u[1]))
        mid.append((centre[0] + r * u[0], centre[1] + r * u[1], r))
    return outer, inner, mid


def vault():
    """A chameleon whose tail fades into what is behind it."""
    oy = -2.5

    def P(x, y):
        return (x, y + oy)

    centre = P(-11.5, 12.5)
    a0, r0, b, k = math.radians(-108), 11, math.log(2.4) / (2 * math.pi), 0.36
    a1 = a0 + math.log(2.4 / r0) / b
    outer, inner, mid = spiral_edges(centre, a0, r0, b, k, a1)
    tip = mid[-1]
    tail = union(poly(outer + inner[::-1]), ellipse((tip[0], tip[1]), tip[2] * k / 2))

    def heading(a, rr, sign):
        dx = rr * (b * math.cos(a) - math.sin(a)) * sign
        dy = rr * (b * math.sin(a) + math.cos(a)) * sign
        n = math.hypot(dx, dy)
        return dx / n, dy / n

    po, pi = outer[0], inner[0]
    do = heading(a0, 1, -1)  # the way the outer edge leaves the body
    di = heading(a0, 1, 1)   # the way the inner edge runs back into the body
    snout, peak, notch = P(24, -1), P(7.5, -19.5), P(3, -11.5)
    body = poly(path(
        snout,
        (P(20, -8.5), P(13.5, -16), peak),
        (P(6, -16.5), P(4.2, -13.2), notch),
        (P(-3, -18.5), (po[0] - do[0] * 9, po[1] - do[1] * 9), po),
        pi,
        ((pi[0] + di[0] * 3, pi[1] + di[1] * 3), P(-6, 7.6), P(4, 9.5)),
        (P(8, 8.5), P(10, 7), P(12, 5)),
        (P(16, 4), P(21, 2), snout)))
    silhouette = soften(union(body, tail), 0.4)

    front_leg = stroke([P(6.5, 8), P(8, 13.6), P(11.4, 14)], 2.5)
    back_leg = stroke([P(-2, 9.6), P(-1.1, 14.6), P(2.3, 15)], 2.5)
    belly = poly(path(P(16, 2.4), (P(6, 6.4), P(-6, 7.2), P(-17, 3.4)), P(-17, 24), P(16, 24)))
    eye_c, iris_r = P(12.6, -6.2), 2.9
    pupil_c = (eye_c[0] + 0.7, eye_c[1] - 0.2)
    eye = ellipse(eye_c, 5.4)
    mouth = stroke(path(P(23.2, -0.6), (P(20.5, 0.6), P(18, 1.1), P(15.6, 0.9)),
                        (P(15, 0.8), P(14.6, 0.5), P(14.4, 0.1))), 0.85)

    jade, deep = (44, 128, 88), (28, 96, 64)
    fg = layer()
    paint(fg, front_leg, deep)
    paint(fg, silhouette, radial([(0, (156, 196, 156)), (0.45, (112, 172, 128)), (0.8, jade), (1, jade)],
                                 centre, r0 * (1 + k / 2)))
    paint(fg, minus(body, ellipse(centre, r0 * 0.9)), jade)
    paint(fg, minus(inter(body, belly), ellipse(centre, r0 * 0.9)), (66, 150, 104))
    paint(fg, minus(back_leg, body), deep)
    paint(fg, mouth, deep)
    paint(fg, eye, (84, 160, 112))
    paint(fg, ring(eye_c, 5.4, 4.7), deep, 0.55)
    paint(fg, ellipse(eye_c, iris_r), (242, 236, 196))
    paint(fg, ellipse(pupil_c, 1.6), (20, 38, 28))

    mono = union(minus(union(silhouette, front_leg, back_leg), union(ring(eye_c, 5.4, 3.9), mouth)),
                 ellipse(pupil_c, 1.7))
    return (233, 238, 222), fg, mono


def calculator():
    fg, mono = layer(), blank()
    plus = union(stroke([(-15, -9), (-3, -9)], STROKE), stroke([(-9, -15), (-9, -3)], STROKE))
    minus_sign = stroke([(3, -9), (15, -9)], STROKE)
    times = union(stroke([(-13.2, 4.8), (-4.8, 13.2)], STROKE), stroke([(-13.2, 13.2), (-4.8, 4.8)], STROKE))
    key = ellipse((9, 9), 9)
    equals = union(stroke([(5, 6.4), (13, 6.4)], STROKE), stroke([(5, 11.6), (13, 11.6)], STROKE))
    glyphs = union(plus, minus_sign, times)
    paint(fg, glyphs, WHITE)
    paint(fg, key, (206, 222, 255))
    paint(fg, equals, (47, 107, 219))
    return (47, 107, 219), fg, union(glyphs, minus(key, equals))


def notes():
    fg = layer()
    page = rrect(-15, -19, 15, 19, CORNER)
    band = minus(page, poly([(-20, -11), (20, -11), (20, 30), (-20, 30)]))
    lines = union(*[stroke([(-8.5, y), (8.5, y)], STROKE) for y in (-3, 4, 11)])
    paint(fg, page, WHITE)
    paint(fg, band, (201, 132, 0))
    paint(fg, lines, (232, 170, 30))
    mono = minus(page, union(lines, poly([(-20, -11.9), (20, -11.9), (20, -10.1), (-20, -10.1)])))
    return (242, 176, 30), fg, mono


def clock():
    fg = layer()
    face = ellipse((0, 0), 19.5)
    quarters = (0, math.pi / 2, math.pi, 3 * math.pi / 2)

    def hand(angle, length):
        return stroke([(0, 0), (length * math.sin(angle), -length * math.cos(angle))], STROKE)

    def ticks(r_out, r_in):
        return union(*[stroke([(r_out * math.sin(a), -r_out * math.cos(a)),
                               (r_in * math.sin(a), -r_in * math.cos(a))], STROKE) for a in quarters])

    hands = union(hand(math.radians(-55), 8.6), hand(math.radians(60), 12.6))
    navy = (30, 43, 77)
    paint(fg, face, WHITE)
    paint(fg, ticks(15.2, 14), (150, 160, 186))
    paint(fg, hands, navy)
    paint(fg, ellipse((0, 0), 2.6), (240, 112, 72))
    mono = union(ring((0, 0), 19.5, 15.9), hands, ellipse((0, 0), 2.6), ticks(12.2, 11.4))
    return navy, fg, mono


def mood():
    fg = layer()
    face = ellipse((0, 0), 19.5)
    eyes = union(ellipse((-6.8, -5), 2.7), ellipse((6.8, -5), 2.7))
    smile = stroke([(9 * math.cos(math.radians(a)), 1.6 + 7.4 * math.sin(math.radians(a)))
                    for a in range(20, 161, 4)], STROKE)
    teal = (24, 150, 128)
    paint(fg, face, WHITE)
    paint(fg, union(eyes, smile), teal)
    return teal, fg, minus(face, union(eyes, smile))


ICONS = {
    "ic_vault": vault,
    "ic_calculator": calculator,
    "ic_notes": notes,
    "ic_clock": clock,
    "ic_mood": mood,
}
PREVIEWS = {"ic_vault": "vault_icon", "ic_calculator": "calculator_icon", "ic_notes": "notes_icon",
            "ic_clock": "clock_icon", "ic_mood": "mood_icon"}


def rounded(img):
    """The square icon with the corners older launchers and the app's own screens show."""
    m = Image.new("L", (img.width * 4, img.height * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, m.width - 1, m.height - 1], radius=m.width * 0.3, fill=255)
    out = img.convert("RGBA")
    out.putalpha(m.resize(img.size, Image.LANCZOS))
    return out


def drawn():
    """Every icon as (name, background colour, background layer, foreground, monochrome)."""
    for name, draw in ICONS.items():
        bg_color, fg, mono = draw()
        yield name, bg_color, flat(bg_color), fg, mono


def write_app():
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    colors = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    for name, bg_color, bg, fg, mono in drawn():
        mono_layer = Image.new("RGBA", mono.size, (255, 255, 255, 0))
        mono_layer.putalpha(mono)
        for density, scale in DENSITIES.items():
            folder = RES / f"mipmap-{density}"
            folder.mkdir(exist_ok=True)
            side = round(108 * scale)
            fg.resize((side, side), Image.LANCZOS).save(folder / f"{name}_foreground.png")
            mono_layer.resize((side, side), Image.LANCZOS).save(folder / f"{name}_monochrome.png")
            rounded(full_icon(bg, fg, round(48 * scale))).save(folder / f"{name}.png")
        (anydpi / f"{name}.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            f'    <background android:drawable="@color/{name}_background" />\n'
            f'    <foreground android:drawable="@mipmap/{name}_foreground" />\n'
            f'    <monochrome android:drawable="@mipmap/{name}_monochrome" />\n'
            "</adaptive-icon>\n")
        colors.append(f'    <color name="{name}_background">#{"%02X%02X%02X" % bg_color}</color>')
        rounded(full_icon(bg, fg, 256)).save(ROOT / "assets/icons" / f"{PREVIEWS[name]}.png")
        if name == "ic_vault":
            full_icon(bg, fg, 512).convert("RGB").save(ROOT / "store/icon-512.png")
        print(f"wrote {name}")
    colors.append("</resources>")
    (RES / "values" / "icon_colors.xml").write_text("\n".join(colors) + "\n")


def write_previews(out):
    out.mkdir(parents=True, exist_ok=True)
    for name, _, bg, fg, mono in drawn():
        full_icon(bg, fg, 512).convert("RGB").save(out / f"{name}-512.png")
        visible(mono, 512).save(out / f"{name}-mono.png")
        print(f"previewed {name}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        write_previews(Path(sys.argv[1]))
    else:
        write_app()
