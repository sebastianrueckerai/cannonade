# The rubble of the models that crumble in the game (I62, I69): every mesh part of a model cut into Voronoi pieces,
# each piece a mesh of its own with its origin at its centre, under an empty named like the part at the part's
# transform, so the game can place the pieces where the part stands when it dies (scripts/Crumble.gd) and make a
# rigid body of each. The cuts keep the part's UV layers: the outer faces keep their paint (and the wall's region
# ids), the cut faces get a box projection and region 0. No materials: the game gives the pieces the part's. A gun's
# plate stays out. Written for the Blender behind blx; GAME_REPO points at the game repo:
#   { echo 'import os; os.environ["GAME_REPO"] = "<repo>"'; cat art/game/assets/3d/fracture.py; } | blx -
import os
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(os.environ.get("GAME_REPO", "/home/womb/repos/grid-cannons"))
## model id: pieces, shared among its parts by bounding-box volume, at least 3 a part
MODELS = {"wall": 16, "wall_upper": 14, "cannon": 12, "cannon22a": 18, "cannon22b": 18, "flak22": 12, "castle_d3": 36,
          "castle_d3.2": 36, "castle_d3.3": 36, "castle_d3.4": 36, "castle_d3.5": 36, "castle_d3.6": 36,
          "castle_d3.7": 36, "castle_d3.8": 36,
          "nature_leaf_tree": 8, "nature_leaf_tree.2": 8, "nature_leaf_tree.3": 8, "nature_bush": 5, "nature_bush.2": 5,
          "nature_bush.3": 5, "nature_boulder": 6, "nature_boulder.2": 6, "nature_boulder.3": 6}
SKIP = {"plate"}
PAD = 0.2
UV_SCALE = 0.75


def load(glb):
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name not in SKIP]


def cell(i, pts, lo, hi):
    """The Voronoi cell of pts[i]: a box round the part, cut by the plane halfway to every other point."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector([(hi[k] + PAD) if v.co[k] > 0 else (lo[k] - PAD) for k in range(3)])
    for j, q in enumerate(pts):
        if j == i:
            continue
        ret = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(pts[i] + q) / 2,
                                     plane_no=(q - pts[i]).normalized(), clear_outer=True)
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
            loop[uv].uv = (0.125 + (loop.vert.co[a] % 1.0) * UV_SCALE, loop.vert.co[b] % 1.0)
            loop[reg].uv = (0.0, 0.0)
    me = bpy.data.meshes.new(f"cell_{i}")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(f"cell_{i}", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def fracture(part, n, rnd):
    """`part` cut into n pieces in its own frame, under an empty of its name at its transform. Returns the empty and
    the count of pieces; a cell that meets no geometry gives none."""
    name = part.name
    part.name = name + "_src"
    holder = bpy.data.objects.new(name, None)
    holder.matrix_world = part.matrix_world.copy()
    bpy.context.scene.collection.objects.link(holder)
    lo = Vector(part.bound_box[0])
    hi = Vector(part.bound_box[6])
    if len(part.data.uv_layers) < 2:
        part.data.uv_layers.new(name="UVMap.001")
    pts = [Vector([rnd.uniform(lo[k], hi[k]) for k in range(3)]) for _ in range(n)]
    made = 0
    for i in range(n):
        cutter = cell(i, pts, lo, hi)
        piece = part.copy()
        piece.data = part.data.copy()
        piece.name = piece.data.name = f"{name}_{i:02d}"
        piece.matrix_world = Matrix.Identity(4)
        bpy.context.scene.collection.objects.link(piece)
        mod = piece.modifiers.new("cut", "BOOLEAN")
        mod.operation = "INTERSECT"
        mod.solver = "EXACT"
        mod.use_hole_tolerant = True
        mod.object = cutter
        with bpy.context.temp_override(object=piece, active_object=piece, selected_objects=[piece]):
            bpy.ops.object.modifier_apply(modifier="cut")
        bpy.data.objects.remove(cutter, do_unlink=True)
        if len(piece.data.polygons) < 4:
            bpy.data.objects.remove(piece, do_unlink=True)
            continue
        centre = sum((Vector(c) for c in piece.bound_box), Vector()) / 8.0
        piece.data.transform(Matrix.Translation(-centre))
        piece.parent = holder
        piece.matrix_parent_inverse = Matrix.Identity(4)
        piece.location = centre
        made += 1
    bpy.data.objects.remove(part, do_unlink=True)
    return holder, made


def build(model_id, n):
    parts = load(ROOT / "art/game/assets/3d" / model_id / "final.glb")
    rnd = random.Random(sum(map(ord, model_id)))
    vols = {p.name: max(p.dimensions.x * p.dimensions.y * p.dimensions.z, 1e-6) for p in parts}
    total = sum(vols.values())
    holders = []
    report = {}
    for p in parts:
        holder, made = fracture(p, max(3, round(n * vols[p.name] / total)), rnd)
        holders.append(holder)
        report[holder.name] = made
    bpy.ops.object.select_all(action="DESELECT")
    for h in holders:
        h.select_set(True)
        for c in h.children:
            c.select_set(True)
    bpy.context.view_layer.objects.active = holders[0]
    glb = ROOT / "assets/art/3d" / f"{model_id}_rubble.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="NONE")
    tris = sum(len(c.data.polygons) for h in holders for c in h.children)
    return {"parts": report, "tris": tris, "kb": os.path.getsize(glb) // 1024}


result = {m: build(m, n) for m, n in MODELS.items()}
