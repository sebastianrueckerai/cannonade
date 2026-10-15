#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""What a frame shows at the game's default view. Each frame is scaled so one tile is 24.7 px wide, the tile width
of the gameplay contract at the default view, a window around the centre is cut, every window is magnified 4 times
without smoothing, and the windows sit in a grid with a label each. Run from the repo root.

px13.py --tile-px 52 --centre 0.5,0.5 --window 120x68 --cols 3 --out OUT.png LABEL=FRAME.png[@TILEPX] ...
tile-px is the width of one tile in the frames, measured along a grid line; @TILEPX after a frame overrides it, and
with it on every frame --tile-px may be left out. A window larger than the scaled frame shrinks to the frame."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TILE_PX, MAG = 24.7, 4


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tile-px", type=float)
    ap.add_argument("--centre", default="0.5,0.5")
    ap.add_argument("--window", default="120x68")
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--out", required=True)
    ap.add_argument("frames", nargs="+", help="LABEL=FRAME.png[@TILEPX]")
    a = ap.parse_args()
    fx, fy = (float(v) for v in a.centre.split(","))
    ww, wh = (int(v) for v in a.window.split("x"))
    font = ImageFont.load_default(20)
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if Path(f).exists():
            font = ImageFont.truetype(f, 20)
            break
    tiles = []
    for item in a.frames:
        label, path = item.split("=", 1)
        path, at, tile_px = path.rpartition("@")
        if not at:
            path, tile_px = tile_px, None
        if not tile_px and a.tile_px is None:
            ap.error(f"{item}: no @TILEPX and no --tile-px")
        im = Image.open(path).convert("RGB")
        s = TILE_PX / (float(tile_px) if tile_px else a.tile_px)
        small = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        cw, ch = min(ww, small.width), min(wh, small.height)
        x0 = min(max(0, round(small.width * fx) - cw // 2), small.width - cw)
        y0 = min(max(0, round(small.height * fy) - ch // 2), small.height - ch)
        win = small.crop((x0, y0, x0 + cw, y0 + ch)).resize((cw * MAG, ch * MAG), Image.NEAREST)
        tiles.append((label, win))
    pad, lab = 10, 28
    cols = min(a.cols, len(tiles))
    rows = -(-len(tiles) // cols)
    out = Image.new("RGB", (cols * (ww * MAG + pad) + pad, rows * (wh * MAG + lab + pad) + pad), (255, 255, 255))
    d = ImageDraw.Draw(out)
    for i, (label, win) in enumerate(tiles):
        x = pad + (i % cols) * (ww * MAG + pad)
        y = pad + (i // cols) * (wh * MAG + lab + pad)
        d.text((x, y), label, fill=(200, 0, 0), font=font)
        out.paste(win, (x, y + lab))
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.out)
    print(a.out)


if __name__ == "__main__":
    main()
