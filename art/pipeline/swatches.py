#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Swatch sheet of a palette file: every world and ui colour and the team mains, name and hex under each. Run from the repo root.
swatches.py palette.json out.png"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    pal = json.loads(Path(sys.argv[1]).read_text())
    items = [(k, v) for k, v in pal["world"].items()] + [(f"team {k}", v["main"]) for k, v in pal["team"].items()] + list(pal["ui"].items())
    font = ImageFont.load_default(22)
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if Path(f).exists():
            font = ImageFont.truetype(f, 22)
            break
    cols, cw, ch, top = 6, 190, 150, 50
    rows = -(-len(items) // cols)
    im = Image.new("RGB", (cols * cw + 20, top + rows * ch + 10), (250, 250, 248))
    d = ImageDraw.Draw(im)
    d.text((12, 12), pal.get("name", Path(sys.argv[1]).stem), fill=(20, 20, 20), font=font)
    for i, (k, h) in enumerate(items):
        x, y = 10 + (i % cols) * cw, top + (i // cols) * ch
        d.rectangle([x + 5, y + 5, x + cw - 10, y + 95], fill=h)
        d.text((x + 8, y + 100), k, fill=(20, 20, 20), font=font)
        d.text((x + 8, y + 124), h, fill=(90, 90, 90), font=font)
    im.save(sys.argv[2])
    print(sys.argv[2])


if __name__ == "__main__":
    main()
