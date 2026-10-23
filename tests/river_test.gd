extends Node
## Rivers (I104): every two-player board draws a river that cuts the same castles off from both start
## castles over land, one or two of each player's own half, with the same count left on each start
## castle's land; every river tile keeps a free tile between it and any castle, no land reaches across
## within the build reach, every river runs to the border, no land region lies dead, and both layouts
## (one river through, one a side in a corner) appear. On the board a held piece previews and places
## over the river as bridges, which carry the reach to the far bank, keep the river's colour and take
## no storey; a ring across the river never closes while the same ring on the far bank does, a shell
## frees the river again, and no gun stands on it.
##   godot --headless --fixed-fps 30 res://tests/river_test.tscn

const Main = preload("res://scripts/Main.gd")
const SEEDS := 12
const INF := 1 << 30
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var main: Node
var game
var map
var human
var failures: Array = []
var ran := 0
var mouse := Vector2.ZERO


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	await get_tree().process_frame
	var bridge_seed := _sweep()
	await _bridges(bridge_seed)
	var ok: bool = failures.is_empty() and ran >= 24
	print("RIVER TEST PASSED" if ok else "RIVER TEST FAILED: %s" % [failures])
	get_tree().quit(0 if ok else 1)


func check(cond: bool, msg: String) -> void:
	ran += 1
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func centre(c) -> Vector2i:
	return map.tile_index_at(c.go.global_position)


func _river() -> Dictionary:
	var water := {}
	for x in map.sizeX:
		for z in map.sizeZ:
			if map.tiles[x][z].river:
				water[Vector2i(x, z)] = true
	return water


## Land region per land tile, 4-connected round the water.
func _regions(water: Dictionary) -> Dictionary:
	var region := {}
	var n := 0
	for x in map.sizeX:
		for z in map.sizeZ:
			var p := Vector2i(x, z)
			if region.has(p) or water.has(p):
				continue
			region[p] = n
			var queue: Array[Vector2i] = [p]
			var head := 0
			while head < queue.size():
				var c: Vector2i = queue[head]
				head += 1
				for d in DIRS4:
					var q: Vector2i = c + d
					if q.x >= 0 and q.y >= 0 and q.x < map.sizeX and q.y < map.sizeZ and not region.has(q) \
							and not water.has(q):
						region[q] = n
						queue.append(q)
			n += 1
	return region


## The river's bodies, 8-connected.
func _bodies(water: Dictionary) -> Array:
	var seen := {}
	var out: Array = []
	for p in water:
		if seen.has(p):
			continue
		seen[p] = true
		var body: Array[Vector2i] = [p]
		var head := 0
		while head < body.size():
			var c: Vector2i = body[head]
			head += 1
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var q := c + Vector2i(dx, dz)
					if water.has(q) and not seen.has(q):
						seen[q] = true
						body.append(q)
		out.append(body)
	return out


