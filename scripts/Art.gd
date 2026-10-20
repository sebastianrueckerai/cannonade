class_name Art
## The art layer. Drop files into res://assets/art/ and the game uses them, nothing else to wire.
##
##   3d/<id>.glb            a model for building id, "ship", "tile" or projectile id ("shell"), origin at the ground
##                          centre, Y up, metres, one tile = 1 m. Walls keep the tile centre as origin, projectiles
##                          their centre. The wall block has one model per look (Catalog.WALL_LOOKS: "wall",
##                          "wall_corbel", ..., dealt one per player each game) and each a storey, "<look>_upper";
##                          Wall.gd puts its shader on them. 3d/wall_rubble.glb and 3d/wall_rubble_upper.glb are the
##                          plain block and its storey in pieces, one mesh each with the origin at the piece's centre;
##                          Crumble.gd makes rigid bodies of them when a shot kills a block
##   3d/<id>.2.glb, .3.glb  more looks of the same id, one picked at random for each instance
##   ui/splash.png          splash screen image
##   ui/logo.png            title image on the menu
##   ui/menu_background.png
##   ui/button.png, ui/button_hover.png, ui/button_pressed.png, ui/panel.png   9-slice styles, see theme()
##   ui/font.ttf            default font of the menu screens
##   sky/world_panorama.png equirectangular sky
##   manifest.json          {"<id>": {"size": [x, y, z], "tolerance": 0.02}} written by the art pipeline
##
## A model part whose snake_case name maps to a prefab node in PascalCase (barrel -> Barrel,
## projectile_spawn -> ProjectileSpawn) is attached to that node, so pivots and spawn points keep
## working. The flak's guns -> Guns, which the game aims by its whole orientation, gives the anchor its rest
## pose. A part named plate stays square to the grid while the building turns. Every other mesh of the
## prefab is hidden. Sizes are checked against the manifest once.

const DIR := "res://assets/art/"
const SLAB_TOP := 0.1
const INDICATOR_GAP := 0.15
const PLATE := preload("res://scripts/ArtPlate.gd")
## Parts the game turns: an indicator floats above their reach.
const MOVING := ["barrel", "guns"]
## Parts the game aims by replacing the anchor's whole basis (Flak.gd): the anchor takes the part's rest orientation.
const AIMED := ["guns"]

static var errors: Array[String] = []
static var _theme: Theme
static var _manifest := {}
static var _manifest_loaded := false
static var _checked := {}
static var _mesh_cache := {}
static var _variants := {}
## Its own generator, so the art never moves the game's random sequence.
static var _rng := RandomNumberGenerator.new()


static func model_path(id: String) -> String:
	return DIR + "3d/" + id + ".glb"


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(model_path(id))


static func texture(name: String) -> Texture2D:
	var p := DIR + "ui/" + name
	return load(p) if ResourceLoader.exists(p) else null


## One look of a UI image at random: ui/<file>, then its numbered looks without a gap, loading.jpg, loading.2.jpg and
## on. Null without a file.
static func texture_look(file: String) -> Texture2D:
	var looks: Array[String] = []
	var look := file
	while ResourceLoader.exists(DIR + "ui/" + look):
		looks.append(look)
		look = "%s.%d.%s" % [file.get_basename(), looks.size() + 1, file.get_extension()]
	return texture(looks[_rng.randi_range(0, looks.size() - 1)]) if not looks.is_empty() else null


static func sky_texture() -> Texture2D:
	var p := DIR + "sky/world_panorama.png"
	return load(p) if ResourceLoader.exists(p) else null


## The theme of the menu, splash and loading screens: ui/theme.tres, then image styles on top when the
## files exist. button.png, button_hover.png, button_pressed.png and panel.png are 9-slice textures,
## font.ttf is the default font. Slice margins default to a quarter of the image on every side,
## manifest.json {"ui": {"button": {"margins": [l, t, r, b], "content": [l, t, r, b]}}} overrides them.
## The in-game HUD keeps the default theme until it is styled.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var p := DIR + "ui/theme.tres"
	_theme = load(p) if ResourceLoader.exists(p) else Theme.new()
	var font := DIR + "ui/font.ttf"
	if ResourceLoader.exists(font):
		_theme.default_font = load(font)
	var normal := _stylebox("button")
	if normal != null:
		var hover := _stylebox("button_hover")
		if hover == null:
			hover = normal.duplicate()
			hover.modulate_color = Color(1.15, 1.15, 1.15)
		var pressed := _stylebox("button_pressed")
		if pressed == null:
			pressed = normal.duplicate()
			pressed.modulate_color = Color(0.8, 0.8, 0.8)
		_theme.set_stylebox("normal", "Button", normal)
		_theme.set_stylebox("hover", "Button", hover)
		_theme.set_stylebox("pressed", "Button", pressed)
		_theme.set_stylebox("focus", "Button", hover)
	var panel := _stylebox("panel")
	if panel != null:
		_theme.set_stylebox("panel", "PanelContainer", panel)
		_theme.set_stylebox("panel", "Panel", panel)
	return _theme


