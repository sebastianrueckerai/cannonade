# The gun alignment gate (session 11b): per gun, the mount's XY centre minus the plate's, from the
# built final.glb (Blender import, Z up). Pass is under 0.02 m on both axes. The split used to centre
# the whole gun on the footprint, and the barrel overhang put the mount 5 to 24 cm off its plate.
# Run: blx game/art-direction/rounds/27-indicators/align.py
import bpy
from mathutils import Vector

GUNS = GUNS if "GUNS" in dir() else ("cannon", "cannon22a", "cannon33a")
out = {}
for gid in GUNS:
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"/home/womb/repos/cannonade/art/game/assets/3d/{gid}/final.glb")
    def centre(name):
        o = bpy.data.objects[name]
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        return ((min(p.x for p in pts) + max(p.x for p in pts)) / 2, (min(p.y for p in pts) + max(p.y for p in pts)) / 2)
    m, p = centre("mount"), centre("plate")
    dx, dy = round(m[0] - p[0], 4), round(m[1] - p[1], 4)
    out[gid] = {"mount_minus_plate_xy": [dx, dy], "pass": abs(dx) < 0.02 and abs(dy) < 0.02}
result = out
