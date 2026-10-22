extends Node
## Renders a game mode and saves screenshots (needs a display, e.g. tools/godot_render.sh).
##   tools/godot_render.sh res://tools/screenshot.tscn -- --mode=ai2 --at=5,40 --out=/tmp/shot
##   --look=x,z     the camera close to that tile; --castle=N instead looks at player N's first castle
##   --eye=Y,Z      with --look or --castle: the camera Y up and Z back from the target instead of 9,6
##   --kill[=wall|gun|castle|tree]   at the first --at time, a shot from the camera kills the wall (the whole stack), the
##                  gun, the castle or the decorated tile nearest the --look or --castle target as it stands then, and the
##                  camera turns to it; the later times show its rubble
##   --scorch=N     at the first --at time, N shells' worth of ground damage on the bare tiles nearest the
##                  target, piled nearest first up to stage 3, and each scar printed
##   --fire=x,z     fires the first gun that reaches the tile (places a cannon that does if none,
##                  --firewith=DEF places that building def instead of the basic cannon),
##                  --firegun re-aims the camera to the gun, --muzzlecam frames its muzzle in profile,
##                  --wet makes the target water, --fxstyle=smoke|fire|soft turns the effects on in that look

const Main = preload("res://scripts/Main.gd")
const FX = preload("res://scripts/FX.gd")

var main: Node
var shots: Array = []
var out := "user://shot"
var aim = null
var kill_kind := ""
var kill_target = null
var eye := Vector3(0, 9, 6)
var scorch := 0
var _scorch_done := false
var fire := Vector2i(-1, -1)
var firewith := "cannon"
var firegun := false
var muzzlecam := false
var wet := false
var _fired := false
var look_target = null


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
		look_target = target
		var e: PackedStringArray = str(args.get("eye", "9,6")).split(",")
		eye = Vector3(0, float(e[0]), float(e[1]))
		_look_at(target)
		if args.has("kill"):
			kill_kind = args["kill"] if args["kill"] != "true" else "wall"
			kill_target = target
	if args.has("scorch"):
		scorch = int(args["scorch"])
	if args.has("fire"):
		var f: PackedStringArray = str(args["fire"]).split(",")
		fire = Vector2i(int(f[0]), int(f[1]))
	if args.has("firewith"):
		firewith = str(args["firewith"])
	firegun = args.has("firegun")
	muzzlecam = args.has("muzzlecam")
	wet = args.has("wet")
	if args.has("fxstyle"):
		FX.style = str(args["fxstyle"])
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
		if fire.x >= 0 and not _fired:
			_fired = true
			_fire(t)
			return
		if scorch > 0 and not _scorch_done:
			_scorch_done = true
			var where: Vector3 = look_target if look_target != null else Vector3.ZERO
			var bare: Array = []
			for col in main.game.map.tiles:
				for bt in col:
					if bt.is_free() and not bt.water:
						bare.append(bt)
			bare.sort_custom(func(a, b):
				return a.go.global_position.distance_to(where) < b.go.global_position.distance_to(where))
			var i := 0
			var scarred: Array = []
			for _n in scorch:
				var hit = bare[i % bare.size()]
				hit.damage_building_place(10.0, main.camera.global_position)
				if hit.groundDamage >= 50.0:
					i += 1
				if not scarred.has(hit):
					scarred.append(hit)
			for hit in scarred:
				print("scorch: %d,%d stage %d %s" % [hit.idxX, hit.idxZ, hit.ground_stage(), hit._ground_look])
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

## Fires the first gun that reaches tile --fire=x,z through the real try_shoot
## and schedules the muzzle and impact captures. --firegun re-aims the camera
## to the gun instead of keeping it on the --look target.
func _fire(t0: float) -> void:
	var tile = main.game.map.tiles[fire.x][fire.y]
	if wet:
		tile.water = true
	var guns: Array = []
	for col in main.game.map.tiles:
		for t in col:
			if U.alive(t.structure):
				var sh = U.shooter(t.structure)
				if sh != null:
					guns.append([t.go.global_position.distance_squared_to(look_target if look_target != null else tile.go.global_position), sh, t])
	guns.sort_custom(func(x, y): return x[0] < y[0])
	for g in guns:
		if g[1].try_shoot(tile.go.global_position, tile):
			_sched(g[1], g[2], t0)
			return
	# board scaffolding: no AI gun in reach yet - place a cannon that is
	if firewith != "cannon":
		var def = load("res://data/buildings/%s.tres" % firewith)
		for col in main.game.map.tiles:
			for t in col:
				if not (t.is_free() and not t.water):
					continue
				var placed: Node3D = main.game.players[0].place(def, t.idxX, t.idxZ)
				if not U.alive(placed):
					continue
				var psh = U.shooter(placed)
				if psh != null and psh.try_shoot(tile.go.global_position, tile):
					_sched(psh, t, t0)
					return
				U.destroy(placed)
		print("fire: no placed %s reached %d,%d" % [firewith, fire.x, fire.y])
		get_tree().quit(1)
		return
	var spot = null
	for col in main.game.map.tiles:
		for t in col:
			if t.is_free() and not t.water and not main.game.map.is_tile_enclosed(t.idxX, t.idxZ):
				var d2: float = t.go.global_position.distance_squared_to(tile.go.global_position)
				if d2 < 6.25 or d2 > 361.0:
					continue
				var near: float = t.go.global_position.distance_squared_to(look_target) if look_target != null else 1e9
				if spot == null or near < spot[0]:
					spot = [near, t]
	if spot == null:
		print("fire: no gun reached %d,%d and no ground to place one" % [fire.x, fire.y])
		get_tree().quit(1)
		return
	main.game.players[0].build_building(spot[1], Catalog.spawn("cannon"))
	var sh = U.shooter(spot[1].structure)
	sh.nextBulletTime = 0.0
	if sh.try_shoot(tile.go.global_position, tile):
		_sched(sh, spot[1], t0)
		return
	print("fire: the placed cannon at %d,%d cannot reach %d,%d" % [spot[1].idxX, spot[1].idxZ, fire.x, fire.y])
	get_tree().quit(1)


## Schedules the muzzle and impact captures and prints the board times.
func _sched(sh, gtile, t0: float) -> void:
	if firegun:
		_look_at(gtile.go.global_position)
	var sp: Node3D = sh.get_node_or_null(sh.projectileSpawn)
	if muzzlecam and sp != null:
		var mp := sp.global_position
		var aim3: Vector3 = main.game.map.tiles[fire.x][fire.y].go.global_position - mp
		aim3.y = 0.0
		aim3 = aim3.normalized() if aim3.length_squared() > 0.0001 else Vector3.FORWARD
		var perp := aim3.cross(Vector3.UP).normalized()
		main.camera.global_position = mp + perp * 2.6 + Vector3.UP * 1.15
		main.camera.look_at(mp + aim3 * 0.6)
	var ipos: Vector3 = main.game.map.tiles[fire.x][fire.y].go.global_position
	if sp != null:
		print("muzzle screen ", main.camera.unproject_position(sp.global_position))
	print("impact screen ", main.camera.unproject_position(ipos))
	var t_m := t0 + 0.12
	var t_i: float = t0 + sh.flyTime + 0.3
	for tt: float in [t_m, t_i]:
		var i := 0
		while i < shots.size() and shots[i] < tt:
			i += 1
		shots.insert(i, tt)
	print("fire: gun at %d,%d -> %d,%d fly=%.2f muzzle@%.2f impact@%.2f" % [gtile.idxX, gtile.idxZ, fire.x, fire.y, sh.flyTime, t_m, t_i])
