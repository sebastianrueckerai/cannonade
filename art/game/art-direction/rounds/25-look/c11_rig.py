# C11 remeasure for the round 25 pick (D52): the same wall row as
# tools/shoot_battle.gd --look=10,2 (game repo) rebuilt in EEVEE under
# pipeline/blender/render.py's game_light. Run:
#   blx game/art-direction/rounds/25-look/c11_rig.py
# The fitted knobs live in CAL below; everything else is fixed.
import math
import sys
from pathlib import Path

PIPELINE = Path("/home/womb/repos/grid-cannons/art/pipeline")
GAME = Path("/home/womb/repos/grid-cannons/assets/art/3d")
sys.path.insert(0, str(PIPELINE))

import bpy  # noqa: E402
from blender.render import game_light, game_view  # noqa: E402
from mathutils import Vector, Matrix  # noqa: E402

# fitted to the game frame's clean lit face band: R -0.4% G +0.5% B +0.6%
CAL = {"sun_energy": 13.6, "ambient_strength": 0.16, "ambient_blue_scale": 0.92, "grade_sat": 0.5}
LIGHT = {
    "sun_elevation": 38, "sun_azimuth": 40, "sun_colour": "#ffd29d",
    "ambient_colour": "#bec3c4", "sky": "#f7e3c0",
    "blender_eevee": CAL,
    "post": {"tonemap": "filmic", "exposure": 0.97, "saturation": 1.07, "contrast": 1.05},
}
OUT = "/tmp/c11blend/c11.png"


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bbox_all(objs):
    vs = [Vector(c) @ o.matrix_world for o in objs for c in o.bound_box]
    return (
        Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
        Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))),
    )


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"

# the wall row: four wall_line_base segments at tile spacing, base on the floor
bpy.ops.import_scene.gltf(filepath=str(GAME / "wall_line_base.glb"))
walls = meshes()
lo, hi = bbox_all(walls)
if hi.y - lo.y > hi.x - lo.x:  # glb long axis came in along Y: turn the row onto X
    c = (lo + hi) / 2
    rot = Matrix.Translation(c) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Translation(-c)
    for o in walls:
        o.matrix_world = rot @ o.matrix_world
lo, hi = bbox_all(walls)
shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
for o in walls:
    o.location += shift
for k in (1, 2, 3):  # copies sharing mesh data, one tile to the right each
    for o in walls:
        d = bpy.data.objects.new(f"{o.name}.c{k}", o.data)
        sc.collection.objects.link(d)
        d.matrix_world = Matrix.Translation(Vector((k, 0, 0))) @ o.matrix_world
lo, hi = bbox_all(meshes())
for o in meshes():  # centre the four-span row on the origin: tile centres land on the half lattice
    o.location.x -= (lo.x + hi.x) / 2
wall_objs = meshes()

# no ground: tile.glb is a white quad (the game paints grass green on the Map),
# and the C11 contract fits wall bands only
game_light(sc, LIGHT)
game_view(sc, LIGHT)

# the --look camera: game target + (0, 9, 6) in game axes -> blender (0, -6, 9),
# fov 30 vertical, the sandbox camera's framing
cam_data = bpy.data.cameras.new("c11_cam")
cam_data.sensor_fit = "VERTICAL"
cam_data.lens_unit = "FOV"
cam_data.angle = math.radians(30.0)
cam = bpy.data.objects.new("c11_cam", cam_data)
sc.collection.objects.link(cam)
_, whi = bbox_all(wall_objs)
target = Vector((0, 0, whi.z / 2))
cam.location = target + Vector((0, -6, 9))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)

result = {"cal": CAL, "out": OUT, "wall_top_z": round(whi.z, 3)}
print("RESULT", result)
