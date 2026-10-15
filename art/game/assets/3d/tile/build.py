import bmesh
import bpy

SIZE, HEIGHT, CHAMFER = 1.0, 0.2, 0.05


def build(asset):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= SIZE
        v.co.y *= SIZE
        v.co.z = HEIGHT if v.co.z > 0 else 0.0
    top = [e for e in bm.edges if all(v.co.z > HEIGHT / 2 for v in e.verts)]
    bmesh.ops.bevel(bm, geom=top, offset=CHAMFER, offset_type="OFFSET", segments=1, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tile")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("tile", me)
    bpy.context.scene.collection.objects.link(ob)
