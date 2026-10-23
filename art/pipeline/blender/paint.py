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
    "mud_hit": {   # the enclosed stamped paving shelled (I73): cracked and pocked, near-white for the Map colour
        "stops": [(0.0, "#ffffff"), (1.0, "#f6f1e7")],
        "grain": (0.07, 0.035),
        "ground": None,
        "patches": [(6, (14, 30), (0.25, 0.45), (-45, -25))],
        "streaks": None,
        "stipples": (22, (3.0, 6.0), (0.7, 1.0), (-45, -20)),   # rubble and dirt flecks
        "cracks": (7, (18, 40), (1.5, 3.0), -70),   # count, segment count, half width px, darkening
        "edge": (1.0, 36.0, 0.32),
    },
    "flat": {   # no texture of our own: the source texture as flat colours, one per UV island, on the UVs it came with
        "k": 6,
        "blur": 2,
    },
    "dirt_hit": {  # open nature ground blasted (I73): churned earth and char, near-white for the Map colour
        "stops": [(0.0, "#ffffff"), (1.0, "#f2ede2")],
        "grain": (0.09, 0.045),
        "ground": None,
        "patches": [(5, (20, 44), (0.35, 0.6), (-55, -30)), (4, (10, 20), (0.2, 0.4), (-25, -12))],
        "streaks": None,
        "stipples": (18, (2.5, 5.0), (0.7, 1.0), (-40, -18)),
        "edge": (0.8, 30.0, 0.28),
    },
}


def rgb(hexstr):
    return tuple(int(hexstr.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))


def linear(c):
    return tuple(((v / 255 + 0.055) / 1.055) ** 2.4 if v / 255 > 0.04045 else v / 255 / 12.92 for v in c)


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
            if params.get("white_band") and params["white_band"][0] <= v <= params["white_band"][1]:
                c = (255.0, 255.0, 255.0)   # the rows a recoloured region samples: grain only, the game's colour on top
            c = tuple(ch * (1.0 + n) for ch in c)
            o = (y * W + x) * 4
            flat[o:o + 3] = c
            flat[o + 3] = 255
    if params.get("courses"):
        # running-bond masonry: `rows` courses over the painted height, vertical joints every
        # `block_m` metres of u (u is metres mod 1, so joints meet at the corners), staggered per
        # row, wobbled so no line reads ruler-straight, every block cell jittered in value.
        rows, block_m, mortar, jitter = params["courses"][:4]
        mwid = params["courses"][4] if len(params["courses"]) > 4 else 2.5
        v0 = (params["ground"][1] + 0.015) if params["ground"] else 0.03
        v1 = 0.985
        ph = [rng.random() * 6.28 for _ in range(rows + 1)]
        jk = {}
        def cell(row, seg):
            key = (row, seg)
            if key not in jk:
                r2 = random.Random(seed + row * 4099 + seg * 7919).random()
                jk[key] = 1.0 + jitter * (r2 * 2 - 1) / 100.0
            return jk[key]
        span = v1 - v0
        hw = mwid / H         # mortar half width in v
        hwu = mwid / W        # in u: u spans one metre
        for y in range(H):
            v = y / (H - 1)
            fy = (v - v0) / span * rows
            row = int(fy)
            for x in range(W):
                u = x / (W - 1)
                o = (y * W + x) * 4
                if row < 0 or row >= rows:
                    continue
                # the course boundary under this pixel, in v, wobbled along the metre u
                line = v0 + (row + 1 + 0.05 * math.sin(u * 2 * math.pi * 2 + ph[row + 1])) * span / rows
                kv = max(0.0, 1.0 - abs(v - line) / hw)
                ub = u + (block_m * 0.5 if row % 2 else 0.0)
                seg = math.floor(ub / block_m)
                frac = ub / block_m - seg
                du = min(frac, 1.0 - frac) * block_m
                ku = max(0.0, 1.0 - du / hwu)
                m = max(kv, ku) * mortar / 100.0
                flat[o:o + 3] = [max(0, ch * cell(row, seg) * (1.0 - m)) for ch in flat[o:o + 3]]
    for cx, cy, r, a, chg in params.get("dabs_at") or []:   # fixed dabs, e.g. the scorch over its crater
        dab(flat, rng, cx, cy, r, a, chg)
    for count, (rlo, rhi), (alo, ahi), chg in params["patches"]:
        for _ in range(count):
            dab(flat, rng, rng.randrange(W), int(rng.random() * H),
                rng.uniform(rlo, rhi), rng.uniform(alo, ahi), rng.uniform(*chg))
    if params.get("cracks"):   # a random walk of small dark dabs, the crack a line of them
        count, (llo, lhi), (wlo, whi), dark = params["cracks"]
        for _ in range(count):
            x, y = rng.randrange(W), rng.randrange(H)
            ang = rng.random() * 6.28
            for _ in range(rng.randrange(llo, lhi + 1)):
                dab(flat, rng, x, y, rng.uniform(wlo, whi), 1.0, dark)
                ang += rng.uniform(-0.7, 0.7)
                x, y = (x + int(math.cos(ang) * 4)) % W, max(0, min(H - 1, y + int(math.sin(ang) * 4)))
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



