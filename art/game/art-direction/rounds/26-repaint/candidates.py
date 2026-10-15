#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pyyaml", "pillow", "httpx"]
# ///
"""C12 step 1: wall paint candidates. Builds wall_line_base once per candidate, paints it with a
stone variant, renders through the C11 game view (soft_honey light + grade), composes the D48
board: per candidate the whole 3/4 view, the front face, the side face, the row at the default
view (x4) and zoomed in. Procedural board: no provider call, no sidecar. Run from the repo root:
    uv run --script game/art-direction/rounds/26-repaint/candidates.py"""
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
BOARD = Path(__file__).parent / "candidates-board.png"
CANDS = ["1_subtle", "2_weathered", "3_patchy", "4_pale"]
SEED = {"1_subtle": 41, "2_weathered": 42, "3_patchy": 43, "4_pale": 44}
OVER = {
    "1_subtle": {"patches": [(10, (8, 15), (0.07, 0.12), (22, 44)), (7, (9, 17), (0.06, 0.10), (-40, -22))],
                 "streaks": (12, (0.82, 0.96), (0.04, 0.11), (3, 7), (0.20, 0.32), 34)},
    "3_patchy": {"patches": [(14, (12, 24), (0.10, 0.16), (44, 74)), (10, (13, 26), (0.09, 0.14), (-64, -40))],
                 "streaks": (13, (0.80, 0.97), (0.06, 0.14), (4, 9), (0.26, 0.40), 36)},
    "4_pale": {"grain": (0.06, 0.03),
               "patches": [(6, (8, 14), (0.05, 0.09), (12, 24)), (4, (9, 15), (0.04, 0.08), (-22, -12))],
               "streaks": (8, (0.84, 0.96), (0.03, 0.08), (3, 6), (0.12, 0.20), 28)},
}
ROWS = [("a34", "whole 3/4"), ("bfront", "front"), ("cmerlon", "merlon"),
        ("ddefault", "default x4"), ("ezoom", "zoom x2")]
CELL, LBL, LEFT = 560, 36, 150


def picked_light():
    rules = yaml.safe_load((ROOT / "game/art-direction/lighting_rules.yaml").read_text())
    light = dict(rules["variants"][rules["picked"]])
    light["sky"] = "#f7e3c0"  # the panorama haze band, as the C11 rig uses it
    return light


def blender(name, light):
    spec = {"kind": "stone", "seed": SEED[name], "over": OVER.get(name)}
    code = f"""
import importlib, math, sys
sys.path.insert(0, {str(ROOT / 'pipeline')!r})
import bpy
from mathutils import Vector
import blender.paint as paint
importlib.reload(paint)
from blender.render import game_light, game_view

bpy.ops.wm.read_homefile(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
ns = {{"__name__": "build"}}
exec(open({str(ROOT / 'game/assets/3d/wall_cornice.py')!r}).read(), ns)
ns["build"]({{"asset_id": "wall_line_base", "parts": ["wall"], "shape": "line", "level": "base"}})
wall = bpy.data.objects["wall"]
paint.painted_material(wall, {spec!r})
for k in (1, 2, 3):
    d = bpy.data.objects.new(f"wall.c{{k}}", wall.data)
    sc.collection.objects.link(d)
    d.location = (k, 0, 0)

light = {light!r}
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

for tag, tx, tz, dist, az, el, res in (
        ("a34", 1.5, 0.45, 3.2, 35, 14, 560), ("bfront", 1.5, 0.42, 2.0, 0, 4, 560),
        ("cmerlon", 0.25, 0.70, 1.7, 22, 18, 560),
        ("ddefault", 1.5, 0.5, 54.4, 0, 60, 720), ("ezoom", 0.5, 0.68, 3.0, 25, 18, 1080)):
    place(tx, tz, dist, az, el, res)
    sc.render.filepath = {str(OUT)!r} + "/" + tag + ".png"
    bpy.ops.render.render(write_still=True)
result = {{"done": True}}
"""
    p = subprocess.run(["blx", "-"], input=code, text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit(f"blender failed:\n{p.stdout[-2000:]}\n{p.stderr[-2000:]}")
    for tag, _ in ROWS:
        (OUT / f"{tag}.png").rename(OUT / f"{name}_{tag}.png")


def crop_mag(im, half_w, half_h, mag):
    w, h = im.size
    return im.crop((w // 2 - half_w, h // 2 - half_h, w // 2 + half_w, h // 2 + half_h)) \
             .resize((2 * half_w * mag, 2 * half_h * mag), Image.NEAREST)


def compose():
    im = Image.new("RGB", (LEFT + len(CANDS) * (CELL + 12) + 12,
                           46 + len(ROWS) * (CELL + LBL + 10)), (255, 255, 255))
    d = ImageDraw.Draw(im)
    f, fs = font(26), font(20)
    x = LEFT
    for name in CANDS:
        d.text((x + CELL // 2 - 60, 14), name, fill=(200, 0, 0), font=f)
        x += CELL + 12
    y = 46
    for tag, label in ROWS:
        d.text((8, y + CELL // 2 - 12), label, fill=(0, 0, 0), font=fs)
        x = LEFT
        for name in CANDS:
            src = Image.open(OUT / f"{name}_{tag}.png")
            if tag == "ddefault":
                src = crop_mag(src, 62, 44, 4)
            elif tag == "ezoom":
                src = crop_mag(src, 125, 70, 2)
            else:
                src.thumbnail((CELL, CELL))
            im.paste(src, (x + (CELL - src.width) // 2, y + (CELL - src.height) // 2))
            x += CELL + 12
        y += CELL + LBL + 10
    im.save(BOARD)
    print(BOARD)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    light = picked_light()
    for name in CANDS:
        blender(name, light)
    compose()


if __name__ == "__main__":
    main()
