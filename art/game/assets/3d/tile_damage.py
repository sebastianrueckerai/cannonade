# The three damage stages of the ground (I73), both families: the paving slab of tile_mud with craters
# pressed into its top face and a blast texture painted in step with them. The enclosed family
# (tile_mud_d1..d3) cracks the stamped paving, the nature family (tile_dirt_d1..d3) churns open ground;
# both stay near-white so the game's per-tile colour keeps multiplying on top, and the slab's border
# stays at full height, so slabs of different stages meet without a seam. The first hit already leaves
# a crater deep enough to read as mesh, the stages deepen and spread it. Written for the Blender behind
# blx; GAME_REPO points at the game repo:
#   { echo 'import os; os.environ["GAME_REPO"] = "<repo>"'; cat art/game/assets/3d/tile_damage.py; } | blx -
import json
import math
import os
import random
import sys
from pathlib import Path

import bmesh
import bpy

ROOT = Path(os.environ.get("GAME_REPO", "/home/womb/repos/grid-cannons"))
sys.path.insert(0, str(ROOT / "art/pipeline"))
for m in [k for k in sys.modules if k == "blender" or k.startswith("blender.") or k == "paint"]:
    del sys.modules[m]   # the daemon keeps modules of whichever repo imported them last
from blender import paint  # noqa: E402

GRID = 14          # cuts per side of the top face; the facets of a dent catch the light
BORDER = 0.42      # craters stay inside this radius, so the slab border never dips
TEX = paint.W

# per family and stage: crater count, radius and depth in metres, texture seed
STAGES = {
    ("mud", 1): dict(craters=1, r=(0.13, 0.17), depth=(0.040, 0.050), seed=81),
    ("mud", 2): dict(craters=3, r=(0.13, 0.19), depth=(0.055, 0.070), seed=82),
    ("mud", 3): dict(craters=5, r=(0.14, 0.22), depth=(0.070, 0.085), seed=83),
    ("dirt", 1): dict(craters=1, r=(0.16, 0.20), depth=(0.050, 0.060), seed=91),
    ("dirt", 2): dict(craters=2, r=(0.19, 0.25), depth=(0.065, 0.080), seed=92),
    ("dirt", 3): dict(craters=3, r=(0.22, 0.30), depth=(0.080, 0.095), seed=93),
}
# the deeper stages darken past the painter kind: more cracks on the paving, wider char on open ground
OVER = {
    ("mud", 1): {},
    ("mud", 2): {"cracks": (10, (20, 44), (1.5, 3.5), -75)},
    ("mud", 3): {"cracks": (14, (22, 48), (2.0, 4.0), -80)},
    ("dirt", 1): {},
    ("dirt", 2): {"patches": [(7, (22, 40), (0.3, 0.5), (-50, -28))]},
    ("dirt", 3): {"patches": [(9, (26, 48), (0.4, 0.65), (-60, -32))]},
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


def dabs_at(craters, family):
    """The scorch of each crater in texture pixels, on the top-planar UV (u = x + 0.5), plus the ejecta
    flecks thrown out of a dirt crater."""
    out = []
    for cx, cy, r, _ in craters:
        px, py = int(round((cx + 0.5) * TEX)), int(round((cy + 0.5) * TEX))
        out.append((px, py, int(r * TEX * 1.35), 0.9, -80))
        if family == "dirt":
            rnd = random.Random(int(px * 131 + py))
            for _ in range(8):
                ang = rnd.random() * 2 * math.pi
                dist = r * rnd.uniform(1.1, 1.7)
                out.append((int(round((cx + math.cos(ang) * dist + 0.5) * TEX)),
                            int(round((cy + math.sin(ang) * dist + 0.5) * TEX)),
                            rnd.uniform(2.5, 5.0), 0.8, -50))
    return out


result = {}
me = base_mesh()
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
    paint.painted_material(ob, {"kind": f"{family}_hit", "seed": spec["seed"], "top_planar": True,
                                "over": {**OVER[(family, stage)], "dabs_at": dabs_at(craters, family)}})
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
