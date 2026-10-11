extends Node3D
# Loads one .glb at the board centre under the gameplay camera and saves a screenshot.
# tools/godot_render.sh res://tools/preview_glb.tscn -- --glb=<abs> --out=<abs.png> [--dist=54.4] [--pitch=60] [--fov=30]


func arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return default


func _ready() -> void:
	var glb := arg("glb", "")
	var out := arg("out", "/tmp/preview.png")
	var dist := float(arg("dist", "54.4"))
	var pitch := float(arg("pitch", "60"))
	var fov := float(arg("fov", "30"))

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.19, 0.30, 0.47)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

	for x in range(-3, 4):
		for z in range(-3, 4):
			var slab := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1, 0.2, 1)
			slab.mesh = box
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.890, 0.678, 0.455) if (x + z) % 2 == 0 else Color(0.80, 0.60, 0.40)
			slab.material_override = m
			slab.position = Vector3(x, 0, z)
			add_child(slab)

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(glb, state)
	if err != OK:
		push_error("glb load failed: %s" % err)
		get_tree().quit(1)
		return
	var model := doc.generate_scene(state)
	model.position = Vector3(0, 0.1, 0)
	add_child(model)

	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 500
	var p := deg_to_rad(pitch)
	cam.position = Vector3(0, dist * sin(p), dist * cos(p))
	cam.rotation_degrees = Vector3(-pitch, 0, 0)
	add_child(cam)
	cam.current = true

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
