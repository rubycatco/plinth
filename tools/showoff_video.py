"""Render Plinth's show-off video: every skin knocked in turn, then all
twenty-one played as a drum kit. Its cast is the skins that shipped with
Plinth when it was made; six have since moved to the gallery, and are drawn
from App/Resources/Retired.

Frames are drawn with PIL from the skins' own sprites, with the mallet swing,
give and burst timed like Sprites.swift. The soundtrack is the skins' real
knocks, synthesized by knock_synth.py, a numpy port of KnockSynth.swift.

Needs numpy, scipy, pillow, ffmpeg and the Noto Serif/Sans CJK fonts (the
.ttc files, in /usr/share/fonts/opentype/noto or the folder PLINTH_FONTS names).

Usage: python showoff_video.py <out.mp4> [--vertical]
       python showoff_video.py <out-dir> [--vertical] --stills <seconds>...
"""
import math, os, random, subprocess, sys, tempfile, wave
from pathlib import Path
from functools import lru_cache
from multiprocessing import Pool

import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import knock_synth as synth

RES = Path(__file__).resolve().parents[1] / "App/Resources"
VERT = "--vertical" in sys.argv
W, H, FPS = (1080, 1920, 30) if VERT else (1920, 1080, 30)
CX = W / 2
# Where things sit: landscape for the 16:9 cut, portrait for 9:16.
LAY = dict(glow=(1000, 520, 640), floor=1100, floor_r=520, side=720, near=520, far=300,
         quote=820, src=960, en=1060, merit=(540, 380), nomerit=1350, nomerit_en=1430,
         name=1300, zh=1362, cap=1420, dots=1560, gx=[CX + (c - 1) * 340 for c in range(3)],
         gy=[290, 545, 800, 1055, 1310, 1565, 1820], gside=185, cols=3, glabel=19,
         end_floor=900, end_side=520, title=1040, tag=1160, tag2=1250, url=1380) if VERT else \
    dict(glow=(560, 620, 420), floor=745, floor_r=700, side=600, near=700, far=420,
         quote=470, src=610, en=680, merit=(660, 420), nomerit=860, nomerit_en=940,
         name=850, zh=908, cap=962, dots=1030, gx=[CX + (c - 3) * 262 for c in range(7)],
         gy=[330, 640, 950], gside=235, cols=7, glabel=19,
         end_floor=470, end_side=380, title=585, tag=690, tag2=745, url=860)

