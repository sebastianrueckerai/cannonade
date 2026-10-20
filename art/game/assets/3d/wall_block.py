# Shared build for the full-tile wall block (level base) and its storey (level upper) in the four faction looks
# of D78 (asset.yaml `style`): plain, corbel, pilaster, course. The arch and caps looks of round 35 stay buildable.
# One mesh, `wall`, so a block is one draw call. Its top is a walkway deck in regions, each face tagged with a
# region id in the second UV layer `region` (u = id), which the game's wall shader colours per block:
#   0  body and merlons                      7  cap_nx          the walkway's last 0.04 m to the -x edge
#   1  walk_c   the centre square            8  cap_py
#   2  walk_px  corridor to the +x edge      9  cap_ny
#   3  walk_nx                              10  deck   the four corner squares the merlons stand on
#   4  walk_py  (Blender +y is Godot -z)    11  rim    a 0.04 m frame round the corners, a line round the wall
#   5  walk_ny                              12  band   the top 0.06 m of the body, a line round the wall's faces
#   6  cap_px
# The corridors and caps split so a rim line stays whole where no walkway crosses the edge.
#   base:  body z 0..0.75 with the band cut at 0.69, deck 0.75..0.77, merlons 0.77..1.0
#   upper: everything 0.75 up; the body swallows the lower block's deck and merlons
# Merlons 0.25 x 0.25 at [0.125, 0.375] and [-0.375, -0.125] on x and y (0.5 m period), so a tile seam falls in
# the middle of a 0.25 gap and neighbours continue the grid; the corridors run in those gaps.
# A block knows nothing of its neighbours (D75), so no style protrudes past the tile edge (a neighbour's
# protrusion would overlap it) and no recess goes deeper than 0.12 (the storey above must still hide the merlons).
# An inset body leaves a joint groove at every seam, twice the inset wide.
# Styles, each with its own merlons (TOPS), since the game camera sees the tops and not the faces:
#   plain     the D75 block, a full-tile box; square merlons
#   corbel    plinth 0..0.08 full tile, body inset 0.07, eight corbels under a full-tile slab; octagonal drum merlons
#   pilaster  panels 0.05 deep between corner posts, from a plinth at 0.08 up to a string course at 0.62;
#             pyramid-capped merlons
#   course    three stone courses round a set-back core: joints 0.03 wide and deep at 0.25 and 0.50, a centre joint
#             in the middle course, notched block corners in the outer courses so every seam reads as a joint;
#             sixteen small stud merlons
#   arch      one blind round-headed arch recess per face: 0.5 wide, sill 0.12, springing 0.36, apex 0.61, 0.07 deep
#   caps      body inset 0.04 under a full-tile cornice 0.65..0.69, pyramid caps on the merlons
# Chamfers (flat, one segment, 0.05): square merlons on their top and vertical edges, drums on top, pyramids on their
# verticals, studs none. Never an edge in a tile
# boundary plane (x or y = +-0.5), never an edge on the ground, never a concave edge.
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

BODY_TOP = 0.69
BAND_TOP = 0.75
DECK_TOP = 0.77
MERLON_TOP = 1.0
LEVEL = 0.75
SPANS = ((-0.375, -0.125), (0.125, 0.375))
HALF_WALK = 0.125
CAP = 0.46
CHAMFER = 0.05
EDGE = 0.5
OUT = 0.6  # a cutter starts here, outside the tile, so no cutter face is coplanar with a block face
EPS = 1e-4
REGION_PLANES = (-CAP, -HALF_WALK, HALF_WALK, CAP)


