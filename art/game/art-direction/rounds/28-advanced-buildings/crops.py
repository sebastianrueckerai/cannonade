#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["pillow"]
# ///
"""Cuts each picked design out of its round 28 sheet into refs/a-sketch.png of its asset, with a sidecar.
The reference view edits attach that crop. Run from the repo root:
    uv run --script game/art-direction/rounds/28-advanced-buildings/crops.py"""
import json
from datetime import datetime
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
ASSETS = HERE.parents[2] / "assets/3d"
# Boxes in sheet pixels (2752 x 1536), read off each painting by eye.
CROPS = {
    "cannon22b": ("mortar.png", (40, 300, 930, 1340)),
    "flak22": ("flak.png", (80, 130, 1080, 1520)),
    "supply22": ("supply22.png", (55, 280, 1045, 1125)),
    "supply22.2": ("supply22.png", (1010, 320, 1890, 1125)),
    "supply22.3": ("supply22.png", (1870, 330, 2720, 1125)),
    "supply33": ("supply33.png", (50, 330, 1020, 1380)),
    "supply33.2": ("supply33.png", (930, 240, 1820, 1410)),
    "supply33.3": ("supply33.png", (1820, 320, 2720, 1380)),
}

for asset, (sheet, box) in CROPS.items():
    refs = ASSETS / asset / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    Image.open(HERE / sheet).convert("RGB").crop(box).save(refs / "a-sketch.png")
    (refs / "a-sketch.json").write_text(json.dumps({
        "tool": "crop", "source": str((HERE / sheet).relative_to(HERE.parents[3])), "box_px": list(box),
        "est_cost_usd": 0, "note": "the picked design of round 28, cut at the empty paper around it",
        "created": datetime.now().isoformat(timespec="seconds")}, indent=2))
    print(asset, box)
