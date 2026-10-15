"""The era ladder block-out: one gun per game size on a board of 1 m tiles, seen from the game camera.
Run: blender --background --factory-startup --python blockout.py -- OUT.png"""

import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
GUNS = [(-4, 1, 1), (-2, 1, 2), (1, 1, 3)]  # footprint x0, y0, side in tiles
BOXES = [(-5, -2), (-3, -2), (-1, -2), (1, -2), (3, -2), (5, -2)]


def mat(name, hexc):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*[(int(hexc[i:i + 2], 16) / 255) ** 2.2 for i in (1, 3, 5)], 1)
    return m


GRASS, GAP, IRON, GUN, WOOD = (mat(*a) for a in [("grass", "#8fb04a"), ("gap", "#5e7a2e"), ("iron", "#3a3634"), ("gun", "#56514d"), ("wood", "#9a6a44")])


def box(loc, size, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = Vector(size) / 2
    o.data.materials.append(m)
    return o


def cyl(loc, r, depth, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=r, depth=depth, location=loc, rotation=rot)
    bpy.context.object.data.materials.append(m)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
box((0.5, 1.0, -0.15), (14, 9, 0.1), GAP)
for x in range(-6, 7):
    for y in range(-3, 5):
        box((x + 0.5, y + 0.5, -0.05), (0.94, 0.94, 0.1), GRASS)

for x0, y0, n in GUNS:
    cx, cy = x0 + n / 2, y0 + n / 2
    cyl((cx, cy, 0.06), 0.48 * n, 0.12, IRON)
    box((cx - 0.08 * n, cy, 0.12 + 0.14 * n), (0.42 * n, 0.36 * n, 0.28 * n), WOOD if n < 3 else IRON)
    yaw, pitch, length = math.radians(-25), math.radians(15), 0.95 * n
    d = Vector((math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch)))
    mid = Vector((cx - 0.08 * n, cy, 0.12 + 0.32 * n)) + d * (length * 0.35)
    cyl(mid, 0.09 * n, length, GUN, rot=d.to_track_quat("Z", "Y").to_euler())

for x, y in BOXES:
    box((x + 0.5, y + 0.5, 0.3), (0.8, 0.8, 0.6), WOOD)

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_cavity = True
sh.show_shadows = True
sc.display.light_direction = (0.5, -0.4, 0.75)
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.9, 0.72, 0.56)
cd = bpy.data.cameras.new("cam")
cd.sensor_fit = "VERTICAL"
cd.lens_unit = "FOV"
cd.angle = math.radians(30)
cam = bpy.data.objects.new("cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
target, pitch, dist = Vector((0.5, 0.9, 0)), math.radians(60), 13.5
cam.location = target + Vector((0, -math.cos(pitch), math.sin(pitch))) * dist
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.resolution_x, sc.render.resolution_y = 2048, 1152
sc.view_settings.view_transform = "Standard"
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
