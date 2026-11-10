"""Draw quiet impact pulses for the desk-object skins.

The key and the abacus get rounded-square pulses in cyan and gold; bamboo,
stone, piston, CRT, the cloud gong, the bianzhong, the stone chime and the
temple fish get thin oval ripples in mint, moss green, amber, phosphor green,
patina teal, bronze gold, pale jade and old gold. All are
transparent, rendered at 1024 px and downsampled to 256, like the bowl's ripple.

The images are original and released under CC0 (the code itself is MIT).

Usage: python draw_skin_impacts.py <skins-directory>

Draws those of its skins that are in the directory: App/Resources/Skins for
the ones that ship, App/Resources/Retired for the ones now in the gallery.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

N = 1024
y, x = np.mgrid[0:N, 0:N].astype(np.float64)
c = (N - 1) / 2
dx, dy = (x - c) / (N / 2), (y - c) / (N / 2)

for name, color in [
    ("space-key", (128, 226, 242)),
    ("bamboo-block", (164, 218, 167)),
    ("moss-stone", (186, 203, 139)),
    ("piston", (248, 178, 87)),
    ("crt-terminal", (101, 239, 149)),
    ("abacus", (240, 198, 112)),
    ("cloud-gong", (168, 250, 232)),
    ("bianzhong", (244, 216, 140)),
    ("stone-chime", (206, 238, 224)),
    ("temple-fish", (236, 200, 140)),
]:
    if not (Path(sys.argv[1]) / name).is_dir():
        continue
    if name in ("space-key", "abacus"):
        # A rounded square, flattened to sit on the top of the keycap.
        r = (dx ** 4 + (dy / 0.60) ** 4) ** 0.25
    else:
        r = np.hypot(dx, dy / 0.48)

    a = np.zeros_like(r)
    shade = np.zeros_like(r)
    for radius, strength in [(0.42, 0.9), (0.77, 0.55)]:
        a += strength * np.exp(-((r - radius) / 0.023) ** 2)
        a += strength * 0.18 * np.exp(-((r - radius) / 0.065) ** 2)
        # A faint shadow just outside each ring, lost on a dark desktop, so a
        # pale ring still shows over a light one.
        shade += strength * 0.32 * np.exp(-((r - radius - 0.03) / 0.03) ** 2)
    a = np.clip(a, 0, 1)
    shade = np.clip(shade, 0, 1)
    # The ring over its shadow, in a darker shade of its own colour.
    alpha = a + shade * (1 - a)
    dark = np.array(color) * 0.35
    rgb = (np.array(color) * a[..., None] + dark * (shade * (1 - a))[..., None]) / np.maximum(alpha, 1e-6)[..., None]
    pixels = np.dstack([rgb, alpha * 255]).round().astype(np.uint8)
    image = Image.fromarray(pixels).resize((256, 256), Image.Resampling.LANCZOS)
    image.save(Path(sys.argv[1]) / name / "impact.png", optimize=True)
