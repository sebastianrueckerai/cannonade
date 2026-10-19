extends Node
## Human player through real input events (mouse motion / buttons and keys
## pushed into Godot's Input, mapped by the project's InputMap).
##   godot --headless --fixed-fps 30 res://tests/human.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var human
var map
var mouse := Vector2.ZERO
var failures: Array = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "7", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	human = game.players[0]
	map = game.map
	game.players[1].nextAction = 1e9  # keep the AI idle during the scripted checks
	await _run()
	print("HUMAN TEST PASSED" if failures.is_empty() else "HUMAN TEST FAILED: %s" % [failures])
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


## Moves the mouse over the world position p.
func point_at(p: Vector3) -> void:
	mouse = main.camera.unproject_position(p)
	var ev := InputEventMouseMotion.new()
	ev.position = mouse
	Input.parse_input_event(ev)
	await frames(2)


func point_at_tile(xz: Vector2i) -> void:
	await point_at(map.tile_position(xz.x, xz.y, 0.1))


## Presses and releases the input bound to action.
func press(action: String) -> void:
	for pressed in [true, false]:
		var ev: InputEvent
		match action:
			"build_wall", "build_building":
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT if action == "build_wall" else MOUSE_BUTTON_RIGHT
				mb.position = mouse
				ev = mb
			_:
				var k := InputEventKey.new()
				k.physical_keycode = {"fire": KEY_SPACE, "rotate_cw": KEY_X, "rotate_ccw": KEY_Y}[action]
				ev = k
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(1)


func base_xz() -> Vector2i:
	return Vector2i(map.sizeX / 2, map.sizeZ / 4)


