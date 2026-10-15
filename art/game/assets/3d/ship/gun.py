# The oversized ship gun (D47 + Sebastian's amendment: congruous with the 1x1 cannon, scaled to
# dominate the boat). Runs on the cleaned hull: blx game/assets/3d/ship/gun.py
# Placement measured on the cleaned hull: foredeck z rises 0.33->0.36 across y 0.19..0.40, deck
# half-width 0.10 at y 0.29, step down to the lower deck at y 0.17, mast front face y 0.074,
# stem top z 0.401 at y 0.50, rail top z 0.352. A regenerated hull means re-measuring.
import json
import math
import os

import bpy

# blx exec()s this file without __file__ or argv, so the dir is found from Blender's cwd (a session
# starts Blender in the repo root) with the canonical checkout as the fallback.
D = next((os.path.join(r, "game/assets/3d/ship")
          for r in (os.getcwd(), os.path.expanduser("~/repos/grid-cannons/art"))
          if os.path.exists(os.path.join(r, "game/assets/3d/ship/source.blend"))), None)
assert D, "run from the art folder of the game repo, or start Blender there"
ELEV = math.radians(8.0)           # near-horizontal like the 1x1 cannon, not the painted 20
TRUNNION = (0.0, 0.31, 0.505)      # barrel reference: where it rides the pedestal top
BARREL_LEN = 0.50                  # barrel reaches past the stem: the oversized joke
L_BACK, L_MUZ = 0.14, 0.36         # breech face and muzzle along the axis from TRUNNION
R_BAR_BRE, R_BAR_MUZ = 0.115, 0.092
PED_Y, PED_TOP, PED_FOOT = 0.29, 0.537, 0.365   # pedestal axis, top embeds the barrel past centre

bpy.ops.wm.read_homefile(filepath=f"{D}/source.blend")
for o in list(bpy.data.objects):            # idempotent: rebuild the gun from the hull state
    if o.name.startswith("ship_cannon"):
        bpy.data.objects.remove(o, do_unlink=True)
for m in list(bpy.data.meshes):             # orphaned meshes would rename the rebuild .001
    if m.name.startswith("ship_cannon"):
        bpy.data.meshes.remove(m)
for m in list(bpy.data.materials):
    if m.name.startswith(("ship_gun_iron", "ship_gun_wood")):
        bpy.data.materials.remove(m)
hull = next(o for o in bpy.data.objects if o.type == "MESH")

iron = bpy.data.materials.new("ship_gun_iron")
iron.use_nodes = True
iron.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.10, 0.10, 0.11, 1)
iron.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.5
wood = bpy.data.materials.new("ship_gun_wood")
wood.use_nodes = True
wood.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.26, 0.16, 0.09, 1)
wood.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85

SPIN = math.radians(22.5)          # flat facet up, like the 1x1's barrel
BARREL_ROT = (ELEV - math.pi / 2, 0.0, 0.0)   # cylinder +Z -> near-horizontal +Y


def piece(verts, radius1, radius2, depth, location, rot, mat, spin=SPIN):
    # 5.2 cylinders take one radius; the taper is a vertex edit on the +Z end
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius1, depth=depth, location=location)
    ob = bpy.context.active_object
    for v in ob.data.vertices:
        if spin:
            v.co.x, v.co.y = (v.co.x * math.cos(spin) - v.co.y * math.sin(spin),
                              v.co.x * math.sin(spin) + v.co.y * math.cos(spin))
        if radius2 is not None and v.co.z > 0:
            k = radius2 / radius1
            v.co.x *= k
            v.co.y *= k
    ob.rotation_euler = rot
    ob.data.update()
    ob.data.materials.append(mat)
    return ob


u = (0.0, math.cos(ELEV), math.sin(ELEV))
at = lambda t: tuple(TRUNNION[i] + t * u[i] for i in range(3))     # point on the barrel axis

parts = [
    piece(8, R_BAR_BRE, R_BAR_MUZ, BARREL_LEN, at((L_MUZ - L_BACK) / 2), BARREL_ROT, iron),
    piece(8, 0.126, None, 0.032, at(-0.125), BARREL_ROT, iron),    # breech ring
    piece(8, 0.121, None, 0.035, at(-0.055), BARREL_ROT, iron),    # mid reinforce
    piece(8, 0.118, None, 0.030, at(0.335), BARREL_ROT, iron),     # muzzle flare band
    piece(6, 0.032, None, 0.045, at(-0.152), BARREL_ROT, iron, math.radians(30)),  # cascabel neck
    piece(8, 0.095, 0.070, PED_TOP - PED_FOOT, (0.0, PED_Y, (PED_TOP + PED_FOOT) / 2),
          (0.0, 0.0, 0.0), wood),                                  # tapered pedestal
    piece(8, 0.115, None, 0.033, (0.0, PED_Y, 0.3485), (0.0, 0.0, 0.0), wood),  # plate, sunk 0.005
]
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.038, location=at(-0.188))
ball = bpy.context.active_object
ball.data.materials.append(iron)
parts.append(ball)

for p in parts:                                  # barrel pieces carry object-space rotation
    bpy.context.view_layer.objects.active = p
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
gun = bpy.context.active_object
gun.name = gun.data.name = "ship_cannon"

bpy.ops.wm.save_as_mainfile(filepath=f"{D}/source.blend", compress=True)
bpy.ops.object.select_all(action="DESELECT")
hull.select_set(True)
gun.select_set(True)
bpy.ops.export_scene.gltf(filepath=f"{D}/final.glb", export_format="GLB", use_selection=True,
                          export_yup=True, export_materials="EXPORT",
                          export_image_format="JPEG", export_jpeg_quality=90)

res = {
    "gun_tris": sum(len(p.vertices) - 2 for p in gun.data.polygons),
    "objects": [o.name for o in bpy.data.objects if o.type == "MESH"],
    "materials": [m.name for m in gun.data.materials],
}
print(json.dumps(res))
