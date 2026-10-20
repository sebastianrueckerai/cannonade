#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow"]
# ///
"""Round 35, fourth pass: looks-in-game.jpg from the /tmp/fw4 frames of tools/screenshot.gd --mode=ai4 --castle=N:
each player's castle ring at the start of a four-player game, one column per look, the game's angle above and a
low angle below. Run from art/:
    uv run --script game/art-direction/rounds/35-faction-walls/board4.py"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SRC = Path("/tmp/fw4")
HERE = Path(__file__).parent
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
LOOKS = ["1 plain, blue", "2 corbel, purple", "3 pilaster, teal", "4 course, olive"]
BOX = (0.2, 0.15, 0.8, 0.85)  # the frame's middle, where the castle and its ring sit
PAD, LBL = 10, 36


def cell(stem):
    im = Image.open(SRC / f"{stem}_003.png").convert("RGB")
    w, h = im.size
    return im.crop((int(BOX[0] * w), int(BOX[1] * h), int(BOX[2] * w), int(BOX[3] * h)))


cells = [[cell(f"castle{i}_{kind}") for i in range(4)] for kind in ("game", "low")]
cw, ch = cells[0][0].size
out = Image.new("RGB", (4 * (cw + PAD) + PAD, 44 + 2 * (ch + LBL + PAD)), "white")
d = ImageDraw.Draw(out)
d.text((PAD, 8), "The four looks in a four-player game, each player's start ring: the game's angle, then a low angle", fill="black", font=FONT)
for r, row in enumerate(cells):
    for c, im in enumerate(row):
        x = PAD + c * (cw + PAD)
        y = 44 + r * (ch + LBL + PAD)
        d.text((x, y), LOOKS[c] + ("" if r == 0 else ", low angle"), fill="black", font=FONT)
        out.paste(im, (x, y + LBL))
out.save(HERE / "looks-in-game.jpg", quality=90)
print("looks-in-game.jpg", out.size)
