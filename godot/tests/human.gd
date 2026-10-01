extends Node
## Scripted test of the human player code paths using injected input
## (PlayerController.simulated_aim / simulated_actions).
##   godot --headless --fixed-fps 30 res://tests/human.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var human
var map
var failures: Array = []
var checks := 0


func _ready() -> void:
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "7"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	human = game.players[0]
	map = game.map
	# keep the AI from interfering with the scripted checks
	game.players[1].nextAction = 1e9
	await _run()
	print("checks=%d failures=%d" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: ", f)
	print("HUMAN TEST PASSED" if failures.is_empty() else "HUMAN TEST FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
		printerr("FAIL: ", msg)
	else:
		print("ok: ", msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(t: float) -> void:
	var end: float = U.time + t
	while U.time < end:
		await get_tree().process_frame


func aim_tile(x: int, z: int) -> void:
	human.simulated_aim = map.tile_position(x, z, 0.1)
	await frames(2)


func press(action: String) -> void:
	human.simulated_actions[action] = true
	await frames(2)


func base_xz() -> Vector2i:
	return Vector2i(map.sizeX / 2, map.sizeZ / 4)


func find_free_buildable(min_dist := 2) -> Vector2i:
	var b := base_xz()
	for r in range(min_dist, 4):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var x := b.x + dx
				var z := b.y + dz
				var t = map.tiles[x][z]
				if human.ibr(x, z) and not U.alive(t.structure) and t.buildable():
					return Vector2i(x, z)
	return Vector2i(-1, -1)


func _check_input_map() -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	check(InputMap.event_is_action(mb, "build_wall"), "left mouse button = build_wall")
	mb.button_index = MOUSE_BUTTON_RIGHT
	check(InputMap.event_is_action(mb, "build_building"), "right mouse button = build_building")
	for pair in [[KEY_SPACE, "fire"], [KEY_X, "rotate_cw"], [KEY_Y, "rotate_ccw"], [KEY_Z, "rotate_ccw"]]:
		var k := InputEventKey.new()
		k.physical_keycode = pair[0]
		k.pressed = true
		check(InputMap.event_is_action(k, pair[1]), "key %s = %s" % [OS.get_keycode_string(pair[0]), pair[1]])


func _run() -> void:
	_check_input_map()
	await frames(3)
	var b := base_xz()
	check(U.alive(map.tiles[b.x][b.y].structure), "start base built at %s" % b)
	var ring := 0
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if (dx != 0 or dz != 0) and U.alive(map.tiles[b.x + dx][b.y + dz].structure):
				ring += 1
	check(ring == 8, "start base is walled in (%d walls)" % ring)
	check(map.is_tile_enclosed(b.x, b.y), "base tile is enclosed")
	check(U.alive(human.nextWall), "human has a next wall preview")

	# --- rotate the next wall
	var bb = U.comp(human.nextWall, "BuildingBlock")
	var before: Array = bb.connects_up_down_left_right()
	await aim_tile(b.x, b.y)  # aiming at an occupied tile keeps the preview in the GUI
	await press("rotate_cw")
	var after: Array = bb.connects_up_down_left_right()
	check(after == [before[2], before[3], before[1], before[0]], "rotate clockwise turns connectors %s -> %s" % [before, after])
	await press("rotate_ccw")
	check(bb.connects_up_down_left_right() == before, "rotate counter clockwise restores connectors")

	# --- place a wall with the mouse
	var free := find_free_buildable()
	check(free.x >= 0, "found a free tile in build range")
	await aim_tile(free.x, free.y)
	check(human.canBuildOnTile, "can build on free tile in range")
	check(human.nextWall.get_parent() == map.tiles[free.x][free.y].go, "wall preview follows the cursor")
	var walls_before: int = human.wallTiles.size()
	var placed = human.nextWall
	await press("build_wall")
	check(human.wallTiles.size() == walls_before + 1, "wall placed (wallTiles %d -> %d)" % [walls_before, human.wallTiles.size()])
	check(map.tiles[free.x][free.y].structure == placed, "placed wall is the tile's structure")
	check(map.get_mini(free.x, free.y) == human.playerID, "miniMap marks the tile")
	check(U.alive(human.nextWall) and human.nextWall != placed, "a new wall is offered")

	# --- out of range tile is highlighted negative and not buildable
	await aim_tile(2, map.sizeZ - 3)
	check(not human.canBuildOnTile, "cannot build far away from own buildings")

	# --- drop the wall into the void
	human.simulated_aim = Vector3(500, 0.1, 500)
	await frames(2)
	var dropped = human.nextWall
	await press("build_wall")
	check(human.nextWall == null, "dropping the wall clears nextWall")
	await seconds(3.3)
	check(not U.alive(dropped), "dropped wall vanished")
	check(U.alive(human.nextWall), "new wall after the drop")

	# --- stack a wall on an own wall (rotate until it fits)
	var stacked := false
	for t in human.wallTiles:
		if U.alive(t.wallStacked):
			continue
		await aim_tile(t.idxX, t.idxZ)
		for r in 4:
			if human.canStackWall:
				break
			await press("rotate_cw")
		if human.canStackWall:
			await press("build_wall")
			stacked = U.alive(t.wallStacked)
			break
	if not stacked:
		# try with the start base walls (not in wallTiles)
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if stacked or (dx == 0 and dz == 0):
					continue
				var t = map.tiles[b.x + dx][b.y + dz]
				for attempt in 8:
					await aim_tile(t.idxX, t.idxZ)
					for r in 4:
						if human.canStackWall:
							break
						await press("rotate_cw")
					if human.canStackWall:
						await press("build_wall")
						stacked = U.alive(t.wallStacked)
						break
					# get another wall piece
					human.drop(human.nextWall, true)
					await seconds(3.2)
	check(stacked, "stacked a wall on an own wall")

	# --- buildings: wait for one, place it
	await seconds(0.5)
	check(U.alive(human.nextBuilding), "a next building is offered")
	free = find_free_buildable()
	await aim_tile(free.x, free.y)
	var building = human.nextBuilding
	await press("build_building")
	check(map.tiles[free.x][free.y].structure == building, "building placed with the right mouse button")

	# --- combine: Upgrade_a on Upgrade_a gives a supply building
	var up_tile := find_free_buildable()
	var up_a: Node3D = U.instantiate(preload("res://prefabs/Upgrade_a.tscn"))
	human.build_building(map.tiles[up_tile.x][up_tile.y], up_a)
	U.destroy(human.nextBuilding)
	human.nextBuilding = U.instantiate(preload("res://prefabs/Upgrade_a.tscn"), human.buildingSpawn)
	await aim_tile(up_tile.x, up_tile.y)
	check(human.canCombine, "can combine upgrade with upgrade block")
	await press("build_building")
	var combined = map.tiles[up_tile.x][up_tile.y].structure
	check(U.comp(combined, "SupplyBuilding") != null, "combination produced a supply building")
	check(human.supplies.has(up_tile), "supply registered for the player")

	# --- 2x2 upgrade cluster becomes a big cannon
	var corner := Vector2i(-1, -1)
	for x in range(2, map.sizeX - 3):
		for z in range(2, map.sizeZ - 3):
			var ok := true
			for dx in 2:
				for dz in 2:
					var t = map.tiles[x + dx][z + dz]
					ok = ok and not U.alive(t.structure) and not t.water and not U.alive(t.ship)
			if ok and corner.x < 0:
				corner = Vector2i(x, z)
	var guns_before: int = human.cannons.size()
	for k in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		human.build_building(map.tiles[corner.x + k.x][corner.y + k.y], U.instantiate(preload("res://prefabs/Upgrade_a.tscn")))
	var big = map.tiles[corner.x + 1][corner.y + 1].structure
	check(human.cannons.size() == guns_before + 1, "2x2 upgrade cluster turned into a cannon")
	check(big != null and big.scene_file_path.ends_with("Cannon22a.tscn"), "cluster structure is Cannon22a (%s)" % [big.scene_file_path if big else "none"])
	var cluster_ok := true
	for k in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		cluster_ok = cluster_ok and map.tiles[corner.x + k.x][corner.y + k.y].upgradeCluster != null
	check(cluster_ok, "all four tiles belong to the cluster")

	# --- enclose a gun and fire at the enemy
	var gun_tile := Vector2i(b.x, b.y + 3)
	var plans := {
		Vector2i(-1, 1): [false, true, false, true], Vector2i(1, 1): [false, true, true, false],
		Vector2i(-1, -1): [true, false, false, true], Vector2i(1, -1): [true, false, true, false],
		Vector2i(0, -1): [false, false, true, true], Vector2i(0, 1): [false, false, true, true],
		Vector2i(-1, 0): [true, true, false, false], Vector2i(1, 0): [true, true, false, false]}
	for k in plans:
		var t = map.tiles[gun_tile.x + k.x][gun_tile.y + k.y]
		if U.alive(t.structure):
			t.un_build()
		human._build_from_random_prefabs(t, plans[k])
	var gt = map.tiles[gun_tile.x][gun_tile.y]
	if U.alive(gt.structure):
		gt.un_build()
	human.build_building(gt, U.instantiate(preload("res://prefabs/Cannon.tscn")))
	await frames(2)
	check(map.is_tile_enclosed(gun_tile.x, gun_tile.y), "new ring encloses the gun tile")
	check(human.activeCannons.size() >= 1, "enclosed gun is active (%d active)" % human.activeCannons.size())
	# switch to the battle phase
	game.timeLeftInRound = -1.5
	await frames(2)
	check(game.shootingAllowed and not game.buildingAllowed, "battle phase started")
	var enemy = game.players[1]
	var target = enemy.startBase.buildingPlace
	var target_tile = map.tiles[target.idxX][target.idxZ - 1]
	var hp_before: float = U.comp(target_tile.structure, "BuildingBlock").health
	await aim_tile(target_tile.idxX, target_tile.idxZ)
	var shots_before := U.projectiles.size()
	await press("fire")
	check(U.projectiles.size() > shots_before, "fire launches a projectile")
	await seconds(12.0)
	var still_there := U.alive(target_tile.structure)
	var hp_after: float = U.comp(target_tile.structure, "BuildingBlock").health if still_there else 0.0
	check(hp_after < hp_before, "enemy wall took damage (%.1f -> %.1f)" % [hp_before, hp_after])
