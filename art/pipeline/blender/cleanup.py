# Sent to Blender by pipeline/cleanup.py with JOB prepended, see the cleanup.json keys there.
# Raw mode renders the run as it came from the API. Otherwise: turn, size, needle faces pruned, origin at the
# ground centre, texture scaled down, the team faces on a first material of their own, then final.glb, source.blend
# and the renders.
import bmesh
import colorsys
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

TEAM_HUE = (0.58, 0.72)     # royal blue of the sketches, hue as a fraction of the circle
TEAM_MIN_SAT = 0.35


def load(path):
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def box(ob):
    ps = [v.co for v in ob.data.vertices]
    return Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)])


def transform(ob, m):
    ob.data.transform(m)
    ob.data.update()


def drop_loose_verts(ob):
    # the API runs carry vertices no face uses; they would skew every bbox the cleanup measures
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    gone = sum(1 for v in bm.verts if not v.link_faces)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.to_mesh(ob.data)
    bm.free()
    return gone


def prune_slivers(ob, ratio=20.0):
    # the runs carry a few needle triangles at eaves and ridges, hair-thin spikes past the silhouette
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    gone = 0
    for f in [f for f in bm.faces
              if max((e.calc_length() for e in f.edges), default=0.0) > ratio * math.sqrt(max(f.calc_area(), 1e-12))]:
        gone += 1
        bm.faces.remove(f)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.to_mesh(ob.data)
    bm.free()
    return gone


