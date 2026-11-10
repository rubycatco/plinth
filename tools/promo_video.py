"""Render Plinth's promo: a 33-second trailer cut to a 140 BPM beat.

1. More knocking, more merit: the fish knocks faster, copies of it fill the
   screen and 功德 +1 piles up.
2. Everything stops. 并无功德.
3. All fifteen built-in skins, quickening: two beats each, then one, then half.
4. What it does, one bar each: knock as you type, knock when a build is done,
   a stick of incense, auto-knock.
5. The drum kit: every skin in one groove, ending on one knock from all.
6. End card.

It draws with showoff_video.py's renderer and plays the skins' real knocks
from knock_synth.py, with a kick, a riser and a sub boom under them.

Usage: python promo_video.py <out.mp4> [--vertical]
       python promo_video.py <out-dir> [--vertical] --stills <seconds>...
"""
import math, os, random, subprocess, sys, tempfile, textwrap, wave
from functools import lru_cache
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import knock_synth as synth
import showoff_video as sv
from showoff_video import SKINS, N, W, H, CX, VERT, FPS, font, text, paste, draw_skin, ease, ramp, clamp, fade

CY = H / 2
B = 60 / 140                                   # one beat, in seconds
def T(b): return b * B

FLOOD, PUNCH, PARADE, FEAT, DROP, END, TOTAL = 8, 16, 20, 36, 52, 68, 78
DUR = T(TOTAL)

@lru_cache(None)
def mono(size, bold=False):
    # DejaVu Sans Mono, from the folder PLINTH_FONTS names if it is there.
    name = "DejaVuSansMono%s.ttf" % ("-Bold" if bold else "")
    own = os.path.join(os.environ.get("PLINTH_FONTS", ""), name)
    return ImageFont.truetype(own if os.path.exists(own) else "/usr/share/fonts/truetype/dejavu/" + name, size)

# ---------------------------------------------------------------- timeline
rnd = random.Random(11)
knocks = []      # (time, skin, bloom, gain, pan): heard
seen = []        # (time, scene, skin): seen
kicks = []       # (time, gain)
popups = []      # (time, x, y, label, size)

def knock(b, k, sc, bloom=.3, gain=1., pan=0., hear=True):
    if hear: knocks.append((T(b), k, bloom, gain, pan))
    seen.append((T(b), sc, k))

# 1. intro: the fish, quickening, earning merit
FISH_FLOOR, FISH_SIDE = (CY + 190, 440) if not VERT else (CY + 220, 560)
intro = [1, 3, 4, 5, 5.5, 6, 6.5, 7, 7.25, 7.5, 7.75]
for b in intro:
    knock(b, 0, "intro", .25, .9)
    popups.append((T(b), CX + rnd.choice([-1, 1]) * rnd.uniform(250, 340), FISH_FLOOR - FISH_SIDE * rnd.uniform(.45, .8), "功德 +1", 46))
for i in range(16):                        # the fish keeps going through the flood
    knock(FLOOD + i * .5, 0, "intro", .15, .7)
    popups.append((T(FLOOD + i * .5), CX + rnd.uniform(-260, 260), FISH_FLOOR - FISH_SIDE - rnd.uniform(0, 80), "功德 +1", 46))

# copies of the fish, spawning faster and faster
CLONES = []
cols, rows = (12, 6) if not VERT else (6, 11)
for r in range(rows):
    for c in range(cols):
        x = (c + .5) / cols * W + rnd.uniform(-25, 25)
        y = (r + .8) / rows * H + rnd.uniform(-20, 20)
        if abs(x - CX) < FISH_SIDE * .62 and FISH_FLOOR - FISH_SIDE * 1.15 < y < FISH_FLOOR + 60: continue
        CLONES.append([x, y])
rnd.shuffle(CLONES)
for i, cl in enumerate(CLONES):
    sp = FLOOD + round(7.2 * (i / len(CLONES)) ** .6 * 4) / 4
    cl.append(sp)
    b = sp
    while b < PUNCH:
        knock(b, 0, f"clone{i}", hear=False)
        popups.append((T(b), cl[0] + rnd.uniform(-20, 20), cl[1] - 110, "+1", 30))
        b += 1
