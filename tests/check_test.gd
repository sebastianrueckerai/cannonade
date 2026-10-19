extends Node
## The rules-v3 check on a real versus map (seed fixed, enemy idle): the castle layout, the burn,
## the claim, the parts gate, castle damage states, the ruin and the game end.
##   godot --headless --fixed-fps 30 res://tests/check_test.tscn

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
	enemy.dormant = true  # keep the map static; the rules are under test, not the AI
	await _run()
	print("CHECK TEST PASSED" if failures.is_empty() else "CHECK TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
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


func neutrals() -> Array:
	var out: Array = []
	for c in map.castles:
		if U.alive(c) and not c.is_ruin() and c.owner() == null:
			out.append(c)
	return out


func ruins() -> int:
	var n := 0
	for c in map.castles:
		if U.alive(c) and c.is_ruin():
			n += 1
	return n


## Runs one check: to battle (the check fires there) and straight back to building.
func run_check() -> void:
	if not game.buildingAllowed:
		game.next_phase()
	game.next_phase()
	game.next_phase()


## Free, open (never enclosed) tiles at Chebyshev distance at least 8 from both start castles.
func open_tiles() -> Array:
	var starts := [Vector2i(15, 7), Vector2i(15, 23)]
	var out: Array = []
	for x in map.sizeX:
		for z in map.sizeZ:
			var t = map.tiles[x][z]
			if U.alive(t.structure) or t.water or t.disabled or map.is_tile_enclosed(x, z):
				continue
			var far := true
			for s in starts:
				if max(absi(x - s.x), absi(z - s.y)) < 8:
					far = false
			if far:
				out.append(Vector2i(x, z))
	return out


## A neutral castle whose whole ring (Chebyshev 2) is free and dry.
func ringable_neutral() -> Vector2i:
	for c in neutrals():
		var cc := centre(c)
		var ok := true
		for x in range(cc.x - 2, cc.x + 3):
			for z in range(cc.y - 2, cc.y + 3):
				if absi(x - cc.x) < 2 and absi(z - cc.y) < 2:
					continue
				var t = map.tiles[x][z]
				if U.alive(t.structure) or t.water or t.disabled:
					ok = false
		if ok:
			return cc
	return Vector2i(-1, -1)


func _run() -> void:
	await frames(3)
	var open := open_tiles()

	# 1: the layout
	var owned: Array = []
	for c in map.castles:
		if U.alive(c) and c.owner() != null:
			owned.append(c)
	check(map.castles.size() == 10 and owned.size() == 2 and neutrals().size() == 8,
			"ten castles: two owned, eight neutral")
	for c in owned:
		var cc := centre(c)
		check(map.is_tile_enclosed(cc.x, cc.y), "the start castle at %s is walled in" % [cc])
	for c in neutrals():
		check(map.get_mini(centre(c).x, centre(c).y) == 255, "the neutral castle at %s reads 255" % [centre(c)])
	var all: Array = map.castles.map(func(c): return centre(c))
	var min_dist := 999
	for i in all.size():
		for j in range(i + 1, all.size()):
			min_dist = mini(min_dist, max(absi(all[i].x - all[j].x), absi(all[i].y - all[j].y)))
	check(min_dist >= 5, "castle centres keep Chebyshev distance 5 (closest %d)" % [min_dist])
	check(human.partsCap == 6 and enemy.partsCap == 6, "one castle caps both players at 6 parts")

	# 2: the burn (an open gun goes, an open wall stays)
	var gun_spot: Vector2i = open[0]
	var wall_spot: Vector2i = open[1]
	human.build_building(map.tiles[gun_spot.x][gun_spot.y], Catalog.spawn("cannon"))
	human._build_from_random_prefabs(map.tiles[wall_spot.x][wall_spot.y], [true, true, false, false])
	check(human.parts_used() == 1, "the open gun costs a part")
	run_check()
	await frames(2)
	check(not U.alive(map.tiles[gun_spot.x][gun_spot.y].structure) and human.parts_used() == 0,
			"the gun outside the walls burns at the check")
	check(map.tiles[wall_spot.x][wall_spot.y].isWall, "an open wall never burns")
	check(neutrals().size() == 8 and ruins() == 0, "no neutral burns or ruins")

	# 3: the claim (ring a neutral)
	var target := ringable_neutral()
	check(target.x > 0, "a neutral with room for a ring exists")
	human._wall_in(target.x - 1, target.y - 1, target.x + 1, target.y + 1)
	check(map.is_tile_enclosed(target.x, target.y), "the ring encloses the neutral castle")
	run_check()
	await frames(2)
	var claimed = null
	for c in map.castles:
		if centre(c) == target:
			claimed = c
	check(claimed != null and claimed.owner() == human, "the ringed neutral castle changes owner")
	check(map.get_mini(target.x, target.y) == human.playerID, "the mini map follows the claim")
	check(human.partsCap == 10, "two castles raise the cap to 10")

	# 4: the parts gate
	var spots: Array = open.slice(2, 14)
	var placed: Array = []
	for i in 11:
		human.nextBuilding = Catalog.spawn("cannon")
		human.build_next_building(map.tiles[spots[i].x][spots[i].y])
		if U.alive(map.tiles[spots[i].x][spots[i].y].structure):
			placed.append(spots[i])
	check(placed.size() == 10 and human.parts_used() == 10, "ten one-part guns fill the cap of 10")
	check(not U.alive(map.tiles[spots[10].x][spots[10].y].structure) and U.alive(human.nextBuilding),
			"the eleventh gun is not placed and the draw is kept")
	for i in 4:
		map.tiles[spots[0].x][spots[0].y].damage_building_place(10.0)
	check(human.parts_used() == 9, "a destroyed gun frees its part")
	human.build_next_building(map.tiles[spots[10].x][spots[10].y])
	check(U.alive(map.tiles[spots[10].x][spots[10].y].structure), "with a part free the gun is placed")
	for s in spots:
		if U.alive(map.tiles[s.x][s.y].structure):
			map.tiles[s.x][s.y].un_build()
	check(human.parts_used() == 0, "the fixture guns are cleared")

	# 8: a hit gun reloads slower
	var gun := Catalog.spawn("cannon")
	human.build_building(map.tiles[spots[0].x][spots[0].y], gun)
	var shooter := U.shooter(gun)
	check(is_equal_approx(shooter._interval(), 2.0), "a fresh gun reloads in its base interval")
	map.tiles[spots[0].x][spots[0].y].damage_building_place(10.0)
	check(is_equal_approx(shooter._interval(), 3.0), "a gun that survived a shell reloads half again slower")
	map.tiles[spots[0].x][spots[0].y].un_build()

	# 9: castle damage states on a third neutral
	var victim := ringable_neutral()
	var vc = null
	for c in map.castles:
		if centre(c) == victim:
			vc = c
	for hits in [3, 6, 9]:
		for i in 3:
			map.tiles[victim.x][victim.y].damage_building_place(10.0)
		check(vc.state == hits / 3, "%d shells show damage state d%d" % [hits, hits / 3])
	check(neutrals().size() == 7 and ruins() == 0, "a damaged neutral is neither claimed nor ruined")

	# 5: the ruin
	for i in 3:
		map.tiles[victim.x][victim.y].damage_building_place(10.0)
	check(vc.is_ruin() and U.alive(vc.go) and vc.state == 4, "twelve shells leave the d4 ruin")
	check(map.get_mini(victim.x, victim.y) == 255, "the ruin reads 255")
	check(not human.can_place(Catalog.get_def("castle"), victim.x - 1, victim.y - 1),
			"nothing can be placed on the ruin")
	human._wall_in(victim.x - 1, victim.y - 1, victim.x + 1, victim.y + 1)
	run_check()
	await frames(2)
	check(vc.is_ruin() and vc.owner() == null, "the ruin is never claimed, walled in or not")
	check(ruins() == 1 and neutrals().size() == 6, "only the shelled castle is a ruin")

	# 6: the end
	for i in 12:
		map.tiles[15][23].damage_building_place(10.0)
	check(enemy.castle_count() == 0, "the enemy holds no castle any more")
	game.next_phase()
	check(not game.started, "a player without a castle is out at the check")
	var overlay := main.get_node_or_null("GameOver")
	check(overlay != null and _find_label(overlay, "VICTORY"), "the overlay shows the victory")
