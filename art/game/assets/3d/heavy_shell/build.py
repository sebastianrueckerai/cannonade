import math

import bmesh
import bpy

RADIUS = 0.15
LENGTH = 0.64       # base to tip; the nose points along +Y, the flight axis in the game
NOSE = 0.30         # length of the tangent ogive
BAND = 0.012        # how far the driving band stands proud of the body
SEGMENTS = 16
NOSE_RINGS = 6


def profile():
    """(radius, y) from the base to the last ring below the tip."""
    base, top = -LENGTH / 2, LENGTH / 2 - NOSE
    pts = [(RADIUS - 0.02, base), (RADIUS, base + 0.02),
           (RADIUS, base + 0.07), (RADIUS + BAND, base + 0.075), (RADIUS + BAND, base + 0.115), (RADIUS, base + 0.12),
           (RADIUS, top)]
    rho = (RADIUS ** 2 + NOSE ** 2) / (2 * RADIUS)
    for k in range(1, NOSE_RINGS):
        x = NOSE * k / NOSE_RINGS
        pts.append((math.sqrt(rho ** 2 - x ** 2) + RADIUS - rho, top + x))
    return pts


def build(asset):
    bm = bmesh.new()
    rings = [[bm.verts.new((r * math.cos(2 * math.pi * k / SEGMENTS), y, r * math.sin(2 * math.pi * k / SEGMENTS)))
              for k in range(SEGMENTS)] for r, y in profile()]
    for lo, hi in zip(rings, rings[1:]):
        for k in range(SEGMENTS):
            bm.faces.new((lo[k], hi[k], hi[(k + 1) % SEGMENTS], lo[(k + 1) % SEGMENTS]))
    for ring, y in ((rings[0], -LENGTH / 2), (rings[-1], LENGTH / 2)):
        pole = bm.verts.new((0, y, 0))
        for k in range(SEGMENTS):
            bm.faces.new((ring[k], ring[(k + 1) % SEGMENTS], pole))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Cylinder UVs round the axis, so the iron painter keeps them instead of projecting a box.
    uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        us = [(math.atan2(lp.vert.co.z, lp.vert.co.x) / (2 * math.pi)) % 1 for lp in f.loops]
        for lp, u in zip(f.loops, us):
            if max(us) - u > 0.5:  # the face across the seam
                u += 1
            lp[uv].uv = (u, lp.vert.co.y / LENGTH + 0.5)
    me = bpy.data.meshes.new("heavy_shell")
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    ob = bpy.data.objects.new("heavy_shell", me)
    bpy.context.scene.collection.objects.link(ob)
