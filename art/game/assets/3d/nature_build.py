# Shared builder for the nine nature looks: bush, leaf tree, boulder in three colourways each.
# D41 wants big stylized solids like the cover art, D45 makes foliage procedural after image-to-3D
# returned leaf-card planes. One solid mass per asset (icosphere, subdiv 2), seeded noise on the
# radius for soft lumps. D49 makes the material the painted path that won round 22: storybook
# gradient stops from the picked round 20 refs (D44), two-octave brush noise, dabs, and for trees
# the scalloped contact shadow, crease, under-crown shade and bark dashes of the approved b6 paint.
# Bushes paint as one crown, boulders get a grounding band and patches. A rebuild with the same
# seed makes the same mesh and the same texture.
import bmesh
import bpy
import math
import random

from mathutils import Vector, noise

SHRINK = 0.95  # headroom for the seeded noise; build() clamps any axis that still overshoots
W, H = 512, 512  # painted texture; the b6 paint was tuned at this size
BOUND = 0.24  # texture v where the trunk band ends and the crown begins (remap: trunk .02-.18, crown .30-.98)
CROWN_BOT = 0.30
# grounding band colour for the kinds that stand on the ground without a trunk
GROUND = {"bush": "#3f4a2a", "boulder": "#57503e"}

# asset_id: kind, seed, gradient stops as (t, hex) from mesh bottom to top
LOOKS = {
    "nature_bush": ("bush", 11,
        [(0.0, "#487032"), (0.55, "#8faf3e"), (1.0, "#97b743")], "refs/bush-look1.png"),
    "nature_bush.2": ("bush", 12,
        [(0.0, "#51703b"), (0.55, "#7a933a"), (1.0, "#8ea93c")], "refs/bush-look2.png"),
    "nature_bush.3": ("bush", 13,
        [(0.0, "#476333"), (0.55, "#7f8737"), (1.0, "#91973e")], "refs/bush-look3.png"),
    # crown darks of the .2 and .3 looks are the sampled mid x 0.78, the ratio the look 1 ref pair measures
    "nature_leaf_tree": ("tree", 21,
        [(0.0, "#684e40"), (0.14, "#916d59"),           # trunk, sampled from the trunk strip of the ref
         (0.30, "#3f6b38"), (0.65, "#477c3f"), (1.0, "#8fb03a")], "refs/leaf-tree-look1.png"),
    "nature_leaf_tree.2": ("tree", 22,
        [(0.0, "#5c3522"), (0.14, "#80472e"),
         (0.30, "#48682a"), (0.65, "#5d8531"), (1.0, "#7ea634")], "refs/leaf-tree-look2.png"),
    "nature_leaf_tree.3": ("tree", 23,
        [(0.0, "#5b311d"), (0.14, "#7f4527"),
         (0.30, "#41632f"), (0.65, "#557938"), (1.0, "#93a83c")], "refs/leaf-tree-look3.png"),
    # boulder stops ordered by luminance; look 3 keeps its olive top as sampled
    "nature_boulder": ("boulder", 31,
        [(0.0, "#8d795b"), (0.5, "#947d5b"), (1.0, "#ccb69a")], "refs/boulder-look1.png"),
    "nature_boulder.2": ("boulder", 32,
        [(0.0, "#817465"), (0.5, "#858161"), (1.0, "#aa9d83")], "refs/boulder-look2.png"),
    "nature_boulder.3": ("boulder", 33,
        [(0.0, "#9f9c57"), (0.5, "#a6907c"), (1.0, "#c8b8a0")], "refs/boulder-look3.png"),
}

AMP = {"bush": 0.07, "tree": 0.05, "boulder": 0.10}


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