for s in range(32):                        # what the copies sound like: one knock every sixteenth
    b = FLOOD + s / 4
    knocks.append((T(b), rnd.choice([0, 0, 0, 1, 4, 5]), .1, .35 + .45 * s / 31, rnd.uniform(-.8, .8)))
popups.sort()

# 2. punchline
SLAM = PUNCH + 1
knocks.append((T(SLAM), 6, 1.0, 1.6, 0))
knocks.append((T(SLAM), 11, 1.0, 1.1, 0))
seen.append((T(SLAM), "slam", 6))

# 3. the skins, quickening
SLOTS, b = [], PARADE
for k in range(N):
    d = 2 if k < 4 else 1 if k < 9 else .5
    SLOTS.append((k, b, d))
    knock(b, k, "parade", .6 if k in sv.RING else .3, 1.0)
    if d == 2: knock(b + 1, k, "parade", .3, .8)
    b += d
assert b == FEAT
for i in range(PARADE, FEAT):
    kicks.append((T(i), .8))

# 4. features, one bar each
TYPED = "写代码，也是修行"
TYPIST = 4                                 # the pixel fish knocks as you type
for i in range(len(TYPED)):
    knock(FEAT + .25 + i * .45, TYPIST, "type", .2, .8)
CMD = "$ make test; open -g plinth://knock"
knock(FEAT + 7, 0, "term", .8, 1.1)
INC = FEAT + 8
knock(INC + .25, 0, "inc", .5, .9)
for o in (3, 3.33, 3.67):
    knock(INC + o, 0, "inc", .5, .9)
AUTO = FEAT + 12
AUTO_HITS = [0, 1, 1.75, 2.25, 2.625, 3, 3.25, 3.5, 3.625, 3.75, 3.875]
for o in AUTO_HITS:
    knock(AUTO + o, 0, "auto", .2, .85)
for i in range(FEAT, DROP, 2):
    kicks.append((T(i), .55))

# 5. the drum kit, sv's groove at 140
STEP = B / 4
G0 = T(DROP)
for k in range(N):
    knocks.append((G0 + k * STEP, k, .2, .9, (k % sv.LAY["cols"]) / (sv.LAY["cols"] - 1) - .5))
    seen.append((G0 + k * STEP, "grid", k))
for t, k, bl, sc in sv.impacts:
    if sc == "grid" and t > sv.GRID0 + N * sv.STEP - 1e-6 and t < sv.ALL_HIT - 1e-6:
        tt = G0 + (t - sv.GRID0) / sv.STEP * STEP
        knocks.append((tt, k, bl, 1.0, (k % sv.LAY["cols"]) / (sv.LAY["cols"] - 1) - .5))
        seen.append((tt, "grid", k))
for k in range(N):
    knocks.append((T(END), k, 1.0 if k in sv.RING else .5, .55, (k % sv.LAY["cols"]) / (sv.LAY["cols"] - 1) - .5))
    seen.append((T(END), "grid", k))
for i in range(DROP, END):
    kicks.append((T(i), 1.0 if (i - DROP) % 4 == 0 else .8))
kicks.append((T(END), 1.2))

# 6. end card
knock(END + 4, 0, "end", 1.0, 1.0)

sv.HITS = {}
for t, sc, k in sorted(seen):
    sv.HITS.setdefault((sc, k), []).append(t)


# ---------------------------------------------------------------- drawing helpers
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
DARK = np.array((10, 11, 15), np.float32)
VIG = np.clip(1 - .5 * (((xx - CX) / W) ** 2 + ((yy - CY) / H) ** 2) * 2.2, 0, 1)[..., None]

@lru_cache(64)
def glow_map(cy, rx, ry):
    return np.exp(-(((xx - CX) / rx) ** 2 + ((yy - cy) / ry) ** 2))[..., None]

def bg(color, base=0., glow=0., cy=None, rx=None, ry=None):
    c = np.array(color, np.float32)
    g = glow_map(int(cy or CY), int(rx or W * .35), int(ry or H * .4))
    img = (DARK + c * base) * VIG + g * c * glow
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

