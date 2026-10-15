#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow", "httpx"]
# ///
"""Round 28 gate boards, every asset big (D48): gate-guns.png for the mortar, the flak and the projectiles,
gate-depots.png for the six depot looks. Inputs: frames/ (game screenshots from tools/shoot_battle.tscn in the
game repo), renders/ (gate_renders.py), the picked sketch crops in each asset's refs/. Procedural, no provider
call. Run from the repo root:
    uv run --script game/art-direction/rounds/28-advanced-buildings/gate.py"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "pipeline"))
from img import font  # noqa: E402

HERE = Path(__file__).parent
ASSETS = HERE.parents[2] / "assets/3d"
W, PAD, LBL = 2400, 12, 44
BG, INK = (250, 246, 238), (40, 30, 25)


def fit(im, w, h):
    im = im.convert("RGB")
    s = min(w / im.width, h / im.height)
    return im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)


def mag(path, box, k):
    """An in-game crop magnified k times, pixels kept square."""
    im = Image.open(HERE / "frames" / path).convert("RGB").crop(box)
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def row(cells, h):
    """cells: (image, label). Each cell gets an equal share of the width, the image fitted inside."""
    w = (W - PAD * (len(cells) + 1)) // len(cells)
    out = Image.new("RGB", (W, h + LBL), BG)
    d = ImageDraw.Draw(out)
    for i, (im, label) in enumerate(cells):
        x = PAD + i * (w + PAD)
        f = fit(im, w, h)
        out.paste(f, (x + (w - f.width) // 2, LBL))
        d.text((x, LBL // 2), label, fill=INK, font=font(24), anchor="lm")
    return out


def board(title, rows, out):
    h = 90 + sum(r.height for r in rows)
    im = Image.new("RGB", (W, h), BG)
    ImageDraw.Draw(im).text((PAD, 45), title, fill=INK, font=font(40), anchor="lm")
    y = 90
    for r in rows:
        im.paste(r, (0, y))
        y += r.height
    im.save(HERE / out)
    print(HERE / out)


def sketch(asset):
    return Image.open(ASSETS / asset / "refs/a-sketch.png")


def render(name):
    return Image.open(HERE / "renders" / f"{name}.png")


def frame(name):
    return Image.open(HERE / "frames" / f"{name}.png")


def texture(asset):
    return Image.open(ASSETS / asset / "previews/views/6_texture.png")


board("Round 28 gate, board 1: the mortar cannon22b, the flak flak22, the cluster bomb and its shards", [
    row([(sketch("cannon22b"), "mortar: the picked sketch"), (render("cannon22b_-10"), "barrel -10, the game's rest"),
         (render("cannon22b_+45"), "barrel +45, the lowest shot"), (render("cannon22b_+80"), "barrel +80, a steep shot")], 560),
    row([(sketch("flak22"), "flak: the picked sketch"), (render("flak22_+00"), "guns level"),
         (render("flak22_+43"), "guns +43, the rest pose"), (render("flak22_+90"), "guns straight up")], 560),
    row([(frame(f"flak_joint_{p}"), f"flak joint at {int(p)} deg") for p in ("00", "43", "60", "80", "90")], 420),
    row([(frame("guns_020"), "in game, zoomed: mortar aiming high, flak tracking a ball"),
         (frame("guns_060"), "in game, zoomed: the flak aims low across the mortar")], 640),
    row([(frame("top_020"), "straight down: mount minus plate 0.000 m on both guns, placed"),
         (frame("shards_070"), "straight down: five shards falling round the mortar and the flak")], 640),
    row([(mag("fire_004.png", (470, 120, 650, 280), 4), "bomb leaving the mortar, 4x"),
         (mag("shards_070.png", (880, 556, 968, 644), 6), "falling shard, 6x"),
         (texture("cluster_bomb"), "cluster bomb, 0.3 m, 96 tris"), (texture("cluster_shard"), "shard, 0.12 m, 16 tris"),
         (texture("shell"), "the shell beside them, 0.28 m")], 420),
    row([(mag("battle_050.png", (760, 470, 960, 620), 3), "default view, 3x: near fort, mortar, flak, depots"),
         (mag("battle_050.png", (760, 100, 960, 220), 3), "default view, 3x: far fort, the same corner")], 700),
], "gate-guns.png")

depots = ["supply22", "supply22.2", "supply22.3", "supply33", "supply33.2", "supply33.3"]
crops = {"supply22": (380, 90, 780, 400), "supply22.2": (360, 120, 780, 520), "supply22.3": (400, 20, 760, 340),
         "supply33": (380, 90, 900, 500), "supply33.2": (440, 0, 840, 520), "supply33.3": (420, 0, 840, 460)}
board("Round 28 gate, board 2: the six depot looks, supply22 (2x2) and supply33 (3x3)", [
    row([(sketch(a), f"{a}: sketch"), (Image.open(HERE / "frames" / f"{a}.png").crop(crops[a]), f"{a}: in game, zoomed")]
        + [(sketch(b), f"{b}: sketch"), (Image.open(HERE / "frames" / f"{b}.png").crop(crops[b]), f"{b}: in game, zoomed")], 560)
    for a, b in zip(depots[::2], depots[1::2])
] + [
    row([(frame("battle_050"), "default view, both forts"),
         (mag("battle_050.png", (250, 450, 400, 600), 3), "default view, 3x: the near warehouse")], 680),
], "gate-depots.png")

board("Round 28, after the gate: every gun inside its square (D61), the flak smaller with shorter barrels", [
    row([(frame("after_top_33"), "siege cannon33a from above"), (frame("after_top_old"), "heavy cannon22a and small cannon from above"),
         (frame("after_top_new"), "mortar and flak from above")], 520),
    row([(frame("after_new_020"), "in game, zoomed: the mortar and the smaller flak"),
         (frame("after_new_060"), "the flak aiming low stays on its plate")], 640),
    row([(frame("after_old_020"), "in game, zoomed: the siege, heavy and small guns"),
         (mag("after_battle_050.png", (760, 470, 960, 620), 3), "default view, 3x: near fort, mortar, flak, depots")], 680),
], "gate-after.png")
