# The painted material path of the repaint round (C12): the D49 painted look carried from the
# nature solids to the flat set. Box meshes get a world-metre cube projection (u runs in metres
# mod 1, so a wall run continues the grain across pieces; v runs over the piece height, so feature
# bands land by height: ground splash low, weathering under the merlon tops). A mesh that already
# carries UVs keeps them (the shell's sphere). The noise tiles in u, dabs wrap in u, so a texture
# repeats along a wall without a seam. Every painter is seeded: same seed, same texture.
import math
import random

import bpy
from mathutils import Vector, noise

W, H = 512, 512

# kind: texture params. stops are (v, hex) bottom to top of the piece height.
PAINTERS = {
    "stone": {
        "stops": [(0.0, "#dbc9a4"), (0.09, "#e8d6b0"), (0.72, "#e9d8b4"), (1.0, "#ecdcba")],
        "grain": (0.13, 0.065),         # two noise octaves, multiplicative
        "ground": (0.16, 0.08, "#c2ad86"),   # strength, v height, colour of the splash band
        "patches": [(16, (9, 17), (0.10, 0.18), (30, 60)), (12, (10, 19), (0.09, 0.15), (-52, -28))],
        "streaks": (16, (0.80, 0.97), (0.05, 0.15), (3, 8), (0.30, 0.45), 38),
        "stipples": (20, (2.0, 3.5), (0.28, 0.40), (36, 60)),
    },
    "iron": {
        "stops": [(0.0, "#282524"), (0.4, "#302d2b"), (1.0, "#383430")],
        "grain": (0.11, 0.055),
        "ground": None,
        "patches": [(12, (8, 16), (0.07, 0.12), (8, 18)), (9, (9, 17), (0.06, 0.10), (-20, -12))],
        "streaks": None,
        "stipples": (14, (1.8, 3.2), (0.20, 0.30), (14, 26)),
        "fade_top": 0.06,               # sphere poles smear dabs: fade near v=1 (the D49 rule)
    },
    "plate": {
        "stops": [(0.0, "#4c454b"), (0.5, "#544d52"), (1.0, "#5d555b")],   # the D39 grey, painted
        "grain": (0.09, 0.045),
        "ground": None,
        "patches": [(10, (8, 15), (0.06, 0.10), (8, 18)), (8, (9, 16), (0.05, 0.09), (-20, -10))],
        "streaks": None,
        "stipples": (8, (1.8, 3.0), (0.18, 0.28), (16, 30)),
    },
    "grain": {
        "stops": [(0.0, "#ffffff"), (1.0, "#fdfcf9")],   # near-white: the Map multiplies its lerp colour on top
        "grain": (0.030, 0.016),
        "ground": None,
        "patches": [(8, (10, 20), (0.05, 0.08), (4, 8)), (6, (10, 20), (0.04, 0.07), (-8, -4))],
        "streaks": None,
        "stipples": None,
    },
    "stamp": {
        "stops": [(0.0, "#ffffff"), (1.0, "#faf7f1")],   # near-white like grain: the Map colour multiplies on top
        "grain": (0.06, 0.03),           # packed earth, coarser than the paved tile
        "ground": None,
        "patches": [(8, (40, 100), (0.85, 1.0), (-70, -30)), (6, (30, 70), (0.8, 1.0), (30, 60))],
        "streaks": None,
        "stipples": (16, (4.0, 7.0), (0.8, 1.0), (-50, -25)),   # pebbles and dirt flecks
        "edge": (1.0, 36.0, 0.32),       # soft stamped border, darker toward the piece edge
    },
}


def rgb(hexstr):
    return tuple(int(hexstr.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, k):
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))


def grad(stops, t):
    t = min(max(t, 0.0), 1.0)
    i, (t0, c0) = max((i, s) for i, s in enumerate(stops) if s[0] <= t)
    if i + 1 < len(stops):
        t1, c1 = stops[i + 1]
        return lerp(c0, c1, (t - t0) / (t1 - t0) if t1 > t0 else 0.0)
    return c0


def pnoise(u, v, su, sv, off):
    # noise on a circle in u: periodic with period 1, so texture repeats along a wall run
    a = u * 2 * math.pi * su
    return noise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, v * sv + off)))


def cube_uv(ob, top_planar=False):
    """World-metre cube projection, object space. Side faces: u along the face in metres (mod 1),
    v over the object height. Top and bottom faces: u along x, v fixed at the face's height, so
    they sample one texture row and pick up the grain and the weathering rows. With `top_planar`
    (a terrain top, where one row would flatten the pattern): the full texture over the piece's
    x-y extent, one stamp per piece. (`% 1` would collapse a centred 1 m piece onto the seam.)"""
    me = ob.data
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    zs = [v.co.z for v in me.vertices]
    lo, h = min(zs), max(zs) - min(zs)
    if h < 1e-6:
        h = 1.0
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    x0, sx = min(xs), (max(xs) - min(xs)) or 1.0
    y0, sy = min(ys), (max(ys) - min(ys)) or 1.0
    for p in me.polygons:
        for li in p.loop_indices:
            c = me.vertices[me.loops[li].vertex_index].co
            if abs(p.normal.z) > 0.5:
                u = c.x % 1.0
            elif abs(p.normal.x) > 0.5:
                u = c.y % 1.0
            else:
                u = c.x % 1.0
            if top_planar and abs(p.normal.z) > 0.5:
                uv.data[li].uv = ((c.x - x0) / sx, (c.y - y0) / sy)
            else:
                uv.data[li].uv = (u, (c.z - lo) / h)
    return uv


