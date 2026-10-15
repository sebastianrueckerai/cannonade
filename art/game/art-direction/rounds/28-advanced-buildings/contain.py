# The containment gate (session 12, Sebastian: "The guns should be contained to their squares!"): per gun, from the
# built final.glb (Blender import, Z up), the farthest horizontal reach of the mount and of the moving part over every
# tilt the game gives it, against the plate's half side. The game turns a barrel's whole gun about the origin and
# aims guns about their pivot. Pass is reach under the half side. Run with ROOT, the assets folder, prepended:
#   (echo 'ROOT = "<repo>/game/assets/3d"'; cat game/art-direction/rounds/28-advanced-buildings/contain.py) | blx -
import math

import bpy
from mathutils import Vector

GUNS = {"cannon": "barrel", "cannon22a": "barrel", "cannon22b": "barrel", "flak22": "guns", "cannon33a": "barrel"}
out = {}
for gid, part in GUNS.items():
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"{ROOT}/{gid}/final.glb")  # noqa: F821
    mov, mount, plate = bpy.data.objects[part], bpy.data.objects["mount"], bpy.data.objects["plate"]
    mov.rotation_mode = "XYZ"
    half = max(abs((plate.matrix_world @ v.co).x) for v in plate.data.vertices)
    reach = max(math.hypot(p.x, p.y) for p in (mount.matrix_world @ v.co for v in mount.data.vertices))
    worst = "mount"
    for t in range(0 if part == "guns" else -10, 91, 5):
        mov.rotation_euler = (math.radians(t), 0, 0)
        bpy.context.view_layer.update()
        pv = mov.matrix_world.translation
        axis = Vector((pv.x, pv.y)) if part == "guns" else Vector((0, 0))
        r = max(((mov.matrix_world @ v.co).xy - axis).length for v in mov.data.vertices) + axis.length
        if r > reach:
            reach, worst = r, f"{part} at {t:+d}"
    out[gid] = {"plate_half": round(half, 3), "reach": round(reach, 3), "at": worst, "pass": reach < half}
result = out