## Builds each sweep board in place (no decorations: the whole map goes up inside add_child) and
## measures it; returns the first seed whose river comes into the human's reach at the start.
func _sweep() -> int:
	var rivers := 0
	var fair := 0
	var kinds := {}
	var nearest := 1 << 20
	var jumps := 0
	var dead := 0
	var landlocked := 0
	var wet := 0
	var built := 0
	var bridge_seed := -1
	var far_seed := -1
	var far_d := -1
	for s in range(1, SEEDS + 1):
		Main.requested_mode = "versus"
		Main.requested_args = {"seed": str(s), "no-decorations": "true"}
		main = Main.new()
		get_tree().root.add_child(main)
		game = main.game
		map = game.map
		var water := _river()
		if not water.is_empty():
			rivers += 1
		var centres: Array = []
		for c in map.castles:
			centres.append(centre(c))
		for p: Vector2i in water:
			var t = map.tiles[p.x][p.y]
			if not t.water:
				wet += 1
			if U.alive(t.structure):
				built += 1
			for q: Vector2i in centres:
				nearest = mini(nearest, maxi(absi(p.x - q.x), absi(p.y - q.y)))
			if bridge_seed < 0 and game.players[0].in_reach(p.x, p.y):
				bridge_seed = s
		# the bridge board the walk makes: the river farthest from the human's start walls, so the
		# line must reach it before any piece goes over the water
		var human_walls: Array = game.players[0].wallTiles
		var nearest_d: int = INF
		for p: Vector2i in water:
			for w in human_walls:
				nearest_d = mini(nearest_d, maxi(absi(p.x - w.idxX), absi(p.y - w.idxZ)))
		if nearest_d > far_d:
			far_d = nearest_d
			far_seed = s
		var region := _regions(water)
		for p: Vector2i in region:
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var q := p + Vector2i(dx, dz)
					if region.has(q) and region[q] != region[p]:
						jumps += 1
		var held := {}
		var home := [-1, -1]
		for c in map.castles:
			var r: int = region[centre(c)]
			held[r] = true
			for i in 2:
				if c.owner() == game.players[i]:
					home[i] = r
		var ids := {}
		for p in region:
			ids[region[p]] = true
		dead += ids.size() - held.size()
		var cut := [0, 0]
		var kept := [0, 0]
		for c in map.castles:
			var q := centre(c)
			for i in 2:
				if region[q] == home[i]:
					kept[i] += 1
				elif (q.y < map.sizeZ / 2) == (i == 0):
					cut[i] += 1
		if cut[0] == cut[1] and cut[0] >= 1 and cut[0] <= 2 and kept[0] == kept[1]:
			fair += 1
		print("seed %d: %d river tiles, cut %s, kept %s" % [s, water.size(), cut, kept])
		var bodies := _bodies(water)
		kinds[bodies.size()] = kinds.get(bodies.size(), 0) + 1
		for b: Array in bodies:
			if not b.any(func(p): return p.x == 0 or p.y == 0 or p.x == map.sizeX - 1 or p.y == map.sizeZ - 1):
				landlocked += 1
		main.free()
	check(rivers == SEEDS, "every board of the sweep draws a river (%d of %d)" % [rivers, SEEDS])
	check(fair == SEEDS, "every river cuts 1-2 own castles off each start castle alike and leaves both the same land (%d of %d)"
			% [fair, SEEDS])
	check(nearest >= 3, "a free tile parts every castle from the river (nearest river tile %d from a centre)" % nearest)
	check(jumps == 0, "no land lies within the build reach of land across the river (%d pairs)" % jumps)
	check(dead == 0, "every land region holds a castle (%d dead)" % dead)
	check(landlocked == 0, "every river runs to the border, so the flood always reaches it (%d landlocked)" % landlocked)
	check(kinds.has(1) and kinds.has(2), "both layouts appear, one river through and one a side (%s)" % [kinds])
	check(wet == 0 and built == 0, "river tiles are water and stand bare after the build (%d dry, %d built)" % [wet, built])
	check(bridge_seed > 0, "a sweep board brings the river into the human's start reach")
	check(far_seed > 0, "a sweep board holds the river far from the human's walls")
	return far_seed


## Every legal placement of every wall def and rotation that covers a river cell: first the ones with a
## river cell within 2 of the far bank, then those over the most river cells.
func _river_spots(across) -> Array:
	var spots: Array = []
	for def in Catalog.drawable(BuildingDef.Category.WALL):
		U.destroy(human.nextWall)
		human.nextWall = Catalog.spawn(def, human.hand)
		var bb = U.comp(human.nextWall, "BuildingBlock")
		for rot in 4:
			for x in map.sizeX:
				for z in map.sizeZ:
					var t = map.tiles[x][z]
					if not human.can_place_piece(t):
						continue
					var under: Array = human.piece_tiles(t)
					var wet: int = under.filter(func(c): return c.river).size()
					if wet > 0:
						spots.append([wet + (100 if under.any(across) else 0), def, rot, Vector2i(x, z)])
			bb.rotate_clockwise()
	return spots


