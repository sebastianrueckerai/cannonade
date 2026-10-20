#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow"]
# ///
"""Round 35, second pass: accents.jpg from the /tmp/fw2 frames shoot2.sh takes. One row per scheme on the D78
walkway (blue near on the plain look, red far on the corbel look): the default view cropped to the board, the
near fort's corner at the game's angle, the far fort magnified 3x. Run from art/:
    uv run --script game/art-direction/rounds/35-faction-walls/board2.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from board import BOARD, FAR, board, mag  # noqa: E402

SRC = Path("/tmp/fw2")
SCHEMES = [("1 walkway 0.6 (shipped)", "walk0.6"), ("2 walkway 0.35", "walk0.35"), ("3 walkway 1.0", "walk1"),
           ("4 walkway + rim line 0.6", "walk0.6_rim0.6"), ("5 walkway + band 0.6", "walk0.6_band0.6"),
           ("6 rim line only", "walk0_rim0.6"), ("7 band only", "walk0_band0.6"),
           ("8 walkway + ground 0.25", "walk0.6_floor0.25"), ("9 walkway + rim + ground", "walk0.6_rim0.6_floor0.25")]


def frame(stem):
    from PIL import Image
    return Image.open(SRC / f"{stem}_050.png").convert("RGB")


rows = []
for lbl, spec in SCHEMES:
    f = frame(f"accent_{spec}")
    rows.append((lbl, [("default view", mag(f, BOARD, 1)), ("near corner, game angle", frame(f"accent_{spec}_close")),
                       ("far fort x3", mag(f, FAR, 3))]))
board("Accents on the walkway: blue near (plain look), red far (corbel look)", rows, "accents.jpg")