def box(name, x0, x1, y0, y1, z0, z1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = x1 if v.co.x > 0 else x0
        v.co.y = y1 if v.co.y > 0 else y0
        v.co.z = z1 if v.co.z > 0 else z0
    return _object(name, bm)


def prism(name, pts, lo, hi, axis="z"):
    """A closed prism: the outline `pts` (2D, counter-clockwise) extruded from lo to hi along `axis`. Along z the
    outline is (x, y); along y it is (x, z). One mesh, so a boolean with it meets no coincident cutter faces."""
    bm = bmesh.new()
    to3 = (lambda a, b, c: Vector((a, b, c))) if axis == "z" else (lambda a, b, c: Vector((a, c, b)))
    verts = [bm.verts.new(to3(a, b, lo)) for a, b in pts]
    face = bm.faces.new(verts)
    ret = bmesh.ops.extrude_face_region(bm, geom=[face])
    new_verts = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=new_verts, vec=to3(0, 0, hi - lo))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object(name, bm)


def arch_outline(half_w, sill, spring, segments=8):
    """A round-headed arch in (x, z): jambs from the sill to the springing, a semicircle above."""
    pts = [(half_w, sill), (half_w, spring)]
    for i in range(1, segments):
        a = math.pi * i / segments
        pts.append((half_w * math.cos(a), spring + half_w * math.sin(a)))
    pts += [(-half_w, spring), (-half_w, sill)]
    return pts


def _object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def boolean(base, others, operation):
    for o in others:
        m = base.modifiers.new("b", "BOOLEAN")
        m.operation, m.solver, m.object = operation, "EXACT", o
        bpy.context.view_layer.objects.active = base
        bpy.ops.object.modifier_apply(modifier=m.name)
        bpy.data.objects.remove(o, do_unlink=True)


