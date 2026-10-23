# Sent to Blender by pipeline/barrel.py with JOB prepended:
#   {"mode": "parts" | "cut" | "join", "glb": whole gun or mount, "barrel_glb": for join, "ref_glb": whole gun of
#    the same API for join, "footprint": tiles, "out_dir": ..., "tilts": [deg, ...]}
# Splits the gun into `barrel` and `mount`, puts the barrel's origin on the trunnion axis, an empty
# `projectile_spawn` at the muzzle, renders the barrel at each tilt, saves source.blend and the numbers.
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

CONTAIN_GAP = 0.02  # metres between the farthest reach of a gun and the edge of its plate


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in set(bpy.data.objects) - before if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in set(bpy.data.objects) - before - set(objs):
        bpy.data.objects.remove(o)
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def verts(ob):
    return [ob.matrix_world @ v.co for v in ob.data.vertices]


def box(ps):
    return Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)])


def weld(ob, dist):
    """Welds the texture seams. The imported custom normals no longer fit, so smooth shading with sharp
    edges above 40 degrees replaces them."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(ob.data)
    bm.free()
    bpy.context.view_layer.objects.active = ob
    if ob.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    ob.data.shade_smooth()
    ob.data.set_sharp_from_angle(angle=math.radians(40))


def make_plate(spec, footprint, mount, barrel):
    """A square plate under the gun, the footprint less a margin, in the gun's colour, chamfered on its top
    edges, so the grid squares the gun stands on read. The gun rises by the plate's height. In the game the
    plate stays square to the grid while the gun turns."""
    side, h = footprint - 2 * spec["margin"], spec["height"]
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(side, side, h), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    top = [e for e in bm.edges if all(v.co.z > h - 1e-6 for v in e.verts)]
    bmesh.ops.bevel(bm, geom=top, offset=spec["chamfer"], segments=1, affect="EDGES")
    me = bpy.data.meshes.new("plate")
    bm.to_mesh(me)
    bm.free()
    plate = bpy.data.objects.new("plate", me)
    bpy.context.scene.collection.objects.link(plate)
    rgb = [int(spec["colour"][i:i + 2], 16) / 255 for i in (1, 3, 5)]
    mat = bpy.data.materials.new("plate")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*[c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb], 1)
    bsdf.inputs["Roughness"].default_value = 0.8
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    for v in mount.data.vertices:
        v.co.z += h
    mount.data.update()
    barrel.location.z += h
    return plate


def rotate_z(ob, angle):
    for v in ob.data.vertices:
        v.co = Matrix.Rotation(angle, 4, "Z") @ v.co
    ob.data.update()


def main_angle(ps):
    """Direction of the largest spread in the ground plane."""
    n = len(ps)
    mx, my = sum(p.x for p in ps) / n, sum(p.y for p in ps) / n
    cxx = sum((p.x - mx) ** 2 for p in ps)
    cyy = sum((p.y - my) ** 2 for p in ps)
    cxy = sum((p.x - mx) * (p.y - my) for p in ps)
    return 0.5 * math.atan2(2 * cxy, cxx - cyy)


def normalise(ob, footprint, top=0.4):
    """The barrel along X: the main direction of the upper part, where the barrel sits. Then scaled to fill
    the footprint, origin at the ground centre."""
    lo, hi = box(verts(ob))
    upper = [p for p in verts(ob) if p.z >= hi.z - (hi.z - lo.z) * top]
    rotate_z(ob, -main_angle(upper))
    lo, hi = box(verts(ob))
    s = footprint / max(hi.x - lo.x, hi.y - lo.y)
    for v in ob.data.vertices:
        v.co = (v.co - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))) * s
    ob.data.update()
    weld(ob, footprint * 1e-4)


def split_loose(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    return [o for o in bpy.context.selected_objects]


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = ob.data.name = name
    return ob


def axis_of(ps):
    """The barrel runs along X. Its axis is the centre of its cross-section, its radius the widest point."""
    lo, hi = box(ps)
    yc, zc = (lo.y + hi.y) / 2, (lo.z + hi.z) / 2
    return yc, zc, max((hi.y - lo.y), (hi.z - lo.z)) / 2, lo.x, hi.x


def bore_centre(barrel, ex, yc, zc, r, sign):
    """The centre of the mouth hole, where the shots leave: a grid of rays down the muzzle maps the
    face, and the mean of the cells that fall deep into the bore is the centre of the visible ring.
    The box centre sits off the hole when the drilled bore runs off the axis: 4.8 cm on the cannon,
    16.6 cm on the mortar. Returns the (y, z) centre and where it came from."""
    bm = bmesh.new()
    bm.from_mesh(barrel.data)
    bm.transform(barrel.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    pitch, half = 0.002, r + 0.01
    n = int(half * 2 / pitch) + 1
    org_y, org_z = yc - half, zc - half
    start = Vector((ex + 0.2 * sign, 0.0, 0.0))
    down = Vector((-sign, 0.0, 0.0))
    t1 = []
    for i in range(n):
        row = []
        for j in range(n):
            start.y, start.z = org_y + i * pitch, org_z + j * pitch
            hit = tree.ray_cast(start, down)
            row.append(hit[3] if hit[0] is not None else math.inf)
        t1.append(row)
    hits = sorted(t for row in t1 for t in row if t < math.inf)
    if not hits:
        return yc, zc, "axis"
    deep_level = hits[len(hits) // 2] + 0.04
    deep = [[t > deep_level for t in row] for row in t1]
    seen = [[False] * n for _ in range(n)]
    best = None
    for i in range(n):
        for j in range(n):
            if seen[i][j] or not deep[i][j]:
                continue
            comp, stack = [], [(i, j)]
            seen[i][j] = True
            while stack:
                a, b = stack.pop()
                comp.append((a, b))
                for na, nb in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= na < n and 0 <= nb < n and deep[na][nb] and not seen[na][nb]:
                        seen[na][nb] = True
                        stack.append((na, nb))
            floor = max(t1[a][b] for a, b in comp)
            if best is None or floor > best[0]:
                best = (floor, comp)
    if best is None or len(best[1]) < 100:
        return yc, zc, "axis"
    cy = sum(org_y + a * pitch for a, _ in best[1]) / len(best[1])
    cz = sum(org_z + b * pitch for _, b in best[1]) / len(best[1])
    return cy, cz, "mouth"


def muzzle_sign(ps, yc, zc, x0, x1, anchor=None):
    """The muzzle is the end farther from the anchor: the mount's mass centre, or the trunnions of a barrel on its
    own. When the anchor sits near the middle, the wider end is the muzzle: a thin knob closes the breech."""
    if anchor is not None and abs(anchor - (x0 + x1) / 2) > (x1 - x0) * 0.1:
        return 1 if x1 - anchor > anchor - x0 else -1
    n = (x1 - x0) * 0.06
    def r(sel):
        return max((math.hypot(p.y - yc, p.z - zc) for p in ps if sel(p.x)), default=0)
    return 1 if r(lambda x: x > x1 - n) > r(lambda x: x < x0 + n) else -1


def mass_x(ob):
    ps = verts(ob)
    return sum(p.x for p in ps) / len(ps)


def pins_x(barrel, yc, r):
    pins = [p.x for p in verts(barrel) if abs(p.y - yc) > r * 1.15]
    return sum(pins) / len(pins) if pins else None


def numbered_pieces(ob):
    """The loose pieces in a fixed order, bottom to top, then along the barrel, so a number names the same piece
    on every run of the same model."""
    pieces = split_loose(ob)
    def key(o):
        lo, hi = box(verts(o))
        c = (lo + hi) / 2
        return (round(c.z, 2), round(c.x, 2), round(c.y, 2))
    pieces.sort(key=key)
    for i, o in enumerate(pieces):
        o.name = f"p{i:02d}"
    return pieces


def auto_barrel(pieces):
    """Meshy's low-poly mode returns the barrel as loose pieces: the tube, its rings, sometimes a front and a rear
    section and a breech knob. Every piece on the barrel's axis next to the tube joins it."""
    lo_all, hi_all = box([p for o in pieces for p in verts(o)])
    upper = [o for o in pieces if box(verts(o))[1].z > (lo_all.z + hi_all.z) / 2]
    def tube(o):  # long and thick: a rail or a rod is long but thin
        lo, hi = box(verts(o))
        return (hi.x - lo.x) * min(hi.y - lo.y, hi.z - lo.z)
    def elongated(o):
        lo, hi = box(verts(o))
        return hi.x - lo.x >= 2 * max(hi.y - lo.y, hi.z - lo.z)
    core = max([o for o in upper if elongated(o)] or upper, key=tube)
    yc, zc, r, x0, x1 = axis_of(verts(core))
    barrel, grown = [core], True
    while grown:
        grown = False
        for o in pieces:
            if o in barrel:
                continue
            lo, hi = box(verts(o))
            rad = max(hi.y - lo.y, hi.z - lo.z) / 2
            coaxial = math.hypot((lo.y + hi.y) / 2 - yc, (lo.z + hi.z) / 2 - zc) < r * 0.4 and rad <= r * 1.45
            near = lo.x <= x1 + r and hi.x >= x0 - r
            inside = lo.x >= x0 and hi.x <= x1 and all(  # rivets and bands on the barrel's surface
                math.hypot(y - yc, z - zc) <= r * 1.2 for y in (lo.y, hi.y) for z in (lo.z, hi.z))
            c = (lo + hi) / 2
            fitted = max(hi - lo) < r and math.hypot(c.y - yc, c.z - zc) < r * 1.6 and x0 <= c.x <= x1  # a sight
            if (coaxial and near) or inside or fitted:
                barrel.append(o)
                x0, x1, grown = min(x0, lo.x), max(x1, hi.x), True
    return barrel


