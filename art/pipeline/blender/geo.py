import bpy
from mathutils import Vector


def parts(asset):
    return [o for o in bpy.data.objects if o.type == "MESH" and o.name in asset["parts"]]


def anchor(asset, objs):
    """The object the game anchors to the tile: `pivots.anchor` in asset.yaml, else the part named
    like the asset. Extra parts may overhang the tile by design (the ship's gun over the bow, a
    gun's barrel past its plate), so origin maths uses only this."""
    name = asset.get("pivots", {}).get("anchor") or asset["asset_id"]
    root = [o for o in objs if o.name == name]
    return root or objs


def bbox(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)
