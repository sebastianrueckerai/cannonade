extends Node
## Renders a game mode and saves screenshots (needs a display, e.g. tools/godot_render.sh).
##   tools/godot_render.sh res://tools/screenshot.tscn -- --mode=ai2 --at=5,40 --out=/tmp/shot
##   --look=x,z     the camera close to that tile; --castle=N instead looks at player N's first castle
##   --eye=Y,Z      with --look or --castle: the camera Y up and Z back from the target instead of 9,6
##   --kill[=wall|gun|castle|tree]   at the first --at time, a shot from the camera kills the wall (the whole stack), the
##                  gun, the castle or the decorated tile nearest the --look or --castle target as it stands then, and the
##                  camera turns to it; the later times show its rubble

const Main = preload("res://scripts/Main.gd")

var main: Node
var shots: Array = []
var out := "user://shot"
var aim = null
var kill_kind := ""
var kill_target = null
var eye := Vector3(0, 9, 6)


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	for s in str(args.get("at", "3")).split(","):
		shots.append(float(s))
	out = args.get("out", out)
	if args.has("artseed"):
		Art._rng.seed = int(args["artseed"])
	Main.requested_args = args
	Main.requested_mode = args.get("mode", "ai2")
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	if args.has("style"):
		var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/looks.json"))
		preload("res://tools/looks.gd").apply(main, looks[args["style"]])
	if args.has("zoom"):  # wheel notches towards the screen centre
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.position = get_viewport().get_visible_rect().size / 2.0
		ev.pressed = true
		for i in int(args["zoom"]):
			main.camera._unhandled_input(ev)
	if args.has("fov"):
		main.camera.fov = float(args["fov"])
	var target = null
	if args.has("look"):
		var q: PackedStringArray = str(args["look"]).split(",")
		target = main.game.map.tile_position(int(q[0]), int(q[1]))
	elif args.has("castle"):
		var p = main.game.players[int(args["castle"])]
		for c in main.game.map.castles:
			if c.owner() == p:
				target = c.go.global_position
				break
	if target != null:
		var e: PackedStringArray = str(args.get("eye", "9,6")).split(",")
		eye = Vector3(0, float(e[0]), float(e[1]))
		_look_at(target)
		if args.has("kill"):
			kill_kind = args["kill"] if args["kill"] != "true" else "wall"
			kill_target = target
	if args.has("aim"):
		var p: PackedStringArray = str(args["aim"]).split(",")
		aim = Vector2i(int(p[0]), int(p[1]))


func _process(_delta: float) -> void:
	if main == null or main.game == null:
		return
	if aim != null:
		var wp: Vector3 = main.game.map.tile_position(aim.x, aim.y, 0.1)
		if not main.camera.is_position_behind(wp):
			var ev := InputEventMouseMotion.new()
			ev.position = main.camera.unproject_position(wp)
			Input.parse_input_event(ev)
	if shots.is_empty():
		return
	if U.time >= shots[0]:
		var t: float = shots.pop_front()
		if kill_kind != "":
			_kill()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s_%03d.png" % [out, int(t)] if t == floorf(t) else "%s_%05.2f.png" % [out, t]
		img.save_png(path)
		print("saved ", path)
		if shots.is_empty():
			get_tree().quit()


func _look_at(target: Vector3) -> void:
	main.camera.global_position = target + eye
	main.camera.look_at(target)


## The thing of the kill kind nearest the kill target, as it stands now: the camera turns to it and a shot from the
## camera kills it.
func _kill() -> void:
	var kill = null
	for col in main.game.map.tiles:
		for t in col:
			if _kind_of(t) == kill_kind and (kill == null
					or t.go.global_position.distance_to(kill_target) < kill.go.global_position.distance_to(kill_target)):
				kill = t
	var kind := kill_kind
	kill_kind = ""
	if kill == null:
		print("kill: no %s stands" % kind)
		return
	print("kill: the %s at %d, %d" % [kind, kill.idxX, kill.idxZ])
	_look_at(kill.go.global_position)
	kill.damage_building_place(1e6, main.camera.global_position)


static func _kind_of(t) -> String:
	if not U.alive(t.structure):
		return "tree" if not t.decorations.is_empty() else ""
	if t.isWall:
		return "wall"
	if U.comp(t.structure, "Castle") != null:
		return "castle"
	return "gun" if U.shooter(t.structure) != null else ""
