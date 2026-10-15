# Shared build for wall_<shape>_<level>: slab (or storey body), a cornice band projecting beyond both faces,
# square merlons on the band. Origin = tile centre on the ground, arms run to the tile edges (+-0.5), flush there.
#
# Merlons (period 0.5 m, none ever crosses a tile seam): 0.25 wide at [0.125, 0.375] along every arm, so the seam
# falls in the middle of a 0.25 gap. Junction pieces (curve, tri, cross) add a merlon over the junction square that
# merges with the arm merlons into one corner post; a line has a gap at its centre.
#
# Chamfers (flat, one segment, one set for every piece so neighbours match). Triangles on the cross, the worst piece:
# none 144, band top 168, merlon tops 168, verticals 176, merlon tops + verticals 200,
# band top + merlon tops 192, all three 224. Priority order: merlon tops, vertical corners, band top; the first two
# fit, the third does not.
#   merlon_top: the top edges of every merlon, 0.05
#   verticals: the outer vertical corner edges of the slab / storey body and the merlons, 0.05
#   band_top (0.03, the band's outer top edges) is implemented but off.
# Never chamfered: edges lying in a tile boundary plane (x or y = +-0.5, so neighbours join square), edges on the
# ground, the bottom of the upper body, concave edges, the band's own 0.10 tall corners.
import bmesh
import bpy

T = 0.30
BAND_OUT = 0.04
SLAB_TOP = 0.65
BAND_H = 0.10
MERLON_H = 0.25
MERLON_FROM, MERLON_TO = 0.125, 0.375
UPPER_BODY_BOTTOM = 0.75
UPPER_BODY_PROUD = 0.005
BAND_CHAMFER = 0.03
CHAMFER = 0.05
EDGE = 0.5
ARMS = {
    "line": [(1, 0), (-1, 0)],
    "curve": [(1, 0), (0, 1)],
    "tri": [(0, 1), (0, -1), (1, 0)],
    "cross": [(1, 0), (-1, 0), (0, 1), (0, -1)],
}
EPS = 1e-4
CHAMFERS = ("merlon_top", "verticals")


def box(name, x0, x1, y0, y1, z0, z1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = x1 if v.co.x > 0 else x0
        v.co.y = y1 if v.co.y > 0 else y0
        v.co.z = z1 if v.co.z > 0 else z0
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def arm_box(name, d, h, z0, z1, a0=None, a1=EDGE, half=None):
    """Box along arm direction d, from a0 (default behind the centre by h) to a1, `half` either side."""
    a0 = -h if a0 is None else a0
    half = h if half is None else half
    if d[0]:
        return box(name, *sorted((a0 * d[0], a1 * d[0])), -half, half, z0, z1)
    return box(name, -half, half, *sorted((a0 * d[1], a1 * d[1])), z0, z1)


def union(base, others):
    for o in others:
        m = base.modifiers.new("u", "BOOLEAN")
        m.operation, m.solver, m.object = "UNION", "EXACT", o
        bpy.context.view_layer.objects.active = base
        bpy.ops.object.modifier_apply(modifier=m.name)
        bpy.data.objects.remove(o, do_unlink=True)


def select(bm, pred):
    return [e for e in bm.edges if len(e.link_faces) == 2 and pred(e) and e.calc_face_angle_signed() > 0.1]


def on_boundary(e):
    return any(all(abs(abs(v.co[i]) - EDGE) < EPS for v in e.verts) for i in (0, 1))


def build(asset):
    shape, level = asset["shape"], asset["level"]
    arms = ARMS[shape]
    upper = level == "upper"
    half = T / 2
    band_half = half + BAND_OUT
    if upper:
        body = (UPPER_BODY_BOTTOM, UPPER_BODY_BOTTOM + 0.90)
        body_half = half + UPPER_BODY_PROUD
    else:
        body = (0.0, SLAB_TOP)
        body_half = half
    band = (body[1], body[1] + BAND_H)
    top = band[1] + MERLON_H

    parts = [box("wall", -body_half, body_half, -body_half, body_half, *body)]
    parts += [arm_box("a", d, body_half, *body) for d in arms]
    parts += [arm_box("b", d, band_half, *band) for d in arms]
    parts.append(box("b", -band_half, band_half, -band_half, band_half, *band))
    if shape != "line":
        parts.append(box("m", -half, half, -half, half, band[1], top))
    parts += [arm_box("m", d, half, band[1], top, a0=MERLON_FROM, a1=MERLON_TO) for d in arms]
    base = parts[0]
    union(base, parts[1:])

    bm = bmesh.new()
    bm.from_mesh(base.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=1e-3, verts=bm.verts, edges=bm.edges)
    z = lambda e: [v.co.z for v in e.verts]
    flat_at = lambda h: lambda e: all(abs(c - h) < EPS for c in z(e))
    vertical = lambda e: abs(e.verts[0].co.x - e.verts[1].co.x) < EPS and abs(e.verts[0].co.y - e.verts[1].co.y) < EPS

    if "band_top" in CHAMFERS:
        edges = select(bm, lambda e: flat_at(band[1])(e) and not on_boundary(e))
        bmesh.ops.bevel(bm, geom=edges, offset=BAND_CHAMFER, offset_type="OFFSET", segments=1, affect="EDGES")
        bm.edges.ensure_lookup_table()
    edges = []
    if "merlon_top" in CHAMFERS:
        edges += select(bm, lambda e: flat_at(top)(e) and not on_boundary(e))
    if "verticals" in CHAMFERS:
        edges += select(bm, lambda e: vertical(e) and e.calc_length() > 0.2 and not on_boundary(e))
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=CHAMFER, offset_type="OFFSET", segments=1, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(base.data)
    bm.free()
