#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow", "httpx"]
# ///
"""C12 gate board: the whole repainted set in the running game plus magnified parts, for the
Gemini critic and Sebastian. Inputs: the /tmp/gate11 screenshots (synced set, seed 1) and the
rebuilt Blender texture views. Procedural composition, no provider call. Run from the repo root:
    uv run --script game/art-direction/rounds/26-repaint/gate.py"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "pipeline"))
from img import font  # noqa: E402

ROOT = Path(__file__).resolve().parents[4]
G = Path("/tmp/gate11")
A3 = ROOT / "game/assets/3d"
OUT = Path(__file__).parent / "gate-board.png"
LBL, PAD, LEFT = 34, 12, 170
WIDE = 1180


def mag(im, box, factor):
    return im.crop(box).resize(((box[2] - box[0]) * factor, (box[3] - box[1]) * factor), Image.NEAREST)


def row(im, d, y, cells, height):
    """cells: list of (label, PIL image); images fit within one row width and `height`."""
    x = LEFT
    wcap = WIDE // len(cells) - PAD
    for label, src in cells:
        src.thumbnail((wcap, height))
        d.rectangle((x - 2, y - 2, x + src.width + 2, y + src.height + 2), outline=(180, 180, 180))
        im.paste(src, (x, y))
        d.text((x, y + src.height + 4), label, fill=(60, 60, 60), font=font(19))
        x += src.width + PAD
    return y + height + LBL + 8


def main():
    battle = Image.open(G / "battle_050.png")
    single = Image.open(G / "single.png_003.png")
    close_walls = Image.open(G / "battle_look_050.png")     # shoot_battle --look=10,2: the fort walls
    close_grove = Image.open(G / "single_close.png_003.png")  # single --look=0,6 zoom: the grove
    tex_wall = Image.open(A3 / "wall_line_base/previews/views/6_texture.png")
    tex_tile = Image.open(A3 / "tile/previews/views/6_texture.png")
    tex_shell = Image.open(A3 / "shell/previews/views/6_texture.png")

    im = Image.new("RGB", (LEFT + WIDE + PAD, 3200), (255, 255, 255))
    d = ImageDraw.Draw(im)
    d.text((LEFT, 6), "C12 gate - the repainted set in the game (seed 1, shipped soft_honey look)", fill=(0, 0, 0), font=font(22))
    y = 40
    y = row(im, d, y, [("sandbox battle, default view", battle)], 560)
    y = row(im, d, y, [("single-player view", single)], 560)
    y = row(im, d, y, [("walls, tile, plates at zoom", close_walls), ("trees at zoom", close_grove)], 400)
    y = row(im, d, y, [
        ("merlons x2", mag(close_walls, (140, 130, 400, 205), 2)),          # the look frame is 640x360
        ("plate and gun foot x2", mag(close_walls, (216, 5, 386, 110), 2)),
        ("tile edge and base shadow x2", mag(close_walls, (66, 205, 286, 295), 2)),
    ], 290)
    y = row(im, d, y, [
        ("wall texture view (Blender)", tex_wall),
        ("tile texture view (Blender)", tex_tile),
        ("shell texture view (Blender)", tex_shell),
    ], 300)
    im = im.crop((0, 0, im.width, y))
    im.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