def trunnion_caps(barrel, rest):
    """The small mount pieces level with the barrel's axis at its sides. Returns their mean x, or None."""
    yc, zc, r, x0, x1 = axis_of([p for o in barrel for p in verts(o)])
    caps = []
    for o in rest:
        lo, hi = box(verts(o))
        c = (lo + hi) / 2
        if abs(c.z - zc) < r * 0.6 and r * 0.6 < abs(c.y - yc) < r * 3 and max(hi - lo) < r * 3 and x0 < c.x < x1:
            caps.append(c.x)
    return sum(caps) / len(caps) if caps else None


def fix(pieces, op):
    """Hand fixes to single pieces, from the asset's split.json.
    raise_top: the top rim of `piece` rises to the bottom of the pieces in `to`, closing a gap between them.
    lift: the pieces in `pieces` rise by `by` metres, and the upper half of each piece in `stretch` rises with them,
    lengthening it.
    shorten: each piece in `pieces` shrinks by the fraction `by` along its own long axis, toward its end nearer the
    pieces in `base`.
    drop: the pieces in `pieces` are deleted outright, a generated piece with no place in the gun.
    slot: an axis-aligned box, `x` and `z` spans plus a `y` half-width, is cut out of `piece`, opening a grip
    that clamps too tight for the barrel to swing through."""
    by = {int(o.name[1:]): o for o in pieces}
    if op["op"] == "lift":
        for i in op["pieces"]:
            for v in by[i].data.vertices:
                v.co.z += op["by"]
        for i in op.get("stretch", []):
            zs = [v.co.z for v in by[i].data.vertices]
            mid = (min(zs) + max(zs)) / 2
            for v in by[i].data.vertices:
                if v.co.z > mid:
                    v.co.z += op["by"]
        for i in op["pieces"] + op.get("stretch", []):
            by[i].data.update()
    elif op["op"] == "shorten":
        base = sum((sum((v.co for v in by[i].data.vertices), Vector()) / len(by[i].data.vertices) for i in op["base"]),
                   Vector()) / len(op["base"])
        for i in op["pieces"]:
            vs = by[i].data.vertices
            c = sum((v.co for v in vs), Vector()) / len(vs)
            axis = max(((v.co - c).normalized() for v in vs if (v.co - c).length > 1e-6),
                       key=lambda d: max(abs((v.co - c).dot(d)) for v in vs))
            ts = [(v.co - c).dot(axis) for v in vs]
            root = min(ts) if (c + axis * min(ts) - base).length < (c + axis * max(ts) - base).length else max(ts)
            for v, t in zip(vs, ts):
                v.co -= axis * (t - root) * op["by"]
            by[i].data.update()
    elif op["op"] == "raise_top":
        ob = by[op["piece"]]
        target = min(p.z for i in op["to"] for p in verts(by[i]))
        top = max(p.z for p in verts(ob))
        band = (top - min(p.z for p in verts(ob))) * 0.04
        for v in ob.data.vertices:
            if v.co.z >= top - band:
                v.co.z += target - top
        ob.data.update()
    elif op["op"] == "slot":
        ob = by[op["piece"]]
        x, z = op["x"], op["z"]
        cut = bpy.data.meshes.new("slot")
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(
            Vector(((x[0] + x[1]) / 2, 0, (z[0] + z[1]) / 2)), None,
            Vector((x[1] - x[0], op["y"] * 2, z[1] - z[0]))))
        bm.to_mesh(cut)
        bm.free()
        knife = bpy.data.objects.new("slot", cut)
        bpy.context.scene.collection.objects.link(knife)
        mod = ob.modifiers.new("slot", 'BOOLEAN')
        mod.operation = 'DIFFERENCE'
        mod.object = knife
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        out = ev.to_mesh()
        ob.modifiers.remove(mod)
        slotted = bpy.data.meshes.new("slotted")
        slotted.from_pydata([v.co.copy() for v in out.vertices], [],
                            [tuple(p.vertices) for p in out.polygons])
        ev.to_mesh_clear()
        ob.data = slotted
        bpy.data.objects.remove(knife, do_unlink=True)
        bpy.data.meshes.remove(cut)
        ob.data.update()
    else:
        raise ValueError(f"unknown fix {op['op']}")


