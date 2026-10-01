extends Node3D
## Renders wall models side by side for visual inspection.
func _ready() -> void:
	var files := ["ModellLineLower1", "ModellCornerLower1", "ModellTriLower1", "ModellCrossLower1", "ModelLineUpper1", "ModellCornerUpper1"]
	for i in files.size():
		var n: Node3D = load("res://prefabs/walls/%s.tscn" % files[i]).instantiate()
		add_child(n)
		n.position = Vector3(i * 1.5 - 3.75, 0, 0)
		var tile := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 0.2, 1)
		tile.mesh = bm
		tile.position = n.position - Vector3(0, 0.1, 0)
		add_child(tile)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 3.5, 5)
	cam.look_at(Vector3(0, 0, 0))
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-50, 30, 0)
	add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.4, 0.5)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
