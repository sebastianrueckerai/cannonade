extends Node
## Screenshots any scene at a given window size, for UI checks.
# godot --rendering-driver opengl3 res://tools/shoot_ui.tscn -- --scene=res://scenes/menu.tscn --out=/tmp/menu.png [--width=1280 --height=720 --frames=10]


func arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return default


func _ready() -> void:
	var scene := arg("scene", "res://scenes/menu.tscn")
	var out := arg("out", "/tmp/ui.png")
	get_window().size = Vector2i(int(arg("width", "1280")), int(arg("height", "720")))
	var node: Node = load(scene).instantiate()
	get_tree().root.add_child.call_deferred(node)
	await get_tree().process_frame
	for i in int(arg("frames", "10")):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
