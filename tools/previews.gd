extends Node
## Screenshots every next-piece preview of player 1: each wall in all four rotations
## and each drawable building, plus one shot of the wall hovering a free tile (needs a
## display, e.g. xvfb-run).
##   xvfb-run godot --rendering-driver opengl3 --fixed-fps 30 res://tools/previews.tscn -- --out=/tmp/pieces

const Main = preload("res://scripts/Main.gd")

var main: Node
var human
var map
var queue: Array = []  # [id, rotations, is_wall]
var out := "/tmp/pieces"
var _busy := false


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	out = args.get("out", out)
	DirAccess.make_dir_recursive_absolute(out)
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "5", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	human = main.game.players[0]
	map = main.game.map
	main.game.players[1].nextAction = 1e9  # keep the AI idle
	for def in Catalog.drawable(BuildingDef.Category.WALL):
		for r in 4:
			queue.append([def.id, r, true])
	for def in Catalog.drawable(BuildingDef.Category.BUILDING):
		queue.append([def.id, 0, false])


func _process(_delta: float) -> void:
	if main == null or main.game == null or _busy:
		return
	if queue.is_empty():
		_capture_map_hover()
		return
	_busy = true
	var item: Array = queue.pop_front()
	var id: String = item[0]
	if item[2]:
		U.destroy(human.nextWall)
		human.nextWall = Catalog.spawn(id, human.wallSpawn)
		var bb = U.comp(human.nextWall, "BuildingBlock")
		for i in item[1]:
			bb.rotate_counter_clockwise()
		human.wallColor = U.get_color(human.nextWall)
		human.next_wall_to_gui()
	else:
		U.destroy(human.nextBuilding)
		human.nextBuilding = Catalog.spawn(id, human.buildingSpawn)
		human.switch_casting_shadows(human.nextBuilding, false)
	await RenderingServer.frame_post_draw
	_shot(id if not item[2] else "%s_r%d" % [id, item[1]])
	_busy = false


## Last shot: the wall doubles as the placement preview on a hovered free tile.
func _capture_map_hover() -> void:
	_busy = true
	var base := Vector2i(map.sizeX / 2, map.sizeZ / 4)
	var free := Vector2i(-1, -1)
	for r in range(2, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var t = map.tiles[base.x + dx][base.y + dz]
				if human.in_reach(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable():
					free = Vector2i(t.idxX, t.idxZ)
	if free.x >= 0:
		var ev := InputEventMouseMotion.new()
		ev.position = main.camera.unproject_position(map.tile_position(free.x, free.y, 0.1))
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("wall_on_map")
		print("hover parent is the tile: ", human.nextWall.get_parent() == map.tiles[free.x][free.y].go)
	get_tree().quit()


func _shot(name: String) -> void:
	var path := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