# name, folder, chinese, voice, glow colour, caption (from KnockSynth's comments)
SKINS = [
    ("Ink Fish", "ink-fish", "水墨鱼", "ink", (190, 190, 200), "A painting of the fish, heard through paper."),
    ("Wooden Fish", "wooden-fish", "木鱼", "wood", (255, 70, 200), "Hollow wood, struck in one wooden hall."),
    ("Cartoon Fish", "cartoon-fish", "卡通鱼", "cartoon", (255, 150, 70), "A small light fish. Round, short, almost no grit."),
    ("Jade Fish", "jade-fish", "玉鱼", "jade", (60, 230, 140), "Solid jade, closer to a stone chime than a hollow block."),
    ("Pixel Fish", "pixel-fish", "像素鱼", "pixel", (60, 220, 255), "Wood drawn in pixels: stiff partials, a grainy attack."),
    ("Red Lacquer", "red-lacquer", "朱漆", "lacquer", (255, 175, 60), "A hard lacquered shell, higher, with a sharper click."),
    ("Singing Bowl", "singing-bowl", "铜磬", "bowl", (60, 210, 230), "A struck bronze bowl. The hum under a slightly sharp rim."),
    ("Space Key", "space-key", "空格键", "key", (128, 226, 242), "A low plastic thud and a short bright click. Knock as you type."),
    ("Bamboo Block", "bamboo-block", "竹节", "bamboo", (164, 218, 167), "A hollow bamboo tube, more air than wood."),
    ("Moss Stone", "moss-stone", "苔石", "stone", (186, 203, 139), "Mossy stone: dull, gritty, the ring soaked up."),
    ("Piston", "piston", "活塞", "piston", (248, 178, 87), "Steel on steel. A short clack, not a bowl's ring."),
    ("CRT Terminal", "crt-terminal", "CRT 终端", "crt", (101, 239, 149), "A plastic case, and a faint tick as the screen flashes."),
    ("Abacus", "abacus", "算盘", "bead", (240, 198, 112), "Rosewood beads knocked together. It keeps no count."),
    ("Cloud Gong", "cloud-gong", "云板", "plate", (110, 225, 205), "A flat bronze plate under a leather mallet."),
    ("Porcelain Fish", "porcelain-fish", "青花瓷鱼", "porcelain", (80, 130, 255), "Thin glazed porcelain: high, bright and clean."),
    ("Bianzhong", "bianzhong", "编钟", "bell", (244, 210, 130), "One bronze bell, two notes a minor third apart."),
    ("Seal", "seal", "印章", "stamp", (235, 85, 65), "A stone seal pressed onto paper. It leaves 空."),
    ("Stone Chime", "stone-chime", "石磬", "chime", (190, 235, 215), "A thin slab of hanging stone, rung with felt."),
    ("Fish Board", "fish-board", "鱼板", "board", (255, 80, 190), "The long wooden fish that hangs outside the hall."),
    ("Mug", "mug", "马克杯", "ceramic", (255, 160, 70), "A spoon on the rim of a full mug."),
    ("Temple Fish", "temple-fish", "古木鱼", "temple", (236, 183, 88), "A big old temple fish under a cloth-wrapped mallet."),
]
N = len(SKINS)


def load(path):
    try:
        return Image.open(path).convert("RGBA")
    except FileNotFoundError:
        return None


HIT = -15.0                            # the mallet's angle as it lands
PACKS = []
# Whether each skin still ships with the app, or has moved to the gallery.
SHIPS = [(RES / "Skins" / folder).is_dir() for _, folder, *_ in SKINS]
for (name, folder, zh, voice, col, cap), ships in zip(SKINS, SHIPS):
    d = f"{RES}/{'Skins' if ships else 'Retired'}/{folder}"
    meta = json.load(open(f"{d}/skin.json"))
    PACKS.append(dict(idle=load(f"{d}/idle.png"), hit=load(f"{d}/hit.png"),
                      mallet=load(f"{d}/mallet.png") or load(f"{RES}/mallet.png"),
                      impact=load(f"{d}/impact.png") or load(f"{RES}/impact.png"),
                      screen=load(f"{d}/impact.png") is None, strike=meta["strike"],
                      rest=HIT + meta.get("raise", 25)))

FONT = os.environ.get("PLINTH_FONTS", "/usr/share/fonts/opentype/noto").rstrip("/") + "/"
@lru_cache(None)
def font(kind, size):
    f = {"serif": "NotoSerifCJK-Regular.ttc", "serifb": "NotoSerifCJK-Bold.ttc",
         "sans": "NotoSansCJK-Regular.ttc", "sansb": "NotoSansCJK-Bold.ttc"}[kind]
    return ImageFont.truetype(FONT + f, size, index=2)


# ---------------------------------------------------------------- timeline
SLOT, PARADE = 1.8, 9.0
OFFSETS = [[.3, 1.05], [.3, .9], [.3, .6, .9], [.3, .9, 1.2], [.3, .45, .6, .9], [.3, .6, .9], [.3],
           [.3, .45, .6, .75, .9], [.3, .9], [.3, .9], [.3, .6, .75, .9], [.3, .9],
           [.3, .45, .6, .9], [.3], [.3, .9], [.3, 1.05], [.3, .9], [.3, 1.0], [.3, .6, .9], [.3, .45, .9], [.3, 1.0]]
RING = (6, 13, 15)                     # the bronzes, given their full hall
GRID0 = PARADE + N * SLOT + 1.0
STEP = 60 / 110 / 4
ALL_HIT = GRID0 + 4 * 16 * STEP
END0 = ALL_HIT + 2.7
DUR = END0 + 6.0

