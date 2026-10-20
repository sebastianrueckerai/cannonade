extends Node
## The AI finishes the castle it started on, and the game ends as the last castle falls (I65), on
## a real versus map with the AI idle until the script fires its guns: the target list leads with
## the castles the enemy holds, the nearest to ruin first, never a neutral one; every gun fires at
## the first target in its reach; the shell that ruins the last castle ends the game at once.
##   godot --headless --fixed-fps 30 res://tests/finish_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var human
var enemy
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "4", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	human = game.players[0]
	enemy = game.players[1]
	enemy.dormant = true  # it fires when the script says so
	await _run()
	print("FINISH TEST PASSED" if failures.is_empty() else "FINISH TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


func _find_label(node, text: String) -> bool:
	if node is Label and node.text == text:
		return true
	for child in node.get_children():
		if _find_label(child, text):
			return true
	return false


func centre(c) -> Vector2i:
	return map.tile_index_at(c.go.global_position)


## The centre tile of a castle, the tile the AI aims at.
func seat(c):
	var cc := centre(c)
	return map.tiles[cc.x][cc.y]


func castles_of(p) -> Array:
	var out: Array = []
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == p:
			out.append(c)
	return out


## A neutral castle whose ring tiles are all free ground.
func ringable_neutral():
	for c in castles_of(null):
		var cc := centre(c)
		var ok := true
		for x in range(cc.x - 2, cc.x + 3):
			for z in range(cc.y - 2, cc.y + 3):
				if maxi(absi(x - cc.x), absi(z - cc.y)) == 2 and not map.tiles[x][z].is_free():
					ok = false
		if ok:
			return c
	return null


## A free tile between lo and hi from `near`, and `margin` nearer to it than to `far`.
func gun_spot(near: Vector3, lo: float, hi: float, far := Vector3.INF, margin := 0.0):
	for x in map.sizeX:
		for z in map.sizeZ:
			var t = map.tiles[x][z]
			var p: Vector3 = t.go.global_position
			var d: float = p.distance_to(near)
			if t.is_free() and d >= lo and d <= hi and p.distance_to(far) > d + margin:
				return t
	return null


func shells_of(p) -> Array:
	return U.projectiles.filter(func(s): return s.player == p)


## Waits until none of p's shells is in flight (the ships keep firing their own).
func landed(p) -> void:
	for i in 300:
		if shells_of(p).is_empty():
			return
		await get_tree().process_frame


func _run() -> void:
	game.timeLeftInRound = 1e6  # no phase flips while the script runs
	var a = castles_of(human)[0]
	var n = ringable_neutral()
	check(n != null, "a neutral castle with free ground round it exists")
	if n == null:
		return
	var nc := centre(n)
	human._wall_in(nc.x - 1, nc.y - 1, nc.x + 1, nc.y + 1)
	game.next_phase()  # to battle through the check: the ringed neutral is claimed
	game.timeLeftInRound = 1e6
	await frames(2)
	check(n.owner() == human and castles_of(human).size() == 2,
			"the human holds its start castle and the one it ringed")

	# 1: the list leads with the castles the enemy holds, the nearest to ruin first, never a neutral
	for i in 3:
		seat(a).damage_building_place(10.0)
	for i in 9:
		seat(n).damage_building_place(10.0)
	var targets: Array = enemy.aquire_targets(human)
	check(targets.slice(0, 2) == [seat(n), seat(a)],
			"the castle nearest to ruin comes first, the other held one second")
	var neutral_seats: Array = castles_of(null).map(seat)
	check(neutral_seats.size() == 7 and not targets.any(func(t): return neutral_seats.has(t)),
			"no neutral castle is a target")
	var walls: Array = targets.slice(2)
	check(walls.size() == human.wallTiles.size() and walls.all(func(t): return human.wallTiles.has(t)),
			"the enemy's walls follow the castles")
	check(walls[0].count_neighbouring_walls() >= walls[-1].count_neighbouring_walls()
			and walls[0].count_neighbouring_walls() > 1, "the most walled-in wall first")

	# 2: a gun that shoots back comes before everything
	var hs = gun_spot(seat(a).go.global_position, 3.0, 8.0)
	human.place(Catalog.get_def("cannon"), hs.idxX, hs.idxZ)
	check(enemy.aquire_targets(human)[0] == hs, "the enemy's gun comes first")
	hs.un_build()
	check(enemy.aquire_targets(human)[0] == seat(n), "and the castles again once it is gone")

	# 3: every gun fires at the first target in its reach: one AI cannon near the castle nearest to
	# ruin, and one cut down to a range that reaches the start castle alone (every gun of the data
	# reaches the whole map)
	var s1 = gun_spot(seat(n).go.global_position, 4.0, 12.0)
	var g1: Node3D = enemy.place(Catalog.get_def("cannon"), s1.idxX, s1.idxZ)
	var reload: float = U.shooter(g1).secondsBetweenShots
	var s2 = gun_spot(seat(a).go.global_position, 4.0, 10.0, seat(n).go.global_position, 3.0)
	check(s2 != null, "a spot nearer the start castle than the other exists")
	var g2: Node3D = enemy.place(Catalog.get_def("cannon"), s2.idxX, s2.idxZ)
	var short = U.shooter(g2)
	short.maxDesiredRange = s2.go.global_position.distance_to(seat(a).go.global_position) + 1.5
	short.refresh()
	check(not short.can_reach(s2.go.global_position.distance_to(seat(n).go.global_position)),
			"the short gun cannot reach the castle nearest to ruin")
	enemy.refresh_active_cannons()
	check(enemy.activeCannons.size() == 2, "the AI has two guns")
	enemy.search_and_fire_at_targets()
	check(shells_of(enemy).size() == 1, "one shot per action")
	enemy.search_and_fire_at_targets()  # the other gun; the first is reloading
	var aimed: Array = shells_of(enemy).map(func(s): return s.destinationTile)
	check(aimed.size() == 2 and aimed.has(seat(n)) and aimed.has(seat(a)),
			"each gun fires at the first target in its reach")
	await landed(enemy)
	check(n.state == 3 and a.state == 1 and game.started, "the shells land, nothing is a ruin yet")

	# 4: the castle nearest to ruin falls to the AI's next shell; the game goes on while one is held
	seat(n).damage_building_place(10.0)  # eleven
	await seconds(reload + 0.1)
	enemy.search_and_fire_at_targets()
	enemy.search_and_fire_at_targets()
	await landed(enemy)
	check(n.is_ruin() and human.castle_count() == 1 and game.started,
			"the twelfth shell leaves a ruin, and the game goes on while the human holds a castle")
	check(not enemy.aquire_targets(human).has(seat(n)), "a ruin is no target")

	# 5: the last castle falls in battle and the game ends at once, no check in between
	for i in 11 - 5:
		seat(a).damage_building_place(10.0)  # eleven: four, g2's second shell, then these
	check(a.state == 3 and game.started, "eleven shells on the last castle, the game is on")
	await seconds(reload + 0.1)
	var round_before: int = game.roundNumber
	enemy.search_and_fire_at_targets()
	enemy.search_and_fire_at_targets()
	check(shells_of(enemy).any(func(s): return s.destinationTile == seat(a)), "a shell flies at the last castle")
	await landed(enemy)
	check(a.is_ruin() and not game.started and game.roundNumber == round_before,
			"the shell that ruins the last castle ends the game at once, before any check")
	var overlay := main.get_node_or_null("GameOver")
	check(overlay != null and _find_label(overlay, "DEFEAT"), "the overlay shows the defeat")
