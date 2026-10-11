class_name Art
## The art layer. Drop files into res://assets/art/ and the game uses them, nothing else to wire.
##
##   3d/<id>.glb            a model for building id, "ship", "tile" or "wall_<fbx stem>" (wall_line_upper1)
##                          origin at the ground centre, Y up, metres, one tile = 1 m
##   ui/splash.png          splash screen image
##   ui/logo.png            title image on the menu
##   ui/menu_background.png
##   sky/world_panorama.png equirectangular sky
##   manifest.json          {"<id>": {"size": [x, y, z], "tolerance": 0.02}} written by the art pipeline
##
## A model part whose snake_case name maps to a prefab node in PascalCase (barrel -> Barrel,
## projectile_spawn -> ProjectileSpawn) is attached to that node, so pivots and spawn points keep
## working. Every other mesh of the prefab is hidden. Sizes are checked against the manifest once.

const DIR := "res://assets/art/"
const SLAB_TOP := 0.1

static var errors: Array[String] = []
static var _manifest := {}
static var _manifest_loaded := false
static var _checked := {}
static var _mesh_cache := {}


static func model_path(id: String) -> String:
	return DIR + "3d/" + id + ".glb"


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(model_path(id))


static func texture(name: String) -> Texture2D:
	var p := DIR + "ui/" + name
	return load(p) if ResourceLoader.exists(p) else null


static func sky_texture() -> Texture2D:
	var p := DIR + "sky/world_panorama.png"
	return load(p) if ResourceLoader.exists(p) else null


## The theme of the menu, splash and loading screens. The in-game HUD keeps the default theme until it is styled.
static func theme() -> Theme:
	var p := DIR + "ui/theme.tres"
	return load(p) if ResourceLoader.exists(p) else null


## A fresh instance of the model, or null when the file does not exist.
static func instance(id: String) -> Node3D:
	if not has_model(id):
		return null
	var node := (load(model_path(id)) as PackedScene).instantiate() as Node3D
	node.name = "Art"
	_check(id, node)
	return node


## Attaches the model `id` to the prefab root `go`. Returns false and leaves the prefab alone when
## there is no file. Call before the prefab enters the tree and before components look for anchors.
static func attach(go: Node3D, id: String) -> bool:
	var art := instance(id)
	if art == null:
		return false
	for mi in go.find_children("*", "MeshInstance3D", true, false):
		if mi.get_script() == null:
			mi.visible = false
	go.add_child(art)
	art.scale = Vector3(1.0 / go.scale.x, 1.0 / go.scale.y, 1.0 / go.scale.z)
	art.position = Vector3(0, SLAB_TOP, 0)
	for part in art.find_children("*", "Node3D", true, false):
		var target := go.find_child(part.name.to_pascal_case(), true, false)
		if target == null or not target is Node3D or art.is_ancestor_of(target):
			continue
		var part_rel := _rel(part, go)
		var parent_rel := _rel(target.get_parent(), go)
		var target_rel := _rel(target, go)
		target_rel.origin = part_rel.origin
		target.transform = parent_rel.affine_inverse() * target_rel
		if _has_mesh(part):
			part.get_parent().remove_child(part)
			target.add_child(part)
			part.transform = target_rel.affine_inverse() * part_rel
	return true


## Replaces the mesh of `mi` with the model's first mesh, for tiles that get repainted in place.
static func swap_mesh(mi: MeshInstance3D, id: String) -> bool:
	if not _mesh_cache.has(id):
		var art := instance(id)
		var src: MeshInstance3D = null
		if art != null:
			src = art if art is MeshInstance3D else art.find_children("*", "MeshInstance3D", true, false).front()
		_mesh_cache[id] = src.mesh if src != null else null
		if art != null:
			art.free()
	if _mesh_cache[id] == null:
		return false
	mi.mesh = _mesh_cache[id]
	mi.transform = Transform3D(Basis.IDENTITY, Vector3(0, -SLAB_TOP, 0))
	return true


## Checks every model named in the manifest, plus any model without an entry. Returns the problems.
static func validate() -> Array[String]:
	_load_manifest()
	for id in _manifest:
		if has_model(id):
			instance(id).free()
		else:
			push_warning("Art: manifest lists %s but there is no %s" % [id, model_path(id)])
	var dir := DirAccess.open(DIR + "3d")
	if dir != null:
		for f in dir.get_files():
			var id := f.get_basename()
			if f.get_extension() == "glb" and not _manifest.has(id) and has_model(id):
				instance(id).free()
	return errors


static func checked_count() -> int:
	return _checked.size()


## Bounds of all meshes under `node`, in the space of `node`.
static func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	for mi in meshes:
		var b: AABB = _rel(mi, node) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _check(id: String, node: Node3D) -> void:
	if _checked.has(id):
		return
	_checked[id] = true
	_load_manifest()
	var size := bounds(node).size
	if not _manifest.has(id):
		push_warning("Art: %s.glb has no manifest entry, its size %.2f x %.2f x %.2f m is not checked" % [id, size.x, size.y, size.z])
		return
	var want: Array = _manifest[id].get("size", [])
	var tol: float = _manifest[id].get("tolerance", 0.02)
	if want.size() != 3:
		return
	for i in 3:
		if absf(size[i] - float(want[i])) > tol:
			var msg := "Art: %s.glb is %.3f x %.3f x %.3f m, the manifest says %s" % [id, size.x, size.y, size.z, want]
			push_error(msg)
			errors.append(msg)
			return


static func _load_manifest() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	var p := DIR + "manifest.json"
	if not FileAccess.file_exists(p):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		_manifest = parsed
	else:
		push_error("Art: manifest.json is not a JSON object")


## Transform of `node` relative to `root`, from the local transforms, so it works before the node is in the tree.
static func _rel(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _has_mesh(node: Node) -> bool:
	return node is MeshInstance3D or not node.find_children("*", "MeshInstance3D", true, false).is_empty()
