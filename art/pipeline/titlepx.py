#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""What a title lockup shows at store sizes. Each study is cropped to its letters, the pixels that differ from the
corner colour, scaled to every width, then magnified without smoothing and labelled, one row per study. Run from
the repo root.

titlepx.py --widths 212,208,120 --mag 2 --out OUT.png LABEL=STUDY.png ...
The letter widths of the store set: 212 is the header capsule, 920 px * 0.46 at half size, 208 the small capsule,
462 px * 0.90 at half size, 120 the smallest size checked."""

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


def letters(im, pad=12):
    bg = Image.new("RGB", im.size, im.getpixel((2, 2)))
    diff = ImageChops.difference(im, bg)
    mask = ImageChops.lighter(ImageChops.lighter(*diff.split()[:2]), diff.split()[2]).point(lambda v: 255 if v > 40 else 0)
    x0, y0, x1, y1 = mask.getbbox() or (0, 0, im.width, im.height)
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--widths", default="212,208,120")
    ap.add_argument("--mag", type=int, default=2)
    ap.add_argument("--out", required=True)
    ap.add_argument("studies", nargs="+", help="LABEL=STUDY.png")
    a = ap.parse_args()
    widths = [int(w) for w in a.widths.split(",")]
    font = ImageFont.load_default(20)
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if Path(f).exists():
            font = ImageFont.truetype(f, 20)
            break
    rows = []
    for item in a.studies:
        label, path = item.split("=", 1)
        im = letters(Image.open(path).convert("RGB"))
        cells = []
        for w in widths:
            h = round(im.height * w / im.width)
            cells.append((f"{label} at {w} px", im.resize((w, h), Image.LANCZOS).resize((w * a.mag, h * a.mag), Image.NEAREST)))
        rows.append(cells)
    pad, lab = 10, 28
    colw = [w * a.mag for w in widths]
    rowh = [max(c.height for _, c in cells) for cells in rows]
    out = Image.new("RGB", (sum(colw) + pad * (len(widths) + 1), sum(h + lab + pad for h in rowh) + pad), (255, 255, 255))
    d = ImageDraw.Draw(out)
    y = pad
    for cells, h in zip(rows, rowh):
        x = pad
        for (label, cell), cw in zip(cells, colw):
            d.text((x, y), label, fill=(200, 0, 0), font=font)
            out.paste(cell, (x, y + lab))
            x += cw + pad
        y += h + lab + pad
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.out)
    print(a.out)


if __name__ == "__main__":
    main()
