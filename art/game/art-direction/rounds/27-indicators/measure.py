# /// script
# dependencies = ["pillow", "numpy"]
# ///
"""Round 27 gate: measure the reload rings in an overhead frame (shoot_battle --look --top).
Per ring: width, height, width/height and centre in pixels. A ring passes at w/h 1.00 within 0.03.
    uv run --script game/art-direction/rounds/27-indicators/measure.py FRAME.png [red|team]
red:  the bright accent-red rings of the early candidates.
team: the shipped ring, the gun's iron shifted toward blue. The vivid aim arcs are cut by
      brightness, and what is left of them by keeping only pixels whose 9x9 neighbourhood is
      mostly ring colour (an arc is 3 to 5 px wide)."""
import sys

import numpy as np
from PIL import Image

im = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(int)
mode = sys.argv[2] if len(sys.argv) > 2 else "red"
r, g, b = im[..., 0], im[..., 1], im[..., 2]
if mode == "red":
    mask = (r > 150) & (g < 90) & (b < 90)
else:
    # the ring is a dark muted blue; the aim arc is the vivid team blue (b well above 160)
    mask = (b - r > 25) & (b > 80) & (b < 160) & (b - g > 15)
    k = 9
    pad = np.pad(mask.astype(int), k // 2)
    s = sum(pad[dy:dy + mask.shape[0], dx:dx + mask.shape[1]] for dy in range(k) for dx in range(k))
    mask = mask & (s >= int(k * k * 0.6))
ys, xs = np.nonzero(mask)
print("ring px", int(mask.sum()))
order = np.argsort(xs)
xs_s, ys_s = xs[order], ys[order]
cuts = [0] + [i for i in range(1, len(xs_s)) if xs_s[i] - xs_s[i - 1] > 40] + [len(xs_s)]
for a, b2 in zip(cuts, cuts[1:]):
    cx, cy = xs_s[a:b2], ys_s[a:b2]
    if len(cx) < 50:
        continue
    w, h = cx.max() - cx.min(), cy.max() - cy.min()
    ok = abs(w / max(h, 1) - 1.0) <= 0.03
    print(f"ring x {cx.min()}-{cx.max()} y {cy.min()}-{cy.max()}  w={w} h={h}  w/h={w / max(h, 1):.2f}"
          f"  centre=({(cx.min() + cx.max()) // 2},{(cy.min() + cy.max()) // 2})  {'PASS' if ok else 'FAIL'}")
