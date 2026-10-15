#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow", "httpx"]
# ///
"""Round 27 boards: the reload and the arc candidates as real game screenshots. Reads the
/tmp/ind27b frames shot by tools/shoot_battle.gd --ind=<reload>,<arc> --reload=2 at battle
times 5 (just fired), 7 (mid reload) and 9 (ready again). Two boards: reload.png, one row per
candidate with the near fort's guns close at the three times; arcs.png, one row per candidate
with the default view at the three times plus the near fort magnified. Procedural, no provider
call. Run from the repo root:
    uv run --script game/art-direction/rounds/27-indicators/board.py"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "pipeline"))
from img import font  # noqa: E402

SRC = Path("/tmp/ind27b")
SRC_RELOAD = Path("/tmp/ind27c")  # pass 3: the close camera on the own fort (side 0, far on screen)
HERE = Path(__file__).parent
TIMES = [("050", "t=5 just fired"), ("070", "t=7 mid reload"), ("090", "t=9 ready")]
RELOAD = [("1 ring (shipped)", "ring_wire"), ("2 none", "none_none"), ("3 heat", "heat_none"),
          ("4 plate", "plate_none"), ("5 ground ring", "ground_none"), ("6 slump", "slump_none")]
ARCS = [("1 wire (shipped)", "ring_wire"), ("2 none", "none_none"), ("3 taper", "ring_taper"),
        ("4 band", "ring_band"), ("5 marker", "ring_marker"), ("6 puffs", "ring_puffs")]
PAD, LBL, LEFT = 10, 30, 210


def mag(im, box, factor):
    return im.crop(box).resize((int((box[2] - box[0]) * factor), int((box[3] - box[1]) * factor)), Image.NEAREST)


def board(title, rows, cell_w, cell_h, out):
    """rows: list of (row label, [(cell label, image), ...])."""
    cols = max(len(cells) for _, cells in rows)
    im = Image.new("RGB", (LEFT + cols * (cell_w + PAD) + PAD, 44 + len(rows) * (cell_h + LBL + PAD)), (255, 255, 255))
    d = ImageDraw.Draw(im)
    d.text((PAD, 10), title, fill=(0, 0, 0), font=font(24))
    for r, (rlabel, cells) in enumerate(rows):
        y = 44 + r * (cell_h + LBL + PAD)
        d.text((PAD, y + cell_h // 2 - 12), rlabel, fill=(190, 0, 0), font=font(22))
        for c, (clabel, src) in enumerate(cells):
            x = LEFT + c * (cell_w + PAD)
            src = src.copy()
            src.thumbnail((cell_w, cell_h))
            im.paste(src, (x, y))
            d.rectangle((x - 1, y - 1, x + src.width, y + src.height), outline=(170, 170, 170))
            d.text((x, y + src.height + 4), clabel, fill=(60, 60, 60), font=font(19))
    im.save(out)
    print(out)


def main():
    rows = []
    for label, tag in RELOAD:
        cells = []
        for t, tl in TIMES:
            im = Image.open(SRC_RELOAD / f"{tag}_look_{t}.png")
            cells.append((tl, mag(im, (0, 0, 1280, 420), 1.0)))
        rows.append((label, cells))
    board("round 27 - reload candidates - the own fort's guns close (reload x2 = 4 s)", rows, 600, 197, HERE / "reload.png")

    rows = []
    for label, tag in ARCS:
        cells = []
        for t, tl in TIMES:
            im = Image.open(SRC / f"{tag}_{t}.png")
            cells.append((tl, im))
        im7 = Image.open(SRC / f"{tag}_070.png")
        cells.append(("t=7 near fort x2", mag(im7, (340, 420, 900, 660), 2.0)))
        rows.append((label, cells))
    board("round 27 - arc candidates - default view at three battle times (reload x2 = 4 s)", rows, 440, 248, HERE / "arcs.png")


if __name__ == "__main__":
    main()