def flat_materials(ob, source, params, seed):
    """The flat look as one solid material per part, no texture: a seeded k-means over the
    blurred source gives the centres, bright centres of one hue merge into one part, and
    every UV island takes the nearest centre whole. Returns a part id per face (0 team,
    1 stone, 2 dark, 3+ further stone hues) and each part's colour."""
    import numpy as np
    w, h = int(source.size[0]), int(source.size[1])
    arr = np.array(source.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, :3] * 255.0
    for _ in range(int(params.get("blur", 2))):
        q = np.pad(arr, ((1, 1), (1, 1), (0, 0)), mode="edge")
        arr = sum(q[i:i + h, j:j + w] for i in range(3) for j in range(3)) / 9.0
    rng = random.Random(seed)
    flat_px = arr.reshape(-1, 3)
    sample = flat_px[rng.sample(range(w * h), min(6000, w * h))]
    k = int(params.get("k", 6))
    cent = sample[[int(len(sample) * (i + 0.5) / k) for i in range(k)]].copy()
    for _ in range(12):
        lab = ((sample[:, None, :] - cent[None, :, :]) ** 2).sum(-1).argmin(1)
        for i in range(k):
            m = sample[lab == i]
            if len(m):
                cent[i] = m.mean(0)
    # the source's baked light and shadow split one material into brightness steps,
    # so bright centres of one hue are that material's lighting variants: merge them to
    # their running mean and every island of one material takes one colour. A dark centre
    # of the same hue stays apart: it is a part of its own, a door or a window, not a
    # shadow of the wall.
    import colorsys
    def hls(c):
        r, g, b = (v / 255.0 for v in c)
        return colorsys.rgb_to_hls(r, g, b)
    merged, counts = [cent[0].copy()], [1]
    for c in cent[1:]:
        for gi, g in enumerate(merged):
            dh = abs(hls(c)[0] - hls(g)[0])
            if min(dh, 1 - dh) < 0.03 and hls(c)[1] >= 0.45 and hls(g)[1] >= 0.45:
                merged[gi] = g + (c - g) / (counts[gi] + 1)
                counts[gi] += 1
                break
        else:
            merged.append(c.copy())
            counts.append(1)
    cent = np.array(merged)
    tlo, thi = params.get("team_hue") or (0.0, -1.0)
    part, stone = [], 0
    for c in cent:
        hue, lig = hls(c)[0], hls(c)[1]
        if tlo <= hue <= thi:
            part.append(0)
        elif lig < 0.45:
            part.append(2)
        else:
            stone += 1
            part.append(1 if stone == 1 else stone + 1)
    cols = {q: [c for c, r in zip(cent, part) if r == q] for q in set(part)}
    cols = {q: (255.0, 255.0, 255.0) if q == 0 else tuple(np.array(v).mean(0)) for q, v in cols.items()}

    # UV islands: faces joined by an edge their uv coords share
    uv = ob.data.uv_layers.active.data
    faces = ob.data.polygons
    parent = list(range(len(faces)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    edges = {}
    for fi, p in enumerate(faces):
        end = p.loop_start + p.loop_total
        for li in range(p.loop_start, end):
            a = uv[li].uv
            b = uv[p.loop_start if li + 1 == end else li + 1].uv
            key = tuple(sorted(((round(a.x, 4), round(a.y, 4)), (round(b.x, 4), round(b.y, 4)))))
            other = edges.setdefault(key, fi)
            if other != fi:
                parent[find(fi)] = find(other)
    islands = {}
    for fi in range(len(faces)):
        islands.setdefault(find(fi), []).append(fi)

    roles = [1] * len(faces)
    for members in islands.values():
        mask = np.zeros((h, w), dtype=bool)
        for fi in members:
            p = faces[fi]
            end = p.loop_start + p.loop_total
            pts = [np.array([uv[li].uv.x * (w - 1), uv[li].uv.y * (h - 1)]) for li in range(p.loop_start, end)]
            for a, b, c in zip(range(len(pts) - 2), range(1, len(pts) - 1), range(2, len(pts))):
                v0, v1, v2 = pts[a], pts[b], pts[c]
                x0, y0 = np.floor(min(v0[0], v1[0], v2[0])).astype(int), np.floor(min(v0[1], v1[1], v2[1])).astype(int)
                x1, y1 = np.ceil(max(v0[0], v1[0], v2[0])).astype(int), np.ceil(max(v0[1], v1[1], v2[1])).astype(int)
                xs = np.arange(max(0, x0), min(w, x1 + 1))
                ys = np.arange(max(0, y0), min(h, y1 + 1))
                if not len(xs) or not len(ys):
                    continue
                gx, gy = np.meshgrid(xs, ys)
                d = (v1[1] - v2[1]) * (v0[0] - v2[0]) + (v2[0] - v1[0]) * (v0[1] - v2[1])
                if abs(d) < 1e-9:
                    continue
                l1 = ((v1[1] - v2[1]) * (gx - v2[0]) + (v2[0] - v1[0]) * (gy - v2[1])) / d
                l2 = ((v2[1] - v0[1]) * (gx - v2[0]) + (v0[0] - v2[0]) * (gy - v2[1])) / d
                mask[gy[(l1 >= -0.001) & (l2 >= -0.001) & (l1 + l2 <= 1.001)],
                     gx[(l1 >= -0.001) & (l2 >= -0.001) & (l1 + l2 <= 1.001)]] = True
        if mask.any():
            ci = int(((cent - arr[mask].mean(0)) ** 2).sum(1).argmin())
            for fi in members:
                roles[fi] = part[ci]
        else:
            # an island too small to rasterize falls back to each face's own texel
            for fi in members:
                p = faces[fi]
                li = p.loop_start + p.loop_total // 2
                x, y = min(w - 1, int(uv[li].uv.x * w)), min(h - 1, int(uv[li].uv.y * h))
                roles[fi] = part[int(((cent - arr[y, x]) ** 2).sum(1).argmin())]

    # a team part welded into a bigger island washes out of the island mean, but its own
    # texels stay team-coloured underneath: the face's own source texel votes team
    for fi, p in enumerate(faces):
        li = p.loop_start + p.loop_total // 2
        x = min(w - 1, int(uv[li].uv.x * w))
        y = min(h - 1, int(uv[li].uv.y * h))
        if tlo <= hls(arr[y, x])[0] <= thi:
            roles[fi] = 0
    return roles, cols


def painted_material(ob, spec, keep_slots=False, source=None):
    """Paints `spec` {"kind", "seed", optional "over"} onto `ob`, assigns the material, returns it.
    Keeps existing UVs (the shell's sphere); projects box meshes that have none, or any mesh with `project`
    (the wall block carries a second UV layer of region ids and wants the projection on its first). `tint`, a
    hex, becomes the material's base colour factor over the texture, for a part the game recolours. `white_band`
    [v0, v1] in `over` paints those rows white, grain only, for the faces the game colours itself.
    keep_slots: leave the slot list alone (the caller places the material), for
    meshes whose first material must stay, like the castle's team slot."""
    kind = spec["kind"]
    params = dict(PAINTERS[kind])
    params.update(spec.get("over") or {})
    name = f"{ob.name}_{kind}"
    if ob.data.uv_layers.active is None or spec.get("project"):
        cube_uv(ob, top_planar=spec.get("top_planar", False))
    if kind == "flat":
        roles, cols = flat_materials(ob, source, params, int(spec["seed"]))
        names = {0: "team", 1: "stone", 2: "dark"}
        mats = {}
        for q in sorted(set(roles)):
            m = bpy.data.materials.new(names.get(q, "stone%d" % (q - 2)))
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (*linear(tuple(cols[q])), 1.0)
            b.inputs["Roughness"].default_value = 1.0
            b.inputs["Metallic"].default_value = 0.0
            mats[q] = m
        ob.data.materials.clear()
        pos = {q: i for i, q in enumerate(sorted(mats))}
        for q in sorted(mats):
            ob.data.materials.append(mats[q])
        for fi, q in enumerate(roles):
            ob.data.polygons[fi].material_index = pos[q]
        if not spec.get("smooth"):
            for p in ob.data.polygons:
                p.use_smooth = False
        return mats.get(1)
    else:
        img = bpy.data.images.new(name + "_tex", width=W, height=H)
        img.colorspace_settings.name = "sRGB"
        img.pixels[:] = [v / 255.0 for v in paint_texture(params, int(spec["seed"]))]
    img.pack()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    if spec.get("tint"):
        # a multiply with a constant exports as the glTF base colour factor (Godot: albedo_color), so the game
        # changes the part's colour by writing that one value while the painted grain stays (session 26)
        mix = mat.node_tree.nodes.new("ShaderNodeMix")
        mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[6].default_value = (*linear(rgb(spec["tint"])), 1.0)
        mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[7])
        mat.node_tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    else:
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
