extends Node
## A sandbox battle between two walled forts that hold every building of the art kit's first batch: the three
## guns, the base, four supply depots (enough supply for both big guns) and the two blocks. Saves screenshots at
## the given battle times (needs a display, run it through tools/godot_render.sh).
##   tools/godot_render.sh res://tools/shoot_battle.tscn -- --at=4,6 --out=/tmp/battle
##   --look=x,z   camera close to that tile, as in tools/screenshot.gd
##   --stack      a second storey on the front walls of both forts
##   --seed=N     the map seed, default 1, which draws grass for the open ground

const SandboxScene = preload("res://scenes/sandbox.tscn")
const SIZE := 30

var sb: Node
var shots: Array = []
var out := "user://battle"


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	for s in str(args.get("at", "5")).split(","):
		shots.append(float(s))
	out = args.get("out", out)
	if args.has("artseed"):
		Art._rng.seed = int(args["artseed"])
	if args.has("ind"):  # round 27: --ind=<reload>,<arc>, see scripts/Indicators.gd
		var q: PackedStringArray = str(args["ind"]).split(",")
		Indicators.reload_style = q[0]
		Indicators.arc_style = q[1] if q.size() > 1 else "wire"
	sb = SandboxScene.instantiate()
	add_child(sb)
	sb.ui.visible = false
	sb.scenario.map_size = SIZE
	sb.scenario.seed = int(args.get("seed", "1"))
	sb.scenario.items.assign(_fort(0, 2) + _fort(1, SIZE - 10))
	sb._enter_edit()
	sb.play()
	if args.has("ind"):
		Indicators.own_player = sb.player(0)
	if args.has("reload"):  # round 27: stretch every gun's reload so a mid-reload frame exists to shoot
		for s in get_tree().get_nodes_in_group("structures"):
			var sh = U.comp(s, "Shooter")
			if sh != null:
				sh.secondsBetweenShots *= float(args["reload"])
	if args.has("style"):
		var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/looks.json"))
		preload("res://tools/looks.gd").apply(sb.world, looks[args["style"]])
	if args.has("stack"):
		for s in 2:
			_stack_row(s, 2 if s == 0 else SIZE - 3)
	if args.has("look"):
		var q: PackedStringArray = str(args["look"]).split(",")
		var target: Vector3 = sb.map.tile_position(int(q[0]), int(q[1]))
		var cam := get_viewport().get_camera_3d()
		if args.has("top"):  # straight down, for checking what sits on the ground round a gun
			cam.global_position = target + Vector3(0, float(args["top"]) if args["top"] != "true" else 9.0, 0.001)
		else:
			cam.global_position = target + Vector3(0, 9, 6)
		cam.look_at(target)


## Walls round x 6..23 and z z0..z0+7, the buildings inside, side 1 mirrored so its guns face side 0.
func _fort(side: int, z0: int) -> Array:
	var items: Array = []
	for x in range(6, 24):
		for z in range(z0, z0 + 8):
			if x == 6 or x == 23 or z == z0 or z == z0 + 7:
				items.append({"side": side, "id": "wall", "x": x, "z": z, "rot": 0})
	var inside := [["cannon33a", 8, 2], ["cannon22a", 12, 2], ["cannon", 15, 3], ["base", 17, 2],
		["supply", 21, 2], ["supply", 22, 2], ["supply", 21, 4], ["supply", 22, 4],
		["upgrade_a", 15, 5], ["upgrade_b", 13, 5]]
	for b in inside:
		var size: int = Catalog.get_def(b[0]).size
		var dz: int = b[2] if side == 1 else 6 - b[2] - size + 1
		items.append({"side": side, "id": b[0], "x": b[1], "z": z0 + dz, "rot": 0})
	return items


func _stack_row(side: int, z: int) -> void:
	for x in range(6, 24):
		var t = sb.map.tiles[x][z]
		if not U.alive(t.structure) or not t.isWall:
			continue
		var go: Node3D = Catalog.spawn_wall_for(sb._connectors(Vector2i(x, z), side))
		U.comp(go, "BuildingBlock").player = sb.player(side)
		t.stack_wall(go)


func _process(_delta: float) -> void:
	if shots.is_empty() or sb.battle_time() < shots[0]:
		return
	var t: float = shots.pop_front()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [out, int(t * 10)])
	if shots.is_empty():
		get_tree().quit()
