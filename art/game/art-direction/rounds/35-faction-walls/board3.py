#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow"]
# ///
"""Round 35, third pass: pieces.jpg from the /tmp/fw3 frames shoot3.sh takes with the battle tool's --pieces
layout under the shipped D79 colours. The view straight down over the layout, labelled by group, then the six
close views at the game's angle in two rows. Run from art/:
    uv run --script game/art-direction/rounds/35-faction-walls/board3.py"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SRC = Path("/tmp/fw3")
HERE = Path(__file__).parent
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
PAD = 10
CLOSE = [("row 1: one, two, three", "pieces_a1"), ("row 1: four", "pieces_a2"),
         ("row 2: S and T", "pieces_b1"), ("row 2: X and a corner", "pieces_b2"),
         ("row 3: a 2 x 2 and a filled 3 x 3", "pieces_c1"), ("row 3: a 4 x 4 ring", "pieces_c2")]


def frame(stem):
    return Image.open(SRC / f"{stem}_050.png").convert("RGB")


top = frame("pieces_top")
d = ImageDraw.Draw(top)
d.text((PAD, PAD), "straight down: every piece alone, a corner, a 2 x 2, a filled 3 x 3, a 4 x 4 ring", fill="white", font=FONT)
cells = [frame(stem) for _, stem in CLOSE]
cw = top.width // 3
ch = int(cells[0].height * cw / cells[0].width)
out = Image.new("RGB", (top.width, top.height + 2 * (ch + 34) + PAD), "white")
out.paste(top, (0, 0))
d = ImageDraw.Draw(out)
for i, ((lbl, _), im) in enumerate(zip(CLOSE, cells)):
    x = (i % 3) * cw
    y = top.height + PAD + (i // 3) * (ch + 34)
    d.text((x + PAD, y), lbl, fill="black", font=FONT)
    out.paste(im.resize((cw, ch), Image.LANCZOS), (x, y + 30))
out.save(HERE / "pieces.jpg", quality=90)
print("pieces.jpg", out.size)
