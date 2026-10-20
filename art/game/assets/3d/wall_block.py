# Shared build for the full-tile wall block (level base) and its storey (level upper), in the styles of session 26.
# Three parts: `wall` the body, `deck` the walkway slab on the body's top, `merlons` the 2 x 2 teeth on the deck.
# Deck and merlons paint on a white base with the stone colour as the material's base colour factor, so the game
# tints them by writing one albedo colour (the mud tile's rule, D70); the body keeps the cream stone paint.
#   base:  body z 0..0.75, deck 0.75..0.77, merlons 0.77..1.0
#   upper: everything 0.75 up; the body swallows the lower block's deck and merlons
# Merlons 0.25 x 0.25 at [0.125, 0.375] and [-0.375, -0.125] on x and y (0.5 m period), so a tile seam falls in
# the middle of a 0.25 gap and neighbours continue the grid.
# A block knows nothing of its neighbours (D75), so no style protrudes past the tile edge (a neighbour's
# protrusion would overlap it) and no recess goes deeper than 0.12 (the storey above must still hide the merlons).
# An inset body leaves a joint groove at every seam, twice the inset wide.
# Styles, asset.yaml `style`, default plain:
#   plain     the D75 block, a full-tile box
#   arch      one blind round-headed arch recess per face: 0.5 wide, sill 0.12, springing 0.36, apex 0.61, 0.07 deep
#   corbel    plinth 0..0.08 full tile, body inset 0.07, eight corbels under a full-tile slab 0.55..0.75
#   pilaster  panels 0.05 deep between corner posts, from a plinth at 0.08 up to a string course at 0.62
#   course    three stone courses round a set-back core: joints 0.03 wide and deep at 0.25 and 0.50, a centre joint
#             in the middle course, notched block corners in the outer courses so every seam reads as a joint
#   caps      body inset 0.04 under a full-tile cornice band 0.68..0.75, pyramid caps on the merlons
# Chamfers (flat, one segment, 0.05): merlon top edges and merlon vertical corner edges. Never an edge in a tile
# boundary plane (x or y = +-0.5), never an edge on the ground, never a concave edge.
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

BODY_H = 0.75
DECK_H = 0.02
MERLON_TOP = 1.0
SPANS = ((-0.375, -0.125), (0.125, 0.375))
CHAMFER = 0.05
EDGE = 0.5
OUT = 0.6  # a cutter starts here, outside the tile, so no cutter face is coplanar with a block face
EPS = 1e-4


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


# ------------------------------------------------------------------ bodies, from z0 to z0 + BODY_H
def body_plain(z0):
    return box("wall", -EDGE, EDGE, -EDGE, EDGE, z0, z0 + BODY_H)


def body_arch(z0):
    wall = body_plain(z0)
    outline = arch_outline(0.25, z0 + 0.12, z0 + 0.36)
    boolean(wall, four(lambda: prism("c", outline, -OUT, -EDGE + 0.07, axis="y")), "DIFFERENCE")
    return wall


def body_corbel(z0):
    inset = 0.07
    wall = box("wall", -EDGE, EDGE, -EDGE, EDGE, z0, z0 + 0.08)
    parts = [box("p", -EDGE + inset, EDGE - inset, -EDGE + inset, EDGE - inset, z0 + 0.06, z0 + 0.57),
             box("p", -EDGE, EDGE, -EDGE, EDGE, z0 + 0.55, z0 + BODY_H)]
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
    core = box("wall", -EDGE + d + 0.005, EDGE - d - 0.005, -EDGE + d + 0.005, EDGE - d - 0.005, z0, z0 + BODY_H)
    e, n = EDGE, EDGE - d
    plus = [(-n, -e), (n, -e), (n, -n), (e, -n), (e, n), (n, n), (n, e), (-n, e), (-n, n), (-e, n), (-e, -n), (-n, -n)]
    parts = [prism("p", plus, z0 + za, z0 + zb) for za, zb in ((0.0, 0.25 - j), (0.50 + j, BODY_H))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("p", min(sx * j, sx * e), max(sx * j, sx * e), min(sy * j, sy * e), max(sy * j, sy * e),
                             z0 + 0.25 + j, z0 + 0.50 - j))
    boolean(core, parts, "UNION")
    return core


def body_caps(z0):
    inset = 0.04
    wall = box("wall", -EDGE + inset, EDGE - inset, -EDGE + inset, EDGE - inset, z0, z0 + 0.70)
    boolean(wall, [box("p", -EDGE, EDGE, -EDGE, EDGE, z0 + 0.68, z0 + BODY_H)], "UNION")
    return wall


BODIES = {"plain": body_plain, "arch": body_arch, "corbel": body_corbel, "pilaster": body_pilaster,
          "course": body_course, "caps": body_caps}


# ------------------------------------------------------------------ deck and merlons
def merlons(z_from, z_to, pyramid):
    bm = bmesh.new()
    for x0, x1 in SPANS:
        for y0, y1 in SPANS:
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
    vertical = lambda e: abs(e.verts[0].co.x - e.verts[1].co.x) < EPS and abs(e.verts[0].co.y - e.verts[1].co.y) < EPS
    flat_top = lambda e: all(abs(v.co.z - z_to) < EPS for v in e.verts)
    edges = [e for e in bm.edges if vertical(e) and e.calc_length() > 0.1]
    if not pyramid:
        edges += [e for e in bm.edges if flat_top(e)]
    bmesh.ops.bevel(bm, geom=edges, offset=CHAMFER, offset_type="OFFSET", segments=1, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object("merlons", bm)


def build(asset):
    z0 = BODY_H if asset.get("level") == "upper" else 0.0
    style = asset.get("style", "plain")
    wall = BODIES[style](z0)
    clean(wall)
    body_top = z0 + BODY_H
    box("deck", -EDGE, EDGE, -EDGE, EDGE, body_top, body_top + DECK_H)
    merlons(body_top + DECK_H, z0 + MERLON_TOP, style == "caps")
