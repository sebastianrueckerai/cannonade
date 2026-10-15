# Run through blx with ROOT and OUT prepended. The gate's big renders of the two guns from final.glb: the
# mortar's barrel at the game's rest (-10), the lowest firing angle (45) and a steep shot (80); the flak's
# guns at level (0), their rest pitch (43) and straight up (90). Workbench, texture colour, the muzzle side.
import math
import os

import bpy
from mathutils import Vector

POSES = {"cannon22b": ("barrel", (-10, 45, 80)), "flak22": ("guns", (0, 43, 90))}
for gid, (part, tilts) in POSES.items():
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, gid, "final.glb"))  # noqa: F821
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = sc.render.resolution_y = 800
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.82, 0.82, 0.82)
    sc.display.shading.light, sc.display.shading.color_type = "STUDIO", "TEXTURE"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.4
    moving = bpy.data.objects[part]
    moving.rotation_mode = "XYZ"
    for t in tilts:
        moving.rotation_euler = (math.radians(t), 0, 0)
        bpy.context.view_layer.update()
        centre = Vector((0, 0, 1.3))
        a, e = math.radians(135), math.radians(25)
        cam.location = centre + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * 12
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, f"{gid}_{t:+03d}.png")  # noqa: F821
        bpy.ops.render.render(write_still=True)
result = {"ok": True}