def camera(im, z=1., dx=0., dy=0.):
    if abs(z - 1) < 1e-4 and abs(dx) < .5 and abs(dy) < .5: return im
    return im.transform((W, H), Image.AFFINE, (1 / z, 0, CX - (CX + dx) / z, 0, 1 / z, CY - (CY + dy) / z), Image.BILINEAR)

def overlay(im, color, a):
    if a <= .003: return im
    return Image.blend(im, Image.new("RGBA", (W, H), color + (255,)), clamp(a))

def since(sc, k, t):
    h = sv.last_hit(sc, k, t)
    return None if h is None or t < h else t - h

def shake(t, amp, seed=0):
    return amp * math.sin(t * 91 + seed), amp * math.cos(t * 73 + 2 * seed)

def slam(t, t0, dur=.14):
    """1 at rest; bigger before t0 + dur, for text that lands."""
    return 1 + .9 * (1 - ease(ramp(t, t0, t0 + dur)))

def title(canvas, t, t0, zh, en, y):
    a = ease(ramp(t, t0, t0 + .08))
    s = slam(t, t0, .12)
    text(canvas, zh, font("sansb", int(78 * s)), CX, y, (245, 242, 236), a)
    if VERT: en = "\n".join(textwrap.wrap(en, 44))
    text(canvas, en, font("serif", 32), CX, y + 74 + 24 * en.count("\n"), (170, 166, 158), ease(ramp(t, t0 + .1, t0 + .3)))

def panel(canvas, box, fill=(24, 26, 32), outline=(60, 64, 72)):
    ImageDraw.Draw(canvas).rounded_rectangle(box, 22, fill=fill + (235,), outline=outline + (255,), width=2)


# ---------------------------------------------------------------- scenes
def merit_count(t):
    return sum(1 for p in popups if p[0] <= t)

def draw_popups(canvas, t):
    for t0, x, y, label, size in popups:
        u = t - t0
        if 0 <= u < .7:
            a = (1 - ramp(u, .35, .7)) * ease(ramp(u, 0, .05))
            text(canvas, label, font("serifb", int(size * slam(t, t0, .08) ** .4)), x, y - 90 * ease(u / .7),
                 (255, 214, 120), a)

def scene_flood(t, frozen=False):
    heat = ramp(t, T(FLOOD), T(PUNCH))
    canvas = bg(SKINS[0][4], .02 + .06 * heat, .22 + .25 * heat, FISH_FLOOR - FISH_SIDE * .4)
    for i, (x, y, sp) in enumerate(CLONES):
        st = since(f"clone{i}", 0, t + .13)         # its first swing starts .13 s before the knock
        if t < T(sp) - .13: continue
        pop = ease(ramp(t, T(sp) - .13, T(sp) - .02))
        draw_skin(canvas, 0, x, y, 130 * (.6 + .4 * pop), t, f"clone{i}", pop * .9, reflect=False, ring=False)
    draw_skin(canvas, 0, CX, FISH_FLOOR, FISH_SIDE, t, "intro", ease(ramp(t, 0, .3)))
    draw_popups(canvas, t)
    n = merit_count(t)
    if n and not frozen:
        last = max(p[0] for p in popups if p[0] <= t)
        y = 150 if not VERT else 300
        text(canvas, f"功德  {n}", font("serifb", int(72 * (1 + .12 * math.exp(-(t - last) * 20)))), CX, y, (255, 214, 120))
    z = 1 + .05 * ease(heat)
    dx, dy = shake(t, 9 * ramp(t, T(PUNCH - 2), T(PUNCH)) ** 2)
    canvas = camera(canvas, z, dx, dy)
    if frozen:
        canvas = overlay(canvas, (0, 0, 0), .55)
    return canvas

