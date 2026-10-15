import os

import bpy

from .geo import parts


def run(asset, asset_dir):
    objs = parts(asset)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    glb = asset_dir + "/final.glb"
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT")
    blend = asset_dir + "/source.blend"
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    return {"glb_bytes": os.path.getsize(glb), "blend_bytes": os.path.getsize(blend)}
