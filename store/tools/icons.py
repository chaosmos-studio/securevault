"""Draws SecureVault's launcher icons: the vault itself and its four disguises.

Writes adaptive icon layers into android/app/src/main/res, square previews for
the app into assets/icons, and the 512 px store icon into store/.

Usage: python3 store/tools/icons.py   (from the repo root)
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "android/app/src/main/res"
S = 1728  # working size of one 108 dp layer, 16 px per dp
DP = S / 108
WHITE = (255, 255, 255, 255)

ICONS = {
    "ic_shield": {"bg": (30, 94, 80), "draw": "vault"},
    "ic_calculator": {"bg": (47, 91, 176), "draw": "calculator"},
    "ic_notes": {"bg": (232, 166, 0), "draw": "notes"},
    "ic_clock": {"bg": (38, 76, 150), "draw": "clock"},
    "ic_mood": {"bg": (47, 143, 131), "draw": "mood"},
}

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def c(x):
    """dp from the layer's centre to pixels from its top-left."""
    return S / 2 + x * DP


def line(d, pts, w, fill=WHITE):
    d.line([(c(x), c(y)) for x, y in pts], fill=fill, width=int(w * DP), joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = w * DP / 2
        d.ellipse([c(x) - r, c(y) - r, c(x) + r, c(y) + r], fill=fill)


def draw_vault(d, bg):
    r = 21
    d.ellipse([c(-r), c(-r), c(r), c(r)], outline=WHITE, width=int(5 * DP))
    for k in range(8):
        a = k * math.pi / 4
        x, y = math.cos(a) * (r + 5.5), math.sin(a) * (r + 5.5)
        d.ellipse([c(x) - 2.2 * DP, c(y) - 2.2 * DP, c(x) + 2.2 * DP, c(y) + 2.2 * DP], fill=WHITE)
    d.ellipse([c(-5), c(-9), c(5), c(1)], fill=WHITE)
    d.polygon([(c(-3.2), c(-2)), (c(3.2), c(-2)), (c(4.2), c(10)), (c(-4.2), c(10))], fill=WHITE)


def draw_calculator(d, bg):
    w = 4.2
    line(d, [(-15, -9), (-3, -9)], w)
    line(d, [(-9, -15), (-9, -3)], w)
    line(d, [(3, -9), (15, -9)], w)
    line(d, [(-13.5, 4.5), (-4.5, 13.5)], w)
    line(d, [(-13.5, 13.5), (-4.5, 4.5)], w)
    d.ellipse([c(1), c(1), c(17), c(17)], fill=(215, 227, 250, 255))
    line(d, [(5, 6.6), (13, 6.6)], 3, fill=bg + (255,))
    line(d, [(5, 11.4), (13, 11.4)], 3, fill=bg + (255,))


def draw_notes(d, bg):
    left, top, right, bottom, fold = -15, -19, 15, 19, 9
    d.polygon([(c(left), c(top)), (c(right - fold), c(top)), (c(right), c(top + fold)),
               (c(right), c(bottom)), (c(left), c(bottom))], fill=WHITE)
    d.polygon([(c(right - fold), c(top)), (c(right - fold), c(top + fold)), (c(right), c(top + fold))],
              fill=(248, 214, 130, 255))
    ink = (176, 122, 0, 255)
    for y, end in ((-6, 8), (1, 8), (8, 1)):
        line(d, [(-9, y), (end, y)], 2.6, fill=ink)


def draw_clock(d, bg):
    r = 21
    d.ellipse([c(-r), c(-r), c(r), c(r)], fill=WHITE)
    ink = bg + (255,)
    for k in range(12):
        a = k * math.pi / 6
        x, y = math.sin(a) * 16.5, -math.cos(a) * 16.5
        s = 1.6 if k % 3 == 0 else 0.9
        d.ellipse([c(x - s), c(y - s), c(x + s), c(y + s)], fill=ink)
    line(d, [(0, 0), (0, -12)], 3.2, fill=ink)
    line(d, [(0, 0), (8, 5)], 3.2, fill=ink)
    d.ellipse([c(-2.6), c(-2.6), c(2.6), c(2.6)], fill=(230, 120, 80, 255))


def draw_mood(d, bg):
    r = 20
    d.ellipse([c(-r), c(-r), c(r), c(r)], outline=WHITE, width=int(4.4 * DP))
    for x in (-7, 7):
        d.ellipse([c(x - 2.6), c(-7.6), c(x + 2.6), c(-2.4)], fill=WHITE)
    smile = [(10 * math.cos(math.radians(a)), 1.5 + 8.5 * math.sin(math.radians(a)))
             for a in range(28, 153, 4)]
    line(d, smile, 4.2)


def foreground(name):
    spec = ICONS[name]
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    globals()["draw_" + spec["draw"]](ImageDraw.Draw(img), spec["bg"])
    return img


def squircle_mask(size):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.3, fill=255)
    return mask


def full_icon(name, size):
    """The layers composed and cropped like a launcher shows them."""
    fg = foreground(name)
    bg = Image.new("RGBA", (S, S), ICONS[name]["bg"] + (255,))
    bg.alpha_composite(fg)
    inset = int(S * 18 / 108)  # launchers show the middle 72 of 108 dp
    shown = bg.crop((inset, inset, S - inset, S - inset)).resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(shown, (0, 0), squircle_mask(size))
    return out


def main():
    (RES / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    colors = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    for name, spec in ICONS.items():
        fg = foreground(name)
        for density, scale in DENSITIES.items():
            folder = RES / f"mipmap-{density}"
            folder.mkdir(exist_ok=True)
            fg.resize((round(108 * scale), round(108 * scale)), Image.LANCZOS).save(
                folder / f"{name}_foreground.png")
            full_icon(name, round(48 * scale)).save(folder / f"{name}.png")
        (RES / "mipmap-anydpi-v26" / f"{name}.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            f'    <background android:drawable="@color/{name}_background" />\n'
            f'    <foreground android:drawable="@mipmap/{name}_foreground" />\n'
            f'    <monochrome android:drawable="@mipmap/{name}_foreground" />\n'
            "</adaptive-icon>\n")
        colors.append(f'    <color name="{name}_background">#{"%02X%02X%02X" % spec["bg"]}</color>')
    colors.append("</resources>")
    (RES / "values" / "icon_colors.xml").write_text("\n".join(colors) + "\n")

    previews = {"ic_shield": "shield_icon", "ic_calculator": "calculator_icon",
                "ic_notes": "notes_icon", "ic_clock": "clock_icon", "ic_mood": "mood_icon"}
    for name, out in previews.items():
        full_icon(name, 256).save(ROOT / "assets/icons" / f"{out}.png")

    store = Image.new("RGBA", (S, S), ICONS["ic_shield"]["bg"] + (255,))
    store.alpha_composite(foreground("ic_shield"))
    inset = int(S * 18 / 108)
    store.crop((inset, inset, S - inset, S - inset)).resize((512, 512), Image.LANCZOS).convert(
        "RGB").save(ROOT / "store/icon-512.png")


if __name__ == "__main__":
    main()