# impacts: (time, skin, bloom, scene)
impacts = [(5.0, 0, 1.0, "car")]
for k in range(N):
    for o in OFFSETS[k]:
        impacts.append((PARADE + k * SLOT + o, k, 1.0 if k in RING else 0.3, "car"))
groove = {8: [0, 3, 8, 10], 7: [4, 12], 9: [4], 10: [12], 5: [2, 6, 10, 14], 4: [7, 15], 11: [9],
          1: [6, 11], 0: [5], 2: [13], 16: [0, 8], 12: [1, 9], 19: [3, 11], 18: [14], 14: [11], 17: [15], 20: [10]}
for k in range(N):
    impacts.append((GRID0 + k * STEP, k, .25, "grid"))
for bar in (1, 2, 3):
    for k, steps in groove.items():
        for s in steps:
            if bar == 3 and s >= 12:
                continue
            impacts.append((GRID0 + (bar * 16 + s) * STEP, k, .15, "grid"))
    if bar == 1:
        impacts.append((GRID0 + 16 * STEP, 6, .6, "grid"))
    if bar == 2:
        impacts.append((GRID0 + (32 + 1) * STEP, 3, .2, "grid"))
        impacts.append((GRID0 + 32 * STEP, 15, .5, "grid"))
    if bar == 3:
        impacts.append((GRID0 + 48 * STEP, 13, .5, "grid"))
for i, k in enumerate([1, 2, 3, 5]):          # fill
    impacts.append((GRID0 + (48 + 12 + i) * STEP, k, .2, "grid"))
impacts.append((GRID0 + (48 + 12) * STEP, 8, .2, "grid"))
for k in range(N):
    impacts.append((ALL_HIT, k, 1.0 if k in RING else .5, "grid"))
impacts.append((END0 + 2.4, 0, 1.0, "end"))
impacts.sort()

HITS = {}
for t, k, b, sc in impacts:
    HITS.setdefault((sc, k), []).append(t)


# ---------------------------------------------------------------- helpers
def clamp(x, a=0., b=1.):
    return min(max(x, a), b)

def ease(x):  # ease in-out
    x = clamp(x); return x * x * (3 - 2 * x)

def ramp(t, a, b):
    return clamp((t - a) / (b - a))

def fade(t, a, b, c, d):
    return ease(ramp(t, a, b)) * (1 - ease(ramp(t, c, d)))

def last_hit(sc, k, t):
    best = None
    for h in HITS.get((sc, k), []):
        if h - .13 <= t:
            best = h
    return best


def mallet_angle(u, rest):
    if u is None or u < 0: return rest
    if u < .05:
        x = u / .05; return rest + 7 * (1 - (1 - x) ** 2)
    if u < .13:
        x = (u - .05) / .08; return rest + 7 + (HIT - rest - 7) * x * x
    v = u - .13
    w, z = 2 * math.pi / .5, .33
    s = 1 - math.exp(-z * w * v) * math.cos(w * math.sqrt(1 - z * z) * v)
    return HIT + (rest - HIT) * s


@lru_cache(maxsize=400)
def scaled(k, kind, size):
    im = PACKS[k][kind]
    return im.resize((size, size), Image.LANCZOS)

def with_alpha(im, a):
    if a >= .999: return im
    im = im.copy()
    im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
    return im

def paste(canvas, im, x, y):
    x, y = int(round(x)), int(round(y))
    sx, sy = max(0, -x), max(0, -y)
    if sx >= im.width or sy >= im.height or x >= W or y >= H: return
    if sx or sy: im = im.crop((sx, sy, im.width, im.height))
    canvas.alpha_composite(im, (x + sx, y + sy))

