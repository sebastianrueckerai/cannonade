extends Node3D
## The castle's four damage states side by side, textured, under the game camera.
##   godot --path . res://tools/damage_view.tscn                          look around: wheel zooms, middle drags
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 \
##     res://tools/damage_view.tscn -- --shot=/tmp/damage_view.png

const STATES := [
	{"glb": "res://assets/art/3d/castle_d1.glb", "label": "d1 light"},
	{"glb": "res://assets/art/3d/castle_d2.glb", "label": "d2 heavy"},
	{"glb": "res://assets/art/3d/castle_d3.glb", "label": "d3 severe"},
	{"glb": "res://assets/art/3d/castle_d4.glb", "label": "d4 ruins"},
]
const TEAM_BLUE := Color("#2d55c4")   # palette.json team blue main
const MUD := Color("#b2915f")         # palette.json mud_dark, the paving
const SKY := Color("#6cb9f5")         # palette.json sky


func _ready() -> void:
	get_tree().root.size = Vector2i(1600, 900)
	_world()
	for i in STATES.size():
		var st: Dictionary = STATES[i]
		var castle: Node3D = load(st["glb"]).instantiate()
		castle.position = Vector3(i * 4.5, 0.0, 0.0)
		add_child(castle)
		_paint_team(castle)
		var label := Label3D.new()
		label.text = st["label"]
		label.position = Vector3(i * 4.5, 4.2, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.modulate = Color(0.15, 0.15, 0.15)
		add_child(label)
	var rig: Camera3D = preload("res://scripts/CameraRig.gd").new()
	add_child(rig)
	rig.current = true
	rig.global_position = Vector3(6.75, 16.0, 9.5)
	rig.look_at(Vector3(6.75, 1.0, 0.0))
	rig.capture_home_view(9.0)
	var shot := _arg("shot", "")
	if shot != "":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _world() -> void:
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
	box.size = Vector3(30, 0.2, 10)
	ground.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MUD
	ground.material_override = mat
	ground.position = Vector3(6.75, -0.1, 0.0)
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
