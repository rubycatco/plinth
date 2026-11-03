"""Draw quiet impact pulses for the desk-object skins.

The key gets a rounded-square cyan pulse; bamboo, stone, piston and CRT get
thin oval ripples in mint, moss green, amber and phosphor green. All are
transparent, rendered at 1024 px and downsampled to 256, like the bowl's ripple.
The poteto skin gets a warm orange oval, like its pedestal's rim.

The images are original and released under CC0 (the code itself is MIT).

Usage: python draw_skin_impacts.py <skins-directory>
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
    ("poteto", (255, 152, 64)),
    ("space-key", (128, 226, 242)),
    ("bamboo-block", (164, 218, 167)),
    ("moss-stone", (186, 203, 139)),
    ("piston", (248, 178, 87)),
    ("crt-terminal", (101, 239, 149)),
]:
    if name == "space-key":
        # A rounded square, flattened to sit on the top of the keycap.
        r = (dx ** 4 + (dy / 0.60) ** 4) ** 0.25
    else:
        r = np.hypot(dx, dy / 0.48)

    a = np.zeros_like(r)
    for radius, strength in [(0.42, 0.9), (0.77, 0.55)]:
        a += strength * np.exp(-((r - radius) / 0.023) ** 2)
        a += strength * 0.18 * np.exp(-((r - radius) / 0.065) ** 2)
    a = np.clip(a, 0, 1)
    rgb = np.broadcast_to(np.array(color), (N, N, 3))
    pixels = np.dstack([rgb, a * 255]).astype(np.uint8)
    image = Image.fromarray(pixels).resize((256, 256), Image.Resampling.LANCZOS)
    image.save(Path(sys.argv[1]) / name / "impact.png", optimize=True)
