extends Node3D
## Every castle look's five states in a grid, textured, under the game camera, one row a look
## (C20). Healthy first, then the four damage states.
##   godot --path . res://tools/damage_view.tscn                          look around: wheel zooms, middle drags pans, right drags turn the board
##   tools/godot_render.sh res://tools/damage_view.tscn -- --shot=/tmp/damage_view.png

const LOOKS := ["castle", "castle.2", "castle.3", "castle.4", "castle.5", "castle.6", "castle.7", "castle.8"]
const STATES := [
	{"suffix": "", "label": "healthy"},
	{"suffix": "_d1", "label": "d1 light"},
	{"suffix": "_d2", "label": "d2 heavy"},
	{"suffix": "_d3", "label": "d3 severe"},
	{"suffix": "_d4", "label": "d4 ruins"},
]
const TEAM_BLUE := Color("#2d55c4")   # palette.json team blue main
const MUD := Color("#b2915f")         # palette.json mud_dark, the paving
const SKY := Color("#6cb9f5")         # palette.json sky

const CELL_X := 4.5
const CELL_Z := 5.5

var _board: Node3D
var _rig: Camera3D
var _orbiting := false


func _ready() -> void:
	var cols := STATES.size()
	var rows := LOOKS.size()
	var size := Vector2i(1600, 160 + 260 * rows)
	get_tree().root.size = size
	_world(cols, rows)
	_board = Node3D.new()
	add_child(_board)
	for r in rows:
		var look: String = LOOKS[r]
		for c in cols:
			var st: Dictionary = STATES[c]
			var id: String = look + st["suffix"]
			var path := "res://assets/art/3d/%s.glb" % id
			if not FileAccess.file_exists(path):
				continue
			var at := Vector3(c * CELL_X, 0.0, r * CELL_Z)
			var castle: Node3D = load(path).instantiate()
			castle.position = at
			_board.add_child(castle)
			_paint_team(castle)
			var label := Label3D.new()
			label.text = ("%s\n" % look) if c == 0 else ""
			label.text += st["label"]
			label.position = at + Vector3(0, 4.2, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 96
			label.modulate = Color(0.15, 0.15, 0.15)
			_board.add_child(label)
	var rig: Camera3D = preload("res://scripts/CameraRig.gd").new()
	_rig = rig
	add_child(rig)
	rig.current = true
	var centre := Vector3((cols - 1) * CELL_X * 0.5, 1.0, (rows - 1) * CELL_Z * 0.5)
	rig.global_position = centre + Vector3(0, 30.0, 17.0)
	rig.look_at(centre)
	rig.capture_home_view(Vector2((cols - 1) * CELL_X * 0.5 + 2.0, (rows - 1) * CELL_Z * 0.5 + 2.0))
	var shot := _arg("shot", "")
	if shot != "":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_orbiting = event.pressed
	elif event is InputEventMouseMotion and _orbiting:
		_spin_board(_rig._target, event.relative.x * 0.01)


## The turntable: the board turns about the ground point at the screen centre, so the
## castle under inspection stays put while the camera, sun and grid hold still.
func _spin_board(pivot: Vector3, ang: float) -> void:
	_board.global_transform = (Transform3D(Basis(), pivot)
			* Transform3D(Basis(Vector3.UP, ang), Vector3.ZERO)
			* Transform3D(Basis(), -pivot)
			* _board.global_transform)


func _world(cols: int, rows: int) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cols * CELL_X + 8.0, 0.2, rows * CELL_Z + 8.0)
	ground.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MUD
	ground.material_override = mat
	ground.position = Vector3((cols - 1) * CELL_X * 0.5, -0.1, (rows - 1) * CELL_Z * 0.5)
	add_child(ground)


func _paint_team(root: Node3D) -> void:
	# The cleanup puts the team material first, flat and without a texture; the game paints it.
	for mi in _meshes(root):
		var mesh: Mesh = mi.mesh
		if mesh.get_surface_count() > 0:
			var m: Material = mesh.surface_get_material(0)
			if m is StandardMaterial3D and m.albedo_texture == null:
				var paint: StandardMaterial3D = m.duplicate()
				paint.albedo_color = TEAM_BLUE
				mi.set_surface_override_material(0, paint)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in node.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes(c))
	return out


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
	return default
