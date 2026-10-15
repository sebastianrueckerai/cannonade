import math

import bpy
from mathutils import Vector

from .geo import bbox, parts

# azimuth in degrees from the front (camera on -Y), elevation in degrees
VIEWS = {"1_front": (0, 0), "2_right": (90, 0), "3_back": (180, 0), "4_three_quarter": (45, 30)}


def place(cam, target, dist, az_deg, el_deg):
    az, el = math.radians(az_deg), math.radians(el_deg)
    offset = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * dist
    cam.location = target + offset
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def srgb(hexstr):
    return tuple(int(hexstr.lstrip("#")[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def linear(rgb):
    # Blender colour sockets are linear, the kit's hex values are sRGB
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in rgb)


def game_light(sc, light):
    # C11: the gameplay view lit like the game, from lighting_rules.yaml's picked
    # variant with its blender_eevee calibration (wall bands match a game screenshot within 2%).
    cal = light["blender_eevee"]
    el, az = math.radians(light["sun_elevation"]), math.radians(light["sun_azimuth"])
    to_sun = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    sun_data = bpy.data.lights.new("game_sun", "SUN")
    sun_data.color = linear(srgb(light["sun_colour"]))
    sun_data.energy = cal["sun_energy"]
    sun_data.angle = 0.02
    sun = bpy.data.objects.new("game_sun", sun_data)
    sun.rotation_euler = (-to_sun).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(sun)
    amb = linear(srgb(light["ambient_colour"]))
    amb = (amb[0], amb[1], amb[2] * cal["ambient_blue_scale"])
    w = bpy.data.worlds.new("game_world")
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    bg.inputs[0].default_value = (*amb, 1.0)
    bg.inputs[1].default_value = cal["ambient_strength"]
    cam_bg = nt.nodes.new("ShaderNodeBackground")
    cam_bg.inputs[0].default_value = (*linear(srgb(light["sky"])), 1.0)
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(bg.outputs[0], mx.inputs[1])
    nt.links.new(cam_bg.outputs[0], mx.inputs[2])
    nt.links.new(lp.outputs[0], mx.inputs[0])
    nt.links.new(mx.outputs[0], nt.nodes["World Output"].inputs[0])
    sc.world = w


def game_view(sc, light):
    # the game's grade in Blender: view transform plus exposure in stops, then
    # saturation and contrast as compositor nodes. Godot applies the adjustment
    # in display space after the tonemap, the nodes run in scene linear before
    # it; grade_sat scales the node saturation down so the calibration absorbs
    # that difference. The white point and glow have no equivalent; the shoulder
    # shape is the known gap.
    post = light.get("post") or {}
    cal = light.get("blender_eevee") or {}
    sc.view_settings.view_transform = {"filmic": "Filmic", "aces": "AgX"}.get(post.get("tonemap"), "Standard")
    if post.get("exposure"):  # Godot multiplies by exposure, Blender works in stops
        sc.view_settings.exposure = math.log2(post["exposure"])
    if post.get("saturation") or post.get("contrast"):
        nt = bpy.data.node_groups.new("game_grade", "CompositorNodeTree")
        nt.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        sc.compositing_node_group = nt
        rl = nt.nodes.new("CompositorNodeRLayers")
        hsv = nt.nodes.new("CompositorNodeHueSat")
        sat = post.get("saturation") or 1.0
        hsv.inputs["Saturation"].default_value = 1 + (sat - 1) * cal.get("grade_sat", 1.0)
        bc = nt.nodes.new("CompositorNodeBrightContrast")
        bc.inputs["Contrast"].default_value = post.get("contrast") or 0.0
        go = nt.nodes.new("NodeGroupOutput")
        nt.links.new(rl.outputs["Image"], hsv.inputs["Image"])
        nt.links.new(hsv.outputs["Image"], bc.inputs["Image"])
        nt.links.new(bc.outputs["Image"], go.inputs["Image"])


def run(asset, asset_dir, contract):
    objs = parts(asset)
    lo, hi = bbox(objs)
    centre = (lo + hi) / 2
    size = max(hi - lo)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "MATCAP"
    sh.show_cavity = True
    sh.color_type = "MATERIAL"
    sc.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("_preview_cam")
    cam_data.clip_end = max(100.0, size * 20)
    cam = bpy.data.objects.new("_preview_cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    out = []
    for name, (az, el) in VIEWS.items():
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = size * 1.25
        place(cam, centre, size * 4, az, el)
        sc.render.resolution_x = sc.render.resolution_y = 512
        sc.render.filepath = f"{asset_dir}/previews/views/{name}.png"
        bpy.ops.render.render(write_still=True)
        out.append(sc.render.filepath)
    # the wireframe view: a solid and a cluster of flat planes are told apart at a glance
    # here, while matcap and texture views can hide it (the session 08 bush gate miss)
    for o in objs:
        o.show_wire = o.show_all_edges = True
    sh.show_cavity = False
    cam_data.ortho_scale = size * 1.25
    place(cam, centre, size * 4, 0, 0)
    sc.render.filepath = f"{asset_dir}/previews/views/5_wire.png"
    bpy.ops.render.render(write_still=True)
    out.append(sc.render.filepath)
    for o in objs:
        o.show_wire = o.show_all_edges = False
    sh.show_cavity = True
    light = (contract or {}).get("light")
    c = (contract or {}).get("camera") or {}
    if light:
        sc.render.engine = "BLENDER_EEVEE"
        game_view(sc, light)
        game_light(sc, light)
        # the textured view: matcap shows only the flat base colour and the gameplay
        # view is a few pixels tall, so this is the only magnified preview of the
        # material itself (an empty material slot renders white exactly here)
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = size * 1.25
        place(cam, centre, size * 4, 0, 0)
        sc.render.resolution_x = sc.render.resolution_y = 512
        sc.render.filepath = f"{asset_dir}/previews/views/6_texture.png"
        bpy.ops.render.render(write_still=True)
        out.append(sc.render.filepath)
        if c.get("pitch_deg") is not None and c.get("fov_deg") and c.get("distance_m"):
            cam_data.type = "PERSP"
            cam_data.sensor_fit = "VERTICAL"
            cam_data.lens_unit = "FOV"
            cam_data.angle = math.radians(c["fov_deg"])
            place(cam, Vector((0, 0, 0)), c["distance_m"], 0, c["pitch_deg"])
            sc.render.resolution_x, sc.render.resolution_y = 1280, 720
            sc.render.filepath = f"{asset_dir}/previews/gameplay.png"
            bpy.ops.render.render(write_still=True)
            out.append(sc.render.filepath)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(cam_data)
    return out