func free_tile_in_range() -> Vector2i:
	var b := base_xz()
	for r in range(2, 4):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var t = map.tiles[b.x + dx][b.y + dz]
				if human.ibr(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable():
					return Vector2i(t.idxX, t.idxZ)
	return Vector2i(-1, -1)


## A free 2x2 square in build range, for the cannon fusion.
func free_quad_in_range() -> Vector2i:
	var b := base_xz()
	for r in range(2, 5):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var x: int = b.x + dx
				var z: int = b.y + dz
				var free := true
				for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var t = map.tiles[x + q.x][z + q.y]
					if not (human.ibr(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable()):
						free = false
				if free:
					return Vector2i(x, z)
	return Vector2i(-1, -1)


func _run() -> void:
	await frames(3)
	var b := base_xz()
	check(map.is_tile_enclosed(b.x, b.y), "player starts with a walled-in castle")

	# rotating the held piece with X / Y (a T: no quarter turn maps it onto itself)
	_hold("wall_t")
	var bb = U.comp(human.nextWall, "BuildingBlock")
	await point_at_tile(b)
	await press("rotate_cw")
	check(bb.cells == _v([[0, 1], [0, 0], [0, -1], [1, 0]]), "X turns the T clockwise, its stem to the right %s" % [bb.cells])
	await press("rotate_ccw")
	check(bb.cells == _v([[-1, 0], [0, 0], [1, 0], [0, 1]]), "Y turns it back %s" % [bb.cells])

	# left click stamps one block per cell, on the tiles the ghost covered; the piece is used up.
	# Upright three west of the ring: its tiles sit two from the ring's west side.
	var w := Vector2i(b.x - 4, b.y)
	var want := [w + Vector2i(0, 1), w, w + Vector2i(0, -1)]
	check(_all_free(want), "the three tiles west of the ring are free")
	_hold("wall_3")
	U.comp(human.nextWall, "BuildingBlock").rotate_clockwise()
	await point_at_tile(w)
	var ghost: Array = []
	for n in human.nextWall.get_children():
		if n is Node3D:
			ghost.append(map.tile_index_at(n.global_position))
	check(ghost == want, "the ghost of the upright three covers %s (got %s)" % [want, ghost])
	var piece = human.nextWall
	var walls_before: int = human.wallTiles.size()
	await press("build_wall")
	check(_all_blocks(want), "left click stamps a wall block on every tile the ghost covered")
	check(human.wallTiles.size() == walls_before + 3, "the three blocks count as the player's walls")
	check(not U.alive(piece) and U.alive(human.nextWall), "the piece is used up and a new one is offered")

	# a piece hanging off the map edge places nothing, even with its other cells in reach
	var edge := Vector2i(0, b.y)
	check(_all_free([Vector2i(0, b.y), Vector2i(1, b.y), Vector2i(2, b.y)]), "the row at the west edge is free")
	human.build_wall(map.tiles[2][b.y], Catalog.spawn("wall"))
	_hold("wall_3")
	await point_at_tile(edge)
	await press("build_wall")
	check(not U.alive(map.tiles[0][b.y].structure) and not U.alive(map.tiles[1][b.y].structure),
			"a piece hanging off the map edge places nothing")

	# out of range: nothing is built (clear of every neutral castle band)
	var far := Vector2i(10, 15)
	await point_at_tile(far)
	await press("build_wall")
	check(not U.alive(map.tiles[far.x][far.y].structure), "no building far away from own walls")

	# clicking outside the map discards the piece; a new one comes after it flew away
	var dropped = human.nextWall
	await point_at(map.tile_position(-6, -6))
	await press("build_wall")
	await seconds(3.3)
	check(not U.alive(dropped) and U.alive(human.nextWall), "click outside the map discards the piece")

	# stacking: a single block stacks on an own wall, a longer piece never does
	var target = map.tiles[w.x][w.y]
	_hold("wall_3")
	await point_at_tile(w)
	await press("build_wall")
	check(not U.alive(target.wallStacked), "a three-block piece does not stack")
	_hold("wall_1")
	await point_at_tile(w)
	await press("build_wall")
	check(U.alive(target.wallStacked) and Catalog.def_of(target.wallStacked).id == "wall",
			"a single block stacks on an own wall")

	# right click places the next building (a fixed piece: a drawn gun here would
	# also count as active below)
	await seconds(0.5)
	_offer_building("supply")
	var building = human.nextBuilding
	var free := free_tile_in_range()
	await point_at_tile(free)
	await press("build_building")
	check(U.alive(building) and map.tiles[free.x][free.y].structure == building, "right click places the building")

	# right click with a cannon on the fourth tile of a 2x2 fuses the heavy gun
	var quad := free_quad_in_range()
	for i in 3:
		var q = map.tiles[quad.x + i / 2][quad.y + i % 2]
		human.build_building(q, Catalog.spawn("cannon"))
	_offer_building("cannon")
	await point_at_tile(quad + Vector2i(1, 1))
	await press("build_building")
	var fused = map.tiles[quad.x][quad.y].structure
	check(U.alive(fused) and Catalog.def_of(fused).id == "cannon22a",
			"the fourth cannon fuses the square into the heavy gun (got %s)"
			% [Catalog.def_of(fused).id if U.alive(fused) else "nothing"])
	map.tiles[quad.x][quad.y].upgradeCluster.un_build_upgrade()  # would burn outside the walls

	# a gun inside the walls fires at the enemy in the battle phase
	_pocket()
	_offer_building("cannon")
	await point_at_tile(b + Vector2i(3, 0))
	await press("build_building")
	await frames(2)  # active guns are re-evaluated every frame
	check(human.activeCannons.size() == 1, "gun inside the walls is active")
	game.timeLeftInRound = -1.5  # skip to the battle phase
	await frames(2)
	var enemy = null
	for c in map.castles:
		if c.owner() == game.players[1]:
			enemy = c
			break
	var ec: Vector2i = map.tile_index_at(enemy.go.global_position)
	var enemy_wall = map.tiles[ec.x][ec.y - 2]  # the ring wall south of the 3x3 castle
	await point_at_tile(Vector2i(enemy_wall.idxX, enemy_wall.idxZ))
	await press("fire")
	await seconds(12.0)
	check(not U.alive(enemy_wall.structure), "space fires a shell that destroys the aimed enemy wall")


## Replaces the randomly drawn wall piece (fixture for a specific piece).
func _hold(id: String) -> void:
	U.destroy(human.nextWall)
	human.nextWall = Catalog.spawn(id, human.wallSpawn)


func _all_free(tiles: Array) -> bool:
	for t in tiles:
		if not map.tiles[t.x][t.y].is_free():
			return false
	return true


## Every tile holds a wall block.
func _all_blocks(tiles: Array) -> bool:
	for t in tiles:
		var s = map.tiles[t.x][t.y].structure
		if not U.alive(s) or Catalog.def_of(s).id != "wall":
			return false
	return true


## Cells from [x, z] pairs.
func _v(pairs: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in pairs:
		out.append(Vector2i(p[0], p[1]))
	return out


## Replaces the randomly drawn next building (fixture for a specific piece).
func _offer_building(id: String) -> void:
	U.destroy(human.nextBuilding)
	human.nextBuilding = Catalog.spawn(id, human.buildingSpawn)


## A one-tile pocket on the east side of the start ring, so a gun fits inside the walls without
## touching the castle.
func _pocket() -> void:
	var b := base_xz()
	human.build_wall(map.tiles[b.x + 3][b.y - 2], Catalog.spawn("wall"))
	human.build_wall(map.tiles[b.x + 4][b.y - 2], Catalog.spawn("wall"))
	for z in range(b.y - 1, b.y + 2):
		human.build_wall(map.tiles[b.x + 4][z], Catalog.spawn("wall"))
	human.build_wall(map.tiles[b.x + 4][b.y + 2], Catalog.spawn("wall"))
	human.build_wall(map.tiles[b.x + 3][b.y + 2], Catalog.spawn("wall"))
