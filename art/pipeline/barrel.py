#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "pillow"]
# ///
"""Split a generated gun into `barrel` and `mount` in Blender, pivot on the trunnion axis, renders at each tilt.
Run from the repo root:
  barrel.py game/assets/3d/cannon parts meshy-b-1000             the API's loose parts
  barrel.py game/assets/3d/cannon cut tripo-b-1000               a cut through the fused mesh
  barrel.py game/assets/3d/cannon join meshy-mount meshy-barrel meshy-b-1000   made apart, placed like the whole gun
                                                                 of the same API (its parts, or a cut for Tripo)
  barrel.py game/assets/3d/cannon sheet <name>...                one sheet of the splits named
  barrel.py game/assets/3d/cannon pieces meshy-b-1000            every loose piece numbered and shown in red, for split.json
  barrel.py game/assets/3d/cannon final                          the split by hand in split.json: final.glb, source.blend
Options for a split: --pivot X sets the trunnion by hand, metres along the barrel from the footprint centre
before the turn to the game's forward. --export PATH writes the .glb for Godot."""

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from img import font  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
# A barrel rests 10 degrees down and fires from 45 up. The flak's guns aim from level to near the sky.
TILTS = {"barrel": [-10, 45], "guns": [0, 80]}
FOOTPRINT = {"cannon": 1, "cannon22a": 2, "cannon22b": 2, "flak22": 2, "cannon33a": 3}


def blender(job):
    code = f"import sys; sys.path.insert(0, {str(ROOT / 'pipeline')!r})\nJOB = {job!r}\n" + (ROOT / "pipeline/blender/barrel.py").read_text()
    p = subprocess.run(["blx", "-"], input=code, text=True, capture_output=True)
    print(p.stdout.strip()[-600:], p.stderr.strip()[-600:])


def run(d, mode, stems, pivot=None, export=None):
    name = f"{mode}-{stems[0].split('-')[0] if mode == 'join' else stems[0]}"
    job = {"mode": mode, "footprint": FOOTPRINT[d.name], "tilts": TILTS["barrel"], "out_dir": str(d / "previews" / "barrel" / name),
           "glb": str(d / "raw" / f"{stems[0]}.glb"), "pivot_x": pivot, "export": export}
    if mode == "join":
        job.update({"barrel_glb": str(d / "raw" / f"{stems[1]}.glb"), "ref_glb": str(d / "raw" / f"{stems[2]}.glb"),
                    "ref_mode": "parts" if stems[2].startswith("meshy") else "cut"})
    blender(job)


def final(d):
    """split.json: {"source": raw stem, "barrel": [piece numbers], "pivot_pieces": [piece numbers], "fixes": [...],
    "plate": {"height", "margin", "chamfer" in metres, "colour": hex}}, optional "part": "guns" for a part the game
    aims by its whole orientation, and "pitch": degrees the moving part points above the ground in the source. The
    piece numbers come from the sheet of `pieces`. The build scales the gun until it stays inside its plate."""
    spec = json.loads((d / "split.json").read_text())
    part = spec.get("part", "barrel")
    blender({"mode": "parts", "footprint": FOOTPRINT[d.name], "tilts": TILTS[part], "part": part, "pitch": spec.get("pitch"),
             "gun": d.name,
             "out_dir": str(d / "previews" / "barrel" / "final"),
             "glb": str(d / "raw" / f"{spec['source']}.glb"), "barrel": spec["barrel"], "fixes": spec.get("fixes", []),
             "pivot_x": spec.get("pivot_x"), "pivot_pieces": spec.get("pivot_pieces"), "plate": spec.get("plate"),
             "texture_px": spec.get("texture_px"),
             "export": str(d / "final.glb"), "blend": str(d / "source.blend")})
    sheet(d, ["final"], out="final")


def pieces(d, stem, c=200):
    out = d / "previews" / "pieces" / stem
    blender({"mode": "pieces", "footprint": FOOTPRINT[d.name], "glb": str(d / "raw" / f"{stem}.glb"), "out_dir": str(out)})
    info = json.loads((out / "pieces.json").read_text())
    cols = 4
    im = Image.new("RGB", (cols * 2 * c, 40 + ((len(info) + cols - 1) // cols) * (c + 30)), "white")
    dr = ImageDraw.Draw(im)
    dr.text((8, 8), f"{d.name} {stem}: each piece in red, the automatic barrel in blue", fill="black", font=font(20))
    for k, p in enumerate(info):
        x, y = (k % cols) * 2 * c, 40 + (k // cols) * (c + 30)
        dr.text((x + 6, y + 4), f"p{p['id']:02d}  {p['auto']}  {p['tris']} tris", fill="black", font=font(16))
        for j, view in enumerate(("front", "side")):
            im.paste(Image.open(out / f"p{p['id']:02d}_{view}.png").convert("RGB").resize((c, c)), (x + j * c, y + 26))
    path = d / "previews" / f"pieces-{stem}.png"
    im.save(path)
    print(path)


def sheet(d, names, c=240, label_w=330, out="3-barrel-split"):
    im = Image.new("RGB", (label_w + c * 5, 40 + c * len(names)), "white")
    dr = ImageDraw.Draw(im)
    for r, n in enumerate(names):
        src = d / "previews" / "barrel" / n
        st = json.loads((src / "stats.json").read_text())
        tilts, part = st.get("tilts", TILTS["barrel"]), st.get("part", "barrel")
        cols = [f"tilt{t:+d}_{v}" for t in tilts for v in ("front_left", "side")] + ["split"]
        labels = [f"{part} {t:+d} deg, {v.replace('_', ' ')}" for t in tilts for v in ("front_left", "side")] + [f"{part} and mount"]
        for i, t in enumerate(labels):
            dr.text((label_w + i * c + 6, 12), t, fill="black", font=font(15))
        y = 40 + r * c
        for k, line in enumerate([n, f"barrel {st['barrel_tris']} tris, {st['barrel_open_edges']} open edges",
                                  f"mount {st['mount_tris']} tris, {st['mount_open_edges']} open edges",
                                  f"barrel {st['barrel_length_m']} m", f"pivot from {st['pivot_from']}"]):
            dr.text((8, y + 10 + k * 26), line, fill="black", font=font(18 if k == 0 else 15))
        for i, col in enumerate(cols):
            im.paste(Image.open(src / f"{col}.png").convert("RGB").resize((c, c)), (label_w + i * c, y))
        dr.line((0, y, im.width, y), fill=(180, 180, 180))
    path = d / "previews" / f"{out}.png"
    im.save(path)
    print(path)


def main():
    args, opts = [], {}
    it = iter(sys.argv[1:])
    for x in it:
        if x.startswith("--"):
            opts[x[2:]] = next(it)
        else:
            args.append(x)
    d, mode, rest = (ROOT / args[0]).resolve(), args[1], args[2:]
    if mode == "sheet":
        sheet(d, rest)
    elif mode == "pieces":
        pieces(d, rest[0])
    elif mode == "final":
        final(d)
    else:
        run(d, mode, rest, float(opts["pivot"]) if "pivot" in opts else None, opts.get("export"))


if __name__ == "__main__":
    main()