def turned(ob, quarter_turns):
    """The same object turned about z in quarter turns, so one face's cutter serves all four faces."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=Matrix.Rotation(quarter_turns * math.pi / 2, 3, "Z"))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def four(make):
    """Four copies of a cutter built for the -y face, one per face."""
    return [turned(make(), q) for q in range(4)]


def clean(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=1e-3, verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


# ------------------------------------------------------------------ bodies, from z0 to z0 + BAND_TOP
# The band is not built: the body's faces are cut at BODY_TOP afterwards and the ring above it tagged region 12.
def body_plain(z0):
    return box("wall", -EDGE, EDGE, -EDGE, EDGE, z0, z0 + BAND_TOP)


def body_arch(z0):
    wall = body_plain(z0)
    outline = arch_outline(0.25, z0 + 0.12, z0 + 0.36)
    boolean(wall, four(lambda: prism("c", outline, -OUT, -EDGE + 0.07, axis="y")), "DIFFERENCE")
    return wall


def body_corbel(z0):
    inset = 0.07
    wall = box("wall", -EDGE, EDGE, -EDGE, EDGE, z0, z0 + 0.08)
    parts = [box("p", -EDGE + inset, EDGE - inset, -EDGE + inset, EDGE - inset, z0 + 0.06, z0 + 0.57),
             box("p", -EDGE, EDGE, -EDGE, EDGE, z0 + 0.55, z0 + BAND_TOP)]
    for q in range(4):
        for x0, x1 in SPANS:
            # 5 mm inside the tile plane, so no corbel face lies in the slab's face
            c = box("p", x0, x1, -EDGE + 0.005, -EDGE + inset + 0.03, z0 + 0.45, z0 + 0.57)
            bm = bmesh.new()
            bm.from_mesh(c.data)
            for v in bm.verts:  # the underside slopes up to the outer edge
                if v.co.z < z0 + 0.46 and v.co.y < -EDGE + 0.01:
                    v.co.z = z0 + 0.50
            bm.to_mesh(c.data)
            bm.free()
            parts.append(turned(c, q))
    boolean(wall, parts, "UNION")
    return wall


def body_pilaster(z0):
    wall = body_plain(z0)
    boolean(wall, four(lambda: box("c", -0.32, 0.32, -OUT, -EDGE + 0.05, z0 + 0.08, z0 + 0.62)), "DIFFERENCE")
    return wall


def body_course(z0):
    """Stones in three courses round a core set back by the joint depth: the outer courses are plus-shaped prisms
    whose notched corners meet a neighbour's into one joint at the seam, the middle course is four quadrant stones
    with a joint along each axis."""
    j, d = 0.015, 0.03
    core = box("wall", -EDGE + d + 0.005, EDGE - d - 0.005, -EDGE + d + 0.005, EDGE - d - 0.005, z0, z0 + BAND_TOP)
    e, n = EDGE, EDGE - d
    plus = [(-n, -e), (n, -e), (n, -n), (e, -n), (e, n), (n, n), (n, e), (-n, e), (-n, n), (-e, n), (-e, -n), (-n, -n)]
    parts = [prism("p", plus, z0 + za, z0 + zb) for za, zb in ((0.0, 0.25 - j), (0.50 + j, BAND_TOP))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("p", min(sx * j, sx * e), max(sx * j, sx * e), min(sy * j, sy * e), max(sy * j, sy * e),
                             z0 + 0.25 + j, z0 + 0.50 - j))
    boolean(core, parts, "UNION")
    return core


def body_caps(z0):
    inset = 0.04
    wall = box("wall", -EDGE + inset, EDGE - inset, -EDGE + inset, EDGE - inset, z0, z0 + 0.66)
    boolean(wall, [box("p", -EDGE, EDGE, -EDGE, EDGE, z0 + 0.65, z0 + BAND_TOP)], "UNION")
    return wall


BODIES = {"plain": body_plain, "arch": body_arch, "corbel": body_corbel, "pilaster": body_pilaster,
          "course": body_course, "caps": body_caps}


# ------------------------------------------------------------------ deck and merlons
def deck_plate(z0):
    """The walkway deck, one plate that overlaps the body's top by 0.01 so the union meets no coincident face;
    tag_regions cuts it into its regions afterwards."""
    return box("deck", -EDGE, EDGE, -EDGE, EDGE, z0 + BAND_TOP - 0.01, z0 + DECK_TOP)


def merlons(z_from, z_to, top):
    """The teeth on the deck's corner squares, one shape per look so the looks differ from above, where the game
    camera looks (Sebastian, 2026-10-20): square, the D75 block; octagon, drums; pyramid, square teeth with a
    pyramid cap; studs, a 2 x 2 of small teeth per corner, sixteen a tile. All stay inside [0.125, 0.46] on x
    and y so the walkway's corridors stay free."""
    bm = bmesh.new()
    for x0, x1 in SPANS:
        for y0, y1 in SPANS:
            if top == "octagon":
                r = (x1 - x0) / 2
                ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=r, radius2=r, depth=z_to - z_from)
                bmesh.ops.rotate(bm, verts=ret["verts"], cent=Vector(), matrix=Matrix.Rotation(math.pi / 8, 3, "Z"))
                bmesh.ops.translate(bm, verts=ret["verts"], vec=Vector((x0 + r, y0 + r, (z_from + z_to) / 2)))
            elif top == "studs":
                s = (x1 - x0) / 2
                for sx in (0, 1):
                    for sy in (0, 1):
                        _tooth(bm, x0 + sx * s + 0.015, x0 + (sx + 1) * s - 0.015, y0 + sy * s + 0.015,
                               y0 + (sy + 1) * s - 0.015, z_from, z_to - 0.05, False)
            else:
                _tooth(bm, x0, x1, y0, y1, z_from, z_to, top == "pyramid")
    vertical = lambda e: abs(e.verts[0].co.x - e.verts[1].co.x) < EPS and abs(e.verts[0].co.y - e.verts[1].co.y) < EPS
    flat_top = lambda e: all(abs(v.co.z - z_to) < EPS for v in e.verts)
    edges = []
    if top in ("square", "pyramid"):
        edges += [e for e in bm.edges if vertical(e) and e.calc_length() > 0.1]
    if top in ("square", "octagon"):
        edges += [e for e in bm.edges if flat_top(e)]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=CHAMFER, offset_type="OFFSET", segments=1, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object("merlons", bm)


