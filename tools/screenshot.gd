extends Node
## Renders a game mode and saves screenshots (needs a display, e.g. xvfb-run).
##   xvfb-run godot --rendering-driver opengl3 --fixed-fps 30 res://tests/screenshot.tscn -- --mode=ai2 --at=5,40 --out=/tmp/shot

const Main = preload("res://scripts/Main.gd")

var main: Node
var shots: Array = []
var out := "user://shot"
var aim = null


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	for s in str(args.get("at", "3")).split(","):
		shots.append(float(s))
	out = args.get("out", out)
	Main.requested_args = args
	Main.requested_mode = args.get("mode", "ai2")
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	if args.has("zoom"):  # wheel notches towards the screen centre
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.position = get_viewport().get_visible_rect().size / 2.0
		ev.pressed = true
		for i in int(args["zoom"]):
			main.camera._unhandled_input(ev)
	if args.has("fov"):
		main.camera.fov = float(args["fov"])
	if args.has("look"):
		var q: PackedStringArray = str(args["look"]).split(",")
		var target: Vector3 = main.game.map.tile_position(int(q[0]), int(q[1]))
		main.camera.global_position = target + Vector3(0, 9, 6)
		main.camera.look_at(target)
	if args.has("aim"):
		var p: PackedStringArray = str(args["aim"]).split(",")
		aim = Vector2i(int(p[0]), int(p[1]))


func _process(_delta: float) -> void:
	if main == null or main.game == null:
		return
	if aim != null:
		var human = main.game.players[0]
		human.simulated_aim = main.game.map.tile_position(aim.x, aim.y, 0.1)
	if shots.is_empty():
		return
	if U.time >= shots[0]:
		var t: float = shots.pop_front()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s_%03d.png" % [out, int(t)]
		img.save_png(path)
		print("saved ", path)
		if shots.is_empty():
			get_tree().quit()
