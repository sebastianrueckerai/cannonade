import bmesh
import bpy


def build(asset):
    d = asset["dimensions"]
    length, thick, height = d["max_x"], d["max_y"], d["max_z"]
    body_h = height * 0.8
    n = 3
    w = length / (2 * n)
    top = []
    for k in range(2 * n):
        x0 = -length / 2 + k * w
        z = height if k % 2 == 0 else body_h
        top += [(x0, z), (x0 + w, z)]
    profile = [(-length / 2, 0.0), (length / 2, 0.0)] + top[::-1]
    bm = bmesh.new()
    verts = [bm.verts.new((x, -thick / 2, z)) for x, z in profile]
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    bmesh.ops.translate(bm, verts=[g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)], vec=(0, thick, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("wall")
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new("wall", mesh)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new(asset.get("materials", {}).get("wall", "wall"))
    mat.diffuse_color = (0.6, 0.6, 0.6, 1)
    mesh.materials.append(mat)
