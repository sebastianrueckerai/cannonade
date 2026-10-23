#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""One Blender file holds every asset (C22): game/assets/3d/kit.blend, one collection an asset, its
objects named <asset_id>.<part>, one material a part named for its palette role. Tune meshes and face
assignments in Blender there, then ship to the game:

    pipeline/kit.py build            the first fold: every asset's source.blend appended in, the flag
                                     authored, the keepers' castle states docked for it, the materials
                                     unified by name (a palette role keeps its palette colour)
    pipeline/kit.py add <id>...      a pipeline step rebuilt an asset: replace its collection from the
                                     fresh source.blend (a keeper castle state gets its dock re-drawn)
    pipeline/kit.py export [id]...   ship collections to the game: glb + .import + manifest entry,
                                     budgets re-checked from asset.yaml, the rubble of every shipped
                                     crumbling model re-cut; default: every approved asset plus the
                                     flag; --force ships unapproved ones too

    pipeline/kit.py sharpen          the sharp pass on the tuned kit: every collection except the
                                     organic trees and bushes goes smooth shaded with edges over
                                     35 deg marked sharp (build and add run it on what they fold)

The game repo comes from game_repo in game/art-direction/gameplay_contract.yaml, GAME_REPO overrides
it. Replaces godot_sync.py: after the fold kit.blend is the one source, the pipeline steps end at
`kit.py add`."""
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
A3 = ROOT / "game" / "assets" / "3d"
KIT = A3 / "kit.blend"
FRACTURE = A3 / "fracture.py"
CONTRACT = yaml.safe_load((ROOT / "game" / "art-direction" / "gameplay_contract.yaml").read_text())
GAME = Path(os.environ.get("GAME_REPO") or CONTRACT["game_repo"])
ART = GAME / "assets" / "art"
BLENDER = shutil.which("blender") or str(Path.home() / "Applications/blender-5.2.2-linux-x64/blender")
KEEPERS = ("", ".3", ".6")   # the castle looks in the game (D93)
DOCK_STATES = ("castle", "castle_d1", "castle_d2", "castle_d3")
ORGANIC = ("nature_leaf_tree", "nature_bush")   # collections the sharp pass leaves untouched

IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[params]

gltf/embedded_image_handling=3
"""

