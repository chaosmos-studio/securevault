"""Three looks for SecureVault's vault, each as static mock-ups of the same four screens.

The disguises stay stock-looking. These are only for the vault behind them, for 1.2.

Usage, from the repo root:
  python3 store/tools/sample_photos.py <photos>
  python3 store/tools/vault_looks.py <photos>

Writes docs/redesign/vault-look-options.png.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/redesign/vault-look-options.png"
W, H = 720, 1520  # one phone screen, 360 x 760 dp at 2 px per dp

FONT_FILES = {
    "rh": ROOT / "assets/fonts/RedHatText-Regular.otf",
    "rh-medium": ROOT / "assets/fonts/RedHatText-Medium.otf",
    "rh-semibold": ROOT / "assets/fonts/RedHatText-SemiBold.otf",
    "inter": "/usr/share/fonts/rsms-inter-fonts/Inter-Regular.ttf",
    "inter-medium": "/usr/share/fonts/rsms-inter-fonts/Inter-Medium.ttf",
    "inter-semibold": "/usr/share/fonts/rsms-inter-fonts/Inter-SemiBold.ttf",
    "inter-bold": "/usr/share/fonts/rsms-inter-fonts/InterDisplay-Bold.ttf",
    "serif": "/usr/share/fonts/google-noto/NotoSerif-Regular.ttf",
    "serif-semibold": "/usr/share/fonts/google-noto/NotoSerif-SemiBold.ttf",
    "serif-italic": "/usr/share/fonts/google-noto/NotoSerif-Italic.ttf",
    "mono": "/usr/share/fonts/liberation-mono-fonts/LiberationMono-Regular.ttf",
}
NOTES = [("Locker 14", "Code 2207, top row", "15:08", True),
         ("Passport", "Renew before March", "15 Nov", False),
         ("Gift ideas for Maa", "Silver earrings, the blue shawl", "9 Nov", False)]
SETTINGS = [("Disguise", [("Calculator", "")]),
            ("This vault", [("Name", "My vault"), ("Change PIN", ""), ("Back up and restore", "")]),
            ("Security", [("Lock", "Right away"), ("Vaults", "3")]),
            ("About", [("Contact", "hello@chaosmos.studio"), ("Source code", "GPL-3.0"), ("Made by", "Chaosmos")])]


def font(name, size):
    return ImageFont.truetype(str(FONT_FILES[name]), size)


def fit(img, w, h):
    """The photo cropped to fill w x h."""
    scale = max(w / img.width, h / img.height)
    big = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    x, y = (big.width - w) // 2, (big.height - h) // 2
    return big.crop((x, y, x + w, y + h))


def rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=r, fill=255)
    out = img.convert("RGBA")
    out.putalpha(m)
    return out


def shadow(canvas, box, r, opacity=60, blur=14, dy=6):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle([box[0], box[1] + dy, box[2], box[3] + dy], radius=r,
                                            fill=(30, 26, 20, opacity))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def spaced(d, xy, text, fnt, fill, spacing):
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=fnt, fill=fill)
        x += d.textlength(ch, font=fnt) + spacing
    return x


def right(d, x, y, text, fnt, fill):
    d.text((x - d.textlength(text, font=fnt), y), text, font=fnt, fill=fill)


def wrapped(d, xy, text, fnt, fill, width, leading):
    """Draws text in lines no wider than width and returns the y below them."""
    x, y = xy
    line = ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if d.textlength(trial, font=fnt) > width and line:
            d.text((x, y), line, font=fnt, fill=fill)
            y += leading
            line = word
        else:
            line = trial
    d.text((x, y), line, font=fnt, fill=fill)
    return y + leading


# Icons, drawn with strokes about 5 px wide.

def icon(d, kind, cx, cy, s, color, w=5):
    h = s / 2
    if kind == "lock":
        d.rounded_rectangle([cx - h * 0.8, cy - h * 0.1, cx + h * 0.8, cy + h * 0.9], radius=s * 0.12, outline=color, width=w)
        d.arc([cx - h * 0.5, cy - h * 0.95, cx + h * 0.5, cy + h * 0.1], 180, 360, fill=color, width=w)
        d.line([cx - h * 0.5, cy - h * 0.42, cx - h * 0.5, cy - h * 0.1], fill=color, width=w)
        d.line([cx + h * 0.5, cy - h * 0.42, cx + h * 0.5, cy - h * 0.1], fill=color, width=w)
    elif kind in ("left", "right"):
        k = -1 if kind == "left" else 1
        d.line([cx - k * h * 0.3, cy - h * 0.6, cx + k * h * 0.3, cy, cx - k * h * 0.3, cy + h * 0.6], fill=color, width=w, joint="curve")
    elif kind == "plus":
        d.line([cx - h * 0.6, cy, cx + h * 0.6, cy], fill=color, width=w)
        d.line([cx, cy - h * 0.6, cx, cy + h * 0.6], fill=color, width=w)
    elif kind == "share":
        d.line([cx - h * 0.6, cy - h * 0.1, cx - h * 0.6, cy + h * 0.7, cx + h * 0.6, cy + h * 0.7, cx + h * 0.6, cy - h * 0.1], fill=color, width=w, joint="curve")
        d.line([cx, cy - h * 0.8, cx, cy + h * 0.25], fill=color, width=w)
        d.line([cx - h * 0.35, cy - h * 0.45, cx, cy - h * 0.8, cx + h * 0.35, cy - h * 0.45], fill=color, width=w, joint="curve")
    elif kind == "save":
        d.line([cx, cy - h * 0.8, cx, cy + h * 0.3], fill=color, width=w)
        d.line([cx - h * 0.4, cy - h * 0.05, cx, cy + h * 0.35, cx + h * 0.4, cy - h * 0.05], fill=color, width=w, joint="curve")
        d.line([cx - h * 0.65, cy + h * 0.75, cx + h * 0.65, cy + h * 0.75], fill=color, width=w)
    elif kind == "trash":
        d.line([cx - h * 0.75, cy - h * 0.55, cx + h * 0.75, cy - h * 0.55], fill=color, width=w)
        d.line([cx - h * 0.25, cy - h * 0.8, cx + h * 0.25, cy - h * 0.8], fill=color, width=w)
        d.line([cx - h * 0.55, cy - h * 0.45, cx - h * 0.45, cy + h * 0.8, cx + h * 0.45, cy + h * 0.8, cx + h * 0.55, cy - h * 0.45], fill=color, width=w, joint="curve")
    elif kind == "pin":
        d.ellipse([cx - h * 0.35, cy - h * 0.85, cx + h * 0.35, cy - h * 0.15], outline=color, width=w)
        d.line([cx, cy - h * 0.15, cx, cy + h * 0.85], fill=color, width=w)


def status(d, color, y=18):
    d.text((40, y), "9:41", font=font("inter-semibold", 26), fill=color)
    for i in range(4):
        d.rectangle([560 + i * 12, y + 24 - i * 6, 568 + i * 12, y + 28], fill=color)
    d.rounded_rectangle([622, y + 6, 670, y + 28], radius=6, outline=color, width=3)
    d.rectangle([627, y + 11, 656, y + 23], fill=color)


# 1. Darkroom: photo-first and dark, chrome that steps back.

DARK = {"bg": (11, 16, 14), "surface": (22, 30, 26), "line": (40, 52, 46), "ink": (238, 233, 220),
        "muted": (141, 151, 143), "jade": (61, 190, 132), "jade_dim": (30, 58, 45)}


def dark_header(d, title):
    c = DARK
    status(d, c["ink"])
    spaced(d, (40, 92), title.upper(), font("rh-semibold", 26), c["muted"], 5)
    d.text((40, 128), "My vault", font=font("rh-semibold", 56), fill=c["ink"])
    d.ellipse([612, 112, 680, 180], outline=c["jade"], width=4)
    icon(d, "lock", 646, 146, 30, c["jade"], 4)


def dark_tabs(img, active):
    c = DARK
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([60, 1352, 540, 1448], radius=48, fill=c["surface"] + (240,), outline=c["line"], width=2)
    for k, name in enumerate(["Photos", "Videos", "Notes"]):
        x0 = 72 + k * 156
        if k == active:
            d.rounded_rectangle([x0, 1364, x0 + 144, 1436], radius=36, fill=c["jade_dim"])
        f = font("rh-semibold", 28)
        d.text((x0 + 72 - d.textlength(name, font=f) / 2, 1382), name, font=f, fill=c["jade"] if k == active else c["muted"])
    d.ellipse([564, 1352, 660, 1448], fill=c["jade"])
    icon(d, "plus", 612, 1400, 44, c["bg"], 6)
    img.alpha_composite(layer)


def dark_photos(photos):
    c = DARK
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    dark_header(d, "10 photos")
    side = (W - 8) // 3
    for i, p in enumerate(photos):
        x, y = (i % 3) * (side + 4), 222 + (i // 3) * (side + 4)
        img.paste(fit(p, side, side), (x, y))
    dark_tabs(img, 0)
    return img


def dark_viewer(photos):
    c = DARK
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    shot = fit(photos[4], W, 960)
    img.paste(shot, (0, 260))
    d = ImageDraw.Draw(img)
    status(d, c["ink"])
    icon(d, "left", 56, 112, 40, c["ink"], 5)
    f = font("rh-medium", 28)
    d.text((W / 2 - d.textlength("5 of 10", font=f) / 2, 96), "5 of 10", font=f, fill=c["ink"])
    for k, (kind, name) in enumerate([("share", "Share"), ("save", "Save"), ("trash", "Delete")]):
        cx = 150 + k * 210
        d.ellipse([cx - 52, 1290, cx + 52, 1394], fill=c["surface"])
        icon(d, kind, cx, 1342, 44, c["ink"], 5)
        fs = font("rh", 24)
        d.text((cx - d.textlength(name, font=fs) / 2, 1408), name, font=fs, fill=c["muted"])
    return img


def dark_notes(photos):
    c = DARK
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    dark_header(d, "3 notes")
    y = 230
    for title, body, when, pinned in NOTES:
        d.rounded_rectangle([32, y, W - 32, y + 150], radius=26, fill=c["surface"])
        if pinned:
            d.rounded_rectangle([32, y, 42, y + 150], radius=4, fill=c["jade"])
            icon(d, "pin", W - 74, y + 104, 30, c["jade"], 4)
        d.text((68, y + 30), title, font=font("rh-semibold", 32), fill=c["ink"])
        d.text((68, y + 80), body, font=font("rh", 26), fill=c["muted"])
        right(d, W - 60, y + 36, when, font("rh", 24), c["muted"])
        y += 172
    dark_tabs(img, 2)
    return img


def dark_settings(photos):
    c = DARK
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    status(d, c["ink"])
    icon(d, "left", 56, 112, 40, c["ink"], 5)
    d.text((40, 160), "Settings", font=font("rh-semibold", 56), fill=c["ink"])
    y = 260
    for group, rows in SETTINGS:
        spaced(d, (48, y), group.upper(), font("rh-semibold", 22), c["muted"], 4)
        y += 40
        d.rounded_rectangle([32, y, W - 32, y + 92 * len(rows)], radius=24, fill=c["surface"])
        for k, (name, value) in enumerate(rows):
            ry = y + k * 92
            if k:
                d.line([64, ry, W - 64, ry], fill=c["line"], width=2)
            d.text((64, ry + 28), name, font=font("rh-medium", 28), fill=c["ink"])
            fv = font("rh", 26)
            right(d, W - 96, ry + 30, value, fv, c["muted"])
            icon(d, "right", W - 64, ry + 46, 24, c["muted"], 4)
        y += 92 * len(rows) + 30
    return img


# 2. Keepsake album: warm paper, photos as prints, notes like index cards.

PAPER = {"bg": (244, 239, 228), "card": (255, 253, 248), "ink": (42, 38, 32), "muted": (138, 129, 115),
         "jade": (44, 127, 88), "line": (228, 220, 203), "tabs": [(226, 168, 146), (167, 199, 176), (233, 207, 143)]}


def paper_header(img, d, active, count):
    c = PAPER
    status(d, c["ink"])
    d.text((40, 96), "My vault", font=font("serif-semibold", 64), fill=c["ink"])
    d.text((44, 186), count, font=font("serif-italic", 28), fill=c["muted"])
    d.rounded_rectangle([548, 110, 680, 168], radius=29, outline=c["jade"], width=3)
    icon(d, "lock", 582, 139, 26, c["jade"], 4)
    d.text((604, 120), "Lock", font=font("rh-semibold", 26), fill=c["jade"])
    x = 44
    for k, name in enumerate(["Photos", "Videos", "Notes"]):
        f = font("serif-semibold" if k == active else "serif", 32)
        d.text((x, 248), name, font=f, fill=c["ink"] if k == active else c["muted"])
        if k == active:
            wd = d.textlength(name, font=f)
            d.ellipse([x + wd / 2 - 6, 300, x + wd / 2 + 6, 312], fill=c["jade"])
        x += d.textlength(name, font=f) + 44


def paper_photos(photos):
    c = PAPER
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    paper_header(img, d, 0, "10 photos, 2 videos")
    heights = [[300, 220, 340, 260], [230, 330, 250, 300]]
    for col in range(2):
        x, y = 32 + col * 336, 340
        for row, hgt in enumerate(heights[col]):
            p = photos[col + row * 2]
            box = (x, y, x + 320, y + hgt)
            shadow(img, box, 20, opacity=50, blur=10, dy=5)
            card = Image.new("RGBA", (320, hgt), c["card"] + (255,))
            card.paste(fit(p, 296, hgt - 24), (12, 12))
            img.alpha_composite(rounded(card, 20), (x, y))
            y += hgt + 18
    d = ImageDraw.Draw(img)
    shadow(img, (420, 1376, 688, 1460), 42, opacity=70)
    d.rounded_rectangle([420, 1376, 688, 1460], radius=42, fill=c["jade"])
    icon(d, "plus", 466, 1418, 34, c["card"], 5)
    d.text((496, 1398), "Add photos", font=font("rh-semibold", 28), fill=c["card"])
    return img


def paper_viewer(photos):
    c = PAPER
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    status(d, c["ink"])
    icon(d, "left", 56, 112, 40, c["ink"], 5)
    box = (56, 220, W - 56, 1060)
    shadow(img, box, 10, opacity=70, blur=16, dy=10)
    card = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), c["card"] + (255,))
    card.paste(fit(photos[4], card.width - 40, card.height - 40), (20, 20))
    img.alpha_composite(rounded(card, 10), box[:2])
    d = ImageDraw.Draw(img)
    d.text((64, 1096), "Evening at the lake", font=font("serif-semibold", 38), fill=c["ink"])
    d.text((64, 1152), "IMG_0412.png, added 15 November", font=font("serif-italic", 26), fill=c["muted"])
    for k, (kind, name) in enumerate([("share", "Share"), ("save", "Save to phone"), ("trash", "Delete")]):
        color = (176, 84, 62) if kind == "trash" else c["jade"]
        x = 64 + [0, 190, 470][k]
        icon(d, kind, x + 18, 1290, 34, color, 4)
        d.text((x + 48, 1274), name, font=font("rh-semibold", 28), fill=color)
    return img


def paper_notes(photos):
    c = PAPER
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    paper_header(img, d, 2, "3 notes")
    y = 350
    for k, (title, body, when, pinned) in enumerate(NOTES):
        box = (32, y, W - 32, y + 200)
        shadow(img, box, 16, opacity=40, blur=10, dy=4)
        card = Image.new("RGBA", (box[2] - box[0], 200), c["card"] + (255,))
        cd = ImageDraw.Draw(card)
        cd.rectangle([0, 0, card.width, 14], fill=c["tabs"][k])
        for ly in range(110, 200, 40):
            cd.line([28, ly, card.width - 28, ly], fill=c["line"], width=2)
        cd.text((28, 40), title, font=font("serif-semibold", 34), fill=c["ink"])
        cd.text((28, 116), body, font=font("rh", 26), fill=c["muted"])
        right(cd, card.width - 28, 48, when, font("serif-italic", 24), c["muted"])
        if pinned:
            icon(cd, "pin", card.width - 40, 140, 30, c["jade"], 4)
        img.alpha_composite(rounded(card, 16), box[:2])
        y += 226
    return img


def paper_settings(photos):
    c = PAPER
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    status(d, c["ink"])
    icon(d, "left", 56, 112, 40, c["ink"], 5)
    d.text((40, 150), "Settings", font=font("serif-semibold", 60), fill=c["ink"])
    y = 260
    for group, rows in SETTINGS:
        d.text((44, y), group, font=font("serif-italic", 28), fill=c["muted"])
        y += 44
        d.rounded_rectangle([32, y, W - 32, y + 88 * len(rows)], radius=18, fill=c["card"])
        for k, (name, value) in enumerate(rows):
            ry = y + k * 88
            if k:
                d.line([60, ry, W - 60, ry], fill=c["line"], width=2)
            d.text((60, ry + 26), name, font=font("rh-medium", 28), fill=c["ink"])
            right(d, W - 92, ry + 28, value, font("rh", 26), c["muted"])
            icon(d, "right", W - 64, ry + 44, 24, c["muted"], 4)
        y += 88 * len(rows) + 28
    return img


# 3. Field notebook: a jade header block, square photos, type that does the work.

FIELD = {"bg": (247, 248, 243), "jade": (44, 127, 88), "cream": (244, 241, 230), "ink": (21, 32, 27),
         "muted": (110, 120, 114), "line": (221, 226, 214), "amber": (226, 166, 59), "white": (255, 255, 255)}


def field_header(d, active, sub):
    c = FIELD
    d.rectangle([0, 0, W, 312], fill=c["jade"])
    status(d, c["cream"])
    d.text((40, 110), "My vault", font=font("inter-bold", 76), fill=c["cream"])
    d.text((44, 212), sub, font=font("mono", 24), fill=(200, 222, 207))
    d.rounded_rectangle([612, 104, 680, 172], radius=10, outline=c["cream"], width=3)
    icon(d, "lock", 646, 138, 30, c["cream"], 4)
    x = 40
    for k, (name, n) in enumerate([("PHOTOS", "10"), ("VIDEOS", "2"), ("NOTES", "3")]):
        f = font("inter-semibold", 24)
        end = spaced(d, (x, 340), name, f, c["ink"] if k == active else c["muted"], 3)
        d.text((end + 8, 342), n, font=font("mono", 22), fill=c["muted"])
        if k == active:
            d.rectangle([x, 380, end + 30, 386], fill=c["jade"])
        x = end + 70
    d.line([0, 386, W, 386], fill=c["line"], width=2)


def field_photos(photos):
    c = FIELD
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    field_header(d, 0, "10 PHOTOS / 2 VIDEOS / 3 NOTES")
    side = (W - 4) // 3
    for i, p in enumerate(photos):
        img.paste(fit(p, side, side), ((i % 3) * (side + 2), 388 + (i // 3) * (side + 2)))
    d.rectangle([W - 136, H - 160, W - 24, H - 48], fill=c["jade"])
    icon(d, "plus", W - 80, H - 104, 48, c["cream"], 6)
    return img


def field_viewer(photos):
    c = FIELD
    img = Image.new("RGBA", (W, H), c["white"] + (255,))
    d = ImageDraw.Draw(img)
    status(d, c["ink"])
    icon(d, "left", 56, 112, 40, c["ink"], 5)
    right(d, W - 40, 98, "05 / 10", font("mono", 28), c["muted"])
    img.paste(fit(photos[4], W, 900), (0, 170))
    d.text((40, 1110), "IMG_0412.png", font=font("inter-semibold", 36), fill=c["ink"])
    d.text((40, 1166), "ADDED 15 NOV 2026 / 1.2 MB", font=font("mono", 24), fill=c["muted"])
    d.line([0, 1236, W, 1236], fill=c["line"], width=2)
    for k, (kind, name) in enumerate([("share", "SHARE"), ("save", "SAVE"), ("trash", "DELETE")]):
        x0 = k * W // 3
        if k:
            d.line([x0, 1236, x0, 1420], fill=c["line"], width=2)
        icon(d, kind, x0 + W // 6, 1296, 44, c["ink"], 5)
        f = font("inter-semibold", 22)
        spaced(d, (x0 + W // 6 - (d.textlength(name, font=f) + 2 * len(name)) / 2, 1346), name, f, c["muted"], 2)
    d.line([0, 1420, W, 1420], fill=c["line"], width=2)
    return img


def field_notes(photos):
    c = FIELD
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    field_header(d, 2, "3 NOTES, 1 PINNED")
    y = 388
    for title, body, when, pinned in NOTES:
        day, month = ("18", "NOV") if ":" in when else when.split(" ")
        d.text((40, y + 34), day, font=font("inter-bold", 56), fill=c["ink"])
        spaced(d, (44, y + 104), month.upper(), font("mono", 22), c["muted"], 2)
        d.text((170, y + 40), title, font=font("inter-semibold", 32), fill=c["ink"])
        d.text((170, y + 90), body, font=font("inter", 26), fill=c["muted"])
        if pinned:
            d.rectangle([W - 60, y + 46, W - 40, y + 66], fill=c["amber"])
        y += 170
        d.line([40, y, W - 40, y], fill=c["line"], width=2)
    return img


def field_settings(photos):
    c = FIELD
    img = Image.new("RGBA", (W, H), c["bg"] + (255,))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 240], fill=c["jade"])
    status(d, c["cream"])
    icon(d, "left", 56, 112, 40, c["cream"], 5)
    d.text((40, 150), "Settings", font=font("inter-bold", 56), fill=c["cream"])
    y = 272
    for group, rows in SETTINGS:
        spaced(d, (40, y), group.upper(), font("inter-semibold", 22), c["muted"], 3)
        y += 42
        for name, value in rows:
            d.line([40, y, W - 40, y], fill=c["line"], width=2)
            d.text((40, y + 24), name, font=font("inter-medium", 28), fill=c["ink"])
            right(d, W - 40, y + 28, value.upper() if value else "", font("mono", 22), c["muted"])
            y += 82
        d.line([40, y, W - 40, y], fill=c["line"], width=2)
        y += 36
    return img


LOOKS = [
    ("Darkroom", "Dark and photo-first: the pictures glow, and the controls step back into one floating bar.",
     "Flutter: a custom ThemeData (a dark ColorScheme from the jade) and three widgets of our own, a floating pill tab bar, an edge-to-edge grid and a frosted action bar. No package.",
     [dark_photos, dark_viewer, dark_notes, dark_settings]),
    ("Keepsake album", "Warm paper and a serif title: photos are prints, notes are index cards, nothing feels like a system screen.",
     "Flutter: shadcn_ui for cards, sheets and switches, themed to jade and cream, plus flutter_staggered_grid_view for the masonry grid. shadcn_ui 0.60 needs Flutter 3.47 or later, and the app builds with 3.44.",
     [paper_photos, paper_viewer, paper_notes, paper_settings]),
    ("Field notebook", "A solid jade header, square photos and type that does the work: counts, dates and values in a monospace.",
     "Flutter: forui, a minimal widget set, themed to jade, with Inter and a monospace for figures, and a square-grid photo view of our own. forui 0.28 needs Flutter 3.50 or later.",
     [field_photos, field_viewer, field_notes, field_settings]),
]


def phone(screen):
    pw = 300
    shot = screen.convert("RGB").resize((pw, round(pw * H / W)), Image.LANCZOS)
    bez = 8
    body = Image.new("RGBA", (pw + 2 * bez, shot.height + 2 * bez), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=40, fill=(24, 24, 26))
    body.alpha_composite(rounded(shot, 32), (bez, bez))
    return body


def main():
    photos = [Image.open(p).convert("RGB") for p in sorted(Path(sys.argv[1]).glob("*.jpg"))][:10]
    if len(photos) < 10:
        sys.exit("need ten sample photos from store/tools/sample_photos.py")
    pw, gap, margin = 316, 40, 64
    width = margin * 2 + pw * 4 + gap * 3
    section = 170 + 649 + 70
    canvas = Image.new("RGBA", (width, 170 + section * 3), (244, 242, 238, 255))
    d = ImageDraw.Draw(canvas)
    d.text((margin, 50), "SecureVault 1.2: three looks for the vault", font=font("rh-semibold", 50), fill=(28, 28, 30))
    d.text((margin, 116), "The disguises stay stock. The vault behind them gets its own design language. "
           "The same four screens in each.", font=font("rh", 24), fill=(110, 108, 104))
    for k, (name, idea, route, screens) in enumerate(LOOKS):
        y = 190 + k * section
        d.text((margin, y), f"{k + 1}  {name}", font=font("rh-semibold", 36), fill=(28, 28, 30))
        below = wrapped(d, (margin, y + 54), idea, font("rh", 24), (70, 68, 64), width - 2 * margin, 32)
        below = wrapped(d, (margin, below + 4), route, font("rh", 21), (110, 108, 104), width - 2 * margin, 28)
        top = max(y + 150, below + 16)
        for i, (draw, label) in enumerate(zip(screens, ["Photos", "A photo", "Notes", "Settings"])):
            body = phone(draw(photos))
            x = margin + i * (pw + gap)
            canvas.alpha_composite(body, (x, top))
            f = font("rh-medium", 20)
            d.text((x + (pw - d.textlength(label, font=f)) / 2, top + body.height + 10), label, font=f,
                   fill=(110, 108, 104))
        print(f"drew {name}")
    canvas.convert("RGB").save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({canvas.width}x{canvas.height})")


if __name__ == "__main__":
    main()
