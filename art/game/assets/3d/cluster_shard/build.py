import math
import random

import bmesh
import bpy

SIZE = 0.12
POINTS = 10
SEED = 28  # of seeds 1 to 59, the chunk closest to 1 : 0.8 : 0.65


def build(asset):
    rng = random.Random(SEED)
    bm = bmesh.new()
    for _ in range(POINTS):  # points on a squashed ellipsoid: a jagged chunk, a little flatter than it is long
        u, v = rng.uniform(0, 2 * math.pi), math.acos(rng.uniform(-1, 1))
        bm.verts.new((math.sin(v) * math.cos(u) * 0.5, math.sin(v) * math.sin(u) * 0.42, math.cos(v) * 0.36))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    lo = [min(v.co[i] for v in bm.verts) for i in range(3)]
    hi = [max(v.co[i] for v in bm.verts) for i in range(3)]
    s = SIZE / max(hi[i] - lo[i] for i in range(3))
    for v in bm.verts:
        v.co = [(v.co[i] - (lo[i] + hi[i]) / 2) * s for i in range(3)]
    me = bpy.data.meshes.new("cluster_shard")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("cluster_shard", me)
    bpy.context.scene.collection.objects.link(ob)
