# Run through blx with GLB and OUT prepended. The flak's built final.glb: the rest pitch of `guns` as the
# game receives it, and at each test pitch the lowest point of `guns` above the pedestal top, inside the
# pedestal's radius, plus a side close-up of the joint. Numbers before pixels.
import math
import os

import bpy
from mathutils import Matrix, Vector

bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)  # noqa: F821
guns, mount = bpy.data.objects["guns"], bpy.data.objects["mount"]
guns.rotation_mode = "XYZ"
rest = math.degrees(guns.rotation_euler.x)
bpy.context.view_layer.update()
mv = [mount.matrix_world @ v.co for v in mount.data.vertices]
pivot = guns.matrix_world.translation.copy()
# The pedestal column: mount vertices below the ball's foot, their horizontal reach from the pivot axis.
ball_foot = pivot.z - 0.2
column = [p for p in mv if p.z < ball_foot]
col_top = max(p.z for p in column)
col_r = max(math.hypot(p.x - pivot.x, p.y - pivot.y) for p in column if p.z > col_top - 0.15)
result = {"rest_pitch_deg": round(rest, 1), "pivot": [round(v, 3) for v in pivot], "column_top": round(col_top, 3),
          "column_r": round(col_r, 3), "pitches": {}}
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = sc.render.resolution_y = 480
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.82, 0.82, 0.82)
sc.display.shading.light, sc.display.shading.color_type = "STUDIO", "TEXTURE"
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 1.6
os.makedirs(OUT, exist_ok=True)  # noqa: F821
for pitch in (0, 43, 60, 80, 90):
    for yaw in (0, 180):
        guns.rotation_euler = (math.radians(pitch), 0, math.radians(yaw))
        bpy.context.view_layer.update()
        gv = [guns.matrix_world @ v.co for v in guns.data.vertices]
        inside = [p.z for p in gv if math.hypot(p.x - pivot.x, p.y - pivot.y) < col_r]
        low = min(gv, key=lambda p: p.z)
        result["pitches"][f"{pitch}/{yaw}"] = {"lowest_inside_column": round(min(inside) - col_top, 3) if inside else None,
                                               "lowest_z": round(low.z, 3)}
    guns.rotation_euler = (math.radians(pitch), 0, 0)
    bpy.context.view_layer.update()
    target = pivot + Vector((0, 0, 0.1))
    cam.location = target + Vector((3, 0, 0))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, f"joint_{pitch:02d}.png")  # noqa: F821
    bpy.ops.render.render(write_still=True)
