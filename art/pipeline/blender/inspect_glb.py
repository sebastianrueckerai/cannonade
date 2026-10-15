# Sent to Blender by pipeline/meshsheet.py with GLBS, OUT_DIR and FOOTPRINT prepended.
# Per generated .glb: the raw numbers, the model scaled to fill its footprint on the ground, five renders.
import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

VIEWS = {  # name: (azimuth, elevation, colour, light)
    "tex_front_left": (-45, 30, "TEXTURE", "STUDIO"),
    "tex_back_right": (135, 30, "TEXTURE", "STUDIO"),
    "tex_side": (0, 5, "TEXTURE", "STUDIO"),
    "game_default": (-30, 60, "TEXTURE", "STUDIO"),
    "faces": (-45, 30, "SINGLE", "STUDIO"),
    "parts": (-45, 30, "RANDOM", "STUDIO"),
}
PX_PER_M_DEFAULT = 24.7  # gameplay_contract.yaml, versus default view


def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def bbox(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return (Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)]))


def stats(objs, weld):
    """Counts on a copy welded at the UV seams, where a .glb splits its vertices."""
    nm = islands = 0
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
        nm += sum(1 for e in bm.edges if not e.is_manifold)
        seen = set()
        for v in bm.verts:
            if v in seen:
                continue
            islands += 1
            stack = [v]
            while stack:
                x = stack.pop()
                if x in seen:
                    continue
                seen.add(x)
                stack.extend(e.other_vert(x) for e in x.link_edges)
        bm.free()
    return {
        "objects": len(objs),
        "islands": islands,
        "verts": sum(len(o.data.vertices) for o in objs),
        "tris": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs),
        "non_manifold_edges": nm,
        "materials": len({m.name for o in objs for m in o.data.materials if m}),
        "textures": sorted({f"{i.size[0]}x{i.size[1]}" for i in bpy.data.images if i.size[0]}),
    }


def place(cam, target, dist, az, el):
    az, el = math.radians(az), math.radians(el)
    cam.location = target + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


result = {}
for path in GLBS:
    stem = os.path.splitext(os.path.basename(path))[0]
    out = os.path.join(OUT_DIR, stem)
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = meshes()
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = bbox(objs)
    raw_dims = [round(v, 3) for v in hi - lo]
    if hi.y - lo.y > hi.x - lo.x:  # the longest side, the barrel, along X, so the side view shows the profile
        for o in objs:
            o.rotation_euler.z += math.pi / 2
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        lo, hi = bbox(objs)
    s = FOOTPRINT / max(hi.x - lo.x, hi.y - lo.y)
    for o in objs:
        o.location = (o.location - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))) * s
        o.scale *= s
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = bbox(objs)
    weld = FOOTPRINT * 1e-4
    st = stats(objs, weld)
    st.update({"raw_dims": raw_dims, "dims_m": [round(v, 3) for v in hi - lo], "file_mb": round(os.path.getsize(path) / 1e6, 2)})

    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = sc.render.resolution_y = 360
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.82, 0.82, 0.82)
    sh = sc.display.shading
    sh.show_cavity = False
    sh.show_object_outline = False
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    centre = (lo + hi) / 2
    size = max(hi - lo)
    cam.data.ortho_scale = size * 1.3
    for name, (az, el, colour, light) in VIEWS.items():
        if name == "faces":
            for o in objs:
                bpy.context.view_layer.objects.active = o
                if o.data.has_custom_normals:
                    bpy.ops.mesh.customdata_custom_splitnormals_clear()
                o.data.shade_flat()
                o.modifiers.clear()
        if name == "parts":
            bpy.ops.object.select_all(action="SELECT")
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.remove_doubles(threshold=weld)
            bpy.ops.mesh.separate(type="LOOSE")
            bpy.ops.object.mode_set(mode="OBJECT")
        sh.color_type = colour
        sh.light = light
        sh.single_color = (0.75, 0.72, 0.68)
        game = name == "game_default"  # the ground around the footprint at the default view's pixel size
        cam.data.ortho_scale = FOOTPRINT * 1.6 if game else size * 1.3
        sc.render.resolution_x = sc.render.resolution_y = round(FOOTPRINT * 1.6 * PX_PER_M_DEFAULT) if game else 360
        place(cam, centre, size * 5, az, el)
        sc.render.filepath = os.path.join(out, name + ".png")
        bpy.ops.render.render(write_still=True)
    with open(os.path.join(out, "stats.json"), "w") as f:
        json.dump(st, f, indent=2)
    result[stem] = st
