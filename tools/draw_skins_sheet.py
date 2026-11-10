"""Draw docs/skins.png, the README's picture of every built-in skin.

Bodhidharma's answer from the show-off video, 并无功德, sits above the skins, each resting on
its pedestal with its mallet raised and its name below. The skins are drawn
by showoff_video.py, so the picture and the video stay alike.

Usage: python draw_skins_sheet.py <out.png>
"""
import sys

import numpy as np
from PIL import Image, ImageDraw

import showoff_video as v

W, COLS, CELL, TOP, BOTTOM = 1800, 5, 360, 300, 40
ROWS = -(-v.N // COLS)
H = TOP + ROWS * CELL + BOTTOM
SIDE = 250


def background():
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    img = np.stack([np.full((H, W), c, np.float32) for c in (12, 14, 19)], -1)
    img *= np.clip(1 - 0.55 * (((xx - W / 2) / W) ** 2 + ((yy - H / 2) / H) ** 2) * 2.2, 0, 1)[..., None]
    glow = np.exp(-(((xx - W / 2) / 900) ** 2 + ((yy - 120) / 420) ** 2))[..., None]
    img += glow * np.array((150, 120, 220), np.float32) * .10
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def centered(draw, xy, s, f, fill):
    draw.text(xy, s, font=f, fill=fill, anchor="mm")


def cell(k):
    """One skin at rest on its pedestal, a pool of its colour beneath it."""
    out = Image.new("RGBA", (CELL, CELL))
    floor, cx = 282, CELL / 2
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    pool = np.exp(-(((xx - cx) / 80) ** 2 + ((yy - floor) / 12) ** 2)) * .5
    rgb = np.broadcast_to(np.array(v.SKINS[k][4], np.float32), (CELL, CELL, 3))
    out.alpha_composite(Image.fromarray(np.dstack([rgb, pool * 255]).astype(np.uint8), "RGBA"))
    v.draw_skin(out, k, cx, floor, SIDE, 0.0, "sheet", reflect=False, ring=False)
    name, zh, color = v.SKINS[k][0], v.SKINS[k][2], v.SKINS[k][4]
    d = ImageDraw.Draw(out)
    f = v.font("sans", 22)
    gap = 10
    wn, wz = d.textlength(name, font=f), d.textlength(zh, font=f)
    x = cx - (wn + gap + wz) / 2
    d.text((x, 322), name, font=f, fill=(200, 198, 192), anchor="lm")
    d.text((x + wn + gap, 322), zh, font=f, fill=color, anchor="lm")
    return out


def sheet():
    img = background()
    d = ImageDraw.Draw(img)
    centered(d, (W / 2, 125), "并无功德", v.font("serifb", 84), (240, 234, 222))
    centered(d, (W / 2, 218), "“No merit at all.”  — Bodhidharma, to Emperor Wu", v.font("serif", 26), (150, 146, 140))
    for k in range(v.N):
        r, c = divmod(k, COLS)
        row = min(COLS, v.N - r * COLS)  # a short last row is centred
        left = (W - row * CELL) // 2 + c * CELL
        img.alpha_composite(cell(k), (left, TOP + r * CELL))
    mask = Image.new("L", (W, H))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), 28, fill=255)
    out = Image.new("RGBA", (W, H))
    out.paste(img, mask=mask)
    return out


if __name__ == "__main__":
    sheet().save(sys.argv[1], optimize=True)
