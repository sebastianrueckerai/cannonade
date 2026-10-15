# Sent to Blender by pipeline/asset.py with ASSET_DIR, PIPELINE_DIR, ASSET and CONTRACT prepended.
import importlib
import sys
import time

import bpy

if PIPELINE_DIR not in sys.path:
    sys.path.insert(0, PIPELINE_DIR)
from blender import export, geo, materials, normalise, paint, render, report  # noqa: E402

for m in (geo, normalise, paint, materials, report, render, export):
    importlib.reload(m)

steps = []


def step(name, fn):
    t = time.time()
    out = fn()
    steps.append({"name": name, "ok": True, "elapsed_s": round(time.time() - t, 2), "out": out})
    return out


bpy.ops.wm.read_homefile(use_empty=True)
procedural = ASSET["route"] == "procedural"
if procedural:
    path = ASSET_DIR + "/" + ASSET.get("build", "build.py")
    ns = {"__name__": "build"}
    exec(compile(open(path).read(), path, "exec"), ns)
    step("build", lambda: ns["build"](ASSET))
    step("normalise", lambda: normalise.run(ASSET, ASSET_DIR))
    step("materials", lambda: materials.run(ASSET, PIPELINE_DIR))
else:
    step("import", lambda: bpy.ops.import_scene.gltf(filepath=ASSET_DIR + "/final.glb") and {"glb": "final.glb"})
rep = step("report", lambda: report.run(ASSET, ASSET_DIR))
step("render", lambda: render.run(ASSET, ASSET_DIR, CONTRACT))
if procedural:
    step("export", lambda: export.run(ASSET, ASSET_DIR))
result = {"steps": steps, "report": rep}