static func _stylebox(name: String) -> StyleBoxTexture:
	var p := DIR + "ui/" + name + ".png"
	if not ResourceLoader.exists(p):
		return null
	var tex: Texture2D = load(p)
	_load_manifest()
	var ui: Dictionary = _manifest.get("ui", {}).get(name, {})
	var q := minf(tex.get_width(), tex.get_height()) / 4.0
	var m: Array = ui.get("margins", [q, q, q, q])
	var c: Array = ui.get("content", m)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = c[0]
	sb.content_margin_top = c[1]
	sb.content_margin_right = c[2]
	sb.content_margin_bottom = c[3]
	return sb


## The looks of `id`: <id>.glb, then <id>.2.glb, <id>.3.glb and on until a number is missing.
static func variants(id: String) -> Array:
	if not _variants.has(id):
		var ids := []
		if has_model(id):
			ids.append(id)
			while has_model("%s.%d" % [id, ids.size() + 1]):
				ids.append("%s.%d" % [id, ids.size() + 1])
		_variants[id] = ids
	return _variants[id]


## A fresh instance of one look of the model, or null when the file does not exist.
static func instance(id: String) -> Node3D:
	var ids := variants(id)
	if ids.is_empty():
		return null
	var pick: String = ids[_rng.randi_range(0, ids.size() - 1)]
	var node := (load(model_path(pick)) as PackedScene).instantiate() as Node3D
	node.name = "Art"
	_check(pick, node)
	return node


## Attaches the model `id` to the prefab root `go`, `lift` metres up (the slab top for anything standing on a
## tile). Returns false and leaves the prefab alone when there is no file. Call before the prefab enters the
## tree and before components look for anchors.
static func attach(go: Node3D, id: String, lift := SLAB_TOP) -> bool:
	var art := instance(id)
	if art == null:
		return false
	for mi in go.find_children("*", "MeshInstance3D", true, false):
		if mi.get_script() == null:
			mi.visible = false
	go.add_child(art)
	art.set_meta("art_id", id)
	art.scale = Vector3(1.0 / go.scale.x, 1.0 / go.scale.y, 1.0 / go.scale.z)
	art.position = Vector3(0, lift, 0)
	# Indicators such as the cooldown ring float above the model and above the reach of a moving part.
	var top := bounds(art).end.y
	for name in MOVING:
		var moving := art.find_child(name, true, false) as Node3D
		if moving == null:
			continue
		var b := bounds(moving)
		for i in 8:
			top = maxf(top, _rel(moving, art).origin.y + b.get_endpoint(i).length())
	top = lift + top * art.scale.y + INDICATOR_GAP
	for mi in go.get_children():
		if mi is MeshInstance3D and mi.get_script() != null:
			mi.position.y = top
	for part in art.find_children("*", "Node3D", true, false):
		if part.name == "plate":
			part.set_script(PLATE)
			continue
		var target := go.find_child(part.name.to_pascal_case(), true, false)
		if target == null or not target is Node3D or art.is_ancestor_of(target):
			continue
		var part_rel := _rel(part, go)
		var parent_rel := _rel(target.get_parent(), go)
		var target_rel := _rel(target, go)
		target_rel.origin = part_rel.origin
		if part.name in AIMED:
			target_rel.basis = Basis(part_rel.basis.get_rotation_quaternion()).scaled(target_rel.basis.get_scale())
		target.transform = parent_rel.affine_inverse() * target_rel
		if _has_mesh(part):
			# A placeholder mesh as the anchor was hidden above, and would hide the art under it.
			if target is MeshInstance3D and target.get_script() == null:
				target.mesh = null
				target.visible = true
			part.get_parent().remove_child(part)
			part.owner = null
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
	for s in mi.get_surface_override_material_count():
		mi.set_surface_override_material(s, null)   # the overrides belong to the old mesh's material
		if mi.has_meta("unique_mat_%d" % s):
			mi.remove_meta("unique_mat_%d" % s)
	mi.transform = Transform3D(Basis.IDENTITY, Vector3(0, -SLAB_TOP, 0))
	return true


## Checks every model named in the manifest, plus any model without an entry. Returns the problems.
static func validate() -> Array[String]:
	_load_manifest()
	for id in _manifest:
		if id == "ui":
			continue
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
	if FileAccess.file_exists(p):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
		if parsed is Dictionary:
			_manifest = parsed
		else:
			push_error("Art: manifest.json is not a JSON object")
	# The UI's slice margins live beside the textures they describe.
	var ui := DIR + "ui/manifest.json"
	if FileAccess.file_exists(ui):
		var parsed_ui = JSON.parse_string(FileAccess.get_file_as_string(ui))
		if parsed_ui is Dictionary:
			for key in parsed_ui:
				_manifest[key] = parsed_ui[key]
		else:
			push_error("Art: ui/manifest.json is not a JSON object")


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
