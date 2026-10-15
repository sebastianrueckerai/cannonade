#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml", "pillow"]
# ///
"""Build one asset: run its route and every Blender step through blx, then write manifest.json. Run from the repo root.

    asset.py game/assets/3d/<asset_id>                    procedural: build.py (or `build:` in asset.yaml), normalise,
                                                          materials, report, render, export. generative: report and
                                                          render of the final.glb that the cleanup wrote
    asset.py approve game/assets/3d/<asset_id>...         record Sebastian's approval in manifest.json"""

import datetime as dt
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import yaml
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BLENDER_DIR = ROOT / "pipeline" / "blender"
CONTRACT = ROOT / "game" / "art-direction" / "gameplay_contract.yaml"
LIGHTING = ROOT / "game" / "art-direction" / "lighting_rules.yaml"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()[:12]


def run_in_blender(asset, asset_dir, contract):
    preamble = (
        f"ASSET_DIR = {str(asset_dir)!r}\n"
        f"PIPELINE_DIR = {str(ROOT / 'pipeline')!r}\n"
        f"ASSET = {asset!r}\n"
        f"CONTRACT = {contract!r}\n"
    )
    code = preamble + (BLENDER_DIR / "driver.py").read_text()
    p = subprocess.run(["blx", "-"], input=code, text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit(f"blender step failed:\n{p.stdout[-3000:]}\n{p.stderr[-3000:]}")
    return json.loads(p.stdout.strip().splitlines()[-1])


def sheet(asset_dir):
    views = sorted((asset_dir / "previews" / "views").glob("*.png"))
    ims = [Image.open(v) for v in views]
    if not ims:
        return None
    w, h = ims[0].size
    out = Image.new("RGB", (w * len(ims), h + 24), "white")
    d = ImageDraw.Draw(out)
    for i, (v, im) in enumerate(zip(views, ims)):
        out.paste(im, (i * w, 24))
        d.text((i * w + 6, 6), v.stem, fill="black")
    path = asset_dir / "previews" / "sheet.png"
    out.save(path)
    return path


def approve(dirs):
    for d in dirs:
        p = Path(d) / "manifest.json"
        m = json.loads(p.read_text())
        m["approved_by"], m["approved"] = "Sebastian", dt.date.today().isoformat()
        p.write_text(json.dumps(m, indent=2) + "\n")
        print(f"approved {m['asset_id']}")


def spent(asset_dir):
    return round(sum(json.loads(p.read_text()).get("est_cost_usd", 0) for p in asset_dir.glob("*/*.json")), 3)


def main():
    if sys.argv[1] == "approve":
        return approve(sys.argv[2:])
    asset_dir = Path(sys.argv[1]).resolve()
    asset = yaml.safe_load((asset_dir / "asset.yaml").read_text())
    contract = yaml.safe_load(CONTRACT.read_text()) if CONTRACT.exists() else {}
    rules = yaml.safe_load(LIGHTING.read_text()) if LIGHTING.exists() else {}
    if rules.get("picked"):
        contract = dict(contract)
        contract["light"] = rules["variants"][rules["picked"]]
    (asset_dir / "previews" / "views").mkdir(parents=True, exist_ok=True)
    res = run_in_blender(asset, asset_dir, contract)
    sheet(asset_dir)
    rep = res["report"]
    inputs = {"asset_yaml_sha": sha(asset_dir / "asset.yaml")}
    build_py = (asset_dir / asset.get("build", "build.py")).resolve()
    if build_py.exists():
        inputs["build_py_sha"] = sha(build_py)
    manifest = {
        "asset_id": asset["asset_id"],
        "route": asset["route"],
        "inputs": inputs,
        "steps": [{k: s[k] for k in ("name", "ok", "elapsed_s")} for s in res["steps"]],
        "report": "report.json",
        "limits_ok": rep["limits_ok"],
        "limit_failures": rep["limit_failures"],
        "critic": None,
        "approved_by": None,
        "approved": None,
        "cost_usd": spent(asset_dir),
        "created": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    }
    (asset_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"asset": asset["asset_id"], "tris": rep["tris"], "dims_m": rep["dims_m"],
                      "non_manifold": rep["non_manifold_edges"], "limits_ok": rep["limits_ok"],
                      "failures": rep["limit_failures"]}))
    sys.exit(0 if rep["limits_ok"] else 1)


if __name__ == "__main__":
    main()
