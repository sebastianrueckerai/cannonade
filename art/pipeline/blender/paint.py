# The flat painter (C22, the recipe of D94): one solid material a part, no texture of our own. A
# seeded k-means over the blurred source gives the centres, whole UV islands take the nearest one,
# a team-blue texel marks the part the game repaints. A mesh without UVs gets the world-metre cube
# projection first (a wall run keeps it, so a later region layer finds its islands). Every painter
# is seeded: same seed, same parts.
import random

import bpy


def rgb(hexstr):
    return tuple(int(hexstr.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))


def linear(c):
    return tuple(((v / 255 + 0.055) / 1.055) ** 2.4 if v / 255 > 0.04045 else v / 255 / 12.92 for v in c)


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
    if 0 in roles and 0 not in cols:
        cols[0] = (255.0, 255.0, 255.0)
    return roles, cols


def flat_names(cols):
    """Names the flat parts for what they are: each part's colour takes the name of its nearest role of
    palette.json's `world` (the roles sky and fog are weather, not materials), a second hue of one role
    takes the role's number, so a material's name says what it is on every model (C22)."""
    import json
    import pathlib

    with open(pathlib.Path(__file__).resolve().parents[2] / "game/art-direction/palette.json") as f:
        world = json.load(f)["world"]
    roles = {k: rgb(v) for k, v in world.items() if k not in ("sky", "fog")}
    names, used = {}, {}
    for q, c in cols.items():
        role = min(roles, key=lambda k: sum((a - b) ** 2 for a, b in zip(roles[k], c)))
        used[role] = used.get(role, 0) + 1
        names[q] = role if used[role] == 1 else "%s%d" % (role, used[role])
    return names


def painted_material(ob, spec, source=None):
    """Paints `ob` the flat way (C22): {"kind": "flat", "seed", optional "over": {k, blur}} over the
    `source` image — one solid material a part, named for its nearest palette role, the team slot
    first (slot 0, the one the game repaints). A mesh without UVs, or with `project`, gets the
    world-metre cube projection first. Returns the team material, or None when the source holds no
    team colour."""
    params = {"k": 6, "blur": 2}
    params.update(spec.get("over") or {})
    assert spec.get("kind", "flat") == "flat", "only the flat kind remains (C22), got %r" % spec.get("kind")
    if ob.data.uv_layers.active is None or spec.get("project"):
        cube_uv(ob, top_planar=spec.get("top_planar", False))
    roles, cols = flat_materials(ob, source, params, int(spec["seed"]))
    names = {0: "team"}   # `team` is the player slot the game paints (D94); every other part
    names.update(flat_names({q: cols[q] for q in set(roles) if q != 0}))
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
