# Shared builder for the nine nature looks: bush, leaf tree, boulder in three colourways each.
# D41 wants big stylized solids like the cover art, D45 makes foliage procedural after image-to-3D
# returned leaf-card planes. One solid mass per asset (icosphere, subdiv 2), seeded noise on the
# radius for soft lumps. C22 makes the material flat: one solid material per band, no texture - the
# tree keeps its two bands (trunk and crown, split at the UV v the texture used), the bush and the
# boulder wear one - each named for its palette role and coloured by the mean of the look's stops.
# A rebuild with the same seed makes the same mesh.
import bmesh
import bpy
import random

from mathutils import Vector

SHRINK = 0.95  # headroom for the seeded noise; build() clamps any axis that still overshoots
BOUND = 0.24  # texture v where the trunk band ends and the crown begins (remap: trunk .02-.18, crown .30-.98)

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


def flat_material(name, col):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    lin = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in
           (c / 255 for c in col)]
    m.diffuse_color = (*lin, 1)
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin, 1.0)
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Metallic"].default_value = 0.0
    return m


def mean(stops):
    return tuple(sum(rgb(c)[i] for _, c in stops) / len(stops) for i in range(3))


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
    if kind == "tree":  # the two bands of the painted look, split where its texture split them
        ob.data.materials.append(flat_material("wood", mean(stops[:2])))
        ob.data.materials.append(flat_material("leaf", mean(stops[2:])))
        uv = ob.data.uv_layers.active
        for p in ob.data.polygons:
            v = sum(uv.data[li].uv.y for li in p.loop_indices) / len(p.vertices)
            p.material_index = 0 if v < BOUND else 1
    else:
        ob.data.materials.append(flat_material("leaf" if kind == "bush" else "rock", mean(stops)))
    for p in ob.data.polygons:
        p.use_smooth = True
    return {"kind": kind, "seed": seed, "stops": [s[1] for s in stops]}
