#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pyyaml", "pillow", "httpx"]
# ///
"""C12 step 5: the ivory-tree readability board (the D52 ship critique friction). Renders the
three leaf-tree looks under the shipped soft_honey light, each with repaint candidates beside it
(deeper, more saturated crown stops; same mesh, same paint structure). Columns are chosen in
COLS below; a column is ("label", look_id, stops_override_or_None). Procedural board, no sidecar.
    uv run --script game/art-direction/rounds/26-repaint/ivory.py"""
import math
import subprocess
import sys
from pathlib import Path

import yaml
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "pipeline"))
from img import font  # noqa: E402

ROOT = Path(__file__).resolve().parents[4]
OUT = Path("/tmp/repaint26")
BOARD = Path(__file__).parent / "ivory-board.png"
CELL, LBL, LEFT = 560, 36, 130

# (label, look id, crown-stop override). None override = the look as shipped.
CROWN = lambda *s: [(0.30, s[0]), (0.65, s[1]), (1.0, s[2])]
COLS = [
    ("look 1", "nature_leaf_tree", None),
    ("look 1 deep", "nature_leaf_tree", CROWN("#3f6b38", "#477c3f", "#8fb03a")),
    ("look 1 rich", "nature_leaf_tree", CROWN("#3a6d34", "#44803a", "#7da637")),
    ("look 2", "nature_leaf_tree.2", None),
    ("look 2 deep", "nature_leaf_tree.2", CROWN("#48682a", "#5d8531", "#7ea634")),
    ("look 3", "nature_leaf_tree.3", None),
    ("look 3 deep", "nature_leaf_tree.3", CROWN("#41632f", "#557938", "#93a83c")),
]
TRUNK = {"nature_leaf_tree": [(0.0, "#684e40"), (0.14, "#916d59")],
         "nature_leaf_tree.2": [(0.0, "#5c3522"), (0.14, "#80472e")],
         "nature_leaf_tree.3": [(0.0, "#5b311d"), (0.14, "#7f4527")]}
SEED = {"nature_leaf_tree": 21, "nature_leaf_tree.2": 22, "nature_leaf_tree.3": 23}
ROWS = [("whole 3/4", "awhole"), ("row at default x3", "brow")]


def picked_light():
    rules = yaml.safe_load((ROOT / "game/art-direction/lighting_rules.yaml").read_text())
    light = dict(rules["variants"][rules["picked"]])
    light["sky"] = "#f7e3c0"
    return light


def blender(label, look, crown):
    code = f"""
import importlib, math, sys
sys.path.insert(0, {str(ROOT / 'pipeline')!r})
import bpy
from mathutils import Vector
from blender.render import game_light, game_view

bpy.ops.wm.read_homefile(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
ns = {{"__name__": "nature_build"}}
exec(open({str(ROOT / 'game/assets/3d/nature_build.py')!r}).read(), ns)
look = {look!r}
ns["build"]({{"asset_id": look, "parts": [look], "pivots": {{"origin": "ground_centre"}},
             "dimensions": {{"max_x": 1.0, "max_y": 1.05, "max_z": 1.85}}}})
tree = bpy.data.objects[look]
crown = {crown!r}
if crown:
    stops = {TRUNK!r}[look] + crown
    tree.data.materials.clear()
    tree.data.materials.append(ns["painted_material"](look + "_repaint", "tree", stops, {SEED[look]}))
for k, x in ((1, -1.2), (2, 1.2)):
    d = bpy.data.objects.new(f"t{{k}}", tree.data)
    sc.collection.objects.link(d)
    d.location = (x, 0, 0)

light = {picked_light()!r}
game_view(sc, light)
game_light(sc, light)
cam_data = bpy.data.cameras.new("cam")
cam_data.sensor_fit = "VERTICAL"
cam_data.lens_unit = "FOV"
cam_data.angle = math.radians(30.0)
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.image_settings.file_format = "PNG"

def place(tx, tz, dist, az, el, res):
    azr, elr = math.radians(az), math.radians(el)
    target = Vector((tx, 0, tz))
    off = Vector((math.sin(azr) * math.cos(elr), -math.cos(azr) * math.cos(elr), math.sin(elr))) * dist
    cam.location = target + off
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res, res

place(0, 0.75, 2.9, 35, 14, 560)
sc.render.filepath = {str(OUT)!r} + "/awhole.png"
bpy.ops.render.render(write_still=True)
place(0, 0.5, 54.4, 0, 60, 1080)
sc.render.filepath = {str(OUT)!r} + "/brow.png"
bpy.ops.render.render(write_still=True)
result = {{"done": True}}
"""
    p = subprocess.run(["blx", "-"], input=code, text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit(f"blender failed:\n{p.stdout[-2000:]}\n{p.stderr[-2000:]}")
    for _, tag in ROWS:
        (OUT / f"{tag}.png").rename(OUT / f"{label}_{tag}.png")


def crop_mag(im, half_w, half_h, mag):
    w, h = im.size
    return im.crop((w // 2 - half_w, h // 2 - half_h, w // 2 + half_w, h // 2 + half_h)) \
             .resize((int(2 * half_w * mag), int(2 * half_h * mag)), Image.NEAREST)


def compose():
    im = Image.new("RGB", (LEFT + len(COLS) * (CELL + 12) + 12,
                           30 + len(ROWS) * (CELL + LBL + 10)), (255, 255, 255))
    d = ImageDraw.Draw(im)
    f, fs = font(24), font(20)
    x = LEFT
    for label, *_ in COLS:
        d.text((x + CELL // 2 - 20 - 6 * len(label), 6), label, fill=(200, 0, 0), font=f)
        x += CELL + 12
    y = 40
    for row_label, tag in ROWS:
        d.text((8, y + CELL // 2 - 24), row_label, fill=(0, 0, 0), font=fs)
        x = LEFT
        for label, _, _ in COLS:
            src = Image.open(OUT / f"{label}_{tag}.png")
            if tag == "brow":
                src = crop_mag(src, 150, 60, 1.8)
            else:
                src.thumbnail((CELL, CELL))
            im.paste(src, (x + (CELL - src.width) // 2, y + (CELL - src.height) // 2))
            x += CELL + 12
        y += CELL + LBL + 10
    im.save(BOARD)
    print(BOARD)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for label, look, crown in COLS:
        blender(label, look, crown)
    compose()


if __name__ == "__main__":
    main()
