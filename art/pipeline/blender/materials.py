import json

import bpy

from . import paint
from .geo import parts


def linear(hex_colour):
    c = [int(hex_colour.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]


def run(asset, pipeline_dir):
    """asset.yaml `materials` maps a part to a key of palette.json's `world`, or to a "#rrggbb" literal:
    one flat material per key. asset.yaml `paint` gives a part the flat painter of blender/paint.py
    instead (C22): {"kind": flat, "seed": N} over the part's baked source texture. A part in `paint`
    ignores `materials`."""
    with open(pipeline_dir + "/../game/art-direction/palette.json") as f:
        world = json.load(f)["world"]
    made = {}
    for o in parts(asset):
        spec = (asset.get("paint") or {}).get(o.name)
        if spec is not None:
            imgs = [n.image for m in o.data.materials if m and m.use_nodes
                    for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
            if not imgs:  # already flat (the ship's hand-built gun): keeps its materials
                made.update({m.name: None for m in o.data.materials if m})
                continue
            paint.painted_material(o, spec, source=max(imgs, key=lambda i: i.size[0] * i.size[1]))
            made.update({m.name: None for m in o.data.materials if m})
            continue
        key = asset.get("materials", {}).get(o.name)
        if key is None:
            continue
        if key not in made:
            m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
            rgb = linear(key if key.startswith("#") else world[key])
            m.diffuse_color = (*rgb, 1)
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (*rgb, 1)
            bsdf.inputs["Roughness"].default_value = 1.0
            bsdf.inputs["Metallic"].default_value = 0.0
            made[key] = m
        o.data.materials.clear()
        o.data.materials.append(made[key])
        for p in o.data.polygons:
            p.use_smooth = False
    return {"materials": sorted(made)}
