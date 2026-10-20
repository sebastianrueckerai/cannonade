#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow"]
# ///
"""Round 35 boards from the battle screenshots in /tmp/fw (shot by shoot.sh in this folder with
tools/shoot_battle.gd --wall and --team). Three boards, no provider call:
  models.jpg   one row per wall look: the near fort's corner from a low angle (a model check, not a game
               view), the same corner at the game's angle, and the far fort's walls magnified 3x (the 13 px test)
  pairs.jpg    candidate faction pairs, side 0 near (blue) and side 1 far (red), in neutral stone
  colours.jpg  tint schemes on the plain block: default view, the near fort magnified 2x, the far fort
               magnified 3x
Run from art/:  uv run --script game/art-direction/rounds/35-faction-walls/board.py"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SRC = Path("/tmp/fw")
HERE = Path(__file__).parent
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
PAD, LBL, LEFT = 10, 30, 340
LOOKS = ["plain", "arch", "corbel", "pilaster", "course", "caps"]
PAIRS = [("arch", "pilaster"), ("corbel", "course"), ("arch", "corbel"), ("caps", "arch")]
SCHEMES = [("1 today, no tint", "none"), ("2 walkway 0.35", "deck=0.35"), ("3 walkway 0.6", "deck=0.6"),
           ("4 walkway 1.0", "deck=1"), ("5 walkway + merlons 0.6", "deck=0.6,merlons=0.6"),
           ("6 merlons only 0.6", "merlons=0.6"), ("7 whole block 0.2", "body=0.2"),
           ("8 walkway 0.6 + ground 0.25", "deck=0.6,floor=0.25"), ("9 ground only 0.4", "floor=0.4")]
# frame fractions of the default view: the near fort (side 0, blue) and the far fort (side 1, red)
NEAR = (0.08, 0.52, 0.92, 0.93)
FAR = (0.21, 0.12, 0.77, 0.33)
BOARD = (0.12, 0.04, 0.88, 0.98)


def frame(stem):
    return Image.open(SRC / f"{stem}_050.png").convert("RGB")


def mag(im, box, factor):
    w, h = im.size
    b = (int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))
    return im.crop(b).resize((int((b[2] - b[0]) * factor), int((b[3] - b[1]) * factor)), Image.NEAREST)


def fit(im, h):
    return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)


def board(title, rows, out, cell_h=400):
    """rows: list of (row label, [(cell label, image), ...]); every cell scaled to cell_h tall."""
    rows = [(lbl, [(c, fit(im, cell_h)) for c, im in cells]) for lbl, cells in rows]
    width = LEFT + max(sum(im.width + PAD for _, im in cells) for _, cells in rows) + PAD
    out_im = Image.new("RGB", (width, 44 + len(rows) * (cell_h + LBL + PAD)), "white")
    d = ImageDraw.Draw(out_im)
    d.text((PAD, 10), title, fill="black", font=FONT)
    y = 44
    for lbl, cells in rows:
        d.text((PAD, y + cell_h // 2), lbl, fill="black", font=FONT)
        x = LEFT
        for c, im in cells:
            d.text((x, y), c, fill=(90, 90, 90), font=FONT)
            out_im.paste(im, (x, y + LBL))
            x += im.width + PAD
        y += cell_h + LBL + PAD
    out_im.save(HERE / out, quality=90)
    print(out, out_im.size)


def main():
    rows = []
    for i, look in enumerate(LOOKS):
        f = frame(f"model_{look}")
        rows.append((f"{i + 1} {look}", [("low angle, not a game view", frame(f"low_{look}")),
                                         ("near corner, game angle", frame(f"close_{look}")),
                                         ("far fort x3", mag(f, FAR, 3))]))
    board("Wall looks: both forts in one look, no tint", rows, "models.jpg")

    rows = []
    for i, (a, b) in enumerate(PAIRS):
        f = frame(f"pair_{a}_{b}")
        rows.append((f"{i + 1} near {a}\n  far {b}", [("default view", mag(f, BOARD, 1)), ("near fort x2", mag(f, NEAR, 2)),
                                                       ("far fort x3", mag(f, FAR, 3))]))
    board("Faction pairs: blue near, red far, neutral stone", rows, "pairs.jpg")

    rows = []
    for lbl, spec in SCHEMES:
        f = frame(f"colour_{spec.replace(',', '_').replace('=', '')}")
        rows.append((lbl, [("default view", mag(f, BOARD, 1)), ("near fort x2", mag(f, NEAR, 2)), ("far fort x3", mag(f, FAR, 3))]))
    board("Team tint on the plain block: blue near, red far", rows, "colours.jpg")


if __name__ == "__main__":
    main()