def lump(name, rx, ry, rz, centre_z, amp, rng):
    """Icosphere with seeded noise on the radius: soft lumps, one closed solid."""
    # 80 tris: under the 300 budget, so normalise never decimates. Decimate collapse
    # welds the UV seam and the gradient loses its top half (measured: v max 0.47).
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
    ob = bpy.context.active_object
    ob.name = ob.data.name = name
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for v in bm.verts:
        f = 1.0 + amp * (rng.random() * 2 - 1)
        v.co.x *= rx * f
        v.co.y *= ry * f
        v.co.z *= rz * f
    bm.to_mesh(ob.data)
    bm.free()
    ob.location.z = centre_z
    return ob


def remap_v(ob, lo, hi, cap_t=0.02):
    # the ico sphere's UV v natively spans only [0, 0.472]; rescale what is there.
    # A cylinder's cap fans stretch the mesh-wide min/max far past the side strip
    # (measured: sides ended up in the top 44% of the band), so scale by the side
    # faces and park the caps inside the band: cap_t is the fraction along it.
    # Trees keep 0.02 (the approved b6 pixels): the trunk is the cylinder. A bush
    # or boulder is triangle-only, takes the whole-mesh fallback and its top pole
    # lands at hi by itself; cap_t matters again for quad-side kinds (a stalk).
    uv = ob.data.uv_layers.active
    sides = [li for p in ob.data.polygons if len(p.vertices) == 4 for li in p.loop_indices]
    if not sides:
        sides = [loop.index for loop in ob.data.loops]
    ys = [uv.data[li].uv.y for li in sides]
    y0, y1 = min(ys), max(ys)
    for li in sides:
        uv.data[li].uv.y = lo + (hi - lo) * (uv.data[li].uv.y - y0) / (y1 - y0)
    for p in ob.data.polygons:
        if len(p.vertices) > 4:
            for li in p.loop_indices:
                uv.data[li].uv.y = lo + cap_t * (hi - lo)


