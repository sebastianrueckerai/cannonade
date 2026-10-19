extends Node
## A sandbox battle between two walled forts that hold every building of the art kit: the four guns (small, heavy,
## mortar, flak), the base, the depots of every size (enough supply for every big gun) and the two blocks.
## Saves screenshots at the given battle times (needs a display, run it through tools/godot_render.sh).
##   tools/godot_render.sh res://tools/shoot_battle.tscn -- --at=4,6 --out=/tmp/battle
##   --look=x,z   camera close to that tile, as in tools/screenshot.gd
##   --stack      a second storey on the front walls of both forts
##   --top=H      with --look: the camera straight down from H metres, to check what sits on the ground
##   --reload=K   every gun reloads K times slower, so a screenshot catches a reload in progress
##   --seed=N     the map seed, default 1, which draws grass for the open ground
##   --paving=min,max,wall   hex colours for the enclosed ground (the lerp ends of the build's
##                per-tile variation) and the ground under walls; open ground and water stay as built
##   --tile=id    swap the ground slab model first (e.g. tile_mud), so the colour lands on it
##   --align      at the first shot, print each gun's mount centre minus its plate centre in metres, the placed
##                gate of assets-3d.md: under 0.02 on both axes

const SandboxScene = preload("res://scenes/sandbox.tscn")
const SIZE := 30

var sb: Node
var shots: Array = []
var out := "user://battle"
var align := false
var paving := ""
var tile_id := ""


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	for s in str(args.get("at", "5")).split(","):
		shots.append(float(s))
	out = args.get("out", out)
	align = args.has("align")
	paving = args.get("paving", "")
	tile_id = args.get("tile", "")
	if args.has("artseed"):
		Art._rng.seed = int(args["artseed"])
	if args.has("reload"):  # stretch every gun's reload at spawn, so a mid-reload frame exists to shoot
		Indicators.reload_scale = float(args["reload"])
	sb = SandboxScene.instantiate()
	add_child(sb)
	sb.ui.visible = false
	sb.scenario.map_size = SIZE
	sb.scenario.seed = int(args.get("seed", "1"))
	sb.scenario.items.assign(_fort(0, 2) + _fort(1, SIZE - 10))
	sb._enter_edit()
	sb.play()
	Indicators.own_player = sb.player(0)  # both sandbox sides are AI: draw side 0's arcs as a human's
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


## Walls round x 2..27 and z z0..z0+7, the buildings inside, side 1 mirrored so its guns face side 0.
func _fort(side: int, z0: int) -> Array:
	var items: Array = []
	for x in range(2, 28):
		for z in range(z0, z0 + 8):
			if x == 2 or x == 27 or z == z0 or z == z0 + 7:
				items.append({"side": side, "id": "wall", "x": x, "z": z, "rot": 0})
	var inside := [["cannon22a", 12, 2], ["cannon", 15, 3], ["base", 17, 2],
		["supply", 21, 2], ["supply", 22, 2], ["supply", 21, 4], ["supply", 22, 4],
		["upgrade_a", 15, 5], ["upgrade_b", 13, 5],
		["supply33", 3, 2], ["cannon22b", 23, 2], ["flak22", 25, 2], ["supply22", 23, 4]]
	for b in inside:
		var size: int = Catalog.get_def(b[0]).size
		var dz: int = b[2] if side == 1 else 6 - b[2] - size + 1
		items.append({"side": side, "id": b[0], "x": b[1], "z": z0 + dz, "rot": 0})
	return items


func _stack_row(side: int, z: int) -> void:
	for x in range(2, 28):
		var t = sb.map.tiles[x][z]
		if not U.alive(t.structure) or not t.isWall:
			continue
		var go: Node3D = Catalog.spawn("wall")
		U.comp(go, "BuildingBlock").player = sb.player(side)
		t.stack_wall(go)


func _process(_delta: float) -> void:
	if shots.is_empty() or sb.battle_time() < shots[0]:
		return
	if paving != "":  # at shot time the walls stand, so the enclosures are final
		_apply_paving(paving)
		paving = ""
	var t: float = shots.pop_front()
	if align:
		align = false
		_print_align()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [out, int(t * 10)])
	if shots.is_empty():
		get_tree().quit()


func _apply_paving(spec: String) -> void:
	var p: PackedStringArray = spec.split(",")
	for x in sb.map.sizeX:
		for z in sb.map.sizeZ:
			var t = sb.map.tiles[x][z]
			if t.water:
				continue
			if tile_id != "":
				Art.swap_mesh(t.model(), tile_id)
			t.enclosedColor = Color(p[0]).lerp(Color(p[1]), (0.1 - t.go.position.y) / 0.2)
			t.wallColor = Color(p[2])
			t.reset_color()


func _print_align() -> void:
	for go in get_tree().get_nodes_in_group("structures"):
		var plate := go.find_child("plate", true, false) as Node3D
		var mount := go.find_child("mount", true, false) as Node3D
		if plate == null or mount == null:
			continue
		var d: Vector3 = mount.global_transform * Art.bounds(mount).get_center() - plate.global_transform * Art.bounds(plate).get_center()
		var s = U.comp(go, "Structure")
		print("ALIGN %s at %s: mount minus plate x %.3f z %.3f" % [s.def.id if s else go.name, go.global_position, d.x, d.z])