def barrel_from_parts(ob, job):
    pieces = numbered_pieces(ob)
    for op in job.get("fixes", []):
        if op["op"] == "drop":
            for i in op["pieces"]:
                o = next(o for o in pieces if int(o.name[1:]) == i)
                pieces.remove(o)
                bpy.data.objects.remove(o, do_unlink=True)
            continue
        fix(pieces, op)
    if job.get("barrel") is not None:
        barrel = [o for o in pieces if int(o.name[1:]) in job["barrel"]]
    else:
        barrel = auto_barrel(pieces)
    rest = [o for o in pieces if o not in barrel]
    if job.get("pivot_pieces"):  # the pin or the trunnion stubs, by hand: the pivot is their centre
        cs = [(lambda b: (b[0] + b[1]) / 2)(box(verts(o))) for o in pieces if int(o.name[1:]) in job["pivot_pieces"]]
        trunnion = sum(cs, Vector()) / len(cs)
    else:
        x = trunnion_caps(barrel, rest)
        trunnion = None if x is None else Vector((x, 0, float("nan")))
    return join(barrel, job.get("part", "barrel")), join(rest, "mount"), trunnion


def piece_sheet(ob, out):
    """Every piece once in red, the automatic barrel in blue, the rest grey, from the front left and the side."""
    pieces = numbered_pieces(ob)
    barrel = auto_barrel(pieces)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = sc.render.resolution_y = 240
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.9, 0.9, 0.9)
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_cavity = "STUDIO", "OBJECT", False
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    lo, hi = box([p for o in pieces for p in verts(o)])
    centre, size = (lo + hi) / 2, max(hi - lo)
    cam.data.ortho_scale = size * 1.2
    info = []
    for i, o in enumerate(pieces):
        for q in pieces:
            q.color = (0.35, 0.55, 0.95, 1) if q in barrel else (0.7, 0.7, 0.7, 1)
        o.color = (0.95, 0.1, 0.1, 1)
        for view, (az, el) in (("front", (-45, 25)), ("side", (0, 0))):
            a, e = math.radians(az), math.radians(el)
            cam.location = centre + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * size * 5
            cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = os.path.join(out, f"p{i:02d}_{view}.png")
            bpy.ops.render.render(write_still=True)
        plo, phi = box(verts(o))
        info.append({"id": i, "auto": "barrel" if o in barrel else "mount",
                     "tris": sum(len(f.vertices) - 2 for f in o.data.polygons),
                     "size_m": [round(v, 3) for v in phi - plo], "centre_m": [round(v, 3) for v in (plo + phi) / 2]})
    with open(os.path.join(out, "pieces.json"), "w") as f:
        json.dump(info, f, indent=1)
    return info