def union(base, cutter):
    m = base.modifiers.new("u", "BOOLEAN")
    m.operation, m.solver, m.object = "UNION", "EXACT", cutter
    bpy.context.view_layer.objects.active = base
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def painted_material(name, kind, stops, seed):
    """The D49 paint. Tree = the b6 board's approved paint verbatim (same seed, same
    rng draw order, so look 1 rebuilds the picked texture byte for byte); the crown
    mid stop sits at 0.6 of the band as tuned in the b6 rounds. Bush paints as one
    crown with a scalloped grounding band; boulder adds larger soft patches."""
    rng = random.Random(seed + 2000)
    img = bpy.data.images.new(name + "_tex", width=W, height=H)
    img.colorspace_settings.name = "sRGB"
    stops = [(t, rgb(c)) for t, c in stops]
    if kind == "tree":
        trunk_stops = [(0.0, stops[0][1]), (1.0, stops[1][1])]
        crown_stops = [(0.0, stops[2][1]), (0.6, stops[3][1]), (1.0, stops[4][1])]
    else:
        trunk_stops, crown_stops = None, stops
    p1, p2 = rng.random() * 6.28, rng.random() * 6.28
    flat = [0.0] * (W * H * 4)
    for y in range(H):
        v = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            if kind == "tree":
                if v < BOUND:
                    # ref trunk (measured off leaf-tree-look1): brightest mid third,
                    # ~15-20% darker at the ground, darker again under the canopy; a
                    # full-range bottom-to-top gradient reads airbrushed, this does not.
                    # Visible trunk samples v .02-.154 (junction z~0.95), uv top .18 is
                    # buried inside the crown
                    b = v / BOUND
                    c = grad(trunk_stops, 0.72 + 1.54 * b - 1.96 * b * b)
                    # canopy contact shadow: 40-50% darker desaturated green-brown,
                    # scalloped edge (2-3 bumps round the trunk), reaching ~25% of the
                    # visible trunk height (0.134 of v) below the junction at 0.154
                    wob = 0.012 + 0.016 * math.sin(u * 2 * math.pi * 2 + p1)
                    wob += 0.006 * math.sin(u * 2 * math.pi * 5 + p2)
                    k = min(1.0, max(0.0, (v - (0.118 + wob)) / 0.007))
                    c = lerp(c, rgb("#3f4a2a"), k)
                    # painted crease: darkest line just under the junction (v .154),
                    # visible on the trunk, not buried inside the crown
                    k2 = min(1.0, max(0.0, (v - (0.131 + 0.4 * wob)) / 0.008))
                    c = lerp(c, rgb("#2c3520"), 0.45 * k2)
                else:
                    c = grad(crown_stops, (v - BOUND) / (1 - BOUND))
                    wob = 0.014 + 0.022 * (0.5 + 0.5 * math.sin(u * 2 * math.pi * 4 + p2))
                    wob += 0.009 * math.sin(u * 2 * math.pi * 5 + p1)
                    k = min(1.0, max(0.0, ((CROWN_BOT + 0.10 + wob) - v) / 0.05))
                    c = lerp(c, rgb("#33502c"), 0.35 * k)
            else:
                c = grad(crown_stops, v)
                # grounding band: the seam idea carried to masses without a trunk, a
                # scalloped dark collar where the thing meets the ground
                wob = 0.016 + 0.020 * math.sin(u * 2 * math.pi * 2 + p1)
                wob += 0.008 * math.sin(u * 2 * math.pi * 5 + p2)
                k = min(1.0, max(0.0, ((0.10 + wob) - v) / 0.035))
                c = lerp(c, rgb(GROUND[kind]), 0.35 * k)
            n = noise.noise(Vector((x / 56.0, y / 56.0, 3.1))) * 0.09
            n += noise.noise(Vector((x / 17.0, y / 17.0, 7.7))) * 0.05
            c = tuple(ch * (1.0 + n) for ch in c)
            o = (y * W + x) * 4
            flat[o:o + 3] = c
            flat[o + 3] = 255

    def dab(cx, cy, r, a, change):
        # fade near v=1 (the UV pole smears dabs into spokes); wrap in u so a dab cut
        # at the texture edge does not show a hard line on the mesh seam
        a *= min(1.0, max(0.0, (0.97 * H - cy) / (0.07 * H)))
        for dy in range(-int(r), int(r) + 1):
            yy = cy + dy
            if 0 <= yy < H:
                for dx in range(-int(r), int(r) + 1):
                    d = math.hypot(dx, dy) / r
                    if d < 1.0:
                        o = (yy * W + (cx + dx) % W) * 4
                        k = a * (1.0 - d) ** 1.6
                        flat[o:o + 3] = [max(0, min(255, ch + change * k)) for ch in flat[o:o + 3]]

    if kind == "tree":  # the b6 counts: crown dabs plus trunk bark
        for _ in range(70):
            dab(rng.randrange(W), int(0.30 * H + rng.random() * 0.68 * H),
                4 + rng.random() * 11, 0.10 + rng.random() * 0.16, 28 + rng.random() * 50)
        for _ in range(26):
            dab(rng.randrange(W), int((0.32 + rng.random() * 0.64) * H),
                5 + rng.random() * 13, 0.10 + rng.random() * 0.14, -(20 + rng.random() * 26))
        for _ in range(18):  # crisp stipples: small sharp dabs that survive magnification
            dab(rng.randrange(W), int((0.34 + rng.random() * 0.58) * H),
                2.5 + rng.random() * 2.5, 0.28 + rng.random() * 0.14, 40 + rng.random() * 35)
        for _ in range(7):  # ref: 6-8 soft bark dashes, 10-25% of trunk width, 20-40%
            sx, ph = rng.randrange(W), rng.random() * 6.28  # darker, lower two thirds
            w = 7.0 + rng.random() * 7.0  # sigma: FWHM ~8-16% of the visible width
            frac = 0.20 + rng.random() * 0.15
            yy0 = int((0.035 + rng.random() * 0.05) * H)
            yy1 = yy0 + int((0.02 + rng.random() * 0.022) * H)  # 15-30% of visible height
            for yy in range(yy0, yy1):
                t = (yy - yy0) / max(1, yy1 - yy0 - 1)
                fade = math.sin(t * math.pi)  # taper both ends
                xx = int(sx + 3.0 * math.sin(t * 6.28 + ph))
                for k in range(-24, 25):
                    o = (yy * W + (xx + k) % W) * 4
                    fall = math.exp(-(k / w) ** 2)
                    flat[o:o + 3] = [max(0, ch * (1.0 - frac * fade * fall)) for ch in flat[o:o + 3]]
    elif kind == "bush":  # one crown, no trunk: slightly fewer dabs over the whole mass
        for _ in range(45):
            dab(rng.randrange(W), int((0.06 + rng.random() * 0.90) * H),
                4 + rng.random() * 11, 0.10 + rng.random() * 0.16, 28 + rng.random() * 50)
        for _ in range(16):
            dab(rng.randrange(W), int((0.08 + rng.random() * 0.86) * H),
                5 + rng.random() * 13, 0.10 + rng.random() * 0.14, -(20 + rng.random() * 26))
        for _ in range(12):
            dab(rng.randrange(W), int((0.10 + rng.random() * 0.82) * H),
                2.5 + rng.random() * 2.5, 0.28 + rng.random() * 0.14, 40 + rng.random() * 35)
    else:  # boulder: flatter mass, fewer and larger soft patches, no crisp stipple
        for _ in range(18):
            dab(rng.randrange(W), int((0.08 + rng.random() * 0.86) * H),
                8 + rng.random() * 12, 0.08 + rng.random() * 0.12, 22 + rng.random() * 40)
        for _ in range(12):
            dab(rng.randrange(W), int((0.10 + rng.random() * 0.82) * H),
                9 + rng.random() * 11, 0.08 + rng.random() * 0.10, -(16 + rng.random() * 22))
    img.pixels[:] = [v / 255.0 for v in flat]
    img.pack()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def clamp(ob, dims):
    for i, key in enumerate(("max_x", "max_y", "max_z")):
        ext = max(v.co[i] for v in ob.data.vertices) - min(v.co[i] for v in ob.data.vertices)
        if ext > dims[key]:
            ob.scale[i] *= dims[key] / ext


