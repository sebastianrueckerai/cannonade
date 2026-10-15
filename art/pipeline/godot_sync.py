#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Copy approved assets into the game's art layer and update its manifest.json. Run from the repo root.

    pipeline/godot_sync.py game/assets/3d/<asset_id> [...]   sync these assets
    pipeline/godot_sync.py --all                              sync every approved asset
    --force                                                   also sync assets without an approval

The game repo comes from game_repo in game/art-direction/gameplay_contract.yaml, GAME_REPO overrides it."""

import datetime as dt
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = yaml.safe_load((ROOT / "game" / "art-direction" / "gameplay_contract.yaml").read_text())
GAME = Path(os.environ.get("GAME_REPO") or CONTRACT["game_repo"])
ART = GAME / "assets" / "art"
# Godot fills in the rest on import. Without embedded_image_handling=3 it writes a generated model's texture
# next to the .glb as a separate file.
IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[params]

gltf/embedded_image_handling=3
"""


def sync_one(asset_dir: Path, game_manifest: dict, force: bool) -> bool:
    manifest = json.loads((asset_dir / "manifest.json").read_text())
    asset_id = manifest["asset_id"]
    if not manifest.get("approved") and not force:
        print(f"skip {asset_id}: not approved (use --force to sync anyway)")
        return False
    if not manifest.get("limits_ok"):
        print(f"skip {asset_id}: limits failed: {manifest.get('limit_failures')}")
        return False
    report = json.loads((asset_dir / "report.json").read_text())
    src = asset_dir / "final.glb"
    dst = ART / "3d" / f"{asset_id}.glb"
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    imp = dst.with_name(dst.name + ".import")
    if not imp.exists():
        imp.write_text(IMPORT)
    d = report["dims_m"]
    game_manifest[asset_id] = {
        "size": [d[0], d[2], d[1]],
        "tolerance": 0.02,
        "parts": sorted(report["parts"]),
        "tris": report["tris"],
        "source_sha": hashlib.sha256(src.read_bytes()).hexdigest()[:12],
        "approved_by": manifest.get("approved_by"),
        "synced": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    }
    print(f"sync {asset_id}: {dst.relative_to(GAME)} size {game_manifest[asset_id]['size']} tris {report['tris']}")
    return True


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    if "--all" in sys.argv:
        dirs = sorted(p.parent for p in (ROOT / "game" / "assets" / "3d").glob("*/manifest.json"))
    else:
        dirs = [Path(a).resolve() for a in args]
    if not dirs:
        sys.exit(__doc__)
    if not ART.is_dir():
        sys.exit(f"no art layer at {ART}")
    mpath = ART / "manifest.json"
    game_manifest = json.loads(mpath.read_text()) if mpath.exists() else {}
    n = sum(sync_one(d, game_manifest, force) for d in dirs)
    mpath.write_text(json.dumps(dict(sorted(game_manifest.items())), indent=2) + "\n")
    print(f"{n} synced, manifest {mpath}. Check in the game: {GAME}/run_tests.sh, or godot --headless res://tools/check_art.tscn")


if __name__ == "__main__":
    main()
