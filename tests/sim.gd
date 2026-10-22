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
var _walls_last := {}
var _walls_lost := {}
var _guns_last := {}
var _guns_lost := {}
var _max_walls := {}
## walls each player holds at the first sample: the start ring
var _start_walls := {}
var _max_active := {}
var _next_autobuild := 1.0
var _ship_start := {}
## per AI player as the last frame ended: what it had placed, the tiles in its reach, the ground other
## players' rings closed
var _rules_last := {}
## microseconds the rules check took since the last frame tick, kept out of the frame times
var _rules_usec := 0
## every phase flip as the frame before it ended: its phase, its clock, the sides' guns and shells
var _flips: Array = []
var _flipRound := -1
var _flipRow := {}


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


var _last_tick := 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_tick > 0 and U.time > 1.0:
		frame_times.append(now - _last_tick - _rules_usec)
	_last_tick = now
	_rules_usec = 0
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
	var armed := 0
	for p in g.players:
		armed += p.activeCannons.size()
	var shells := 0
	for s in U.projectiles:
		if s.player != null:
			shells += 1
	if g.roundNumber != _flipRound:
		if _flipRound >= 0:
			_flips.append(_flipRow)
		_flipRound = g.roundNumber
	_flipRow = {"phase": g.phase, "left": g.timeLeftInRound, "guns": armed, "shells": shells}
	if not stats.get("marked") and not U.projectiles.is_empty():
		_scan_marked(g)
	for p in g.players:
		var k: int = p.playerID
		var walls: int = p.wallTiles.size()
		if walls < _walls_last.get(k, 0):
			_walls_lost[k] = true
		_walls_last[k] = walls
		var guns: int = p.cannons.size()
		if guns < _guns_last.get(k, 0):
			_guns_lost[k] = true
		_guns_last[k] = guns
		if not _start_walls.has(k):
			_start_walls[k] = walls
		_max_walls[k] = maxi(_max_walls.get(k, 0), walls)
		_max_active[k] = maxi(_max_active.get(k, 0), p.activeCannons.size())
	var t0 := Time.get_ticks_usec()
	_check_ai_rules(g)
	_rules_usec = Time.get_ticks_usec() - t0
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


## Sees whether any tile currently carries a targeting marker.
func _scan_marked(g) -> void:
	for x in g.map.sizeX:
		for z in g.map.sizeZ:
			if g.map.tiles[x][z]._target_tints > 0:
				stats["marked"] = true
				return


## Very simple stand-in for a human: places the held piece where it fits.
func _autobuild(g) -> void:
	for p in g.players:
		if p.is_ai() or g.phase != g.Phase.WALLS or not U.alive(p.nextWall):
			continue
		var cands: Array = []
		for x in g.map.sizeX:
			for z in g.map.sizeZ:
				var t = g.map.tiles[x][z]
				if p.can_place_piece(t):
					cands.append(t)
		if not cands.is_empty():
			p.build_next_wall(cands[U.rint(0, cands.size())])


func _report(g) -> void:
	var line := "t=%6.1f flips=%d %s proj=%d shots=%d |" % [U.time, g.roundNumber,
			["WALLS", "GUNS", "FIGHT"][g.phase], U.projectiles.size(), stats["shots"]]
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
		line += " P%d walls=%d stacked=%d guns=%d parts=%d/%d castles=%d upg=%d" % [
			p.playerID, p.wallTiles.size(), stacked, p.cannons.size(), p.parts_used(), p.partsCap,
			p.castle_count(), p.upgrades.size()]
		if p.is_ai():
			var open := 0
			for plan in p.activePlans:
				if not plan.closed():
					open += 1
			line += " plans=%d open=%d" % [p.activePlans.size(), open]
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