def scene_punch(t):
    if t < T(PUNCH + .75):                         # freeze, and strike the count out
        canvas = scene_flood(T(PUNCH) - 1e-3, frozen=True)
        y = 150 if not VERT else 300
        n = merit_count(T(PUNCH) - 1e-3)
        w = text(canvas, f"功德  {n}", font("serifb", 72), CX, y, (255, 214, 120)) - 8
        ln = ease(ramp(t, T(PUNCH + .1), T(PUNCH + .35)))
        if ln > 0:
            ImageDraw.Draw(canvas).line((CX - w / 2 - 20, y + 4, CX - w / 2 - 20 + (w + 40) * ln, y + 4), fill=(235, 70, 70, 255), width=10)
        return canvas
    if t < T(SLAM):
        return bg((0, 0, 0))
    u = t - T(SLAM)
    canvas = bg(SKINS[6][4], 0, .35 * math.exp(-u * 1.5) + .08, CY, W * .5, H * .35)
    s = slam(t, T(SLAM), .1)
    text(canvas, "并无功德", font("serifb", int((150 if not VERT else 170) * s)), CX, CY - 30, (244, 238, 226), ease(ramp(u, 0, .05)))
    text(canvas, "No merit at all.", font("serif", 40), CX, CY + 110, (170, 166, 158), ease(ramp(u, .35, .6)))
    text(canvas, "— 达摩答梁武帝  Bodhidharma, to Emperor Wu", font("serif", 24), CX, CY + 170, (110, 108, 104), ease(ramp(u, .6, .9)))
    dx, dy = shake(t, 22 * math.exp(-u * 9), 3)
    return camera(canvas, 1 + .03 * math.exp(-u * 6), dx, dy)

PFLOOR, PSIDE = (CY + 230, 560) if not VERT else (CY + 260, 720)

def scene_parade(t):
    for k, b0, d in SLOTS:
        if t < T(b0 + d): break
    u = t - T(b0)
    col = SKINS[k][4]
    canvas = bg(col, .1, .5, PFLOOR - PSIDE * .45, W * .3, H * .35)
    zh = SKINS[k][2]
    gsize = int(min(H * .62 if not VERT else W * .9, W * .95 / max(len(zh), 1)))
    text(canvas, zh, font("serifb", gsize), CX, PFLOOR - PSIDE * .5, col, .13)
    sgn = 1 if k % 2 else -1
    draw_skin(canvas, k, CX + sgn * 160 * math.exp(-u * 22), PFLOOR, PSIDE, t, "parade", 1.0, reflect=True)
    ny = PFLOOR + (70 if not VERT else 110)
    text(canvas, SKINS[k][0], font("sansb", int(64 * slam(t, T(b0), .1) ** .5)), CX, ny, (245, 242, 236))
    text(canvas, zh, font("serif", 38), CX, ny + 72, col)
    if d >= 1:
        text(canvas, SKINS[k][5], font("serif", 26), CX, ny + 122, (160, 156, 150), ease(ramp(u, .1, .3)))
    top = 70 if not VERT else 230
    text(canvas, f"{k + 1:02d} / {N}", mono(34, True), W - 140 if not VERT else CX, top if not VERT else top + 70, col)
    if not VERT:
        text(canvas, f"{N} 种皮肤，{N} 种声音", font("sansb", 34), 150, top, (230, 226, 218), anchor="lm")
    else:
        text(canvas, f"{N} 种皮肤，{N} 种声音", font("sansb", 40), CX, top, (230, 226, 218))
    z = 1 + .07 * math.exp(-u * 14)
    return camera(canvas, z)

def feat_layout():
    # (title y, panel box, fish x, fish floor, fish side)
    if not VERT:
        return 150, (180, 380, 1060, 760), 1450, 900, 470
    return 330, (90, 560, 990, 960), CX, 1640, 560

