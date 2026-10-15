#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Cut the faint ghost shapes off the top of a sheet: keep the image from fraction TOP of its height down.
Run from the repo root: uv run --script game/art-direction/rounds/17-painted-sketches/croptop.py IN.png OUT.png TOP"""

import json
import sys
from pathlib import Path

from PIL import Image

src, out, top = Path(sys.argv[1]), Path(sys.argv[2]), float(sys.argv[3])
im = Image.open(src)
box = (0, round(im.height * top), im.width, im.height)
im.crop(box).save(out)
out.with_suffix(".json").write_text(json.dumps({"tool": "croptop.py", "argv": sys.argv, "inputs": [src.name], "box_px": box, "est_cost_usd": 0.0}, indent=1))
print(out, box)