## The game actually got played: rounds alternate on time, every AI builds,
## arms itself and fights, ships sail and shoot.
func _check_outcome(g) -> void:
	# a phase flips one second past its end (see _update_round_time); a battle also flips once no
	# side holds a gun and no side's shell is in the air, after its grace (session 56). A game
	# decided by conquest stops the phase clock where it stands.
	for row in _flips:
		if row["left"] < -0.5:
			continue
		if row["phase"] == g.Phase.BATTLE and row["guns"] == 0 and row["shells"] == 0:
			continue
		_fail("the %s phase flipped at %.1f s left" % [["walls", "guns", "battle"][row["phase"]], row["left"]])
	var battle_happened: bool = g.roundNumber >= 2
	var n_ais := 0
	for p in g.players:
		if p.is_ai():
			n_ais += 1
	for p in g.players:
		var k: int = p.playerID
		if not p.is_ai():
			continue
		var built: int = _max_walls.get(k, 0) - _start_walls.get(k, 0)
		if built < 5:
			_fail("AI %d built only %d walls beyond its start ring" % [k, built])
		if _max_active.get(k, 0) < 1:
			_fail("AI %d never had an active gun" % k)
		# only an AI enemy shoots back (the versus human stands still), and the
		# AI aims at guns and castles before walls now
		if battle_happened and n_ais > 1 \
				and not (_walls_lost.get(k, false) or _guns_lost.get(k, false)):
			_fail("AI %d never lost a wall or a gun in battle" % k)
	if battle_happened and stats["shots"] == 0:
		_fail("nobody fired")
	# the aim light rides only the human's cursor now (I77), and the sim's human never aims:
	# no tile is ever marked, with or without a human
	if stats.get("marked") and battle_happened:
		_fail("a tile carried a targeting marker in the battle though nobody aimed")
	if g.fleet.ships.size() > 0:
		var moved: int = stats.get("ships_moved", 0)
		if moved != g.fleet.ships.size():
			_fail("only %d of %d ships moved" % [moved, g.fleet.ships.size()])
		if stats["shots"] == 0:
			_fail("ships never fired")


func _fail(msg: String) -> void:
	if not failures.has(msg):
		failures.append(msg)
		printerr("INVARIANT FAILED: ", msg)


func _check_invariants(g) -> void:
	var m = g.map
	var aimed := {}
	for p in U.projectiles:
		if U.alive(p.destinationTile):
			aimed[p.destinationTile] = true
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
			if U.get_color(t.model()) == Color.BLACK:
				_fail("tile %d,%d painted pure black (selection must outline, not blacken)" % [x, z])
			if t._target_tints > 0 and not aimed.has(t):
				_fail("tile %d,%d marked but no live shot aims at it" % [x, z])
	for p in g.players:
		for t in p.wallTiles:
			if not U.alive(t.structure) or U.comp(t.structure, "Wall") == null:
				_fail("player %d wallTiles contains a tile without wall" % p.playerID)
		for k in p.cannons:
			if not U.alive(p.cannons[k]):
				_fail("player %d has a dead cannon at %s" % [p.playerID, k])


## An AI places by the human's rules: every wall piece and gun it adds this frame has a tile within
## map.buildingRange of its walls and held castles, and none on ground another player's ring closed, as the
## last frame ended. Derived here, not read from the player's own checks.
func _check_ai_rules(g) -> void:
	var m = g.map
	for p in g.players:
		if not p.is_ai():
			continue
		var tiles: Array = p.wallTiles.map(func(t): return Vector2i(t.idxX, t.idxZ))
		tiles.append_array(p.cannons.keys())
		var last = _rules_last.get(p)
		if last != null:
			var added: Array = tiles.filter(func(k): return not last["placed"].has(k))
			if not added.is_empty() and not added.any(func(k): return last["reach"].has(k)):
				_fail("player %d placed %s more than %d tiles from its walls and castles" % [p.playerID, added, m.buildingRange])
			var inside: Array = added.filter(func(k): return last["enemy"].has(k))
			if not inside.is_empty():
				_fail("player %d placed %s on ground another player's ring closed" % [p.playerID, inside])
		var placed := {}
		for k in tiles:
			placed[k] = true
		var anchors: Array = p.wallTiles.map(func(t): return Vector2i(t.idxX, t.idxZ))
		for c in m.castles:
			if U.alive(c) and not c.is_ruin() and c.owner() == p:
				anchors.append_array(c.my_tiles().map(func(t): return Vector2i(t.idxX, t.idxZ)))
		var reach := {}
		var r: int = m.buildingRange
		for a in anchors:
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					reach[a + Vector2i(dx, dz)] = true
		var enemy := {}
		for x in m.sizeX:
			for z in m.sizeZ:
				var t = m.tiles[x][z]
				if m.is_tile_enclosed(x, z) and t.ringOwner != null and t.ringOwner != p:
					enemy[Vector2i(x, z)] = true
		_rules_last[p] = {"placed": placed, "reach": reach, "enemy": enemy}


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
	_check_outcome(main.game)
	if failures.is_empty():
		print("SIM PASSED")
		get_tree().quit(0)
	else:
		print("SIM FAILED: ", failures)
		get_tree().quit(1)
	set_process(false)
