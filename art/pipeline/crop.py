#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Magnified crops for a detail check, one labelled cell per crop. A box is x0,y0,x1,y1 as fractions of the
frame; --box sets the default and @x0,y0,x1,y1 after an image overrides it. Run from the repo root.

crop.py --box 0.1,0.3,0.6,0.8 --mag 2 --cols 2 --out OUT.png "LABEL=IMG.png[@x0,y0,x1,y1]" ..."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--box", default="0,0,1,1")
    ap.add_argument("--mag", type=float, default=2)
    ap.add_argument("--cols", type=int, default=2)
    ap.add_argument("--out", required=True)
    ap.add_argument("crops", nargs="+", help="LABEL=IMG.png[@x0,y0,x1,y1]")
    a = ap.parse_args()
    font = ImageFont.load_default(20)
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if Path(f).exists():
            font = ImageFont.truetype(f, 20)
            break
    cells = []
    for item in a.crops:
        label, path = item.split("=", 1)
        path, at, box = path.rpartition("@")
        if not at:
            path, box = box, a.box
        x0, y0, x1, y1 = (min(max(float(v), 0), 1) for v in box.split(","))
        im = Image.open(path).convert("RGB")
        win = im.crop((round(im.width * x0), round(im.height * y0), round(im.width * x1), round(im.height * y1)))
        cells.append((label, win.resize((round(win.width * a.mag), round(win.height * a.mag)), Image.LANCZOS)))
    pad, lab = 10, 28
    cols = min(a.cols, len(cells))
    rows = -(-len(cells) // cols)
    cw = max(c.width for _, c in cells)
    ch = max(c.height for _, c in cells)
    out = Image.new("RGB", (cols * (cw + pad) + pad, rows * (ch + lab + pad) + pad), (255, 255, 255))
    d = ImageDraw.Draw(out)
    for i, (label, c) in enumerate(cells):
        x = pad + (i % cols) * (cw + pad)
        y = pad + (i // cols) * (ch + lab + pad)
        d.text((x, y), label, fill=(200, 0, 0), font=font)
        out.paste(c, (x, y + lab))
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.out)
    print(a.out)


if __name__ == "__main__":
    main()