## One legal placement nearest the river, placed through the real cursor: a wall may only stand edge on
## the walls before it (I105), so the bridge starts as a line walked tile by tile to the bank.
func _step_to_river() -> bool:
	var river := _river()
	var dist := {}
	for x in map.sizeX:
		for z in map.sizeZ:
			var d: int = INF
			for w: Vector2i in river:
				d = mini(d, maxi(absi(x - w.x), absi(z - w.y)))
			dist[Vector2i(x, z)] = d
	var best: Array = []
	var best_d: int = INF
	for def in Catalog.drawable(BuildingDef.Category.WALL):
		U.destroy(human.nextWall)
		human.nextWall = Catalog.spawn(def, human.hand)
		var bb = U.comp(human.nextWall, "BuildingBlock")
		for rot in 4:
			for x in map.sizeX:
				for z in map.sizeZ:
					var t = map.tiles[x][z]
					if not human.can_place_piece(t):
						continue
					var d: int = INF
					for c: Vector2i in bb.cells:
						d = mini(d, dist[Vector2i(x + c.x, z + c.y)])
					if d < best_d:
						best_d = d
						best = [def, rot, Vector2i(x, z)]
			bb.rotate_clockwise()
	if best.is_empty():
		return false
	U.destroy(human.nextWall)
	human.nextWall = Catalog.spawn(best[0], human.hand)
	var bb = U.comp(human.nextWall, "BuildingBlock")
	for i in best[1]:
		bb.rotate_clockwise()
	await _hover(best[2])
	if human.buildableTileSelected != map.tiles[best[2].x][best[2].y] or not human.canPlaceWall:
		return false
	await _click()
	while U.time < human.secondsLastWall + human.secondsBetweenWalls:
		await frames(1)
	return true


func _hover(xz: Vector2i) -> void:
	mouse = main.camera.unproject_position(map.tile_position(xz.x, xz.y, 0.1))
	var ev := InputEventMouseMotion.new()
	ev.position = mouse
	Input.parse_input_event(ev)
	await frames(2)


func _click() -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = mouse
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(1)
	await frames(1)


func _art(node: Node) -> String:
	var art: Node = node.get_node_or_null("Art")
	return art.get_meta("art_id", "") if art != null else ""


func _bridges(the_seed: int) -> void:
	if the_seed < 0:
		return
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": str(the_seed), "ready": "0", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await frames(1)
	get_tree().current_scene = main
	game = main.game
	map = game.map
	human = game.players[0]
	game.players[1].dormant = true
	var water := _river()
	var region := _regions(water)
	var home: int = region[centre(map.castles.filter(func(c): return c.owner() == human)[0])]
	var far_reached := func() -> bool:
		for p: Vector2i in region:
			if region[p] != home and human.in_reach(p.x, p.y):
				return true
		return false
	check(not far_reached.call(), "before a bridge the human's reach ends at the river")
	# the dealt piece is time-seeded, so the check picks its own, any wall def at any rotation,
	# deterministic like preview_test's: first the placements with a river cell within 2 of the far
	# bank, then those over the most river cells
	var across := func(t) -> bool:
		if not t.river:
			return false
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var q := Vector2i(t.idxX + dx, t.idxZ + dz)
				if region.has(q) and region[q] != home:
					return true
		return false
	var spots: Array = _river_spots(across)
	var steps := 0
	while spots.is_empty() and steps < 40:
		steps += 1
		if not await _step_to_river():
			break
		spots = _river_spots(across)
	check(not spots.is_empty(), "the walls walk to the bank and a piece goes down over the river edge on them (%d placements)" % steps)
	if spots.is_empty():
		return
	spots.sort_custom(func(a, b): return a[0] > b[0])
	var spot: Array = []
	for s in spots:
		U.destroy(human.nextWall)
		human.nextWall = Catalog.spawn(s[1], human.hand)
		for i in s[2]:
			U.comp(human.nextWall, "BuildingBlock").rotate_clockwise()
		await _hover(s[3])
		if human.buildableTileSelected == map.tiles[s[3].x][s[3].y]:
			spot = s
			break
	check(not spot.is_empty(), "the cursor picks an anchor over the river")
	if spot.is_empty():
		return
	var bb = U.comp(human.nextWall, "BuildingBlock")
	var cells: Array = []
	for c: Vector2i in bb.cells:
		cells.append(map.tiles[spot[3].x + c.x][spot[3].y + c.y])
	var nodes: Array = human.nextWall.get_children().filter(func(n): return n is Node3D)
	var ghost_ok := true
	for i in cells.size():
		ghost_ok = ghost_ok and _art(nodes[i]) == ("wall_bridge" if cells[i].river else Catalog.wall_look(human))
	check(ghost_ok, "the ghost wears the bridge over the river and the owner's look on land")
	check(human.canPlaceWall, "the piece over the river can be placed")
	while U.time < human.secondsLastWall + human.secondsBetweenWalls:  # the placement cooldown
		await frames(1)
	await _click()
	var bridges: Array = cells.filter(func(t): return t.river)
	var placed := true
	for t in cells:
		placed = placed and t.isWall and U.alive(t.structure) \
				and _art(t.structure) == ("wall_bridge" if t.river else Catalog.wall_look(human))
	check(placed, "a click stamps bridges on the river cells and the owner's blocks on land")
	check(bridges.all(func(t): return t.water and t.river and U.get_color(t.model()).is_equal_approx(t.openColor)),
			"the river under a bridge stays water in the river's colour")
	check(far_reached.call(), "the bridge carries the reach to the far bank, so the wall goes on across")
	U.destroy(human.nextWall)
	human.nextWall = Catalog.spawn(Catalog.get_def("wall_1"), human.hand)
	var own_land: Array = human.wallTiles.filter(func(t): return not t.river and not U.alive(t.wallStacked))
	check(not own_land.is_empty() and human.can_stack_on(own_land[0]), "a storey stacks on an own wall on land")
	check(not human.can_stack_on(bridges[0]), "a bridge takes no storey")
	_rings(water, region, home)
	var b = bridges[0]
	b.damage_building_place(1000.0)
	await frames(2)
	check(not U.alive(b.structure) and b.river and b.water and b.wall_free(), "a shell frees the river under a bridge")
	check(not b.buildable() and not b.is_free(), "no gun stands on the river")
	main.free()


