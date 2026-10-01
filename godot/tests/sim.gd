extends Node
## Headless simulation test. Runs a game mode for a while with a fixed time
## step, prints the game state periodically and checks invariants.
##
##   godot --headless --fixed-fps 30 res://tests/sim.tscn -- --mode=ai2 --seconds=120 --seed=3

const Main = preload("res://scripts/Main.gd")

var main: Node
var seconds := 60.0
var report_every := 10.0
var next_report := 0.0
var failures: Array = []
var frame_times: Array = []
var stats := {"max_projectiles": 0, "shots": 0, "rounds": 0}
var _last_proj_ids := {}
var autobuild := false
var _next_autobuild := 1.0
var _ship_start := {}


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	seconds = float(args.get("seconds", "60"))
	autobuild = args.has("autobuild")
	Main.requested_args = args
	Main.requested_mode = args.get("mode", "ai2")
	report_every = float(args.get("report", "10"))
	main = Main.new()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	main.game.profile = true


var _last_tick := 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_tick > 0 and U.time > 1.0:
		frame_times.append(now - _last_tick)
	_last_tick = now
	if main == null or main.game == null:
		return
	var g = main.game
	for p in U.projectiles:
		var id: int = p.get_instance_id()
		if not _last_proj_ids.has(id):
			_last_proj_ids[id] = true
			stats["shots"] += 1
	stats["max_projectiles"] = maxi(stats["max_projectiles"], U.projectiles.size())
	stats["rounds"] = g.roundNumber
	if autobuild and U.time >= _next_autobuild:
		_next_autobuild = U.time + 0.5
		_autobuild(g)
	for ship in g.fleet.ships:
		if not _ship_start.has(ship):
			_ship_start[ship] = ship.go.global_position
		elif ship.go.global_position.distance_to(_ship_start[ship]) > 0.5:
			stats["ships_moved"] = stats.get("ships_moved", {})
			stats["ships_moved"][ship.get_instance_id()] = true
	if U.time >= next_report:
		next_report += report_every
		_report(g)
		_check_invariants(g)
	if U.time >= seconds:
		_report(g)
		_check_invariants(g)
		_finish()


## Very simple stand-in for a human: places walls on free tiles in range.
func _autobuild(g) -> void:
	for p in g.players:
		if p.has_method("search_best_building_plans") or not g.buildingAllowed or not U.alive(p.nextWall):
			continue
		var cands: Array = []
		for x in g.map.sizeX:
			for z in g.map.sizeZ:
				var t = g.map.tiles[x][z]
				if p.ibr(x, z) and not U.alive(t.structure) and t.buildable():
					cands.append(t)
		if not cands.is_empty():
			p.build_next_wall(cands[U.rint(0, cands.size())])


func _report(g) -> void:
	var line := "t=%6.1f round=%d %s proj=%d shots=%d |" % [U.time, g.roundNumber,
			"BUILD" if g.buildingAllowed else "FIGHT", U.projectiles.size(), stats["shots"]]
	for p in g.players:
		var enclosed := 0
		for x in g.map.sizeX:
			for z in g.map.sizeZ:
				if g.map.is_tile_enclosed(x, z):
					enclosed += 1
		var stacked := 0
		for t in p.wallTiles:
			if U.alive(t.wallStacked):
				stacked += 1
		line += " P%d walls=%d stacked=%d guns=%d active=%d sup=%d supply=%.0f/%.0f upg=%d" % [
			p.playerID, p.wallTiles.size(), stacked, p.cannons.size(), p.activeCannons.size(),
			p.supports.size(), p.availableSupply, p.supplyNeed, p.upgrades.size()]
		if p.has_method("search_best_building_plans"):
			line += " plans=%d/%d" % [p.activePlans.size(), p.finishedPlans.size()]
		line += " |"
	line += " enclosed_tiles=%d ships=%d" % [_count_enclosed(g), g.fleet.ships.size()]
	print(line)


func _count_enclosed(g) -> int:
	var n := 0
	for x in g.map.sizeX:
		for z in g.map.sizeZ:
			if g.map.is_tile_enclosed(x, z):
				n += 1
	return n


func _fail(msg: String) -> void:
	if not failures.has(msg):
		failures.append(msg)
		printerr("INVARIANT FAILED: ", msg)


func _check_invariants(g) -> void:
	var m = g.map
	for x in m.sizeX:
		for z in m.sizeZ:
			var t = m.tiles[x][z]
			var owner_id: int = m.get_mini(x, z)
			if U.alive(t.structure):
				var bb := U.comp(t.structure, "BuildingBlock")
				if bb == null:
					_fail("structure without BuildingBlock at %d,%d" % [x, z])
				if owner_id == 0:
					_fail("built tile %d,%d not in miniMap" % [x, z])
			elif owner_id != 0 and t.upgradeCluster == null:
				_fail("miniMap says %d at empty tile %d,%d" % [owner_id, x, z])
			if t.water and U.alive(t.structure):
				_fail("building on water %d,%d" % [x, z])
	for p in g.players:
		for t in p.wallTiles:
			if not U.alive(t.structure) or U.comp(t.structure, "Wall") == null:
				_fail("player %d wallTiles contains a tile without wall" % p.playerID)
		for k in p.cannons:
			if not U.alive(p.cannons[k]):
				_fail("player %d has a dead cannon at %s" % [p.playerID, k])


func _finish() -> void:
	frame_times.sort()
	var n := frame_times.size()
	if n > 0:
		var total := 0
		for f in frame_times:
			total += f
		print("frames=%d mean=%.2fms p50=%.2fms p99=%.2fms max=%.2fms" % [n, total / 1000.0 / n,
				frame_times[n / 2] / 1000.0, frame_times[int(n * 0.99)] / 1000.0, frame_times[-1] / 1000.0])
	if stats.has("ships_moved"):
		stats["ships_moved"] = stats["ships_moved"].size()
	print("stats: ", stats)
	print("profile us: supply/select=%d actions=%d" % main.game.profile_data)
	var SM = load("res://scripts/StatesMap.gd")
	print("statesMap.update_tile: calls=%d total=%.1fms" % [SM.profile_calls, SM.profile_usec / 1000.0])
	if failures.is_empty():
		print("SIM PASSED")
		get_tree().quit(0)
	else:
		print("SIM FAILED: ", failures)
		get_tree().quit(1)
	set_process(false)
