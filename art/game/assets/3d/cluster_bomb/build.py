import math

import bmesh
import bpy

DIAMETER = 0.30
SEGMENTS = 8
BAND = 0.012       # how far the iron band stands proud of the ball
BAND_LAT = 12      # degrees above and below the equator


def build(asset):
    r = DIAMETER / 2 - BAND
    rings = [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))) for a in (-50, -BAND_LAT)]
    rings += [(rings[-1][0] + BAND, rings[-1][1]), (rings[-1][0] + BAND, -rings[-1][1]), (rings[-1][0], -rings[-1][1])]
    rings += [(r * math.cos(math.radians(50)), r * math.sin(math.radians(50)))]
    bm = bmesh.new()
    ring_verts = [[bm.verts.new((rad * math.cos(2 * math.pi * k / SEGMENTS), rad * math.sin(2 * math.pi * k / SEGMENTS), z))
                   for k in range(SEGMENTS)] for rad, z in rings]
    for lo, hi in zip(ring_verts, ring_verts[1:]):
        for k in range(SEGMENTS):
            bm.faces.new((lo[k], lo[(k + 1) % SEGMENTS], hi[(k + 1) % SEGMENTS], hi[k]))
    for ring, z in ((ring_verts[0], -r), (ring_verts[-1], r)):
        pole = bm.verts.new((0, 0, z))
        for k in range(SEGMENTS):
            a, b = ring[k], ring[(k + 1) % SEGMENTS]
            bm.faces.new((a, b, pole) if z > 0 else (b, a, pole))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Sphere UVs like the shell's, so the iron painter keeps them instead of projecting a box onto the ball.
    uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        us = [(math.atan2(lp.vert.co.y, lp.vert.co.x) / (2 * math.pi)) % 1 for lp in f.loops]
        for lp, u in zip(f.loops, us):
            if max(us) - u > 0.5:  # the face across the seam
                u += 1
            lp[uv].uv = (u, 0.5 + math.asin(max(-1, min(1, lp.vert.co.z / r))) / math.pi)
    me = bpy.data.meshes.new("cluster_bomb")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("cluster_bomb", me)
    bpy.context.scene.collection.objects.link(ob)