## A ring round river ground never closes, the flood runs under its bridges; the same build on the
## far bank's land closes a room there.
func _rings(water: Dictionary, region: Dictionary, home: int) -> void:
	var spots := [[], []]
	for x in range(3, map.sizeX - 3):
		for z in range(3, map.sizeZ - 3):
			var c := Vector2i(x, z)
			var r := 3 if water.has(c) else 2
			var ok := true
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					var t = map.tiles[x + dx][z + dz]
					ok = ok and not U.alive(t.structure) and t.wall_free() and t.ringOwner == null
					if r == 2 and (water.has(Vector2i(x + dx, z + dz)) or region[Vector2i(x + dx, z + dz)] == home):
						ok = false
			if ok:
				spots[r - 2].append(c)
	# the rings stamp walls round their centre (Chebyshev 2 for the room, 3 for the across ring),
	# so a pair closer than 6 puts one ring's walls inside the other's ground
	var across := Vector2i(-1, -1)
	var room := Vector2i(-1, -1)
	for a: Vector2i in spots[1]:
		for m: Vector2i in spots[0]:
			if maxi(absi(a.x - m.x), absi(a.y - m.y)) >= 6:
				across = a
				room = m
				break
		if across.x >= 0:
			break
	check(across.x >= 0 and room.x >= 0, "free spots for a ring across the river and a room on the far bank")
	if across.x < 0 or room.x < 0:
		return
	human._wall_in(across.x - 2, across.y - 2, across.x + 2, across.y + 2)
	var open := true
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			open = open and not map.is_tile_enclosed(across.x + dx, across.y + dz)
	check(open, "a ring whose walls bridge the river closes nothing: the river runs under it")
	human._wall_in(room.x - 1, room.y - 1, room.x + 1, room.y + 1)
	var closed := true
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			closed = closed and map.is_tile_enclosed(room.x + dx, room.y + dz) \
					and map.tiles[room.x + dx][room.y + dz].ringOwner == human
	check(closed, "the same build on the far bank's land closes a room there")
