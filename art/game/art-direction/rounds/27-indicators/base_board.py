#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow", "httpx"]
# ///
"""Round 27, Sebastian's candidate: the base ring, rebuilt on the measured mount footprints.
Row 1 straight from above (the check Sebastian asked for), row 2 the game camera, six times
across one 4 s reload and the ready pulse. Frames from /tmp/ind27g, shot by shoot_battle
--ind=base,taper --reload=2 with --top=11 for the overhead row.
    uv run --script game/art-direction/rounds/27-indicators/base_board.py"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "pipeline"))
from img import font  # noqa: E402

SRC = Path("/tmp/ind27g")
HERE = Path(__file__).parent
TIMES = [("045", "t=4.5 just fired"), ("053", "t=5.3"), ("063", "t=6.3 mid"), ("073", "t=7.3"),
         ("084", "t=8.4 ready, pulse"), ("089", "t=8.9 after pulse")]
ROWS = [("straight above", "top", (160, 60, 1120, 600)), ("game camera", "obl", (160, 0, 1120, 540))]
PAD, LBL, LEFT = 10, 30, 190


def main():
    cell_w, cell_h = 420, 236
    im = Image.new("RGB", (LEFT + len(TIMES) * (cell_w + PAD) + PAD, 44 + len(ROWS) * (cell_h + LBL + PAD)), (255, 255, 255))
    d = ImageDraw.Draw(im)
    d.text((PAD, 10), "round 27 - base ring on the measured gun footprints - own fort, one reload (x2 = 4 s)", fill=(0, 0, 0), font=font(24))
    for r, (rlabel, tag, box) in enumerate(ROWS):
        y = 44 + r * (cell_h + LBL + PAD)
        d.text((PAD, y + cell_h // 2 - 12), rlabel, fill=(190, 0, 0), font=font(22))
        for c, (t, tl) in enumerate(TIMES):
            x = LEFT + c * (cell_w + PAD)
            src = Image.open(SRC / f"{tag}_{t}.png").crop(box)
            src.thumbnail((cell_w, cell_h))
            im.paste(src, (x, y))
            d.rectangle((x - 1, y - 1, x + src.width, y + src.height), outline=(170, 170, 170))
            d.text((x, y + src.height + 4), tl, fill=(60, 60, 60), font=font(18))
    out = HERE / "base.png"
    im.save(out)
    print(out)


if __name__ == "__main__":
    main()
