# Shared builder for the six battlefield-block looks (I93): the obstacles are tile-size boxes
# assembled in clumped patterns by the game, so each look is one block a different height and
# character, a family a tile. Stone settles as a chiselled mass (taper, bevel, one broken crown);
# a crate is a frame of planks with a planked lid, read from the high camera that sees the top.
import bmesh
import bpy

LOOKS = {
    "terrain_stone":   {"w": 0.96, "d": 0.96, "h": 0.85, "bev": 0.055, "taper": 0.94, "chisel": None},
    "terrain_stone.2": {"w": 0.98, "d": 0.98, "h": 0.55, "bev": 0.130, "taper": 0.90, "chisel": None},
    "terrain_stone.3": {"w": 0.90, "d": 0.90, "h": 1.25, "bev": 0.045, "taper": 0.95, "chisel": (1.0, 1.0, 0.45)},
    "terrain_crate":   {"w": 0.92, "d": 0.92, "h": 0.80, "planks": 3, "stack": None},
    "terrain_crate.2": {"w": 0.92, "d": 0.92, "h": 0.55, "planks": 2, "stack": None},
    "terrain_crate.3": {"w": 0.92, "d": 0.92, "h": 0.55, "planks": 3,
                        "stack": {"w": 0.80, "d": 0.80, "h": 0.50, "planks": 3, "off": (0.04, -0.03)}},
}


def _box(name, sx, sy, sz, x, y, z, bev):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = ob.data.name = name
    ob.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    if bev > 0.0:
        m = ob.modifiers.new("bev", "BEVEL")
        m.width, m.segments = bev, 1
        bpy.ops.object.modifier_apply(modifier="bev")
    ob.location = (x, y, z + sz / 2)
    return ob


def _stone(name, p):
    ob = _box(name, p["w"], p["d"], p["h"], 0.0, 0.0, 0.0, p["bev"])
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for v in bm.verts:
        if v.co.z > 0.0:  # the crown settles in: a chiselled block, not a glass-smooth cube
            v.co.x *= p["taper"]
            v.co.y *= p["taper"]
    if p["chisel"]:
        cx, cy, drop = p["chisel"]
        for v in bm.verts:
            if v.co.z > p["h"] * 0.25 and v.co.x * cx > 0.15 and v.co.y * cy > 0.15:
                v.co.z -= drop
                v.co.x *= 0.78
                v.co.y *= 0.78
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def _crate(name, p, off=(0.0, 0.0), z0=0.0):
    # every box sinks 0.01 into its neighbour: interpenetrating solids union clean,
    # exactly-touching faces weld into non-manifold edges.
    w, d, h, t = p["w"], p["d"], p["h"], 0.10
    made = [_box(f"{name}_bottom", w, d, 0.06, off[0], off[1], z0, 0.0)]
    for i, (sw, sd, sx, sy) in enumerate([(w, t, 0.0, (d - t) / 2), (w, t, 0.0, -(d - t) / 2),
                                          (t, d - 2 * t + 0.02, (w - t) / 2, 0.0),
                                          (t, d - 2 * t + 0.02, -(w - t) / 2, 0.0)]):
        made.append(_box(f"{name}_f{i}", sw, sd, h - 0.05, off[0] + sx, off[1] + sy, z0 + 0.05, 0.0))
    n = p["planks"]
    pw = (w - 2 * t + 0.02) / n
    for i in range(n):
        x = off[0] - (w - 2 * t) / 2 + pw * (i + 0.5)
        made.append(_box(f"{name}_p{i}", pw - 0.015, d - 2 * t + 0.04, 0.045, x, off[1], z0 + h - 0.01, 0.0))
    return made


def _union(base, cutter):
    m = base.modifiers.new("u", "BOOLEAN")
    m.operation, m.solver, m.object = "UNION", "EXACT", cutter
    bpy.context.view_layer.objects.active = base
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def build(asset):
    p = LOOKS[asset["asset_id"]]
    if "planks" not in p:
        _stone(asset["asset_id"], p)
        return
    made = _crate(asset["asset_id"], p)
    for o in made[1:]:
        _union(made[0], o)
    ob = made[0]
    ob.name = ob.data.name = asset["asset_id"]
    if p.get("stack"):
        s = p["stack"]
        for o in _crate(asset["asset_id"] + "_top", s, s["off"], p["h"] - 0.04)[1:]:
            _union(ob, o)
        ob.data.name = asset["asset_id"]