def scene_feat(t):
    b = t / B
    ty, box, fx, ff, fs = feat_layout()
    if b < FEAT + 4:            # knock as you type
        canvas = bg(SKINS[TYPIST][4], .05, .3, ff - fs * .4)
        title(canvas, t, T(FEAT), "打字也会敲", "Knock as you type. Plinth never learns which key.", ty)
        panel(canvas, box)
        times = sv.HITS[("type", TYPIST)]
        n = sum(1 for h in times if h <= t)
        line = TYPED[:n] + ("▍" if int(t * 4) % 2 or n < len(TYPED) else " ")
        text(canvas, line, font("serif", 64), box[0] + 60, (box[1] + box[3]) / 2, (235, 232, 224), anchor="lm")
        draw_skin(canvas, TYPIST, fx, ff, fs, t, "type", 1.0)
    elif b < FEAT + 8:          # knock when the build is done
        canvas = bg(SKINS[0][4], .04, .3, ff - fs * .4)
        title(canvas, t, T(FEAT + 4), "活干完了，敲一下", "open -g plinth://knock  when a build, a test run or an agent is done.", ty)
        panel(canvas, box, (8, 10, 12), (50, 56, 60))
        x0, y0 = box[0] + 40, box[1] + 70
        n = int(len(CMD) * ramp(t, T(FEAT + 4.3), T(FEAT + 5.6)))
        fsz = 34 if not VERT else 30
        cmd = CMD[:n]
        text(canvas, cmd + ("█" if n < len(CMD) or int(t * 4) % 2 else ""), mono(fsz), x0, y0,
             (210, 214, 210), anchor="lm", spacing=14)
        dots = int(ramp(t, T(FEAT + 5.8), T(FEAT + 6.6)) * 12)
        oy = y0 + 90
        if t > T(FEAT + 5.8):
            text(canvas, "running " + "." * dots, mono(fsz), x0, oy, (120, 126, 130), anchor="lm")
        if t > T(FEAT + 6.75):
            text(canvas, "✓ 128 tests passed", mono(fsz, True), x0, oy + 70, (101, 239, 149), anchor="lm")
        draw_skin(canvas, 0, fx, ff, fs, t, "term", 1.0)
    elif b < FEAT + 12:         # incense
        canvas = bg((255, 170, 90), .03, .25, ff - fs * .4)
        title(canvas, t, T(INC), "点一炷香", "A stick of incense. One knock to light it, three when it goes out.", ty)
        cx = box[0] + (box[2] - box[0]) * .5 if not VERT else CX
        cy = ff if not VERT else box[3]
        draw_incense(canvas, t, cx, cy, ramp(t, T(INC + .25), T(INC + 3)))
        draw_skin(canvas, 0, fx, ff, fs, t, "inc", 1.0)
    else:                       # auto-knock, quickening
        canvas = bg(SKINS[0][4], .05, .35 + .3 * ramp(t, T(AUTO), T(DROP)), CY)
        title(canvas, t, T(AUTO), "自动敲 · 起板", "Auto-knock: steady, quickening, or natural. It can stop at 108.", ty)
        acx, acy, aside = CX, CY + (230 if not VERT else 300), 340 if not VERT else 500
        prog = ramp(t, T(AUTO), T(DROP)) ** 1.6
        R = aside * .78
        d = ImageDraw.Draw(canvas)
        for i in range(108):
            a = -math.pi / 2 + 2 * math.pi * i / 108
            x, y = acx + R * math.cos(a), acy - aside * .45 + R * math.sin(a)
            on = i < prog * 108
            r = 5 if on else 3
            c = SKINS[0][4] if on else (70, 70, 78)
            d.ellipse((x - r, y - r, x + r, y + r), fill=c + (255,))
        cnt = int(prog * 108)
        text(canvas, f"{cnt}", mono(30, True), acx, acy - aside * .45 + R + 40, (240, 200, 240))
        draw_skin(canvas, 0, acx, acy, aside, t, "auto", 1.0)
        z = 1 + .04 * ramp(t, T(AUTO), T(DROP)) ** 2
        canvas = camera(canvas, z, *shake(t, 6 * ramp(t, T(DROP - 1), T(DROP)) ** 2))
    return canvas

CENSER = sv.load(f"{sv.RES}/censer.png")

