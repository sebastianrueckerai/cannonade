#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""The 13 pixel test for a palette. Left: the frame scaled so one tile is 24.7 px wide, the tile width of the gameplay
contract at the default view, a base block in each team colour pasted in the middle, then magnified 4 times without
smoothing. Right: the four team colours and a 13 px wall on each ground colour of the palette at the same scale.
Run from the repo root.

teamcrop.py --frame F.png --tile-px 52 --palette P.json --out OUT.png [--centre 0.5,0.5]
tile-px is the width of one tile in F.png, measured along a grid line. palette has "team" and "world" like palette.json."""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

WALL_PX, TILE_PX, MAG = 13, 25, 4
SCALE_TILE_PX = 24.7          # the contract's tile width at the default view, the drawn blocks round it to 25
GROUNDS = ["grass", "sand", "stone", "sea"]


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lighter(c, f=1.25):
    return tuple(min(255, int(v * f)) for v in c)


def base_block(d, x, y, colour):
    """One base building on one tile: a 25 px wide block, 18 px tall side, 8 px top face."""
    d.rectangle([x, y + 8, x + TILE_PX - 1, y + 25], fill=colour)
    d.rectangle([x, y, x + TILE_PX - 1, y + 8], fill=lighter(colour))


def wall_block(d, x, y, stone):
    d.rectangle([x, y + 4, x + 2 * WALL_PX - 1, y + 4 + WALL_PX - 1], fill=stone)
    d.rectangle([x, y, x + 2 * WALL_PX - 1, y + 4], fill=lighter(stone, 1.12))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frame", required=True)
    ap.add_argument("--tile-px", type=float, required=True)
    ap.add_argument("--palette", required=True)
    ap.add_argument("--centre", default="0.5,0.5", help="fraction of width,height the crop is centred on")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    pal = json.loads(Path(a.palette).read_text())
    teams = [hexrgb(v["main"]) for v in pal["team"].values()]
    world = {k: hexrgb(v) for k, v in pal["world"].items() if isinstance(v, str) and v.startswith("#")}

    im = Image.open(a.frame).convert("RGB")
    s = SCALE_TILE_PX / a.tile_px
    small = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    cw, ch = 200, 112
    fx, fy = (float(v) for v in a.centre.split(","))
    x0 = min(max(0, round(small.width * fx) - cw // 2), max(0, small.width - cw))
    y0 = min(max(0, round(small.height * fy) - ch // 2), max(0, small.height - ch))
    crop = small.crop((x0, y0, x0 + cw, y0 + ch))
    d = ImageDraw.Draw(crop)
    for i, t in enumerate(teams):
        base_block(d, cw // 2 - 2 * TILE_PX - 6 + i * (TILE_PX + 4), ch // 2 - 12, t)

    panel = Image.new("RGB", (160, 36 * len(GROUNDS)), (240, 240, 240))
    pd = ImageDraw.Draw(panel)
    for row, g in enumerate(GROUNDS):
        y = row * 36
        pd.rectangle([0, y, 159, y + 35], fill=world.get(g, (128, 128, 128)))
        for i, t in enumerate(teams):
            base_block(pd, 6 + i * (TILE_PX + 4), y + 5, t)
        wall_block(pd, 126, y + 9, world.get("stone", (200, 200, 200)))

    out = Image.new("RGB", (cw + 8 + panel.width, max(ch, panel.height)), (255, 255, 255))
    out.paste(crop, (0, 0))
    out.paste(panel, (cw + 8, 0))
    out = out.resize((out.width * MAG, out.height * MAG), Image.NEAREST)
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.out)
    print(a.out)


if __name__ == "__main__":
    main()