def fill_holes(ob, min_edges=4):
    # the API output is a patchwork of strips; close only the boundary loops big enough to see,
    # the sub-pixel pinholes between strips are not worth their triangles
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=5e-4)  # pinhole verts are coincident, welding closes them face-free
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.mesh.select_mode(type="EDGE")
    bpy.ops.mesh.select_non_manifold(use_wire=False, use_boundary=True, use_multi_face=False,
                                     use_non_contiguous=False, use_verts=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    loops = []
    seen = set()
    for e in bm.edges:
        if not e.select or e in seen:
            continue
        loop, cur = [], e
        while cur is not None and cur not in seen:
            seen.add(cur)
            loop.append(cur)
            cur = next((le for v in cur.verts for le in v.link_edges if le.select and le not in seen), None)
        loops.append(loop)
    filled = 0
    for loop in loops:
        if len(loop) >= min_edges:
            filled += len(bmesh.ops.contextual_create(bm, geom=loop).get("faces", []))
    bm.to_mesh(ob.data)
    bm.free()
    return filled


def split_team(ob):
    """Faces whose texture colour is royal blue move to a new first material `team`, flat white, untextured, so the
    game's colour shows as it is. Samples at the centroid and partway to each corner, away from the edges of the
    UV island where the texture bleeds, vote."""
    tex_mat = ob.data.materials[0]
    img = next(n.image for n in tex_mat.node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    team = bpy.data.materials.new("team")
    team.use_nodes = True
    bsdf = team.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    team.diffuse_color = (1, 0, 1, 1)  # magenta in the renders only, the export carries the white base colour
    ob.data.materials.clear()
    ob.data.materials.append(team)
    ob.data.materials.append(tex_mat)
    n = 0
    for p in ob.data.polygons:
        loops = list(p.loop_indices)
        c = sum((uv[i].uv for i in loops), Vector((0, 0))) / len(loops)
        pts = [c] + [c.lerp(uv[i].uv, 0.6) for i in loops]
        votes = 0
        for q in pts:
            r, g, b, _ = px[min(h - 1, max(0, int(q.y * h))), min(w - 1, max(0, int(q.x * w)))]
            hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
            votes += TEAM_HUE[0] <= hue <= TEAM_HUE[1] and sat >= TEAM_MIN_SAT and val > 0.08
        p.material_index = 0 if votes * 2 > len(pts) else 1
        n += votes * 2 > len(pts)
    return int(n) + fill_team(ob)


def fill_team(ob, passes=4):
    """A face the vote left out inside a team surface joins it: the texture shades a cone roof's slice or an annex
    roof's slope too pale for the hue vote, and the slice stayed stone (Sebastian, 2026-10-20). A face with more
    team neighbours across its edges than not becomes team, and so does a sloping face of some size with any
    team neighbour, a roof slope beside its other half; a wall face under a roof edge stands vertical and stays."""
    # edges keyed by vertex position, not index: a generated mesh doubles its vertices along a UV seam, and the
    # pale slice sits on that seam
    verts = ob.data.vertices
    key = lambda i: tuple(round(c, 3) for c in verts[i].co)
    edge_of = lambda a, b: (min(key(a), key(b)), max(key(a), key(b)))
    edge_faces = {}
    polys = ob.data.polygons
    edges = {}
    for p in polys:
        edges[p.index] = [edge_of(a, b) for a, b in p.edge_keys]
        for k in edges[p.index]:
            edge_faces.setdefault(k, []).append(p.index)
    filled = 0
    for _ in range(passes):
        grew = 0
        for p in polys:
            if p.material_index == 0:
                continue
            team = sum(polys[q].material_index == 0 for k in edges[p.index] for q in edge_faces[k] if q != p.index)
            slope = 0.25 < p.normal.z < 0.95 and p.area > 0.05
            if team * 2 > len(edges[p.index]) or (team >= 1 and slope):
                p.material_index = 0
                grew += 1
        filled += grew
        if grew == 0:
            break
    return filled


def team_deck(ob, spec):
    """A flat roof without its own colour, such as the deck inside battlements, joins the team material: the
    horizontal faces between spec["z"] heights within spec["inside"] metres of the centre. Faces that point down
    are flipped, so the light falls on them from above."""
    lo, hi = spec["z"]
    n = 0
    for p in ob.data.polygons:
        c = p.center
        if abs(p.normal.z) > 0.9 and lo < c.z < hi and abs(c.x) < spec["inside"] and abs(c.y) < spec["inside"]:
            if p.normal.z < 0:
                p.flip()
            p.material_index = 0
            n += 1
    ob.data.update()
    return n


def render(ob, out_dir, prefix=""):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.show_cavity = False
    sc.render.resolution_x = sc.render.resolution_y = 360
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("w")
    lo, hi = box(ob)
    centre, size = (lo + hi) / 2, max(hi - lo)
    cd = bpy.data.cameras.new("cam")
    cd.type, cd.ortho_scale = "ORTHO", size * 1.3
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for i, (name, az) in enumerate([("front", 0), ("right", 90), ("back", 180), ("left", 270), ("front_left", -45)]):
        a, el = math.radians(az), math.radians(30)
        cam.location = centre + Vector((math.sin(a) * math.cos(el), -math.cos(a) * math.cos(el), math.sin(el))) * size * 4
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, f"{prefix}{i}_{name}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


ob = load(JOB["glb"])
res = {}
if not JOB["raw"]:
    transform(ob, Matrix.Rotation(math.radians(JOB.get("turn", 0)), 4, "Z"))
    lo, hi = box(ob)
    dims = hi - lo
    if "size" in JOB:
        s = Vector([JOB["size"][i] / dims[i] for i in range(3)])
    else:
        k = JOB["fit"] / max(dims.x, dims.y)
        s = Vector((k, k, k))
    transform(ob, Matrix.Diagonal((*s, 1)))
    res["slivers_pruned"] = prune_slivers(ob)
    if JOB.get("max_tris"):
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        if tris > JOB["max_tris"]:
            dm = ob.modifiers.new("Decimate", "DECIMATE")
            dm.ratio = JOB["max_tris"] / tris
            dm.delimit = {"UV"} if JOB.get("decimate_uv", True) else set()
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier=dm.name)
            res["decimated_to"] = JOB["max_tris"]
            res["loose_verts_dropped"] = drop_loose_verts(ob)
    if JOB.get("fill_holes"):
        # after the decimate: fill faces carry no UVs, and the UV delimit would block every collapse
        res["holes_filled"] = fill_holes(ob)
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        if JOB.get("max_tris") and tris > JOB["max_tris"]:
            dm = ob.modifiers.new("Decimate", "DECIMATE")
            dm.ratio = JOB["max_tris"] / tris
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier=dm.name)
            res["refilled_decimate_to"] = JOB["max_tris"]
            res["loose_verts_dropped_2"] = drop_loose_verts(ob)
    lo, hi = box(ob)
    transform(ob, Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    px = JOB.get("texture_px", 512)
    for img in bpy.data.images:
        if img.size[0] > px:
            img.scale(px, px)
            img.pack()
    if JOB.get("team"):
        res["team_faces"] = split_team(ob)
    if JOB.get("team_deck"):
        res["deck_faces"] = team_deck(ob, JOB["team_deck"])
    if JOB.get("paint"):
        import sys
        sys.path.insert(0, JOB["pipeline"])
        import importlib
        import blender.paint
        _paint = importlib.reload(blender.paint)
        pspec = dict(JOB["paint"])
        # a forced world-metre projection replaces the API's UV islands, so the
        # D49 bands land by height on the keep as they do on the walls
        for uv in list(ob.data.uv_layers):
            ob.data.uv_layers.remove(uv)
        _paint.cube_uv(ob, top_planar=pspec.pop("top_planar", True))
        mat = _paint.painted_material(ob, pspec, keep_slots=True)
        stone = next(i for i, m in enumerate(ob.data.materials) if m.name != "team")
        ob.data.materials[stone] = mat
        res["painted"] = mat.name
    ob.name = ob.data.name = JOB["part"]
    lo, hi = box(ob)
    res.update({"dims_m": [round(v, 3) for v in hi - lo], "tris": sum(len(p.vertices) - 2 for p in ob.data.polygons),
                "materials": [m.name for m in ob.data.materials]})
    bpy.ops.wm.save_as_mainfile(filepath=JOB["blend"], compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=JOB["export"], export_format="GLB", use_selection=True, export_yup=True,
                              export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=90)
render(ob, JOB["out_dir"])
result = res
