#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pyyaml", "pillow", "httpx"]
# ///
"""C12 steps 3-4 evidence: the tile grain and the shell iron paint. The tile renders twice with
the grain pre-multiplied by the Map's open-ground colours (the game multiplies its colour lerp on
top of the near-white texture, so pre-multiplying shows the in-game read), at the default view x4
and zoomed. The shell renders whole and close in the iron paint. Procedural board, no sidecar.
    uv run --script game/art-direction/rounds/26-repaint/pieces.py"""
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
BOARD = Path(__file__).parent / "pieces-board.png"
CELL, LBL, LEFT = 560, 36, 150
TILE_GREEN = [(0.0, "#9ec558"), (1.0, "#9cc355")]   # Map minOpen grass .lightened(0.06) x white
TILE_SAND = [(0.0, "#f4d489"), (1.0, "#f2d286")]   # Map minOpen sand .lightened(0.06) x white


def picked_light():
    rules = yaml.safe_load((ROOT / "game/art-direction/lighting_rules.yaml").read_text())
    light = dict(rules["variants"][rules["picked"]])
    light["sky"] = "#f7e3c0"
    return light


def blender(job):
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
light = {picked_light()!r}
game_view(sc, light)
game_light(sc, light)

def place(tx, tz, dist, az, el, res):
    azr, elr = math.radians(az), math.radians(el)
    target = Vector((tx, 0, tz))
    off = Vector((math.sin(azr) * math.cos(elr), -math.cos(azr) * math.cos(elr), math.sin(elr))) * dist
    cam.location = target + off
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res, res

cam_data = bpy.data.cameras.new("cam")
cam_data.sensor_fit = "VERTICAL"
cam_data.lens_unit = "FOV"
cam_data.angle = math.radians(30.0)
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.image_settings.file_format = "PNG"

job = {job!r}
if job["what"] == "tile":
    ns = {{"__name__": "tile_build"}}
    exec(open({str(ROOT / 'game/assets/3d/tile/build.py')!r}).read(), ns)
    ns["build"]({{"asset_id": "tile"}})
    tile = bpy.data.objects["tile"]
    paint.painted_material(tile, {{"kind": "grain", "seed": 71, "over": {{"stops": job["stops"]}}}})
    for ix in range(-2, 3):
        for iy in range(-2, 3):
            if ix == 0 and iy == 0:
                continue
            d = bpy.data.objects.new(f"t{{ix}}_{{iy}}", tile.data)
            sc.collection.objects.link(d)
            d.location = (ix, iy, 0)
    place(0, 0.1, 54.4, 0, 60, 1080)
    sc.render.filepath = {str(OUT)!r} + "/tile_default.png"
    bpy.ops.render.render(write_still=True)
    place(0, 0.1, 10.5, 0, 60, 1080)
    sc.render.filepath = {str(OUT)!r} + "/tile_zoom.png"
    bpy.ops.render.render(write_still=True)
else:
    ns = {{"__name__": "shell_build"}}
    exec(open({str(ROOT / 'game/assets/3d/shell/build.py')!r}).read(), ns)
    ns["build"]({{"asset_id": "shell"}})
    shell = bpy.data.objects["shell"]
    paint.painted_material(shell, {{"kind": "iron", "seed": 81}})
    place(0, 0.14, 0.8, 35, 18, 560)
    sc.render.filepath = {str(OUT)!r} + "/shell_whole.png"
    bpy.ops.render.render(write_still=True)
    place(0, 0.14, 0.42, 0, 8, 560)
    sc.render.filepath = {str(OUT)!r} + "/shell_close.png"
    bpy.ops.render.render(write_still=True)
result = {{"done": True}}
"""
    p = subprocess.run(["blx", "-"], input=code, text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit(f"blender failed:\n{p.stdout[-2000:]}\n{p.stderr[-2000:]}")


def crop_mag(im, half_w, half_h, mag):
    w, h = im.size
    return im.crop((w // 2 - half_w, h // 2 - half_h, w // 2 + half_w, h // 2 + half_h)) \
             .resize((int(2 * half_w * mag), int(2 * half_h * mag)), Image.NEAREST)


def compose():
    rows = [
        ("tile green x4", [crop_mag(Image.open(OUT / "tile_green_default.png"), 110, 62, 2.5)]),
        ("tile sand x4", [crop_mag(Image.open(OUT / "tile_sand_default.png"), 110, 62, 2.5)]),
        ("tile zoom", [Image.open(OUT / "tile_green_zoom.png")]),
        ("shell whole", [Image.open(OUT / "shell_whole.png")]),
        ("shell close", [Image.open(OUT / "shell_close.png")]),
    ]
    im = Image.new("RGB", (LEFT + CELL + 12, 10 + len(rows) * (CELL + LBL + 10)), (255, 255, 255))
    d = ImageDraw.Draw(im)
    fs = font(20)
    y = 10
    for label, ims in rows:
        d.text((8, y + CELL // 2 - 12), label, fill=(0, 0, 0), font=fs)
        for i, src in enumerate(ims):
            src.thumbnail((CELL, CELL))
            im.paste(src, (LEFT + i * (CELL + 12) + (CELL - src.width) // 2,
                           y + (CELL - src.height) // 2))
        y += CELL + LBL + 10
    im.save(BOARD)
    print(BOARD)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    blender({"what": "tile", "stops": TILE_GREEN})
    for f in ("tile_default", "tile_zoom"):
        (OUT / f"{f}.png").rename(OUT / f"tile_green_{f.split('_')[1]}.png")
    blender({"what": "tile", "stops": TILE_SAND})
    for f in ("tile_default", "tile_zoom"):
        (OUT / f"{f}.png").rename(OUT / f"tile_sand_{f.split('_')[1]}.png")
    blender({"what": "shell"})
    compose()


if __name__ == "__main__":
    main()
