import bmesh
import bpy
from mathutils import Vector

from .geo import anchor, bbox, parts, tri_count


def run(asset, asset_dir):
    wanted = set(asset["parts"])
    found = {o.name for o in bpy.data.objects if o.type == "MESH"}
    missing = sorted(wanted - found)
    if missing:
        raise RuntimeError(f"parts missing after build: {missing}")
    extra = [o for o in bpy.data.objects if o.name not in wanted]
    removed = [o.name for o in extra]
    for o in extra:
        bpy.data.objects.remove(o, do_unlink=True)
    objs = parts(asset)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
    shift = Vector()
    if asset.get("pivots", {}).get("origin", "ground_centre") == "ground_centre":
        lo, hi = bbox(anchor(asset, objs))   # overhanging parts must not drag the root off its tile
        shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
        for o in objs:
            o.location += shift
    tris = sum(tri_count(o) for o in objs)
    budget = asset.get("budget", {}).get("max_tris")
    decimated = False
    if budget and tris > budget:
        for o in objs:
            m = o.modifiers.new("Decimate", "DECIMATE")
            m.ratio = budget / tris
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=m.name)
        decimated = True
    bpy.ops.object.select_all(action="DESELECT")
    return {"removed": removed, "shift_m": [round(c, 4) for c in shift], "decimated": decimated}