def dab(flat, rng, cx, cy, r, a, change):
    for dy in range(-int(r), int(r) + 1):
        yy = cy + dy
        if 0 <= yy < H:
            for dx in range(-int(r), int(r) + 1):
                d = math.hypot(dx, dy) / r
                if d < 1.0:
                    o = (yy * W + (cx + dx) % W) * 4
                    k = a * (1.0 - d) ** 1.6
                    flat[o:o + 3] = [max(0, min(255, ch + change * k)) for ch in flat[o:o + 3]]


def paint_texture(params, seed):
    rng = random.Random(seed)
    stops = [(t, rgb(c)) for t, c in params["stops"]]
    g1, g2 = params["grain"]
    p1, p2 = rng.random() * 6.28, rng.random() * 6.28
    flat = [0.0] * (W * H * 4)
    for y in range(H):
        v = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            c = grad(stops, v)
            if params["ground"]:
                k, hv, col = params["ground"]
                wob = 0.012 + 0.014 * math.sin(u * 2 * math.pi * 2 + p1) + 0.006 * math.sin(u * 2 * math.pi * 5 + p2)
                kk = min(1.0, max(0.0, ((hv + wob) - v) / 0.035))
                c = lerp(c, rgb(col), k * kk)
            # su is full circles per metre (u features/m = 2*pi*su), so 2.07/6.0 match the v frequencies 13/38
            n = pnoise(u, v, 2.07, 13.0, 3.1) * g1 + pnoise(u, v, 6.0, 38.0, 7.7) * g2
            c = tuple(ch * (1.0 + n) for ch in c)
            o = (y * W + x) * 4
            flat[o:o + 3] = c
            flat[o + 3] = 255
    for count, (rlo, rhi), (alo, ahi), chg in params["patches"]:
        for _ in range(count):
            dab(flat, rng, rng.randrange(W), int(rng.random() * H),
                rng.uniform(rlo, rhi), rng.uniform(alo, ahi), rng.uniform(*chg))
    if params["streaks"]:
        count, (v0lo, v0hi), (llo, lhi), (wlo, whi), (alo, ahi), dark = params["streaks"]
        for _ in range(count):
            sx, w = rng.randrange(W), rng.uniform(wlo, whi)
            top = int((v0lo + rng.random() * (v0hi - v0lo)) * H)
            ln = int((llo + rng.random() * (lhi - llo)) * H)
            a = rng.uniform(alo, ahi)
            for yy in range(max(0, top - ln), min(H, top)):
                t = (top - yy) / max(1, ln)          # 0 at the top edge, 1 at the streak foot
                fade = (1.0 - t) ** 1.2              # weathering runs down from the top, fading
                for k in range(-int(w * 1.6), int(w * 1.6) + 1):
                    o = (yy * W + (sx + k) % W) * 4
                    fall = math.exp(-((k / w) ** 2))
                    flat[o:o + 3] = [max(0, ch * (1.0 - a * fade * fall * dark / 100.0)) for ch in flat[o:o + 3]]
    if params["stipples"]:
        count, (rlo, rhi), (alo, ahi), (clo, chi) = params["stipples"]
        for _ in range(count):
            dab(flat, rng, rng.randrange(W), int(rng.random() * H),
                rng.uniform(rlo, rhi), rng.uniform(alo, ahi), rng.uniform(clo, chi))
    if params.get("edge"):
        strength, wpx, dark = params["edge"]
        for y in range(H):
            dy = min(y, H - 1 - y)
            for x in range(W):
                d = min(dy, x, W - 1 - x) / wpx
                if d < 1.0:
                    o = (y * W + x) * 4
                    k = strength * (1.0 - d) ** 1.4 * dark
                    flat[o:o + 3] = [ch * (1.0 - k) for ch in flat[o:o + 3]]
    return flat


def painted_material(ob, spec, keep_slots=False):
    """Paints `spec` {"kind", "seed", optional "over"} onto `ob`, assigns the material, returns it.
    Keeps existing UVs (the shell's sphere); projects box meshes that have none.
    keep_slots: leave the slot list alone (the caller places the material), for
    meshes whose first material must stay, like the castle's team slot."""
    kind = spec["kind"]
    kind = spec["kind"]
    params = dict(PAINTERS[kind])
    params.update(spec.get("over") or {})
    name = f"{ob.name}_{kind}"
    if ob.data.uv_layers.active is None:
        cube_uv(ob, top_planar=spec.get("top_planar", False))
    img = bpy.data.images.new(name + "_tex", width=W, height=H)
    img.colorspace_settings.name = "sRGB"
    img.pixels[:] = [v / 255.0 for v in paint_texture(params, int(spec["seed"]))]
    img.pack()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if not keep_slots:
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    if not spec.get("smooth"):
        for p in ob.data.polygons:
            p.use_smooth = False
    return mat