BUILD = r'''
import json, re
from pathlib import Path
import bmesh, bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

A3 = Path(%r)
KIT_PATH = %r
KEEPERS = %r
DOCK_STATES = %r
INF = float("inf")

bpy.ops.wm.read_homefile(use_empty=True)
kit = bpy.data.collections.new("kit")
bpy.context.scene.collection.children.link(kit)


def fold(aid):
    # every object of the asset's source.blend, its name prefixed with the asset id: the kit file's
    # object names are unique, the prefix goes away again at export so the game sees the pipeline's
    col = bpy.data.collections.new(aid)
    kit.children.link(col)
    with bpy.data.libraries.load(str(A3 / aid / "source.blend"), link=False) as (df, dt):
        dt.objects = df.objects
    n = 0
    for ob in dt.objects:
        if ob is None:
            continue
        col.objects.link(ob)
        ob.name = f"{aid}.{ob.name}"
        n += 1
    return n


def palette():
    pal = json.loads((A3.parents[1] / "art-direction" / "palette.json").read_text())["world"]
    def lin(hexs):
        c = [int(hexs.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return pal, lin


def unify():
    # one material a name across the whole kit; a palette role keeps exactly its palette colour, so a
    # part retuned to another hue in one model does not pull its siblings' shared name off palette
    pal, lin = palette()
    def rgb_of(m):
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                return list(n.inputs["Base Color"].default_value)[:3]
        return None
    groups = {}
    for m in bpy.data.materials:
        if m.use_nodes:
            groups.setdefault(re.sub(r"\.\d{3}$", "", m.name), []).append(m)
    merged = 0
    for name, ms in sorted(groups.items()):
        keep = ms[0]
        if name in pal:
            want = lin(pal[name])
            keep = next((m for m in ms if rgb_of(m) and all(abs(a - b) < 0.004 for a, b in zip(rgb_of(m), want))), ms[0])
            keep.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*want, 1.0)
            keep.diffuse_color = (*want, 1)
        for m in ms:
            if m is keep:
                continue
            for me in bpy.data.meshes:
                for i, mm in enumerate(me.materials):
                    if mm == m:
                        me.materials[i] = keep
            bpy.data.materials.remove(m)
            merged += 1
        if keep.name != name:   # the keep came in as a suffixed duplicate; take the plain name
            keep.name = name
    return merged


def make_flag():
    # the castle flag (I115): a pole and a cloth that waves in flag.gdshader, both on `team`, the
    # slot the game repaints per player. UV.x runs 0 at the pole to 1 at the fly end
    pal, lin = palette()
    col = bpy.data.collections.new("flag")
    kit.children.link(col)
    team = bpy.data.materials.get("team") or bpy.data.materials.new("team")
    if team.node_tree is None:
        team.use_nodes = True
        b = team.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*lin("#9c7a4f"), 1.0)  # Castle.NEUTRAL_COLOR
        b.inputs["Roughness"].default_value = 1.0
    pole_me = bpy.data.meshes.new("flag.pole")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=8, radius1=0.018, radius2=0.012, depth=1.05)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0.0, 0.0, 1.05 / 2.0)))
    bm.to_mesh(pole_me)
    bm.free()
    pole = bpy.data.objects.new("flag.pole", pole_me)
    pole_me.materials.append(team)
    col.objects.link(pole)
    cloth_me = bpy.data.meshes.new("flag_cloth")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=8, y_segments=5, size=0.5)   # size is the half-extent
    for v in bm.verts:
        v.co.x = (v.co.x + 0.5) * 0.52   # x: 0 at the pole, 0.52 the fly end
        z = (v.co.y + 0.5) * 0.30
        v.co.y = 0.0
        v.co.z = 0.72 + z                # the cloth hangs from 0.72 up to the pole top
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        for l in f.loops:
            l[uv].uv = (l.vert.co.x / 0.52, (l.vert.co.z - 0.72) / 0.30)
    bm.to_mesh(cloth_me)
    bm.free()
    cloth = bpy.data.objects.new("flag.flag_cloth", cloth_me)
    cloth_me.materials.append(team)
    col.objects.link(cloth)


def surface_z(obs, x, y):
    best = -INF
    for o in obs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        tree = BVHTree.FromBMesh(bm)
        hit = tree.ray_cast(Vector((x, y, 1e3)), Vector((0.0, 0.0, -1.0)))
        bm.free()
        if hit[0] is not None and hit[0].z > best:
            best = hit[0].z
    return best


def docks(states=None):
    # a flag_dock empty on every keeper castle state: x/y the centroid of the severe ruin's top
    # vertices (the surviving keep), z each state's own surface, so the flag rides lower every hit
    made = 0
    for look in KEEPERS:
        d3 = bpy.data.collections.get("castle_d3" + look)
        if d3 is None:
            continue
        tops = [(o.matrix_world @ v.co).copy() for o in d3.objects if o.type == "MESH" for v in o.data.vertices]
        if not tops:
            continue
        hi = max(v.z for v in tops)
        lo = min(v.z for v in tops)
        near = [v for v in tops if v.z >= hi - 0.08 * (hi - lo)]
        x = sum(v.x for v in near) / len(near)
        y = sum(v.y for v in near) / len(near)
        for st in DOCK_STATES if states is None else states:
            col = bpy.data.collections.get(st + look)
            if col is None or any(o.name.endswith(".flag_dock") for o in col.objects):
                continue
            z = surface_z([o for o in col.objects if o.type == "MESH"], x, y)
            e = bpy.data.objects.new(f"{st + look}.flag_dock", None)
            e.empty_display_type = "PLAIN_AXES"
            e.location = (x, y, z + 0.01)
            col.objects.link(e)
            made += 1
    return made


if %r:  # build: fold every asset; add: just the given ones into the existing kit
    ids = [d.name for d in sorted(A3.iterdir()) if (d / "source.blend").is_file()]
    counts = {aid: fold(aid) for aid in ids}
    merged = unify()
    make_flag()
    docked = docks()
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(KIT_PATH), compress=True)
    print("KIT_BUILD " + json.dumps({"assets": len(ids), "objects": sum(counts.values()), "merged": merged, "docks": docked}))
else:
    bpy.ops.wm.read_homefile(filepath=str(KIT_PATH))
    kit = bpy.data.collections.get("kit")
    states = []
    for aid in %r:
        col = bpy.data.collections.get(aid)
        if col is not None:
            for ob in list(col.objects):
                bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.collections.remove(col)
        if aid == "flag":
            make_flag()   # the flag is authored in the kit, it has no source.blend
        else:
            fold(aid)
        if re.match(r"castle(_d[0-3])?(\.[236])?$", aid):
            states.append(aid)
    merged = unify()
    docked = docks(states) if states else 0
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(KIT_PATH), compress=True)
    print("KIT_BUILD " + json.dumps({"assets": len(%r), "merged": merged, "docks": docked}))

'''

