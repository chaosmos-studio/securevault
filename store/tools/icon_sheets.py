"""Review sheets for SecureVault's icons.

  docs/redesign/icon-final.png      the refined chameleon, and at 48 px beside
                                    the other finalists from icon-options.png
  docs/redesign/disguise-icons.png  the disguise icons beside their old ones and
                                    among system-style icons, as on a home screen

Usage, from the repo root:
  python3 store/tools/icon_sheets.py
"""

import io
import math
import subprocess

from PIL import Image, ImageDraw

import icon_options
import icons
from draw import (INK, MUTED, PAPER, ROOT, THEME_DARK, THEME_LIGHT, drop, ellipse, flat, font, full_icon,
                  home_row, label, layer, masked, minus, paint, poly, ring, rrect, rgba, themed, union)

FINAL = ROOT / "docs/redesign/icon-final.png"
DISGUISES = ROOT / "docs/redesign/disguise-icons.png"

# The disguise icons as players have them in 1.0.3, and as 1.1 drew them before this redesign.
OLD = {"1.0.3": "main", "1.1 draft": "8405f67"}


def git_png(ref, path):
    data = subprocess.run(["git", "show", f"{ref}:{path}"], cwd=ROOT, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


# A few system-style icons to compare against, drawn here in a generic stock style.

def messages():
    fg = layer()
    bubble = union(rrect(-17, -14, 17, 10, 9), poly([(-9, 6), (-13, 17), (-1, 9)]))
    dots = union(*[ellipse((x, -2), 2.6) for x in (-8, 0, 8)])
    paint(fg, bubble, (255, 255, 255))
    paint(fg, dots, (26, 115, 232))
    return (26, 115, 232), fg, minus(bubble, dots)


def camera():
    fg = layer()
    body = union(rrect(-19, -11, 19, 15, 5), rrect(-7, -16, 7, -8, 3))
    lens = ellipse((0, 2), 8.2)
    paint(fg, body, (255, 255, 255))
    paint(fg, lens, (60, 64, 72))
    paint(fg, ellipse((0, 2), 4.4), (140, 160, 190))
    return (60, 64, 72), fg, minus(body, ring((0, 2), 8.2, 5.6))


def settings():
    fg = layer()
    pts = []
    for k in range(720):
        a = k / 720 * 2 * math.pi
        tooth = 0.5 + 0.5 * math.tanh(6 * math.cos(8 * a))
        r = 14.5 + 4.2 * tooth
        pts.append((r * math.cos(a), r * math.sin(a)))
    gear = minus(poly(pts), ellipse((0, 0), 6.4))
    paint(fg, gear, (255, 255, 255))
    return (95, 99, 104), fg, gear


SYSTEM = {"Messages": messages, "Camera": camera, "Settings": settings}
DISGUISE_NAMES = {"ic_calculator": "Calculator", "ic_notes": "Notes", "ic_clock": "Clock", "ic_mood": "MoodSpace"}
OLD_FILES = {"ic_calculator": "calculator_icon", "ic_notes": "notes_icon", "ic_clock": "clock_icon",
             "ic_mood": "mood_icon"}


def layers(draw_fn):
    bg_color, fg, mono = draw_fn()
    return flat(bg_color), fg, mono


def header(canvas, title, sub, margin=72):
    d = ImageDraw.Draw(canvas)
    d.text((margin, 56), title, font=font("semibold", 52), fill=INK)
    d.text((margin, 124), sub, font=font("regular", 24), fill=MUTED)


def final_sheet():
    w, h, margin = 1720, 830, 72
    canvas = Image.new("RGBA", (w, h), rgba(PAPER))
    header(canvas, "SecureVault icon: the chameleon, refined",
           "A more graphic body, one clean spiral for the tail, and the tail still fading into its background.")
    d = ImageDraw.Draw(canvas)
    bg, fg, mono = layers(icons.vault)
    top = 210
    drop(canvas, masked(full_icon(bg, fg, 512), "play"), margin, top, r=14, opacity=70)
    label(d, margin, top + 520, "512 store icon, as Play rounds it", centre_w=512)

    small = full_icon(bg, fg, 132)
    x0 = margin + 576
    for k, (img, text) in enumerate([(masked(small, "round"), "Round"), (masked(small, "squircle"), "Squircle"),
                                     (themed(mono, 132, *THEME_LIGHT), "Themed, light"),
                                     (themed(mono, 132, *THEME_DARK), "Themed, dark")]):
        x = x0 + k * 164
        drop(canvas, img, x, top, r=6, opacity=50)
        label(d, x - 16, top + 140, text, size=16, centre_w=164)

    picked = {name: fn for name, _, fn in icon_options.DIRECTIONS}
    tiles = [(icon_options.lift_the_corner, "Corner"), (icon_options.locket, "Locket"),
             (picked["Chameleon"], "Picked"), (icons.vault, "Refined")]
    row = []
    for fn, name in tiles:
        tb, tf, _ = layers(fn) if fn is icons.vault else fn()
        row.append((masked(full_icon(tb, tf, 48), "round"), name))
    y = top + 230
    label(d, x0, y, "At 48 px beside the other finalists, and the chameleon as picked", size=20, fill=INK)
    rw, rh = home_row(canvas, x0, y + 40, row, dark=False)
    home_row(canvas, x0, y + 40 + rh + 20, row, dark=True)
    canvas.convert("RGB").save(FINAL, optimize=True)
    print(f"wrote {FINAL.relative_to(ROOT)}")


def disguise_sheet():
    col, margin = 560, 72
    w = margin * 2 + col * 4
    h = 1620
    canvas = Image.new("RGBA", (w, h), rgba(PAPER))
    header(canvas, "Disguise icons",
           "One grid, one 3.8 dp stroke, one 4 dp corner. Plain stock colours, so each sits among a phone's "
           "own icons, and a monochrome layer for themed icons.")
    d = ImageDraw.Draw(canvas)
    new = {name: layers(getattr(icons, fn)) for name, fn in
           {"ic_calculator": "calculator", "ic_notes": "notes", "ic_clock": "clock", "ic_mood": "mood"}.items()}

    top = 200
    for k, (name, (bg, fg, mono)) in enumerate(new.items()):
        x = margin + k * col
        d.text((x, top), DISGUISE_NAMES[name], font=font("semibold", 34), fill=INK)
        drop(canvas, masked(full_icon(bg, fg, 512), "squircle"), x, top + 60, r=14, opacity=60)
        label(d, x, top + 580, "New, 512 px", centre_w=512)
        smalls = [(git_png(ref, f"assets/icons/{OLD_FILES[name]}.png").resize((112, 112), Image.LANCZOS), tag)
                  for tag, ref in OLD.items()]
        smalls += [(themed(mono, 112, *THEME_LIGHT), "Themed"), (themed(mono, 112, *THEME_DARK), "Themed")]
        for j, (img, tag) in enumerate(smalls):
            sx = x + j * 128
            drop(canvas, img, sx, top + 630, r=5, opacity=40)
            label(d, sx - 8, top + 748, tag, size=15, centre_w=128)

    def row_of(source, kind, size=48):
        out = []
        order = ["Messages", "ic_calculator", "Camera", "ic_notes", "ic_clock", "Settings", "ic_mood"]
        for key in order:
            if key in SYSTEM:
                bg, fg, mono = layers(SYSTEM[key])
                name = key
            else:
                bg, fg, mono = new[key]
                name = DISGUISE_NAMES[key]
                if source != "new":
                    old = git_png(OLD[source], f"assets/icons/{OLD_FILES[key]}.png").resize((size, size), Image.LANCZOS)
                    out.append((old, name))
                    continue
            if kind == "themed-light":
                out.append((themed(mono, size, *THEME_LIGHT), name))
            elif kind == "themed-dark":
                out.append((themed(mono, size, *THEME_DARK), name))
            else:
                out.append((masked(full_icon(bg, fg, size), kind), name))
        return out

    y = top + 820
    rows = [("New, among system-style icons: round icons, light wallpaper", "new", "round", False),
            ("New: squircle icons, dark wallpaper", "new", "squircle", True),
            ("New: themed icons, light", "new", "themed-light", False),
            ("New: themed icons, dark", "new", "themed-dark", True),
            ("Before (1.0.3), among the same icons", "1.0.3", "round", False),
            ("Before (1.1 draft), among the same icons", "1.1 draft", "round", True)]
    for k, (title, source, kind, dark) in enumerate(rows):
        x = margin + (k % 2) * (col * 2)
        yy = y + (k // 2) * 190
        label(d, x, yy, title, size=20, fill=INK)
        home_row(canvas, x, yy + 36, row_of(source, kind), dark=dark, size=48, gap=40)
    canvas.convert("RGB").save(DISGUISES, optimize=True)
    print(f"wrote {DISGUISES.relative_to(ROOT)}")


if __name__ == "__main__":
    final_sheet()
    disguise_sheet()
