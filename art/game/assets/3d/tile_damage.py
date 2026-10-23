# The three damage stages of the ground (I73), both families: the paving slab of tile_mud with craters
# pressed into its top face. The enclosed family
# (tile_mud_d1..d3) cracks the stamped paving, the nature family (tile_dirt_d1..d3) churns open ground;
# both stay near-white so the game's per-tile colour keeps multiplying on top, and the slab's border
# stays at full height, so slabs of different stages meet without a seam. The first hit already leaves
# a crater deep enough to read as mesh, the stages deepen and spread it. C22 makes the material the
# flat white carrier the Map tints - the crater mesh alone reads the damage, no blast texture. Written
# for the Blender behind blx; GAME_REPO points at the game repo:
#   { echo 'import os; os.environ["GAME_REPO"] = "<repo>"'; cat art/game/assets/3d/tile_damage.py; } | blx -
import json
import math
import os
import random
from pathlib import Path

import bmesh
import bpy

ROOT = Path(os.environ.get("GAME_REPO", "/home/womb/repos/grid-cannons"))

GRID = 14          # cuts per side of the top face; the facets of a dent catch the light
BORDER = 0.42      # craters stay inside this radius, so the slab border never dips

# per family and stage: crater count, radius and depth in metres, texture seed
STAGES = {
    ("mud", 1): dict(craters=1, r=(0.13, 0.17), depth=(0.040, 0.050), seed=81),
    ("mud", 2): dict(craters=3, r=(0.13, 0.19), depth=(0.055, 0.070), seed=82),
    ("mud", 3): dict(craters=5, r=(0.14, 0.22), depth=(0.070, 0.085), seed=83),
    ("dirt", 1): dict(craters=1, r=(0.16, 0.20), depth=(0.050, 0.060), seed=91),
    ("dirt", 2): dict(craters=2, r=(0.19, 0.25), depth=(0.065, 0.080), seed=92),
    ("dirt", 3): dict(craters=3, r=(0.22, 0.30), depth=(0.080, 0.095), seed=93),
}

def craters_of(spec, seed):
    """The crater layout of one slab: (x, y, r, depth) in metres, kept clear of the border."""
    rnd = random.Random(seed * 100 + 7)
    out = []
    for _ in range(spec["craters"]):
        r = rnd.uniform(*spec["r"])
        reach = BORDER - r
        ang = rnd.random() * 2 * math.pi
        out.append((math.cos(ang) * reach * rnd.random(), math.sin(ang) * reach * rnd.random(),
                    r, rnd.uniform(*spec["depth"])))
    return out


def dent(craters, x, y):
    d = 0.0
    for cx, cy, r, depth in craters:
        dist = math.hypot(x - cx, y - cy)
        if dist < r:
            d += depth * 0.5 * (1.0 + math.cos(math.pi * dist / r))
    return min(d, 0.10)   # overlapping craters must not pit through the slab


bpy.ops.wm.read_homefile(use_empty=True)


def base_mesh():
    """The paving slab of ../tile/build.py with its top face gridded, built fresh: the imported glb comes
    vertex-split, and craters need shared verts to dent without cracks."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.z = 0.2 if v.co.z > 0 else 0.0
    top = [e for e in bm.edges if all(v.co.z > 0.1 for v in e.verts)]
    bmesh.ops.bevel(bm, geom=top, offset=0.05, offset_type="OFFSET", segments=1, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    face = [f for f in bm.faces if f.normal.z > 0.9 and all(v.co.z > 0.19 for v in f.verts)][0]
    bmesh.ops.subdivide_edges(bm, edges=list(face.edges), cuts=GRID, use_grid_fill=True)
    me = bpy.data.meshes.new("tile_damage_base")
    bm.to_mesh(me)
    bm.free()
    return me



result = {}
me = base_mesh()
white = bpy.data.materials.get("#ffffff") or bpy.data.materials.new("#ffffff")
white.use_nodes = True
b = white.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
b.inputs["Roughness"].default_value = 1.0
for (family, stage), spec in STAGES.items():
    craters = craters_of(spec, spec["seed"])
    bm = bmesh.new()
    bm.from_mesh(me)
    for v in bm.verts:
        if v.co.z > 0.19:
            v.co.z -= dent(craters, v.co.x, v.co.y)
    mid = bpy.data.meshes.new(f"tile_{family}_d{stage}")
    bm.to_mesh(mid)
    bm.free()
    ob = bpy.data.objects.new(mid.name, mid)
    bpy.context.scene.collection.objects.link(ob)
    mid.materials.append(white)
    zs = [v.co.z for v in mid.vertices if v.co.z > 0.0]
    mid.calc_loop_triangles()
    tris = len(mid.loop_triangles)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    glb = ROOT / "assets/art/3d" / f"{mid.name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    result[mid.name] = {"tris": tris, "verts": len(mid.vertices),
                        "min_top_z": round(min(zs), 4), "craters": [[round(c, 3) for c in cr] for cr in craters],
                        "seed": spec["seed"], "bytes": os.path.getsize(glb)}

sidecar = ROOT / "art/game/assets/3d/tile_damage.json"
sidecar.write_text(json.dumps({"route": "procedural", "source": "tile/build.py slab geometry via tile_damage.py",
                               "grid_cuts": GRID, "stages": result}, indent=1))
print(json.dumps(result, indent=1))