def tapered_trunk(name, rb, rt, h):
    """Blender 5.2's cylinder operator takes one radius; the taper is done on the top ring."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=rb, depth=h)
    ob = bpy.context.active_object
    ob.name = ob.data.name = name
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= rt / rb
            v.co.y *= rt / rb
    bm.to_mesh(ob.data)
    bm.free()
    ob.location.z = h / 2
    return ob


def build(asset):
    kind, seed, stops, _ref = LOOKS[asset["asset_id"]]
    d = asset["dimensions"]
    rng = random.Random(seed)
    name = asset["asset_id"]
    if kind == "tree":
        rz = 0.23 * d["max_z"] * SHRINK
        cz = d["max_z"] * SHRINK - rz
        crown = lump(name, d["max_x"] / 2 * SHRINK, d["max_y"] / 2 * SHRINK, rz, cz, AMP[kind], rng)
        remap_v(crown, 0.30, 0.98)
        h = cz - 0.55 * rz
        slim = 1 if d["max_x"] > 0.7 else 0.75
        trunk = tapered_trunk("trunk", 0.085 * slim, 0.058 * slim, h)
        remap_v(trunk, 0.02, 0.18)
        union(crown, trunk)
        ob = crown
    else:
        ob = lump(name, d["max_x"] / 2 * SHRINK, d["max_y"] / 2 * SHRINK, d["max_z"] / 2 * SHRINK,
                  d["max_z"] / 2 * SHRINK, AMP[kind], rng)
        remap_v(ob, 0.02, 0.98, cap_t=0.98)
    clamp(ob, d)
    # the boolean leaves an empty slot 0; faces point at it and render untextured white
    ob.data.materials.clear()
    ob.data.materials.append(painted_material(name, kind, stops, seed))
    for p in ob.data.polygons:
        p.use_smooth = True
    return {"kind": kind, "seed": seed, "stops": [s[1] for s in stops]}
