#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Run an image round: every direction times every frame times every model, then the contact sheet and the page. Run from the repo root.
A direction or a model may list `refs`, image paths relative to the round folder, attached to every call as reference images."""

import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMG = ["uv", "run", "--script", str(ROOT / "pipeline" / "img.py")]


def main():
    rd = Path(sys.argv[1]).resolve()
    cfg = json.loads((rd / (sys.argv[2] if len(sys.argv) > 2 else "round.json")).read_text())
    (rd / "prompts").mkdir(exist_ok=True)
    jobs = []
    for mslug, m in cfg["models"].items():
        for d in cfg["directions"]:
            if "only" in m and d["slug"] not in m["only"]:
                continue
            for fslug in m.get("frames", list(cfg["frames"])):
                prompt = cfg["frames"][fslug].format(**{"style": cfg.get("style", ""), **d})
                stem = f"{d['slug']}-{fslug}--{mslug}"
                pf = rd / "prompts" / f"{stem}.txt"
                pf.write_text(prompt + "\n")
                out = rd / f"{stem}.png"
                if out.exists():
                    continue
                cmd = IMG + ["gen", "--model", m["id"], "--prompt-file", str(pf), "--out", str(out), "--label", stem]
                if "est" in m:
                    cmd += ["--est", str(m["est"])]
                for k, v in m.get("params", {}).items():
                    cmd += ["--param", f"{k}={v if isinstance(v, str) else json.dumps(v)}"]
                for r in d.get("refs", []) + m.get("refs", []):
                    cmd += ["--ref", str((rd / r).resolve())]
                jobs.append((stem, cmd))

    def run(job):
        stem, cmd = job
        p = subprocess.run(cmd, capture_output=True, text=True)
        return stem, p.returncode, (p.stdout + p.stderr).strip()[-300:]

    failed = 0
    with ThreadPoolExecutor(cfg.get("parallel", 4)) as ex:
        for stem, rc, tail in ex.map(run, jobs):
            failed += rc != 0
            print(("ok   " if rc == 0 else "FAIL ") + stem + ("" if rc == 0 else "\n     " + tail))
    imgs = sorted(rd.glob("*.png"))
    if imgs:
        subprocess.run(IMG + ["montage", "--images", *map(str, imgs), "--labels", *[p.stem for p in imgs],
                              "--cols", str(cfg.get("cols", len(cfg["frames"]))), "--cell", str(cfg.get("cell", 512)),
                              "--out", str(rd / "contact-sheet.jpg")], check=True)
        subprocess.run(IMG + ["sheet", str(rd)], check=True)
    print(f"{len(imgs)} images, {failed} failed, " + subprocess.run(IMG + ["cost"], capture_output=True, text=True).stdout.strip())
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
