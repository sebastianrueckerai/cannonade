#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow", "numpy"]
# ///
"""Sebastian's picked guns of round 17 on one sheet, small to large: each gun is cut from its board along the
paper colour, with its shadow, and set on a plain paper canvas. Run from the repo root:
uv run --script game/art-direction/rounds/17-painted-sketches/ladder.py"""

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

D = Path(__file__).parent
SMALL = ("9-fortress-long--nanobanana.png", (0.02, 0.33, 0.25, 0.80))
MEDIUM = ("8-shields-nowheels--nanobanana.png", (0.25, 0.27, 0.575, 0.80))
LADDERS = {
    "ladder-a.png": [SMALL, MEDIUM, ("3b-classic-guns--nanobanana.png", (0.605, 0.20, 0.97, 0.82))],
    "ladder-b.png": [SMALL, MEDIUM, ("10-large-noshield--nanobanana.png", (0.58, 0.10, 0.98, 0.90))],
}
WIDTHS = (1.0, 1.6, 2.3)  # relative widths of the three guns: sizes that read, not measured
W, H = 2752, 1376


def paper(a):
    edge = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    return np.median(edge, axis=0)


def cut(name, box):
    im = np.asarray(Image.open(D / name).convert("RGB")).astype(float)
    bg = paper(im)
    h, w = im.shape[:2]
    x0, y0, x1, y1 = int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)
    a = im[y0:y1, x0:x1]
    alpha = np.clip((np.abs(a - bg).max(axis=2) - 8) / 32, 0, 1)
    core = Image.fromarray((alpha > 0.5).astype(np.uint8) * 255).filter(ImageFilter.MinFilter(7)).filter(ImageFilter.MaxFilter(7)).copy()
    ys, xs = np.nonzero(np.asarray(core) > 127)
    seed = (int(np.median(xs)), int(np.median(ys)))
    ImageDraw.floodfill(core, seed, 128)
    keep = Image.fromarray(((np.asarray(core) == 128) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(41)).filter(ImageFilter.GaussianBlur(8))
    alpha = alpha * (np.asarray(keep) / 255)
    ys, xs = np.nonzero(alpha > 0.05)
    rgba = np.dstack([a, alpha * 255])[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return Image.fromarray(rgba.astype(np.uint8), "RGBA"), bg


def main():
    for out, guns in LADDERS.items():
        cuts = [cut(n, b) for n, b in guns]
        canvas_bg = np.mean([bg for _, bg in cuts], axis=0)
        canvas = Image.new("RGB", (W, H), tuple(int(v) for v in canvas_bg))
        unit = (W * 0.84) / sum(WIDTHS)
        x = W * 0.06
        base = H * 0.80
        for (im, _), rel in zip(cuts, WIDTHS):
            f = unit * rel / im.width
            im = im.resize((round(im.width * f), round(im.height * f)), Image.LANCZOS)
            canvas.paste(im, (round(x), round(base - im.height)), im)
            x += im.width + W * 0.02
        canvas.save(D / out)
        (D / out).with_suffix(".json").write_text(json.dumps({
            "tool": "ladder.py", "inputs": [n for n, _ in guns], "boxes": [b for _, b in guns],
            "relative_widths": WIDTHS, "est_cost_usd": 0.0}, indent=1))
        print(out)


if __name__ == "__main__":
    main()
