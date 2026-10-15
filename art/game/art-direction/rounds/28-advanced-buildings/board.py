#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow", "httpx"]
# ///
"""Round 28 boards: each painted sheet with its three designs numbered, the moving parts marked, and
the anchor of its class beside it. Procedural, no provider call. Run from the repo root:
    uv run --script game/art-direction/rounds/28-advanced-buildings/board.py"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "pipeline"))
from img import font  # noqa: E402

HERE = Path(__file__).parent
ART = HERE.parents[1]
GUNS = [(ART / "anchors/gun_ladder.png", "the guns in the game: small, heavy 2x2 (cannon22a), siege 3x3")]
DEPOTS = [(ART / "rounds/19-first-batch/depot.png", "the four 1x1 depots in the game (D38)")]
BLOCKS = [(ART / "anchors/resource_blocks.png", "timber is block A, the crate on the left (D32)")]
# Positions are fractions of the painted sheet, read off each painting by eye.
BOARDS = [
    ("1-mortar", "mortar.png", "Board 1: the mortar, cannon22b, 2x2. Pick one design.",
     [0.17, 0.48, 0.80], [
         ("barrel", (0.17, 0.37), (0.10, 0.12)), ("pivot", (0.12, 0.50), (0.04, 0.68)),
         ("barrel", (0.55, 0.30), (0.42, 0.12)), ("pivot", (0.44, 0.52), (0.36, 0.68)),
         ("barrel", (0.85, 0.25), (0.93, 0.12)), ("pivot", (0.77, 0.46), (0.66, 0.68))],
     GUNS),
    ("2-flak", "flak.png", "Board 2: the flak, flak22, 2x2. Pick one design.",
     [0.17, 0.52, 0.83], [
         ("guns", (0.25, 0.30), (0.10, 0.12)), ("pivot", (0.198, 0.63), (0.05, 0.75)),
         ("guns", (0.54, 0.34), (0.42, 0.12)), ("pivot", (0.505, 0.63), (0.38, 0.75)),
         ("guns", (0.84, 0.33), (0.93, 0.12)), ("pivot", (0.80, 0.63), (0.67, 0.75))],
     GUNS),
    ("3-supply22", "supply22.png", "Board 3: the timber yard, supply22, 2x2. Pick one design.",
     [0.20, 0.53, 0.83], [], DEPOTS + BLOCKS),
    ("4-supply33", "supply33.png", "Board 4: the warehouse, supply33, 3x3. Pick one design.",
     [0.20, 0.50, 0.81], [], DEPOTS),
]
W, TITLE, STRIP = 2752, 90, 560
RED = (200, 40, 40)


def board(name, sheet, title, numbers, marks, anchors):
    paint = Image.open(HERE / sheet).convert("RGB")
    sw, sh = paint.size
    d = ImageDraw.Draw(paint)
    f_num, f_mark = font(120), font(54)
    for i, x in enumerate(numbers, 1):
        d.text((x * sw, 0.06 * sh), str(i), fill=RED, font=f_num, anchor="mm")
    for label, at, text_at in marks:
        ax, ay = at[0] * sw, at[1] * sh
        tx, ty = text_at[0] * sw, text_at[1] * sh
        d.line([(tx, ty), (ax, ay)], fill=RED, width=6)
        d.ellipse([ax - 12, ay - 12, ax + 12, ay + 12], fill=RED)
        box = d.textbbox((tx, ty), label, font=f_mark, anchor="mm")
        d.rectangle([box[0] - 12, box[1] - 8, box[2] + 12, box[3] + 8], fill=(255, 250, 240), outline=RED, width=4)
        d.text((tx, ty), label, fill=RED, font=f_mark, anchor="mm")
    out = Image.new("RGB", (W, TITLE + sh + STRIP + 70), (250, 246, 238))
    od = ImageDraw.Draw(out)
    od.text((30, TITLE // 2), title, fill=(40, 30, 25), font=font(60), anchor="lm")
    out.paste(paint, (0, TITLE))
    x = 30
    for path, caption in anchors:
        a = Image.open(path).convert("RGB")
        a = a.resize((round(a.width * STRIP / a.height), STRIP), Image.LANCZOS)
        out.paste(a, (x, TITLE + sh + 60))
        od.text((x, TITLE + sh + 30), "Anchor: " + caption, fill=(90, 70, 60), font=font(40), anchor="lm")
        x += a.width + 40
    out.save(HERE / f"{name}-board.png")


for b in BOARDS:
    board(*b)
print("boards:", ", ".join(f"{b[0]}-board.png" for b in BOARDS))
