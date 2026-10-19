# Shared build for wall (level base) and wall_upper (level upper): a full-tile block, x and y -0.5..0.5, so two
# blocks sharing a side join flush; blocks touching only at a corner pinch there. Origin = tile centre on the ground.
#   base:  body z 0..0.75, merlons z 0.75..1.0
#   upper: body z 0.75..1.5 (sits on the lower block's top, swallowing its merlons), merlons z 1.5..1.75
# Merlons: 2 x 2 per tile, 0.25 x 0.25, at [0.125, 0.375] and [-0.375, -0.125] on x and y (0.5 m period), so a tile
# seam falls in the middle of a 0.25 gap and neighbours continue the grid.
# Chamfers (flat, one segment, 0.05): merlon top edges and merlon vertical corner edges. Never an edge in a tile
# boundary plane (x or y = +-0.5), never an edge on the ground, never a concave edge.
import bmesh
import bpy

BODY_H = 0.75
MERLON_H = 0.25
SPANS = ((-0.375, -0.125), (0.125, 0.375))
CHAMFER = 0.05
EDGE = 0.5
EPS = 1e-4


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
    upper = asset["level"] == "upper"
    z0 = BODY_H if upper else 0.0
    body_top = z0 + BODY_H
    top = body_top + MERLON_H

    base = box("wall", -EDGE, EDGE, -EDGE, EDGE, z0, body_top)
    union(base, [box("m", x0, x1, y0, y1, body_top, top) for x0, x1 in SPANS for y0, y1 in SPANS])

    bm = bmesh.new()
    bm.from_mesh(base.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=1e-3, verts=bm.verts, edges=bm.edges)
    flat_top = lambda e: all(abs(v.co.z - top) < EPS for v in e.verts)
    vertical = lambda e: abs(e.verts[0].co.x - e.verts[1].co.x) < EPS and abs(e.verts[0].co.y - e.verts[1].co.y) < EPS
    edges = select(bm, lambda e: flat_top(e) and not on_boundary(e))
    edges += select(bm, lambda e: vertical(e) and e.calc_length() > 0.2 and not on_boundary(e))
    bmesh.ops.bevel(bm, geom=edges, offset=CHAMFER, offset_type="OFFSET", segments=1, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(base.data)
    bm.free()