def barrel_by_cut(ob):
    """A fused mesh. Slices across the upper part give the barrel: the narrow slices with one shared centre.
    Every face inside that cylinder goes to the barrel. The cut leaves the mount open where they met."""
    ps = verts(ob)
    lo, hi = box(ps)
    top = [p for p in ps if p.z > lo.z + (hi.z - lo.z) * 0.45]
    tlo, thi = box(top)
    n, slices = 24, []
    for i in range(n):
        a, b = tlo.x + (thi.x - tlo.x) * i / n, tlo.x + (thi.x - tlo.x) * (i + 1) / n
        sel = [p for p in top if a <= p.x < b]
        if len(sel) >= 6:
            slo, shi = box(sel)
            slices.append(((slo.y + shi.y) / 2, (slo.z + shi.z) / 2, max(shi.y - slo.y, shi.z - slo.z) / 2))
    narrow = sorted(slices, key=lambda t: t[2])[: max(3, len(slices) * 6 // 10)]
    yc = sorted(t[0] for t in narrow)[len(narrow) // 2]
    zc = sorted(t[1] for t in narrow)[len(narrow) // 2]
    rmed = sorted(t[2] for t in narrow)[len(narrow) // 2]
    r = max(t[2] for t in slices if math.hypot(t[0] - yc, t[1] - zc) < rmed * 0.15 and t[2] < rmed * 1.5)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    inner = [f for f in bm.faces if all(math.hypot(v.co.y - yc, v.co.z - zc) <= r * 1.08 for v in f.verts)]
    geom = bmesh.ops.split(bm, geom=inner)
    bm.to_mesh(ob.data)
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bm = bmesh.from_edit_mesh(ob.data)
    for f in bm.faces:
        f.select = all(math.hypot(v.co.y - yc, v.co.z - zc) <= r * 1.08 for v in f.verts)
    bmesh.update_edit_mesh(ob.data)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.selected_objects]
    barrel = [o for o in parts if o is not ob][0]
    barrel.name = barrel.data.name = "barrel"
    ob.name = ob.data.name = "mount"
    return barrel, ob


def barrel_by_join(job):
    """The mount and the barrel made apart, sized and placed like the parts of the same API's whole gun."""
    ref = load(job["ref_glb"])
    normalise(ref, job["footprint"])
    rb, rm = barrel_from_parts(ref, {})[:2] if job["ref_mode"] == "parts" else barrel_by_cut(ref)
    ryc, rzc, rr, rx0, rx1 = axis_of(verts(rb))
    rsign = muzzle_sign(verts(rb), ryc, rzc, rx0, rx1, mass_x(rm))
    rpiv = pivot_x(rb, ryc, rzc, rr, rx0, rx1)
    mlo, mhi = box(verts(rm))
    raspect = (mhi.x - mlo.x) / (mhi.y - mlo.y)
    rmean = sum(p.x for p in verts(rm)) / len(rm.data.vertices) - (mlo.x + mhi.x) / 2
    for o in (rb, rm):
        bpy.data.objects.remove(o)
    mount = load(job["glb"])
    weld(mount, 1e-4)
    lo, hi = box(verts(mount))
    if abs((hi.y - lo.y) / (hi.x - lo.x) - raspect) < abs((hi.x - lo.x) / (hi.y - lo.y) - raspect):
        rotate_z(mount, math.pi / 2)
        lo, hi = box(verts(mount))
    mean = sum(p.x for p in verts(mount)) / len(mount.data.vertices) - (lo.x + hi.x) / 2
    if mean * rmean < 0:  # the mass of a one-sided mount leans the same way as in the whole gun
        rotate_z(mount, math.pi)
        lo, hi = box(verts(mount))
    s = (mhi.z - mlo.z) / (hi.z - lo.z)
    for v in mount.data.vertices:
        v.co = (v.co - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))) * s + Vector(((mlo.x + mhi.x) / 2, (mlo.y + mhi.y) / 2, 0))
    mount.data.update()
    mount.name = mount.data.name = "mount"
    barrel = load(job["barrel_glb"])
    normalise(barrel, 1.0, top=1.0)
    yc, zc, r, x0, x1 = axis_of(verts(barrel))
    if muzzle_sign(verts(barrel), yc, zc, x0, x1, pins_x(barrel, yc, r)) != rsign:
        rotate_z(barrel, math.pi)
        yc, zc, r, x0, x1 = axis_of(verts(barrel))
    piv = pivot_x(barrel, yc, zc, r, x0, x1)
    s = (rx1 - rx0) / (x1 - x0)
    for v in barrel.data.vertices:
        v.co = (v.co - Vector((piv, yc, zc))) * s + Vector((rpiv, ryc, rzc))
    barrel.data.update()
    barrel.name = barrel.data.name = "barrel"
    return barrel, mount


def pivot_x(barrel, yc, zc, r, x0, x1):
    """The trunnions stick out sideways. Without them, the pivot sits above the footprint centre."""
    pins = [p.x for p in verts(barrel) if abs(p.y - yc) > r * 1.15]
    return sum(pins) / len(pins) if pins else min(max(0.0, x0), x1)


def level(ob, centre, pitch):
    """A part that points `pitch` degrees above the ground in the source turns level about the Y axis through
    `centre`, the way that leaves it flattest, so the axis, the muzzle and the tilt work as for a level barrel."""
    ps = verts(ob)
    def height(rot):
        zs = [(rot @ (p - centre)).z for p in ps]
        return max(zs) - min(zs)
    rot = min((Matrix.Rotation(math.radians(s * pitch), 3, "Y") for s in (1, -1)), key=height)
    for v, p in zip(ob.data.vertices, ps):
        v.co = rot @ (p - centre) + centre
    ob.matrix_world = Matrix.Identity(4)
    ob.data.update()


def render(out, name, objs, tilt, barrel, az, el):
    sc = bpy.context.scene
    barrel.rotation_euler.x = math.radians(tilt)
    bpy.context.view_layer.update()
    lo, hi = box([p for o in objs for p in verts(o)])
    cam = sc.camera
    centre, size = (lo + hi) / 2, max(hi - lo)
    cam.data.ortho_scale = size * 1.35
    a, e = math.radians(az), math.radians(el)
    cam.location = centre + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * size * 5
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_homefile(use_empty=True)
trunnion = None
if JOB["mode"] == "pieces":
    gun = load(JOB["glb"])
    normalise(gun, JOB["footprint"])
    os.makedirs(JOB["out_dir"], exist_ok=True)
    result = {"pieces": len(piece_sheet(gun, JOB["out_dir"]))}
else:
    if JOB["mode"] == "join":
        barrel, mount = barrel_by_join(JOB)
    else:
        gun = load(JOB["glb"])
        normalise(gun, JOB["footprint"])
        if JOB["mode"] == "parts":
            barrel, mount, trunnion = barrel_from_parts(gun, JOB)
        else:
            barrel, mount = barrel_by_cut(gun)
    if JOB.get("pitch"):
        level(barrel, trunnion, JOB["pitch"])
    yc, zc, r, x0, x1 = axis_of(verts(barrel))
    sign = muzzle_sign(verts(barrel), yc, zc, x0, x1, mass_x(mount))
    if JOB.get("pivot_x") is not None:
        pivot_from, px = "set by hand", JOB["pivot_x"]
    elif trunnion is not None:
        pivot_from, px = ("pivot pieces" if JOB.get("pivot_pieces") else "trunnion caps"), trunnion.x
        if not math.isnan(trunnion.z):
            zc = trunnion.z
        if JOB.get("pivot_pieces"):
            yc = trunnion.y
    else:
        px = pivot_x(barrel, yc, zc, r, x0, x1)
        pivot_from = "trunnion pins" if pins_x(barrel, yc, r) is not None else "footprint centre"
    # The muzzle turns to +Y, which the glTF export makes -Z, the game's forward. The trunnion axis is then X.
    turn = Matrix.Rotation(math.pi / 2 if sign > 0 else -math.pi / 2, 4, "Z")
    ex = x1 if sign > 0 else x0
    myc, mzc, bore_from = bore_centre(barrel, ex, yc, zc, r, sign)
    piv = turn @ Vector((px, yc, zc))
    muzzle = turn @ Vector((ex, myc, mzc))
    for ob in (barrel, mount):
        for v in ob.data.vertices:
            v.co = turn @ (ob.matrix_world @ v.co)
        ob.matrix_world = Matrix.Identity(4)
        ob.data.update()
    # normalise() centred the WHOLE gun on the footprint, and the barrel overhangs the muzzle
    # side, so the mount (the part that stands on the plate) landed 5 to 24 cm off the plate
    # centre (session 11b, measured in the game). The mount's own XY centre goes to the origin;
    # the barrel and its pivot move with it, so nothing between them changes.
    mlo, mhi = box(verts(mount))
    recentre = Vector(((mlo.x + mhi.x) / 2, (mlo.y + mhi.y) / 2, 0.0))
    for ob in (barrel, mount):
        for v in ob.data.vertices:
            v.co -= recentre
        ob.data.update()
    piv -= recentre
    muzzle -= recentre
    # Every gun stays inside its plate at every turn and tilt the game gives it (Sebastian, session 12: "The guns
    # should be contained to their squares!"). The game turns a barrel's whole gun about the origin and tilts the
    # barrel about the pivot. It aims guns about the pivot in every direction, with the mount standing still.
    if JOB.get("plate"):
        limit = JOB["footprint"] / 2 - JOB["plate"]["margin"] - CONTAIN_GAP
        guns = JOB.get("part") == "guns"
        axis = Vector((piv.x, piv.y, 0)) if guns else Vector()
        bv = [v.co.copy() for v in barrel.data.vertices]
        reach = max(math.hypot(p.x, p.y) for p in verts(mount))
        for t in range(0 if guns else -10, 91, 5):
            rot = Matrix.Rotation(math.radians(t), 3, "X")
            reach = max(reach, max((rot @ (p - piv) + piv - axis).xy.length for p in bv) + axis.length)
        k = min(1.0, limit / reach)
        for ob in (barrel, mount):
            for v in ob.data.vertices:
                v.co *= k
            ob.data.update()
        piv *= k
        muzzle *= k
    for v in barrel.data.vertices:
        v.co -= piv
    barrel.data.update()
    barrel.rotation_mode = "XYZ"
    barrel.location = piv
    # Hand-placed spawn anchors (session 49): the projectile_spawn empty dragged to the bore
    # mouth in tools/spawn_place_<gun>.tscn, saved scenes in the game repo. The values are the
    # glb's barrel-local positions converted to blend space (glb (x, y, z) -> blend (x, -z, y)).
    # Guns without an entry keep the bore_centre search below.
    HAND_SPAWN = {
        "cannon": Vector((0.0, 0.3444088, 0.04847598)),
        "cannon22a": Vector((-0.02959942, 0.8090769, 0.058987617)),
        "cannon.2": Vector((0.016620766, 0.24911745, -0.003967464)),  # out of the game (D92), kept for the parked asset
        "cannon.3": Vector((0.008888461, 0.36502713, 0.0309878)),
        "cannon.4": Vector((0.02382414, 0.3067669, 0.031394392)),
    }
    # The flak's guns have no spawn: the game shoots the ball down where it flies.
    spawn = None if JOB.get("part") == "guns" else bpy.data.objects.new("projectile_spawn", None)
    if spawn:
        bpy.context.scene.collection.objects.link(spawn)
        spawn.parent = barrel
        hand = HAND_SPAWN.get(JOB.get("gun"))
        spawn.location = hand if hand is not None else muzzle - piv  # hand is barrel-local already
    plate = make_plate(JOB["plate"], JOB["footprint"], mount, barrel) if JOB.get("plate") else None
    flat_mats = None
    if JOB.get("flat"):  # C22: the source texture's own colours as one flat material a part (D94's recipe)
        from blender import paint
        srcs = {n.image for ob in (barrel, mount) for m in ob.data.materials if m and m.use_nodes
                for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}
        source = max(srcs, key=lambda i: i.size[0] * i.size[1], default=None)
        assert source is not None, "the flat paint needs the gun's source texture"
        flat_mats = []
        for ob in (barrel, mount):
            paint.painted_material(ob, {"kind": "flat", "seed": JOB["flat"]["seed"],
                                        "over": {"k": 5, "blur": 2}}, source=source)
            flat_mats += [m.name for m in ob.data.materials]

    out = JOB["out_dir"]
    os.makedirs(out, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = sc.render.resolution_y = 360
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.82, 0.82, 0.82)
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_cavity = "STUDIO", "TEXTURE", False
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    for t in JOB["tilts"]:  # the muzzle points +Y, so a positive turn about X raises it
        render(out, f"tilt{t:+d}_front_left", [barrel, mount], t, barrel, 135, 25)
        render(out, f"tilt{t:+d}_side", [barrel, mount], t, barrel, 90, 0)
    barrel.rotation_euler.x = 0
    sh.color_type = "RANDOM"
    render(out, "split", [barrel, mount], 0, barrel, 135, 25)
    bpy.data.objects.remove(cam)
    # The game aims guns by their whole orientation, so they keep the source's pitch as their rest pose.
    # A barrel rests level: the game sets its tilt.
    if JOB.get("part") == "guns":
        barrel.rotation_euler.x = math.radians(JOB.get("pitch") or 0)


    def nm(ob):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        n = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
        return n


    tri = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)  # noqa: E731
    stats = {"mode": JOB["mode"], "barrel_tris": tri(barrel), "mount_tris": tri(mount),
             "plate_tris": tri(plate) if plate else 0,
             "barrel_open_edges": nm(barrel), "mount_open_edges": nm(mount), "pivot_from": pivot_from,
             "bore_from": bore_from, "spawn_from": "hand" if JOB.get("gun") in HAND_SPAWN else bore_from, "bore_m": [round(myc, 3), round(mzc, 3)],
             "pivot_m": [round(v, 3) for v in piv], "barrel_length_m": round(x1 - x0, 3),
             "part": JOB.get("part", "barrel"), "tilts": JOB["tilts"], "flat_materials": flat_mats}
    with open(os.path.join(out, "stats.json"), "w") as f:
        json.dump(stats, f, indent=2)
    if JOB.get("export"):
        px = JOB.get("texture_px") or 1024  # at the closest zoom a 3x3 gun covers about 600 px
        for img in bpy.data.images:
            if img.size[0] > px:
                img.scale(px, px)
                img.pack()
    bpy.ops.wm.save_as_mainfile(filepath=JOB.get("blend") or os.path.join(out, "source.blend"))
    if JOB.get("export"):
        bpy.ops.object.select_all(action="DESELECT")
        for o in (barrel, mount, spawn, plate):
            if o is not None:
                o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=JOB["export"], export_format="GLB", use_selection=True,
                                  export_yup=True, export_materials="EXPORT",
                                  export_image_format="JPEG", export_jpeg_quality=90)
        stats["export"] = JOB["export"]
    result = stats