def screen_paste(canvas, im, x, y):
    x, y = int(round(x)), int(round(y))
    box = (max(x, 0), max(y, 0), min(x + im.width, W), min(y + im.height, H))
    if box[2] <= box[0] or box[3] <= box[1]: return
    src = np.asarray(im.crop((box[0] - x, box[1] - y, box[2] - x, box[3] - y)), dtype=np.float32) / 255
    dst = np.asarray(canvas.crop(box), dtype=np.float32) / 255
    a = src[..., 3:4]
    rgb = 1 - (1 - dst[..., :3]) * (1 - src[..., :3] * a)
    out = np.concatenate([rgb, dst[..., 3:4]], -1)
    canvas.paste(Image.fromarray((out * 255).astype(np.uint8), "RGBA"), box[:2])

def text(canvas, s, f, cx, cy, fill, a=1.0, anchor="mm", spacing=10):
    if a <= .01: return
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bb = d.multiline_textbbox((0, 0), s, font=f, anchor="la", spacing=spacing, align="center")
    w, h = int(math.ceil(bb[2])) + 8, int(math.ceil(bb[3])) + 8
    layer = Image.new("RGBA", (w, h))
    ImageDraw.Draw(layer).multiline_text((4, 4), s, font=f, fill=fill + (int(255 * a),), spacing=spacing, align="center")
    x = cx - w / 2 if anchor[0] == "m" else cx
    paste(canvas, layer, x, cy - h / 2)
    return w


# ---------------------------------------------------------------- background
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
BASE = np.stack([np.full((H, W), c, np.float32) for c in (12, 14, 19)], -1)
vig = np.clip(1 - 0.55 * (((xx - W / 2) / W) ** 2 + ((yy - H / 2) / H) ** 2) * 2.2, 0, 1)
BASE *= vig[..., None]
GLOW = np.exp(-(((xx - CX) / LAY["glow"][1]) ** 2 + ((yy - LAY["glow"][0]) / LAY["glow"][2]) ** 2))[..., None]
FLOOR = np.exp(-(((xx - CX) / LAY["floor_r"]) ** 2 + ((yy - LAY["floor"]) / 28) ** 2))[..., None]

def background(color, inten, floor=0.0):
    c = np.array(color, np.float32)
    img = BASE + GLOW * c * inten + FLOOR * c * floor
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