def draw_incense(canvas, t, cx, bottom, burnt):
    cw = 400; ch = int(cw * 170 / 280)
    cen = CENSER.resize((cw, ch), Image.LANCZOS)
    x0, y0 = cx - cw / 2, bottom - ch
    px, py = x0 + cw * .502, y0 + ch * .27
    full = 330
    top = py - full * (1 - .9 * burnt)
    d = ImageDraw.Draw(canvas)
    d.line((px, py, px, top), fill=(150, 92, 60, 255), width=9)
    ash = min(26, full * .9 * burnt * .2)
    d.line((px, top, px, top + ash), fill=(150, 146, 140, 255), width=9)
    lit = burnt < 1 and t > T(INC + .25)
    if lit:
        for r, a in ((22, 40), (12, 90), (6, 255)):
            d.ellipse((px - r, top - r, px + r, top + r), fill=(255, 140, 60, a))
    # smoke: a thread that rises straight, then curls
    if t > T(INC + .3):
        fadeout = 1 - ramp(t, T(INC + 3), T(INC + 4))
        pts = []
        for j in range(60):
            s = j / 59
            y = top - s * 230
            x = px + (s ** 1.8) * 46 * math.sin(s * 7 - t * 2.2) + s * 30 * math.sin(t * .9)
            pts.append((x, y))
        for j in range(len(pts) - 1):
            a = int(150 * (1 - j / 59) ** 1.3 * fadeout)
            d.line((pts[j], pts[j + 1]), fill=(210, 210, 216, a), width=max(2, int(3 + 6 * j / 59)))
    paste(canvas, cen, x0, y0)

def scene_drop(t):
    u = t - T(DROP)
    canvas = bg((150, 120, 220), .03, .12 + .25 * sv.glow_pulse(t, "grid", range(N)))
    for k in range(N):
        r, c = divmod(k, sv.LAY["cols"])
        st = ease(ramp(t, T(DROP) - .5 + .02 * k, T(DROP) - .1 + .02 * k))
        lit = since("grid", k, t)
        lit = math.exp(-lit * 6) if lit is not None else 0
        draw_skin(canvas, k, sv.GX[c], sv.GY[r] - 20, sv.LAY["gside"] * (.8 + .2 * st), t, "grid", st, reflect=False)
        base = np.array((120, 120, 124)); hc = np.array(SKINS[k][4])
        text(canvas, f"{SKINS[k][0]}  {SKINS[k][2]}", font("sans", sv.LAY["glabel"]), sv.GX[c], sv.GY[r] + 2,
             tuple(int(v) for v in base + (hc - base) * lit), st)
    bar = int(max(u, 0) // T(4))
    ub = u - bar * T(4)
    z = 1 + .05 * math.exp(-ub * 7) + .02 * bar
    return camera(canvas, z)

def scene_end(t):
    u = t - T(END)
    a = 1 - ease(ramp(t, DUR - .6, DUR))
    pulse = sv.glow_pulse(t, "end", [0])
    if not VERT:
        floor, side, ty = 470, 380, 590
    else:
        floor, side, ty = 900, 520, 1040
    canvas = bg(SKINS[0][4], .03, (.15 + .2 * pulse) * a, floor - side * .4)
    draw_skin(canvas, 0, CX, floor, side, t, "end", a * ease(ramp(u, 0, .3)))
    b1, b2, b3 = T(END + 1), T(END + 2), T(END + 3)
    text(canvas, "Plinth", font("sansb", int((140 if VERT else 130) * slam(t, b1, .12))), CX, ty, (245, 242, 236), a * ease(ramp(t, b1, b1 + .06)))
    text(canvas, "Mac 桌面上的一只小木鱼", font("serifb", 44), CX, ty + 115, (230, 224, 212), a * ease(ramp(t, b2, b2 + .15)))
    text(canvas, "A tiny wooden fish for your Mac's desktop. Knock it. Earn no merit." if not VERT else
         "A tiny wooden fish for your Mac's desktop.\nKnock it. Earn no merit.", font("serif", 28), CX, ty + 175 + 14 * VERT,
         (160, 156, 150), a * ease(ramp(t, b2 + .15, b2 + .4)))
    text(canvas, "github.com/rubycatco/plinth  ·  macOS 14+  ·  free", font("sans", 30), CX, ty + 270 + 30 * VERT, (128, 226, 242),
         a * ease(ramp(t, b3, b3 + .2)))
    canvas = overlay(canvas, (255, 255, 255), .9 * math.exp(-u * 4))
    return canvas

def frame(fi):
    t = fi / FPS
    if t < T(PUNCH): c = scene_flood(t)
    elif t < T(PARADE): c = scene_punch(t)
    elif t < T(FEAT): c = scene_parade(t)
    elif t < T(DROP): c = scene_feat(t)
    elif t < T(END): c = scene_drop(t)
    else: c = scene_end(t)
    # one-frame flash on every hard cut
    for cut in (PARADE, FEAT, FEAT + 4, FEAT + 8, FEAT + 12, DROP):
        if 0 <= t - T(cut) < 1.5 / FPS:
            c = overlay(c, (255, 255, 255), .25)
    return c

def render(fi):
    return frame(fi).convert("RGB").tobytes()


# ---------------------------------------------------------------- audio
SR = synth.SR

def kick_sample():
    n = int(.5 * SR); x = np.arange(n) / SR
    f = 46 + 84 * np.exp(-x * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-x * 7) + .25 * np.exp(-x * 400) * np.random.default_rng(1).standard_normal(n)
    return s * .9

def boom_sample():
    n = int(2.6 * SR); x = np.arange(n) / SR
    f = 34 + 50 * np.exp(-x * 6)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 1.6)
    nz = np.random.default_rng(2).standard_normal(n)
    from scipy.signal import lfilter
    nz = lfilter([.02], [1, -.98], nz) * np.exp(-x * 3)
    return s + nz * 2