EXPORT = r'''
import json
from pathlib import Path
import bpy
from mathutils import Vector

KIT_PATH = Path(%r)
OUT = Path(%r)
PLAN = json.loads(%r)
INF = float("inf")
res = {}
for aid, meta in PLAN.items():
    bpy.ops.wm.read_homefile(use_empty=True)
    try:
        bpy.ops.wm.append(directory=str(KIT_PATH / "Collection"), filename=aid, link=False)
    except RuntimeError as e:
        res[aid] = {"error": str(e)[:200]}
        continue
    col = bpy.data.collections.get(aid)
    obs = []
    def walk(o):
        if o not in obs:
            obs.append(o)
            for c in o.children:
                walk(c)
    for o in list(col.objects):
        walk(o)
    for o in obs:  # the kit's asset prefix goes away: the game sees the pipeline's part names
        if o.name.startswith(aid + "."):
            o.name = o.name[len(aid) + 1:]
    meshes = [o for o in obs if o.type == "MESH"]
    lo, hi = Vector((INF,) * 3), Vector((-INF,) * 3)
    for o in meshes:  # the game sizes the imported AABB, which rotates each part's local box:
        vs = [v.co for v in o.data.vertices]  # a rotated part (the flak's raised guns) grows by its
        if not vs:  # box corners, so measure the box, not the verts, or the manifest under-reports
            continue
        blo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        bhi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        for x in (blo.x, bhi.x):
            for y in (blo.y, bhi.y):
                for z in (blo.z, bhi.z):
                    w = o.matrix_world @ Vector((x, y, z))
                    lo.x, lo.y, lo.z = min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)
                    hi.x, hi.y, hi.z = max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    mats = sorted({m.name for o in meshes for m in o.data.materials if m})
    fails = []
    if not meshes:
        fails.append("no meshes")
    if meta.get("max_tris") and tris > meta["max_tris"]:
        fails.append(f"tris {tris} > {meta['max_tris']}")
    if meta.get("max_materials") and len(mats) > meta["max_materials"]:
        fails.append(f"materials {len(mats)} ({', '.join(mats)}) > {meta['max_materials']}")
    if fails:
        res[aid] = {"limits": fails}
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    glb = OUT / (aid + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT")
    d = hi - lo
    res[aid] = {"size": [round(d.x, 4), round(d.z, 4), round(d.y, 4)],
                "parts": sorted(o.name for o in meshes), "tris": tris,
                "materials": mats, "bytes": glb.stat().st_size}
print("KIT_EXPORT " + json.dumps(res))

'''

SHARPEN = r'''
import json
from math import radians
import bmesh, bpy

KIT_PATH = %r
IDS = %r   # None: every collection; the add pass sends just its ids
ORGANIC = %r   # the organics stay untouched
LIMIT = radians(35.0)

bpy.ops.wm.read_homefile(filepath=str(KIT_PATH))
kit = bpy.data.collections.get("kit")
res = {"assets": 0, "meshes": 0, "flat": 0, "edges": 0}
for col in kit.children:
    if col.name.startswith(ORGANIC) or IDS is not None and col.name not in IDS:
        continue
    res["assets"] += 1
    for ob in col.objects:
        if ob.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        for f in bm.faces:
            if not f.smooth:
                f.smooth = True
                res["flat"] += 1
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle() > LIMIT:
                e.smooth = False   # the flag reads inverted: False marks the edge sharp
                res["edges"] += 1
        bm.to_mesh(ob.data)
        bm.free()
        res["meshes"] += 1
bpy.ops.wm.save_as_mainfile(filepath=str(KIT_PATH), compress=True)
print("KIT_SHARPEN " + json.dumps(res))

'''


def run_blender(script: str, timeout: int) -> dict:
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
        f.write(script)
        tmp = f.name
    try:
        p = subprocess.run([BLENDER, "--background", "--python", tmp],
                           capture_output=True, text=True, timeout=timeout)
    finally:
        os.unlink(tmp)
    for line in p.stdout.splitlines():
        if line.startswith("KIT_"):
            return json.loads(line.partition(" ")[2])
    tail = "\n".join((p.stdout + p.stderr).splitlines()[-25:])
    sys.exit(f"blender produced no KIT_ line:\n{tail}")


def cmd_build() -> None:
    if KIT.exists():
        sys.exit(f"{KIT.relative_to(ROOT)} exists: rebuild single assets with `kit.py add <id>`")
    run_blender(BUILD % (str(A3), str(KIT), KEEPERS, DOCK_STATES, True, [], []), 5400)
    res = run_blender(SHARPEN % (str(KIT), None, ORGANIC), 3600)
    print(f"folded the sources into {KIT.relative_to(ROOT)}, {res['edges']} edges over 35 deg sharp")


