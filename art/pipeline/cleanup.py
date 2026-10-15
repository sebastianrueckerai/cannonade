#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "pillow"]
# ///
"""The cleanup by hand of a generated model that does not move, from the cleanup.json in its asset folder.
A gun goes through barrel.py and its split.json instead. Run from the repo root:
  cleanup.py game/assets/3d/supply            final.glb and source.blend from cleanup.json
  cleanup.py game/assets/3d/supply --raw      the raw run from the four sides, to choose the turn

cleanup.json: {"source": raw stem, "part": object name, "turn": degrees about Z that bring the front to -Y, which
faces the gameplay camera, "size": [x, y, z] metres, or "fit": metres of the longer side of the footprint with the
proportions kept, "team": true gives the royal blue faces a first material of their own, which the game paints in
the team colour, "team_deck": {"z": [low, high], "inside": metres} adds a flat roof without its own colour to it,
"texture_px": side of the texture, default 512, "max_tris": decimate to this
triangle budget when the run is over it, UV islands kept, "why": notes}"""

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from img import font  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def main():
    d = Path(sys.argv[1]).resolve()
    raw = "--raw" in sys.argv
    spec = json.loads((d / "cleanup.json").read_text())
    out = d / "previews" / ("raw" if raw else "cleanup")
    job = {**spec, "raw": raw, "glb": str(d / "raw" / f"{spec['source']}.glb"), "out_dir": str(out),
           "export": str(d / "final.glb"), "blend": str(d / "source.blend")}
    code = f"JOB = {job!r}\n" + (ROOT / "pipeline/blender/cleanup.py").read_text()
    p = subprocess.run(["blx", "-"], input=code, text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit(p.stdout[-2000:] + p.stderr[-2000:])
    res = json.loads(p.stdout.strip().splitlines()[-1])
    views = sorted(out.glob("*.png"))
    ims = [Image.open(v) for v in views]
    w, h = ims[0].size
    sheet = Image.new("RGB", (w * len(ims), h + 30), "white")
    dr = ImageDraw.Draw(sheet)
    for i, (v, im) in enumerate(zip(views, ims)):
        sheet.paste(im, (i * w, 30))
        dr.text((i * w + 8, 6), v.stem, fill="black", font=font(18))
    sheet.save(out.with_suffix(".png"))
    print(json.dumps(res), out.with_suffix(".png"))


if __name__ == "__main__":
    main()