# ---------------------------------------------------------------- one skin
def draw_skin(canvas, k, cx, floor, side, t, sc, alpha=1.0, reflect=True, ring=True):
    side = int(round(side))
    if side < 8 or alpha <= .01: return
    p = PACKS[k]
    x0, y0 = cx - side / 2, floor - .965 * side
    h = last_hit(sc, k, t)
    u = None if h is None else t - (h - .13)
    ui = None if h is None else t - h          # since impact

    fig = scaled(k, "idle", side)
    if ui is not None and ui >= 0:
        if p["hit"] is not None:
            wgt = ramp(ui, 0, .03) if ui < .17 else 1 - ease(ramp(ui, .17, .37))
            if wgt > 0:
                fig = Image.blend(fig, scaled(k, "hit", side), wgt)
        elif ui < .4:
            g = ramp(ui, 0, .03) if ui < .03 else math.exp(-(ui - .03) * 14) * math.cos((ui - .03) * 18)
            sx, sy = 1 + .008 * g, 1 - .02 * g
            nw, nh = int(side * sx), int(side * sy)
            squashed = fig.resize((nw, nh), Image.BILINEAR)
            fig = Image.new("RGBA", (side, side)); fig.alpha_composite(squashed, ((side - nw) // 2, side - nh))
    fig = with_alpha(fig, alpha)

    if reflect:
        r = fig.transpose(Image.FLIP_TOP_BOTTOM)
        grad = np.clip(1 - np.arange(side) / (side * .28), 0, 1) ** 1.6 * .22
        ra = (np.asarray(r.getchannel("A"), np.float32) * grad[:, None]).astype(np.uint8)
        r.putalpha(Image.fromarray(ra))
        paste(canvas, r, x0, floor - .035 * side)
    paste(canvas, fig, x0, y0)

    stx, sty = x0 + p["strike"][0] * side, y0 + p["strike"][1] * side
    # expanding sound ring
    if ring and ui is not None and 0 <= ui < .7:
        R = side * (.15 + .75 * ease(ui / .7))
        a = (1 - ui / .7) ** 2 * .45 * alpha
        lay = Image.new("RGBA", (int(2 * R + 8), int(.9 * R + 8)))
        ImageDraw.Draw(lay).ellipse((4, 4, 2 * R + 4, .9 * R + 4), outline=SKINS[k][4] + (int(255 * a),), width=max(2, side // 220))
        paste(canvas, lay, stx - R - 4, sty + side * .08 - .45 * R - 4)
    # impact burst
    if ui is not None and 0 <= ui < .34:
        scl = .4 + .75 * (1 - (1 - ramp(ui, .01, .31)) ** 3)
        op = 1 if ui < .09 else 1 - ramp(ui, .09, .34) ** 1.5
        dia = int(side * .26 * scl * .9)
        if dia > 2:
            im = with_alpha(PACKS[k]["impact"].resize((dia, dia), Image.BILINEAR), op * alpha)
            ix, iy = stx - dia / 2, sty + side * .6 * .13 - dia / 2
            (screen_paste if p["screen"] else paste)(canvas, im, ix, iy)
    # mallet, rotating around its grip
    ms = int(side * .6)
    reach = (.964 - .169) * ms
    a15 = math.radians(15)
    gx, gy = stx + reach * math.cos(a15), sty - reach * math.sin(a15)
    m = scaled(k, "mallet", ms).rotate(-mallet_angle(u, p["rest"]), Image.BICUBIC, center=(.964 * ms, .505 * ms))
    paste(canvas, with_alpha(m, alpha), gx - .964 * ms, gy - .505 * ms)


# ---------------------------------------------------------------- scenes
def car_pos(t):
    if t < PARADE: return 0.0
    k = min(int((t - PARADE) // SLOT), N - 1)
    local = t - PARADE - k * SLOT
    if k < N - 1 and local > 1.35:
        return k + ease((local - 1.35) / .45)
    return float(k)

def glow_pulse(t, sc, ks):
    v = 0
    for k in ks:
        h = last_hit(sc, k, t)
        if h is not None and t >= h:
            v = max(v, math.exp(-(t - h) * 5))
    return v

def frame(fi):
    t = fi / FPS
    if t < END0 - .7:
        if t < GRID0 - 1.0 + .8:
            return scene_carousel(t)
        return scene_grid(t)
    return scene_end(t)

def scene_carousel(t):
    p = car_pos(t)
    k0 = int(p); fr = p - k0
    c0, c1 = np.array(SKINS[k0][4]), np.array(SKINS[min(k0 + 1, N - 1)][4])
    col = tuple(c0 * (1 - fr) + c1 * fr)
    show = fade(t, 3.6, 4.6, 99, 100) * (1 - ease(ramp(t, GRID0 - 1.0, GRID0 - .2)))
    pulse = glow_pulse(t, "car", [k0, min(k0 + 1, N - 1)])
    canvas = background(col, (.16 + .14 * pulse) * show, (.10 + .2 * pulse) * show)

    # intro quote
    qa = fade(t, .4, 1.4, 2.9, 3.5)
    text(canvas, "鱼昼夜常醒，\n刻木象形击之，所以警昏惰也。", font("serif", 54), CX, LAY["quote"], (232, 226, 214), qa, spacing=26)
    text(canvas, "— 《敕修百丈清规》", font("serif", 26), CX, LAY["src"], (150, 146, 140), qa)
    text(canvas, "A fish never closes its eyes.\nCarve one in wood and strike it, to keep the drowsy awake."
         if VERT else "A fish never closes its eyes. Carve one in wood and strike it, to keep the drowsy awake.",
         font("serif", 24), CX, LAY["en"], (120, 118, 114), qa * .9)

    neigh = ease(ramp(t, 8.6, 9.4))
    for k in range(N):
        d = k - p
        if abs(d) > 2.2: continue
        ad = abs(d)
        scale = 1 - .5 * min(ad, 1) - .1 * max(ad - 1, 0)
        a = clamp(1 - .62 * ad) if ad > 0 else 1
        a *= show * (1 if ad < .5 else neigh)
        x = CX + math.copysign(min(ad, 1) * LAY["near"] + max(ad - 1, 0) * LAY["far"], d)
        draw_skin(canvas, k, x, LAY["floor"], LAY["side"] * scale, t, "car", a, reflect=True, ring=ad < .5)

    # the merit gag
    if 4.9 < t < 8.8:
        ga = fade(t, 5.0, 5.15, 8.1, 8.6)
        y = LAY["merit"][1] - 90 * ease(ramp(t, 5.0, 6.0))
        w = text(canvas, "功德 +1", font("serifb", 62), LAY["merit"][0], y, (255, 214, 120), ga * (1 - .55 * ramp(t, 6.0, 6.3)))
        line = ease(ramp(t, 6.0, 6.35))
        if line > 0:
            d = ImageDraw.Draw(canvas)
            d.line((LAY["merit"][0] - 130, y + 4, LAY["merit"][0] - 130 + 260 * line, y + 4), fill=(235, 80, 80, int(255 * ga)), width=6)
        text(canvas, "并无功德", font("serifb", 70), CX, LAY["nomerit"], (240, 234, 222), fade(t, 6.5, 7.1, 8.1, 8.6))
        text(canvas, "“No merit at all.”  — Bodhidharma, to Emperor Wu", font("serif", 26), CX, LAY["nomerit_en"],
             (150, 146, 140), fade(t, 6.8, 7.4, 8.1, 8.6))

    # labels
    if t > 8.8:
        la = ease(ramp(t, 9.0, 9.5)) * show
        for k in (k0, k0 + 1):
            if k >= N: continue
            a = clamp(1 - 2.2 * abs(k - p)) * la
            if a <= 0: continue
            dx = (k - p) * 220
            text(canvas, SKINS[k][0], font("sansb", 52), CX + dx, LAY["name"], (240, 238, 232), a)
            text(canvas, SKINS[k][2], font("serif", 30), CX + dx, LAY["zh"], SKINS[k][4], a)
            text(canvas, SKINS[k][5], font("serif", 25), CX + dx, LAY["cap"], (150, 148, 144), a)
        # progress dots, a small mala
        for k in range(N):
            on = clamp(1 - abs(k - p))
            r = 5 + 3 * on
            cx = CX + (k - (N - 1) / 2) * 26
            c = tuple(int(90 + (np.array(SKINS[k][4]) - 90)[i] * on) for i in range(3))
            ImageDraw.Draw(canvas).ellipse((cx - r, LAY["dots"] - r, cx + r, LAY["dots"] + r), fill=c + (int(255 * la),))
    return canvas

GX, GY = LAY["gx"], LAY["gy"]

def scene_grid(t):
    a_in = ease(ramp(t, GRID0 - 1.0, GRID0 - .1))
    a_out = 1 - ease(ramp(t, END0 - 1.4, END0 - .7))
    pulse = glow_pulse(t, "grid", range(N))
    allp = math.exp(-max(t - ALL_HIT, 0) * 1.2) if t >= ALL_HIT else 0
    canvas = background((150, 120, 220), (.07 + .06 * pulse + .25 * allp) * a_out)
    for k in range(N):
        r, c = divmod(k, LAY["cols"])
        st = ease(ramp(t, GRID0 - 1.0 + .06 * k, GRID0 - .3 + .06 * k))
        a = st * a_out
        side = LAY["gside"] * (.85 + .15 * st)
        h = last_hit("grid", k, t)
        lit = math.exp(-(t - h) * 6) if h is not None and t >= h else 0
        draw_skin(canvas, k, GX[c], GY[r] - 20, side, t, "grid", a, reflect=False)
        base = np.array((120, 120, 124)); hc = np.array(SKINS[k][4])
        text(canvas, f"{SKINS[k][0]}  {SKINS[k][2]}", font("sans", LAY["glabel"]), GX[c], GY[r] + 2,
             tuple(int(v) for v in base + (hc - base) * lit), a)
    return canvas

def scene_end(t):
    a = fade(t, END0 - .5, END0 + .5, DUR - 1.0, DUR - .1)
    pulse = glow_pulse(t, "end", [0])
    canvas = background(SKINS[0][4], (.10 + .18 * pulse) * a, (.08 + .2 * pulse) * a)
    draw_skin(canvas, 0, CX, LAY["end_floor"], LAY["end_side"], t, "end", a)
    text(canvas, "Plinth", font("sansb", 130 if VERT else 120), CX, LAY["title"], (245, 242, 236), a)
    text(canvas, "A tiny wooden fish that lives on your Mac's desktop.", font("serif", 32), CX, LAY["tag"], (200, 196, 188),
         fade(t, END0 + .4, END0 + 1.2, DUR - 1.0, DUR - .1))
    text(canvas, ("Click it. Hear a soft tok.\nYou earn no merit for it.  并无功德" if VERT else
          "Click it. Hear a soft tok. You earn no merit for it.   并无功德"), font("serif", 26), CX, LAY["tag2"],
         (150, 146, 140), fade(t, END0 + .9, END0 + 1.7, DUR - 1.0, DUR - .1))
    text(canvas, "github.com/rubycatco/plinth  ·  macOS 14+", font("sans", 28), CX, LAY["url"], (128, 226, 242),
         fade(t, END0 + 1.4, END0 + 2.2, DUR - 1.0, DUR - .1))
    return canvas

def render(fi):
    return frame(fi).convert("RGB").tobytes()


# ---------------------------------------------------------------- audio
def soundtrack(path):
    rnd = random.Random(7)
    n = int((DUR + 3) * synth.SR)
    L = np.zeros(n); R = np.zeros(n)
    cache = {}
    for t, k, bloom, sc in impacts:
        v = SKINS[k][3]
        if v not in cache: cache[v] = synth.prepare(v)
        d, hl, hr = rnd.choice(cache[v])
        rate = rnd.uniform(.98, 1.02)
        gain = .55 * rnd.uniform(.88, 1.0) * (.55 if t == ALL_HIT else 1)
        pan = 0 if sc != "grid" else ((k % LAY["cols"]) / (LAY["cols"] - 1) - .5)
        def put(sig, ch, g):
            idx = np.arange(0, len(sig) - 1, rate)
            s = np.interp(idx, np.arange(len(sig)), sig) * g
            i0 = int(t * synth.SR); m = min(len(s), n - i0)
            ch[i0:i0 + m] += s[:m]
        dg = gain * (.8 + .2 * bloom)
        put(d, L, dg * math.sqrt((1 - pan) / 2) * 1.414)
        put(d, R, dg * math.sqrt((1 + pan) / 2) * 1.414)
        put(hl, L, gain * bloom); put(hr, R, gain * bloom)
    pk = max(np.abs(L).max(), np.abs(R).max())
    st = (np.stack([L, R], 1) / pk * .89 * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(synth.SR); w.writeframes(st[: int(DUR * synth.SR)].tobytes())


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--vertical"]
    out = args[0]
    if len(args) > 1 and args[1] == "--stills":
        for sec in args[2:]:
            frame(int(float(sec) * FPS)).convert("RGB").save(f"{out}/still_{sec}.png")
        sys.exit()
    audio = os.path.join(tempfile.mkdtemp(), "audio.wav")
    soundtrack(audio)
    ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-i", audio, "-c:v", "libx264", "-preset", "slow",
                           "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
                           "-shortest", out], stdin=subprocess.PIPE)
    with Pool(os.cpu_count()) as pool:
        for i, b in enumerate(pool.imap(render, range(int(DUR * FPS)), chunksize=4)):
            ff.stdin.write(b)
            if i % 150 == 0: print(i, flush=True)
    ff.stdin.close(); ff.wait()
    os.remove(audio)
