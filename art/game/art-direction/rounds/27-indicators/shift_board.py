#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow", "httpx"]
# ///
"""Round 27: the reload ring as the gun's iron shifted toward the owner's team colour, three
strengths (Sebastian: clearly visible, but the cozy look must hold). One row per strength,
both forts (blue own, red enemy) at t=4.5 (ring thick after the shot) and 6.3 (mid reload).
Frames from /tmp/ind27i, shot by shoot_battle --ind=base,taper --reload=2 --ringshift=S.
    uv run --script game/art-direction/rounds/27-indicators/shift_board.py"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "pipeline"))
from img import font  # noqa: E402

SRC = Path("/tmp/ind27i")
HERE = Path(__file__).parent
ROWS = [("A subtle 0.35", "0.35"), ("B balanced 0.55", "0.55"), ("C clear 0.75", "0.75")]
COLS = [("own", "045", "blue fort t=4.5"), ("own", "063", "blue fort t=6.3 mid"),
        ("enemy", "045", "red fort t=4.5"), ("enemy", "063", "red fort t=6.3 mid")]
PAD, LBL, LEFT = 10, 30, 210


def main():
    cell_w, cell_h = 480, 270
    im = Image.new("RGB", (LEFT + len(COLS) * (cell_w + PAD) + PAD, 44 + len(ROWS) * (cell_h + LBL + PAD)), (255, 255, 255))
    d = ImageDraw.Draw(im)
    d.text((PAD, 10), "round 27 - reload ring: the gun's iron shifted toward the team colour, three strengths", fill=(0, 0, 0), font=font(24))
    for r, (rlabel, s) in enumerate(ROWS):
        y = 44 + r * (cell_h + LBL + PAD)
        d.text((PAD, y + cell_h // 2 - 12), rlabel, fill=(190, 0, 0), font=font(22))
        for c, (side, t, clabel) in enumerate(COLS):
            x = LEFT + c * (cell_w + PAD)
            src = Image.open(SRC / f"{side}_{s}_{t}.png").crop((0, 0, 1280, 720))
            src.thumbnail((cell_w, cell_h))
            im.paste(src, (x, y))
            d.rectangle((x - 1, y - 1, x + src.width, y + src.height), outline=(170, 170, 170))
            d.text((x, y + src.height + 4), clabel, fill=(60, 60, 60), font=font(18))
    out = HERE / "shift.png"
    im.save(out)
    print(out)


if __name__ == "__main__":
    main()
