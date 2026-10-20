# The rubble of the plain wall block and of its storey for the crumble effect (I58): each model cut into Voronoi
# pieces, every piece a mesh of its own with its origin at its centre, so the game can make a rigid body of it.
# The cuts keep the block's UV layers: the outer faces their painted texture and region ids, the cut faces a box
# projection and region 0, the body stone. Written for the Blender behind blx; GAME_REPO points at the game repo:
#   { echo 'import os; os.environ["GAME_REPO"] = "<repo>"'; cat art/game/assets/3d/wall_fracture.py; } | blx -
import os
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(os.environ.get("GAME_REPO", "/home/womb/repos/grid-cannons"))
MODELS = {"wall": ("wall_rubble", 7, 16), "wall_upper": ("wall_rubble_upper", 8, 14)}
PAD = 0.2
UV_SCALE = 0.75  # the painted atlas spans u 0.125..0.875, v 0..1; a cut face shows three quarters of a metre of it


def load(glb):
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    return [o for o in bpy.context.scene.objects if o.type == "MESH"][0]


def cell(i, pts, lo, hi):
    """The Voronoi cell of pts[i]: a box round the block, cut by the plane halfway to every other point."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector([(hi[k] + PAD) if v.co[k] > 0 else (lo[k] - PAD) for k in range(3)])
    for j, q in enumerate(pts):
        if j == i:
            continue
        no = (q - pts[i]).normalized()
        ret = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(pts[i] + q) / 2,
                                     plane_no=no, clear_outer=True)
        cut = [e for e in ret["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut:
            bmesh.ops.holes_fill(bm, edges=cut)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv = bm.loops.layers.uv.new("UVMap")
    reg = bm.loops.layers.uv.new("UVMap.001")
    for f in bm.faces:
        n = [abs(c) for c in f.normal]
        a, b = [(1, 2), (0, 2), (0, 1)][n.index(max(n))]
        for loop in f.loops:
            loop[uv].uv = (0.125 + (loop.vert.co[a] % 1.0) * UV_SCALE, (loop.vert.co[b] % 1.0))
            loop[reg].uv = (0.0, 0.0)
    me = bpy.data.meshes.new(f"cell_{i}")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(f"cell_{i}", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def fracture(wall, seed, n):
    rnd = random.Random(seed)
    lo = Vector(wall.bound_box[0])
    hi = Vector(wall.bound_box[6])
    pts = [Vector([rnd.uniform(lo[k], hi[k]) for k in range(3)]) for _ in range(n)]
    pieces = []
    for i in range(n):
        cutter = cell(i, pts, lo, hi)
        piece = wall.copy()
        piece.data = wall.data.copy()
        piece.name = piece.data.name = f"piece_{i:02d}"
        bpy.context.scene.collection.objects.link(piece)
        mod = piece.modifiers.new("cut", "BOOLEAN")
        mod.operation = "INTERSECT"
        mod.solver = "EXACT"
        mod.object = cutter
        with bpy.context.temp_override(object=piece, active_object=piece, selected_objects=[piece]):
            bpy.ops.object.modifier_apply(modifier="cut")
        bpy.data.objects.remove(cutter, do_unlink=True)
        if len(piece.data.polygons) < 4:
            bpy.data.objects.remove(piece, do_unlink=True)
            continue
        centre = sum((Vector(c) for c in piece.bound_box), Vector()) / 8.0
        piece.data.transform(Matrix.Translation(-centre))
        piece.location = centre
        pieces.append(piece)
    bpy.data.objects.remove(wall, do_unlink=True)
    return pieces


def export(pieces, glb):
    bpy.ops.object.select_all(action="DESELECT")
    for p in pieces:
        p.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="NONE")


result = {}
for src, (out, seed, n) in MODELS.items():
    wall = load(ROOT / "art/game/assets/3d" / src / "final.glb")
    pieces = fracture(wall, seed, n)
    glb = ROOT / "assets/art/3d" / f"{out}.glb"
    export(pieces, glb)
    result[out] = {"pieces": len(pieces), "tris": sum(len(p.data.polygons) for p in pieces),
                   "bytes": os.path.getsize(glb)}
