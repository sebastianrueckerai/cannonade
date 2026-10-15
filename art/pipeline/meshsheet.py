#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "pillow"]
# ///
"""Compare generated meshes: every raw/*.glb of an asset through Blender (numbers, five renders), one sheet.
Run from the repo root:  meshsheet.py game/assets/3d/cannon --footprint 1"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from img import font  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
COLS = ["tex_front_left", "tex_back_right", "tex_side", "faces", "parts", "game_default"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("asset_dir")
    ap.add_argument("--footprint", type=float, required=True, help="tiles, the model is scaled to fill it")
    ap.add_argument("--only", nargs="*", help="glb stems to render, default all")
    ap.add_argument("--cell", type=int, default=240)
    ap.add_argument("--out", default="route-test", help="sheet name under previews/")
    ap.add_argument("--title", default="")
    a = ap.parse_args()
    d = (ROOT / a.asset_dir).resolve()
    glbs = sorted(p for p in (d / "raw").glob("*.glb") if not p.stem.endswith(("-base_model", "-model")))
    if a.only:
        glbs = [d / "raw" / f"{stem}.glb" for stem in a.only if (d / "raw" / f"{stem}.glb").exists()]
    out_dir = d / "previews" / "route-test"
    todo = [p for p in glbs if not (out_dir / p.stem / "stats.json").exists()]
    if todo:
        pre = f"GLBS = {[str(p) for p in todo]!r}\nOUT_DIR = {str(out_dir)!r}\nFOOTPRINT = {a.footprint!r}\n"
        code = pre + (ROOT / "pipeline/blender/inspect_glb.py").read_text()
        p = subprocess.run(["blx", "-"], input=code, text=True, capture_output=True)
        if p.returncode or '"error"' in p.stdout[:200]:
            sys.exit(f"blender: {p.stdout[-1500:]} {p.stderr[-1500:]}")
    c, label_w, head = a.cell, 370, 70 if a.title else 34
    sheet = Image.new("RGB", (label_w + c * len(COLS), head + c * len(glbs)), "white")
    dr = ImageDraw.Draw(sheet)
    for i, name in enumerate(["textured, front left", "textured, back right", "textured, side", "faces, flat", "parts, one colour each",
                               "game, default view"]):
        dr.text((label_w + i * c + 6, head - 26), name, fill="black", font=font(17))
    if a.title:
        dr.text((8, 8), a.title, fill="black", font=font(22))
    summary = {}
    for r, g in enumerate(glbs):
        st = json.loads((out_dir / g.stem / "stats.json").read_text())
        side = json.loads(g.with_suffix(".json").read_text()) if g.with_suffix(".json").exists() else {}
        prm = side.get("params", {})
        target = prm.get("face_limit") or prm.get("target_polycount")
        st.update({"credits": side.get("credits"), "elapsed_s": side.get("elapsed_s"), "target": target,
                   "inputs": side.get("inputs", [])})
        summary[g.stem] = st
        y = head + r * c
        lines = [g.stem, f"{st['tris']} tris for {target or 'no'} asked, {st['verts']} verts",
                 f"{st['islands']} loose parts, {st['objects']} objects, {st['non_manifold_edges']} open edges",
                 f"texture {', '.join(st['textures']) or 'none'}, {st['file_mb']} MB",
                 f"{st['credits']} credits, {st['elapsed_s']} s"]
        for k, line in enumerate(lines):
            dr.text((8, y + 8 + k * 24), line, fill="black", font=font(19 if k == 0 else 15))
        for k, inp in enumerate(st["inputs"][:4]):
            if inp and inp != "-":
                th = Image.open(ROOT / inp).convert("RGB").resize((76, 76))
                sheet.paste(th, (8 + k * 80, y + c - 84))
        for i, col in enumerate(COLS):
            im = Image.open(out_dir / g.stem / f"{col}.png").convert("RGB")
            k = max(1, c // im.width)  # whole-number magnification, so every game pixel stays a square
            im = im.resize((im.width * k, im.height * k), Image.NEAREST) if col == "game_default" else im.resize((c, c))
            sheet.paste(im, (label_w + i * c + (c - im.width) // 2, y + (c - im.height) // 2))
        dr.line((0, y, sheet.width, y), fill=(180, 180, 180))
    path = d / "previews" / f"{a.out}.png"
    sheet.save(path)
    (d / "previews" / f"{a.out}.json").write_text(json.dumps(summary, indent=2))
    print(path)


if __name__ == "__main__":
    main()
