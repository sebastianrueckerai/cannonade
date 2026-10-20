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


## Moves the mouse over the walkway's centre of the wall block on tile xz.
func point_at_wall(xz: Vector2i) -> void:
	await point_at(map.tiles[xz.x][xz.y].go.global_position + Vector3(0, 0.85, 0))


## Turns the mouse wheel n notches toward the world position p, away from it for n < 0.
func zoom(n: int, p: Vector3) -> void:
	for i in absi(n):
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_WHEEL_UP if n > 0 else MOUSE_BUTTON_WHEEL_DOWN
			ev.position = main.camera.unproject_position(p)
			ev.pressed = pressed
			Input.parse_input_event(ev)
		await frames(1)


func press_key(key: Key) -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = key
		k.pressed = pressed
		Input.parse_input_event(k)
		await frames(1)


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
				if human.in_reach(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable():
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
					if not (human.in_reach(t.idxX, t.idxZ) and not U.alive(t.structure) and t.buildable()):
						free = false
				if free:
					return Vector2i(x, z)
	return Vector2i(-1, -1)


func _run() -> void:
	await frames(3)
	game.timeLeftInRound = 1e6  # the script sets the phase it needs
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
	check(_shade(piece) < 1.0, "the ghost is darker than the ring's blocks")
	await press("build_wall")
	check(_all_blocks(want), "left click stamps a wall block on every tile the ghost covered")
	check(want.all(func(t): return _shade(map.tiles[t.x][t.y].structure) == 1.0),
			"the placed blocks wear the ring's colour, not the ghost's tint")
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
	var far := Vector2i(map.sizeX / 2, map.sizeZ / 2 - 1)
	await point_at_tile(far)
	await press("build_wall")
	check(not U.alive(map.tiles[far.x][far.y].structure), "no building far away from own walls")

	# clicking outside the map discards the piece; a new one comes after it flew away
	var dropped = human.nextWall
	await point_at(map.tile_position(-6, -6))
	await press("build_wall")
	await seconds(3.3)
	check(not U.alive(dropped) and U.alive(human.nextWall), "click outside the map discards the piece")

	# stacking: a piece stacks when every cell lies on an own wall, a storey ghost on each cell first; a piece
	# with cells off the walls does not
	var target = map.tiles[w.x][w.y]
	var storey: String = Catalog.wall_look(human) + "_upper"
	_hold("wall_3")
	await point_at_wall(w)
	await press("build_wall")
	check(not U.alive(target.wallStacked), "a piece with cells off the walls does not stack")
	_hold("wall_3")
	U.comp(human.nextWall, "BuildingBlock").rotate_clockwise()  # upright, on the upright three placed above
	var three: Array = human.nextWall.get_children().filter(func(n): return n is Node3D)
	await point_at_wall(w)
	check(three.all(func(n): return n.get_node("Art").get_meta("art_id") == storey and _shade(n) < 1.0 and _tint(n) == Color.WHITE),
			"the upright three shows a darkened storey on each cell (%s)" % [three.map(func(n): return n.get_node("Art").get_meta("art_id"))])
	var spots: Array = three.map(func(n): return n.get_node("Art").global_transform)
	await point_at_tile(w + Vector2i(-2, 0))
	check(three.all(func(n): return n.basis.is_equal_approx(Basis()) and n.get_node("Art").get_meta("art_id") == Catalog.wall_look(human)),
			"off the walls the turned three is blocks again, turned with the piece")
	await point_at_wall(w)
	await press("build_wall")
	var stacked: Array = want.map(func(k): return map.tiles[k.x][k.y].wallStacked)
	check(stacked.all(func(n): return U.alive(n) and Catalog.def_of(n).id == "wall"),
			"the upright three stacks a storey on each of its walls")
	check(range(3).all(func(i): return U.alive(stacked[i]) and stacked[i].get_node("Art").global_transform.is_equal_approx(spots[i])),
			"each storey stands where its ghost stood")

	# over own walls a piece that cannot stack shows its storeys red, and a click stacks nothing: a T on the ring's
	# south row with its stem on the castle
	_hold("wall_t")
	var tee: Array = human.nextWall.get_children().filter(func(n): return n is Node3D)
	var tee_at := Vector2i(b.x - 1, b.y - 2)
	await point_at_wall(tee_at)
	check(not human.canStackWall and human.nextWall.get_parent() == map.tiles[tee_at.x][tee_at.y].go
			and tee.all(func(n): return _tint(n) == human.NO_STACK), "a T with its stem on the castle shows red storeys")
	await press("build_wall")
	check(not U.alive(map.tiles[tee_at.x][tee_at.y].wallStacked), "a click on the red storeys stacks nothing")

	# a piece stacks wherever walls fill every tile under it, whichever pieces placed them: an S on two blocks of the
	# ring and a two-block piece south of it
	var below := [Vector2i(b.x + 1, b.y - 3), Vector2i(b.x + 2, b.y - 3)]
	check(_all_free(below), "the two tiles south of the ring's east half are free")
	for k in below:
		human.build_wall(map.tiles[k.x][k.y], Catalog.spawn("wall", null, human))
	_hold("wall_s")
	await point_at_wall(below[0])
	check(human.canStackWall, "the S fits on blocks of the ring and of another piece")
	await press("build_wall")
	check(([Vector2i(b.x, b.y - 2), Vector2i(b.x + 1, b.y - 2)] + below).all(func(k): return U.alive(map.tiles[k.x][k.y].wallStacked)),
			"the S stacks a storey on each of the four")
	for k in below:
		map.tiles[k.x][k.y].un_build()  # they would reach the column the gun checks below walk

	# nobody builds on ground another player's closed ring holds, reach or not: a 1 x 1 ring of the enemy's two
	# tiles north of the castle's ring
	var hole := Vector2i(b.x - 2, b.y + 4)
	var enemy_ring: Array = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				enemy_ring.append(hole + Vector2i(dx, dz))
	check(_all_free(enemy_ring + [hole]), "the 3 x 3 north of the ring's west corner is free")
	game.players[1]._wall_in(hole.x, hole.y, hole.x, hole.y)
	var hole_tile = map.tiles[hole.x][hole.y]
	check(map.is_tile_enclosed(hole.x, hole.y) and hole_tile.ringOwner == game.players[1] and human.in_reach(hole.x, hole.y),
			"the enemy's ring closes a tile in the player's reach")
	var hole_far: Vector3 = map.tile_position(hole.x, hole.y, 0.1) + Vector3(0, 0, -0.35)  # the enemy's wall hides the near half
	_hold("wall_1")
	await point_at(hole_far)
	check(human.buildableTileSelected == hole_tile, "the cursor picks the tile inside the enemy's ring")
	await press("build_wall")
	check(not U.alive(hole_tile.structure), "a block inside the enemy's ring is refused")
	_offer_building("cannon")
	await point_at(hole_far)
	await press("build_building")
	check(not U.alive(hole_tile.structure), "a gun inside the enemy's ring is refused")
	for k in enemy_ring:
		map.tiles[k.x][k.y].un_build()
	_hold("wall_1")
	await point_at(hole_far)
	await press("build_wall")
	check(U.alive(hole_tile.structure), "with the enemy's ring gone the block places")
	hole_tile.un_build()  # it would reach the column the reach checks below walk

	# zoomed in, the cursor on a wall's walkway picks that wall, not the ground behind it, and the held block shows
	# there the storey it stacks as. The east side's middle has own walls north and south of it; the cursor sits on
	# the walkway's far half, whose ground point lies on the tile behind.
	var e := Vector2i(b.x + 2, b.y)
	var east = map.tiles[e.x][e.y]
	await zoom(12, map.tile_position(e.x, e.y))
	check(main.camera.zoom_level() < 0.5, "the wheel zoomed in (%.2f)" % main.camera.zoom_level())
	_hold("wall_1")
	var cell: Node3D = human.nextWall.get_child(0)
	await point_at(east.go.global_position + Vector3(0, 0.85, -0.3))
	check(human.buildableTileSelected == east, "the cursor on a wall's walkway picks that wall (got %d, %d)"
			% [human.buildableTileSelected.idxX, human.buildableTileSelected.idxZ])
	check(cell.get_node("Art").get_meta("art_id") == storey and _shade(cell) < 1.0,
			"the held block shows the darkened storey (%s, shade %s)" % [cell.get_node("Art").get_meta("art_id"), _shade(cell)])
	var ghost_at: Transform3D = cell.get_node("Art").global_transform
	await press("build_wall")
	check(U.alive(east.wallStacked) and not U.alive(map.tiles[e.x][e.y + 1].wallStacked),
			"the block stacks on the wall under the cursor, not on the one behind it")
	check(U.alive(east.wallStacked) and east.wallStacked.get_node("Art").global_transform.is_equal_approx(ghost_at),
			"the storey stands where its ghost stood")
	_hold("wall_1")
	cell = human.nextWall.get_child(0)
	await point_at(map.tiles[e.x][e.y - 1].go.global_position + Vector3(0, 0.85, 0))
	check(cell.get_node("Art").get_meta("art_id") == storey, "the next wall south shows the storey too")
	await point_at_tile(b)  # the castle takes no block: the piece goes back to the hand
	check(human.nextWall.get_parent() == human.hand and cell.get_node("Art").get_meta("art_id") == Catalog.wall_look(human),
			"back in the hand the held block is a block again")
	await point_at(map.tiles[e.x][e.y - 1].go.global_position + Vector3(0, 0.85, 0))
	await point_at_tile(e + Vector2i(1, 0))
	check(cell.get_node("Art").get_meta("art_id") == Catalog.wall_look(human),
			"off the wall the held block is a block again (%s)" % cell.get_node("Art").get_meta("art_id"))
	await zoom(-12, map.tile_position(e.x, e.y))

	# reach: a placement needs one tile within two of an own wall or castle. Walls walk the castle's column
	# north from the ring's top row, guns south from its bottom row; d counts tiles out from the ring.
	var top := b.y + 2
	var north: Array = []
	for d in range(1, 7):
		north.append(Vector2i(b.x, top + d))
	check(_all_free(north), "the column north of the ring is free")
	_hold("wall_1")
	await point_at_tile(Vector2i(b.x, top + 3))
	await press("build_wall")
	check(not U.alive(map.tiles[b.x][top + 3].structure), "a block three tiles from every own wall is refused")
	_hold("wall_3")
	U.comp(human.nextWall, "BuildingBlock").rotate_clockwise()  # upright: d = 4, 3, 2
	await point_at_tile(Vector2i(b.x, top + 3))
	await press("build_wall")
	check(_all_blocks([Vector2i(b.x, top + 2), Vector2i(b.x, top + 3), Vector2i(b.x, top + 4)]),
			"an upright three places with only its bottom tile in reach")
	_hold("wall_1")
	await point_at_tile(Vector2i(b.x, top + 6))
	await press("build_wall")
	check(_all_blocks([Vector2i(b.x, top + 6)]), "new blocks extend reach: a block two past them places")
	var bottom := b.y - 2
	var south: Array = []
	for d in range(1, 5):
		south.append(Vector2i(b.x, bottom - d))
	check(_all_free(south), "the column south of the ring is free")
	_offer_building("cannon")
	await point_at_tile(Vector2i(b.x, bottom - 3))
	await press("build_building")
	check(not U.alive(map.tiles[b.x][bottom - 3].structure), "a gun three tiles from every own wall is refused")
	await point_at_tile(Vector2i(b.x, bottom - 2))
	await press("build_building")
	check(U.alive(map.tiles[b.x][bottom - 2].structure), "a gun two tiles out places")
	_hold("wall_1")
	await point_at_tile(Vector2i(b.x, bottom - 4))
	await press("build_wall")
	check(not U.alive(map.tiles[b.x][bottom - 4].structure), "a gun anchors no reach: a block two past it is refused")
	map.tiles[b.x][bottom - 2].un_build()  # it would count as an active gun below

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
	game.timeLeftInRound = -1.5  # the cannon phase ends: the check, then the battle
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

	# with every own wall gone the castle alone anchors reach; a ruined castle anchors nothing
	var own = null
	for c in map.castles:
		if c.owner() == human:
			own = c
	for t in human.wallTiles.duplicate():
		t.un_build()
	check(human.wallTiles.is_empty(), "every own wall is gone")
	check(human.in_reach(b.x + 3, b.y) and not human.in_reach(b.x + 4, b.y),
			"the castle alone reaches two tiles past its edge, not three")
	own.become_ruin()
	check(not human.in_reach(b.x + 2, b.y), "a ruined castle anchors nothing")

	# testing keys: L loses the game to the other player, a key after the end does nothing, K wins a fresh game;
	# the end screen fits the window
	await press_key(KEY_L)
	var overlay := main.get_node_or_null("GameOver")
	check(not game.started and overlay != null and _has_label(overlay, "DEFEAT"), "L loses the game")
	await _check_end_screen(overlay)
	await press_key(KEY_K)
	check(not _has_label(main, "VICTORY"), "K after the end changes nothing")
	main.free()
	main = Main.new()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main.game.players[1].nextAction = 1e9
	await press_key(KEY_K)
	overlay = main.get_node_or_null("GameOver")
	check(not main.game.started and overlay != null and _has_label(overlay, "VICTORY"), "K wins the game")
	await _check_end_screen(overlay)


## The end screen fits the window: its art covers it exactly and Retry and Menu lie inside it.
func _check_end_screen(overlay: Node) -> void:
	await frames(2)
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var art: Array = overlay.find_children("*", "TextureRect", true, false)
	check(art.size() == 1 and art[0].get_global_rect().is_equal_approx(view),
			"the end art covers the window %s (%s)" % [view, art.map(func(a): return a.get_global_rect())])
	var buttons: Array = overlay.find_children("*", "Button", true, false)
	check(buttons.size() == 2 and buttons.all(func(bt): return view.encloses(bt.get_global_rect())),
			"Retry and Menu lie inside the window (%s)" % [buttons.map(func(bt): return bt.get_global_rect())])


func _has_label(node: Node, text: String) -> bool:
	return node.find_children("*", "Label", true, false).any(func(l): return l.text == text)


## The wall phase with a specific piece in hand.
func _hold(id: String) -> void:
	game.phase = game.Phase.WALLS
	U.destroy(human.nextBuilding)
	U.destroy(human.nextWall)
	human.nextWall = Catalog.spawn(id, human.hand, human)


## The wall shader's shade of the first block under node, 1 placed, under 1 as the ghost.
func _shade(node: Node) -> float:
	var mi := node.find_child("wall", true, false) as MeshInstance3D
	return mi.material_override.get_shader_parameter("shade") if mi != null else -1.0


## The wall shader's tint of the first block under node: white, or the red of a piece that cannot stack.
func _tint(node: Node) -> Color:
	var mi := node.find_child("wall", true, false) as MeshInstance3D
	return mi.material_override.get_shader_parameter("tint") if mi != null else Color.BLACK


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


## The cannon phase with a specific building in hand.
func _offer_building(id: String) -> void:
	game.phase = game.Phase.GUNS
	U.destroy(human.nextWall)
	U.destroy(human.nextBuilding)
	human.nextBuilding = Catalog.spawn(id, human.hand)


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
