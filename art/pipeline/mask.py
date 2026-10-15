#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Local fixes of a generated image. Coordinates are fractions of the frame, the convention of crop.py, so the crop
that shows a fault gives the numbers that fix it. Run from the repo root.

mask.py box   --out MASK.png IMG.png x0,y0,x1,y1 ...        white where a model repaints, black elsewhere
mask.py paint --out PAINTED.png IMG.png OP ...              a rough paint-over the inpainting model refines
    fill=x0,y0,x1,y1                 the box in the median colour of a ring around it, to erase an object
    line=x0,y0,x1,y1,width,#hex      a stroke, width in px, a barrel
    rect=x0,y0,x1,y1,#hex            a filled box, a carriage
    disc=cx,cy,radius,#hex           a filled circle, radius in px, a wheel or a muzzle
    copy=x0,y0,x1,y1,dx,dy[,flip]    the box pasted with its top left at dx,dy, mirrored with flip: a second
                                     object identical in size and style to the first
mask.py paste --out OUT.png --base A.png --top B.png --mask MASK.png [--feather 6]
    B over A through the mask, blurred at the edge, so nothing outside the mask changes whatever model made B"""

import argparse
import datetime as dt
import json
import statistics
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


def write_sidecar(out, tool, inputs, params):
    meta = {"tool": f"mask.py {tool}", "argv": sys.argv, "inputs": inputs, "params": params, "est_cost_usd": 0.0,
            "created": dt.datetime.now().isoformat(timespec="seconds"), "outputs": [Path(out).name]}
    Path(out).with_suffix(".json").write_text(json.dumps(meta, indent=2))


def px(im, xs, ys):
    return [round(im.width * float(x)) for x in xs], [round(im.height * float(y)) for y in ys]


def cmd_box(a):
    im = Image.open(a.image)
    mask = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(mask)
    for box in a.ops:
        (x0, x1), (y0, y1) = px(im, box.split(",")[0::2], box.split(",")[1::2])
        d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=255)
    mask.save(a.out)
    print(a.out)


def ring_median(im, x0, y0, x1, y1):
    m = max(4, round(0.25 * min(x1 - x0, y1 - y0)))
    outer = im.crop((max(0, x0 - m), max(0, y0 - m), min(im.width, x1 + m), min(im.height, y1 + m)))
    ox, oy = max(0, x0 - m), max(0, y0 - m)
    pixels = [outer.getpixel((x, y)) for x in range(outer.width) for y in range(outer.height)
              if not (x0 <= x + ox < x1 and y0 <= y + oy < y1)]
    return tuple(round(statistics.median(p[c] for p in pixels)) for c in range(3))


def cmd_paint(a):
    im = Image.open(a.image).convert("RGB")
    d = ImageDraw.Draw(im)
    for op in a.ops:
        kind, args = op.split("=", 1)
        v = args.split(",")
        if kind == "fill":
            (x0, x1), (y0, y1) = px(im, v[0::2][:2], v[1::2][:2])
            d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=ring_median(im, x0, y0, x1, y1))
        elif kind == "line":
            (x0, x1), (y0, y1) = px(im, [v[0], v[2]], [v[1], v[3]])
            d.line((x0, y0, x1, y1), fill=v[5], width=int(v[4]))
        elif kind == "rect":
            (x0, x1), (y0, y1) = px(im, [v[0], v[2]], [v[1], v[3]])
            d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=v[4])
        elif kind == "disc":
            (cx,), (cy,) = px(im, [v[0]], [v[1]])
            r = int(v[2])
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=v[3])
        elif kind == "copy":
            (x0, x1, dx), (y0, y1, dy) = px(im, [v[0], v[2], v[4]], [v[1], v[3], v[5]])
            patch = im.crop((x0, y0, x1, y1))
            im.paste(patch.transpose(Image.FLIP_LEFT_RIGHT) if v[6:] == ["flip"] else patch, (dx, dy))
        else:
            raise SystemExit(f"unknown op {kind}")
    im.save(a.out)
    write_sidecar(a.out, "paint", [a.image], {"ops": a.ops})
    print(a.out)


def cmd_paste(a):
    base = Image.open(a.base).convert("RGB")
    top = Image.open(a.top).convert("RGB").resize(base.size, Image.LANCZOS)
    mask = Image.open(a.mask).convert("L").resize(base.size).filter(ImageFilter.GaussianBlur(a.feather))
    Image.composite(top, base, mask).save(a.out)
    write_sidecar(a.out, "paste", [a.base, a.top, a.mask], {"feather": a.feather})
    print(a.out)


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    for name, f in (("box", cmd_box), ("paint", cmd_paint)):
        p = sp.add_parser(name)
        p.add_argument("--out", required=True)
        p.add_argument("image")
        p.add_argument("ops", nargs="+")
        p.set_defaults(f=f)
    p = sp.add_parser("paste")
    p.add_argument("--out", required=True)
    p.add_argument("--base", required=True)
    p.add_argument("--top", required=True)
    p.add_argument("--mask", required=True)
    p.add_argument("--feather", type=float, default=6)
    p.set_defaults(f=cmd_paste)
    a = ap.parse_args()
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    a.f(a)


if __name__ == "__main__":
    main()
