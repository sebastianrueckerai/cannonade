extends Node3D
# Test bench for gun models: every .glb in tools/gun_test/models/ on its footprint, rows by size.
# Each model needs a `barrel` node with its origin on the trunnion axis, muzzle along -Z, and a
# `projectile_spawn` child at the muzzle (blender-ai pipeline/barrel.py writes them like that).
# Run it from the editor (F6 on this scene), or for a screenshot without a window:
# tools/godot_render.sh res://tools/gun_test.tscn -- --shot=<abs.png> [--yaw=30] [--pitch=30] [--view=close]

const MODELS := "res://tools/gun_test/models/"
const GRASS := Color("8fbf3c")
const SKY := Color("6cb9f5")
const HELP := "Left/Right turn   Up/Down barrel   Space sweep   R reset\n1 game view   2 zoomed in   3 close   right drag orbit   wheel zoom\nP muzzle points   F wireframe"

var guns: Array[Node3D] = []
var barrels: Array[Node3D] = []
var spawns: Array[Node3D] = []
var yaw := 0.0
var pitch := 0.0
var sweep := false
var t := 0.0
var cam: Camera3D
var orbit := Vector3(-30, 35, 22)  # yaw deg, pitch deg, distance m
var target := Vector3(0, 0.5, 5)
var hud: Label


func arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return default


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = SKY
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a9c8e8")
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()  # the afternoon sun of lighting_rules.yaml, from the front right of the game camera
	sun.light_color = Color("ffe8c0")
	sun.rotation_degrees = Vector3(-45, 140, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var files := []
	for f in DirAccess.get_files_at(MODELS):
		if f.ends_with(".glb"):
			files.append(f)
	files.sort()
	var col := {1: 0, 2: 0, 3: 0}
	var row_z := {1: 0.0, 2: 4.0, 3: 9.5}
	for f in files:
		var size := 3 if f.begins_with("cannon33") else 2 if f.begins_with("cannon22") else 1
		var at := Vector3(-7.5 + col[size] * 5.0, 0, row_z[size])
		col[size] += 1
		_tiles(at, size)
		var gun := _load(MODELS + f)
		if gun == null:
			continue
		gun.position = at + Vector3(0, 0.1, 0)
		add_child(gun)
		var barrel := gun.find_child("barrel", true, false) as Node3D
		if barrel == null:
			push_error("%s has no barrel node" % f)
			continue
		guns.append(gun)
		barrels.append(barrel)
		var tris := _tris(gun)
		var spawn := gun.find_child("projectile_spawn", true, false) as Node3D
		if spawn != null:
			var dot := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.06
			s.height = 0.12
			dot.mesh = s
			var m := StandardMaterial3D.new()
			m.albedo_color = Color.RED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dot.material_override = m
			spawn.add_child(dot)
			spawns.append(dot)
		var label := Label3D.new()
		label.text = "%s\n%d tris" % [f.get_basename(), tris]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.pixel_size = 0.004
		label.position = at + Vector3(0, size * 0.9 + 1.0, 0)
		add_child(label)

	cam = Camera3D.new()
	cam.far = 500
	add_child(cam)
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_color_override("font_color", Color.BLACK)
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)

	yaw = float(arg("yaw", "0"))
	pitch = float(arg("pitch", "0"))
	_view(arg("view", "close"))
	_apply()
	var shot := arg("shot", "")
	if shot != "":
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		push_error("glb load failed: %s" % path)
		return null
	return doc.generate_scene(state) as Node3D


func _tris(root: Node) -> int:
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return n


func _tiles(at: Vector3, size: int) -> void:
	for i in size:
		for j in size:
			var slab := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.98, 0.2, 0.98)
			slab.mesh = box
			var m := StandardMaterial3D.new()
			m.albedo_color = GRASS if (i + j) % 2 == 0 else GRASS.darkened(0.08)
			slab.material_override = m
			slab.position = at + Vector3(i - (size - 1) / 2.0, 0, j - (size - 1) / 2.0)
			add_child(slab)


func _view(name: String) -> void:
	match name:
		"game":  # versus default, gameplay_contract.yaml: pitch 60, fov 30, 54.4 m
			cam.fov = 30
			orbit = Vector3(0, 60, 54.4)
		"zoomed":  # the closest zoom of CameraRig.gd, 7 m
			cam.fov = 30
			orbit = Vector3(0, 60, 7)
		_:
			cam.fov = 40
			orbit = Vector3(-30, 35, 22)
	_place_camera()


func _place_camera() -> void:
	var y := deg_to_rad(orbit.x)
	var p := deg_to_rad(orbit.y)
	cam.position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * orbit.z
	cam.look_at(target)


func _apply() -> void:
	for g in guns:
		g.rotation.y = deg_to_rad(yaw)
	for b in barrels:
		b.rotation.x = deg_to_rad(pitch)
	hud.text = "%s\nturn %d deg   barrel %d deg   %d guns" % [HELP, int(yaw), int(pitch), guns.size()]


func _process(delta: float) -> void:
	if sweep:
		t += delta
		yaw = fmod(t * 30.0, 360.0)
		pitch = 25.0 + 35.0 * sin(t * 1.3)
	var turn := Input.get_axis("ui_left", "ui_right")
	var lift := Input.get_axis("ui_down", "ui_up")
	yaw = fmod(yaw - turn * 90.0 * delta, 360.0)
	pitch = clampf(pitch + lift * 45.0 * delta, -15.0, 75.0)
	_apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE:
				sweep = not sweep
			KEY_R:
				yaw = 0.0
				pitch = 0.0
				sweep = false
			KEY_1:
				_view("game")
			KEY_2:
				_view("zoomed")
			KEY_3:
				_view("close")
			KEY_P:
				for s in spawns:
					s.visible = not s.visible
			KEY_F:
				var vp := get_viewport()
				vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED if vp.debug_draw == Viewport.DEBUG_DRAW_WIREFRAME else Viewport.DEBUG_DRAW_WIREFRAME
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		orbit.x -= e.relative.x * 0.3
		orbit.y = clampf(orbit.y + e.relative.y * 0.3, 5.0, 89.0)
		_place_camera()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit.z = maxf(2.0, orbit.z * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit.z = minf(120.0, orbit.z * 1.1)
		_place_camera()
