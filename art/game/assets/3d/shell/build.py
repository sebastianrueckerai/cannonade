import bpy

DIAMETER = 0.28
SEGMENTS = 16
RINGS = 10


def build(asset):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=SEGMENTS, ring_count=RINGS, radius=DIAMETER / 2)
    ob = bpy.context.active_object
    ob.name = ob.data.name = "shell"
