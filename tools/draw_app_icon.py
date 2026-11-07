"""Draw App/AppIcon.png, and the iPhone app's icons: the ink fish on a tile of rice paper.

The same paper and ink as the disk image's background and Settings > Why a
Fish: the default skin's idle frame, App/Resources/Skins/ink-fish/idle.png,
with its own small seal, alone on rice paper. In the disk image the tile
sits in the background's ensō, as the fish does on the scroll, so the icon
draws none of its own. The paper darkens a little toward its edge, so the
tile keeps its shape on a light desktop and on that paper.

The tile is the squircle the icon already has: its alpha is read from
App/AppIcon.png and kept exactly, so the corners and the 100 px margin stay
those of a macOS icon. With --ios, the same tile is drawn for the iPhone
app instead: the squircle's square, filled to its edges and opaque, as iOS
rounds an icon itself and refuses one with transparency. --ios-dark and
--ios-tinted draw the iPhone's dark and tinted icons, the fish alone and in
the same place, as Apple asks for them: for dark, a little subdued on
transparency, for iOS to lay its dark ground behind; for tinted, in grey on
black, so the tint takes what is light and the ink stays dark. Rendered at
2x and downsampled.
Needs numpy and pillow.

The image is original and released under CC0, like the project's other art.

Usage: python draw_app_icon.py <out.png>   (normally App/AppIcon.png)
       python draw_app_icon.py --ios|--ios-dark|--ios-tinted <out.png>
           (normally AppIcon.png, AppIcon-Dark.png or AppIcon-Tinted.png in
           iOS/Plinth/Assets.xcassets/AppIcon.appiconset)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import draw_dmg_background as dmg

ROOT = Path(__file__).resolve().parents[1]
SIDE = 1024
WORK = 2 * SIDE


def main(out, look=""):
    mask = Image.open(ROOT / "App/AppIcon.png").getchannel("A")
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:WORK, 0:WORK].astype(np.float32) / WORK

    # Rice paper, as in the disk image: flat, faint fibres, a little grain.
    paper = np.ones((WORK, WORK, 3), np.float32) * np.array(dmg.PAPER, np.float32)
    grain = rng.normal(0, 1, (WORK // 8, WORK // 8)).astype(np.float32)
    grain = np.asarray(Image.fromarray(grain).resize((WORK, WORK), Image.BICUBIC))
    paper += grain[..., None] * 1.6
    fibres = Image.new("L", (WORK, WORK), 0)
    fd = ImageDraw.Draw(fibres)
    for _ in range(90):
        x, y = rng.uniform(0, WORK), rng.uniform(0, WORK)
        angle, length = rng.uniform(0, np.pi), rng.uniform(WORK * .02, WORK * .07)
        bend = rng.uniform(-0.4, 0.4)
        fd.line([(x + length * s * np.cos(angle + bend * s), y + length * s * np.sin(angle + bend * s))
                 for s in np.linspace(0, 1, 12)], fill=int(rng.uniform(40, 110)), width=8)
    paper -= np.asarray(fibres.filter(ImageFilter.GaussianBlur(4)), np.float32)[..., None] / 255 * 9

    # Lit from above: the paper darkens toward the tile's edge and its foot.
    edge = np.hypot(xx - .5, (yy - .45) * 1.1) / .5
    paper *= (1 - .055 * np.clip(edge, 0, 1.2) ** 3)[..., None]

    # The fish, its visible part centred, a little below the middle.
    fish = Image.open(ROOT / "App/Resources/Skins/ink-fish/idle.png").convert("RGBA")
    left, top, right, bottom = fish.getchannel("A").point(lambda a: 255 * (a > 24)).getbbox()
    scale = WORK * .55 / (right - left)
    fish = fish.resize((round(fish.width * scale), round(fish.height * scale)), Image.LANCZOS)
    x = round(WORK / 2 - (left + right) / 2 * scale)
    y = round(WORK * .535 - (top + bottom) / 2 * scale)
    layer = np.zeros((WORK, WORK, 4), np.float32)
    layer[max(y, 0):y + fish.height, max(x, 0):x + fish.width] = np.asarray(fish, np.float32)[max(-y, 0):, max(-x, 0):]
    a = layer[..., 3:] / 255
    if look == "ios-dark":
        picture = Image.fromarray(np.clip(np.dstack([layer[..., :3] * .85, layer[..., 3]]), 0, 255).astype(np.uint8))
    elif look == "ios-tinted":
        grey = layer[..., :3] @ np.array([.2126, .7152, .0722], np.float32) * a[..., 0]
        picture = Image.fromarray(np.clip(grey, 0, 255).astype(np.uint8))
    else:
        picture = Image.fromarray(np.clip(paper * (1 - a) + layer[..., :3] * a, 0, 255).astype(np.uint8))
    if look:
        tile = picture.resize((SIDE, SIDE), Image.LANCZOS, box=tuple(2 * v for v in mask.getbbox()))
    else:
        tile = picture.resize((SIDE, SIDE), Image.LANCZOS)
        tile.putalpha(mask)
    tile.save(out, optimize=True)


if __name__ == "__main__":
    look = sys.argv[1][2:] if sys.argv[1].startswith("--") else ""
    main(sys.argv[-1], look)