def cmd_add(ids: list[str]) -> None:
    for aid in ids:
        if aid != "flag" and not (A3 / aid / "source.blend").is_file():
            sys.exit(f"no source.blend for {aid}")
    run_blender(BUILD % (str(A3), str(KIT), KEEPERS, DOCK_STATES, False, ids, ids), 3600)
    res = run_blender(SHARPEN % (str(KIT), tuple(ids), ORGANIC), 3600)   # just the folded ids: hand-cleared marks on the rest survive
    print(f"replaced {' '.join(ids)} in {KIT.relative_to(ROOT)}, {res['edges']} edges over 35 deg sharp")


def cmd_sharpen() -> None:
    if not KIT.exists():
        sys.exit(f"no {KIT.relative_to(ROOT)} to sharpen")
    res = run_blender(SHARPEN % (str(KIT), None, ORGANIC), 3600)
    print(f"sharpened {res['assets']} assets: {res['edges']} edges over 35 deg sharp, "
          f"{res['flat']} flat faces smoothed")


def budget(aid: str) -> dict:
    y = yaml.safe_load((A3 / aid / "asset.yaml").read_text()) if (A3 / aid / "asset.yaml").is_file() else {}
    b = y.get("budget") or {}
    return {"max_tris": b.get("max_tris"), "max_materials": b.get("max_materials")}


def cmd_export(ids: list[str], force: bool) -> None:
    plan = {"flag": {"approved_by": "the flag round (I115)"}}
    for m in sorted(A3.glob("*/manifest.json")):
        man = json.loads(m.read_text())
        if man.get("parked"):
            continue
        if not man.get("approved") and not force:
            print(f"skip {man['asset_id']}: not approved")
            continue
        plan[man["asset_id"]] = {"approved_by": man.get("approved_by"), **budget(man["asset_id"])}
    if ids:
        keep = set(ids) | {"flag"}
        plan = {k: v for k, v in plan.items() if k in keep}
    data = run_blender(EXPORT % (str(KIT), str(ART / "3d"), json.dumps(plan)), 5400)
    mpath = ART / "manifest.json"
    gm = json.loads(mpath.read_text()) if mpath.exists() else {}
    bad = [f"{a}: {r}" for a, r in sorted(data.items()) if "limits" in r or "error" in r]
    shipped = []
    for aid, r in sorted(data.items()):
        if "limits" in r or "error" in r:
            continue
        glb = ART / "3d" / f"{aid}.glb"
        imp = glb.with_name(glb.name + ".import")
        if not imp.exists():
            imp.write_text(IMPORT)
        gm[aid] = {"size": r["size"], "tolerance": 0.02, "parts": r["parts"], "tris": r["tris"],
                   "source_sha": hashlib.sha256(glb.read_bytes()).hexdigest()[:12],
                   "approved_by": plan[aid].get("approved_by"),
                   "synced": dt.datetime.now().astimezone().isoformat(timespec="seconds")}
        shipped.append(f"{aid} size {r['size']} tris {r['tris']} mats {r['materials']}")
    mpath.write_text(json.dumps(dict(sorted(gm.items())), indent=2) + "\n")
    models = set(re.findall(r'"([^"]+)":\s*\d+', FRACTURE.read_text().partition("MODELS = ")[2].partition("}")[0]))
    rubbles = sorted(set(gm) & models)
    p = subprocess.run([BLENDER, "--background", "--python", str(FRACTURE)],
                       env={**os.environ, "GAME_REPO": str(GAME), "FRACTURE_MODELS": ",".join(rubbles)},
                       capture_output=True, text=True, timeout=5400)
    line = next((l for l in p.stdout.splitlines() if l.startswith("FRACTURE ")), "")
    if not line:
        sys.exit("fracture produced no FRACTURE line:\n" + "\n".join(p.stdout.splitlines()[-10:]))
    print("\n".join(shipped))
    print(f"{len(shipped)} shipped to {mpath.relative_to(GAME)}, rubble recut: {', '.join(sorted(json.loads(line[9:])))}")
    if bad:
        print("FAILED:\n" + "\n".join(bad))
        sys.exit(1)


def main() -> None:
    args = sys.argv[1:]
    force = "--force" in args
    args = [a for a in args if not a.startswith("--")]
    if args[:1] == ["build"]:
        cmd_build()
    elif args[:1] == ["add"]:
        cmd_add(args[1:] or sys.exit("kit.py add <id>..."))
    elif args[:1] == ["sharpen"]:
        cmd_sharpen()
    elif args[:1] == ["export"]:
        cmd_export(args[1:], force)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
