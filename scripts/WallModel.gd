extends Node3D
## Wall wrapper: uses the art-layer model of the wall's shape and level, wall_line_base for line_base1 to
## line_base7, when it exists, otherwise gives the imported FBX the textures of the Unity materials (the FBX
## files only carry material names).

const TEX := "res://assets/fbx/"
static var _cache := {}


static func material_for(name: String) -> Material:
	var n := name.to_lower()
	var key := ""
	if n.contains("plaster"):
		key = "WhitePlaster.png"
	elif n.contains("rough") or n.contains("hewn"):
		key = "RoughStoneWall.png"
	elif n.contains("stone") or n.contains("bock"):
		key = "StoneBlocks.png"
	elif n.contains("roof"):
		key = "roofTilesxcf.png"
	elif n == "wood":
		key = "Wood.png"
	elif n.contains("wood") or n.contains("window"):
		key = "dark"
	else:
		return null
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	if key == "dark":
		m.albedo_color = Color(0.14117648, 0.098039225, 0.07058824)
	else:
		m.albedo_texture = load(TEX + key)
	m.roughness = 0.9
	_cache[key] = m
	return m


func _ready() -> void:
	var model := get_node("Model")
	var art := Art.instance("wall_" + model.scene_file_path.get_file().get_basename().rstrip("0123456789"))
	if art != null:
		remove_child(model)
		model.free()
		art.name = "Model"
		art.position = Vector3(0, Art.SLAB_TOP, 0)
		add_child(art)
		return
	for mi in find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var m := material_for(src.resource_name)
			if m != null:
				mi.set_surface_override_material(i, m)