def riser(n_len, rng):
    from scipy.signal import lfilter
    x = np.linspace(0, 1, n_len)
    nz = rng.standard_normal(n_len)
    out = np.zeros(n_len); y = 0.
    for i0 in range(0, n_len, 512):                # a lowpass that opens up
        a = .02 + .5 * x[i0] ** 2
        seg, zi = lfilter([a], [1, -(1 - a)], nz[i0:i0 + 512], zi=[y * (1 - a)])
        out[i0:i0 + 512] = seg; y = seg[-1]
    return out * x ** 2.2 * .5

def soundtrack(path):
    r = random.Random(7)
    n = int((DUR + 3) * SR)
    L = np.zeros(n); R = np.zeros(n)
    def put(sig, t, gl, gr, rate=1.):
        if rate != 1.:
            idx = np.arange(0, len(sig) - 1, rate); sig = np.interp(idx, np.arange(len(sig)), sig)
        i0 = int(t * SR); m = min(len(sig), n - i0)
        L[i0:i0 + m] += sig[:m] * gl; R[i0:i0 + m] += sig[:m] * gr
    cache = {}
    for t, k, bloom, gain, pan in knocks:
        v = SKINS[k][3]
        if v not in cache: cache[v] = synth.prepare(v)
        d, hl, hr = r.choice(cache[v])
        rate = r.uniform(.98, 1.02)
        g = .5 * gain * r.uniform(.88, 1.)
        put(d, t, g * math.sqrt((1 - pan) / 2) * 1.414, g * math.sqrt((1 + pan) / 2) * 1.414, rate)
        idx = np.arange(0, len(hl) - 1, rate)
        put(np.interp(idx, np.arange(len(hl)), hl), t, g * bloom, 0)
        put(np.interp(idx, np.arange(len(hr)), hr), t, 0, g * bloom)
    ks = kick_sample()
    for t, g in kicks:
        put(ks, t, .42 * g, .42 * g)
    rng = np.random.default_rng(3)
    for b0, b1 in ((PUNCH - 4, PUNCH), (DROP - 4, DROP)):
        rs = riser(int(T(b1 - b0) * SR), rng)
        put(rs, T(b0), .5, .5)
        put(np.roll(rs, 300), T(b0), 0, .1)
    # silence before the punchline, then the boom
    i0, i1 = int(T(PUNCH) * SR), int(T(SLAM) * SR)
    env = np.ones(n); f = int(.006 * SR)
    env[i0:i1] = 0; env[i0 - f:i0] = np.linspace(1, 0, f); env[i1 - f:i1] = np.linspace(0, 1, f)
    L *= env; R *= env
    put(boom_sample(), T(SLAM), .55, .55)
    put(boom_sample()[: int(1.2 * SR)] * np.linspace(1, 0, int(1.2 * SR)), T(END), .4, .4)
    pk = max(np.abs(L).max(), np.abs(R).max())
    st = np.stack([L, R], 1) / pk * .89
    st = (np.tanh(st * 1.6) / np.tanh(1.6) * .89 * 32767).astype(np.int16)   # glue it a little
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(st[: int(DUR * SR)].tobytes())


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