def _tooth(bm, x0, x1, y0, y1, z_from, z_to, pyramid):
    top = z_to - 0.06 if pyramid else z_to
    geom = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in geom:
        v.co.x = x1 if v.co.x > 0 else x0
        v.co.y = y1 if v.co.y > 0 else y0
        v.co.z = top if v.co.z > 0 else z_from
    if pyramid:
        cap = [f for f in bm.faces if all(v in geom for v in f.verts) and all(abs(v.co.z - top) < EPS for v in f.verts)]
        apex = bmesh.ops.poke(bm, faces=cap)["verts"][0]
        apex.co.z = z_to


TOPS = {"plain": "square", "corbel": "octagon", "pilaster": "pyramid", "course": "studs", "arch": "square",
        "caps": "pyramid"}


def region_of(c, z0):
    """The region id of a face by its centre: the deck by its square, the band by height, the rest 0."""
    z = c.z - z0
    if z > DECK_TOP + EPS:
        return 0
    if z >= BAND_TOP - EPS:
        ax, ay = abs(c.x), abs(c.y)
        if ax <= HALF_WALK + EPS and ay <= HALF_WALK + EPS:
            return 1
        if ay <= HALF_WALK + EPS:
            return (6 if c.x > 0 else 7) if ax > CAP - EPS else (2 if c.x > 0 else 3)
        if ax <= HALF_WALK + EPS:
            return (8 if c.y > 0 else 9) if ay > CAP - EPS else (4 if c.y > 0 else 5)
        return 11 if max(ax, ay) > CAP - EPS else 10
    if z >= BODY_TOP - EPS:
        return 12
    return 0


def bisect(bm, faces, co, no):
    geom = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=EPS)


def tag_regions(ob, z0):
    """Cuts the body at the band line and the deck along the region planes, then writes each face's region id into
    the `region` UV layer. `UVMap` stays the active, empty layer the paint projects."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bisect(bm, list(bm.faces), Vector((0, 0, z0 + BODY_TOP)), Vector((0, 0, 1)))
    for axis in (0, 1):
        for p in REGION_PLANES:
            deck = [f for f in bm.faces if all(z0 + BAND_TOP - EPS <= v.co.z <= z0 + DECK_TOP + EPS for v in f.verts)]
            no = Vector((1, 0, 0)) if axis == 0 else Vector((0, 1, 0))
            bisect(bm, deck, no * p, no)
    uv = bm.loops.layers.uv.new("UVMap")
    reg = bm.loops.layers.uv.new("region")
    areas = {}
    for f in bm.faces:
        rid = region_of(f.calc_center_median(), z0)
        if f.normal.z > 0.5:  # the deck's top only: a look's notched top course adds side faces under the caps
            areas[rid] = areas.get(rid, 0.0) + f.calc_area()
        for loop in f.loops:
            loop[uv].uv = (0.0, 0.0)
            loop[reg].uv = (float(rid), 0.0)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.uv_layers.active_index = 0
    return areas


def build(asset):
    z0 = LEVEL if asset.get("level") == "upper" else 0.0
    style = asset.get("style", "plain")
    wall = BODIES[style](z0)
    clean(wall)
    boolean(wall, [deck_plate(z0), merlons(z0 + DECK_TOP - 0.01, z0 + MERLON_TOP, TOPS[style])], "UNION")
    areas = tag_regions(wall, z0)
    # the deck's top: the centre square, a corridor of 0.335 by 0.25, a cap of 0.04 by 0.25
    for rid, want in ((1, 0.0625), (2, 0.08375), (6, 0.01)):
        if abs(areas.get(rid, 0.0) - want) > 1e-3:
            raise RuntimeError(f"region {rid} area {areas.get(rid, 0.0):.4f}, want {want}")
