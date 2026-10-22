extends Node
## Terrain on the battlefield (I90-I95): both halves hold the same blocked tiles, every
## feature is a clumped shape inside 7x7 whose holes stay buildable ground, a mass five
## tiles across or more is never a filled rectangle, neighbours gather in clusters, the
## count is a knob (--terrain=N), castle rings keep their reach round every feature, a destructible
## feature falls to its shells and frees its ground, an indestructible one absorbs every
## hit, placement refuses the tiles, and the AI shoots the crates that block its own way
## but never the ones that would open the enemy's.
##   godot --headless --fixed-fps 30 res://tests/terrain_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var me
var enemy
var failures: Array = []
var ran := 0


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
	me = game.players[0]
	enemy = game.players[1]
	enemy.dormant = true
	await _versus_board()
	await _ai_board()
	var ok: bool = failures.is_empty() and ran >= 18
	print("TERRAIN TEST PASSED" if ok else "TERRAIN TEST FAILED: %s" % [failures])
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


## Builds a game in place once frames are flowing: with no decorations the whole map goes
## up inside add_child, so the board is readable the line after (each sweep game is freed
## before a frame passes, so no AI coroutine starts either).
func _start(mode: String, seed := 4, terrain := -1) -> void:
	Main.requested_mode = mode
	Main.requested_args = {"seed": str(seed), "no-decorations": "true"}
	if terrain >= 0:
		Main.requested_args["terrain"] = str(terrain)
	main = Main.new()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	game = main.game
	map = game.map
	me = game.players[0]
	enemy = game.players[1]


func _blocked(x: int, z: int) -> bool:
	var t = map.tiles[x][z]
	return U.alive(t.structure) and U.comp(t.structure, "Terrain") != null


func _shell_tiles(centre_cell: Vector2i) -> Array:
	var out: Array = []
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var p := Vector2i(centre_cell.x + dx, centre_cell.y + dz)
			if p.x >= 0 and p.y >= 0 and p.x < map.sizeX and p.y < map.sizeZ:
				out.append(p)
	return out


## The encirclement guarantee, written here on its own: from the build ring of the first
## castle, ground no terrain and no water blocks reaches a tile of every other castle's ring.
func _rings_reach() -> bool:
	var centres: Array = []
	for c in map.castles:
		if U.alive(c.go) and not c.is_ruin():
			centres.append(centre(c))
	if centres.size() < 2:
		return true
	var seen := {}
	var queue: Array = []
	for p in _shell_tiles(centres[0]):
		seen[p] = true
		queue.append(p)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + v
			if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ or seen.has(n):
				continue
			var t = map.tiles[n.x][n.y]
			if t.water or _blocked(n.x, n.y):
				continue
			seen[n] = true
			queue.append(n)
	for i in range(1, centres.size()):
		var reached := false
		for p in _shell_tiles(centres[i]):
			if seen.has(p):
				reached = true
		if not reached:
			return false
	return true


## The generated versus board (seed 4, the enemy idle): the layout rules and the damage.
## The board is already up (built deferred in _ready); later boards use _start.
func _versus_board() -> void:
	await frames(3)

	var centres: Array = map.castles.filter(func(c): return U.alive(c.go)).map(func(c): return centre(c))
	check(map.terrain_features.size() > 0, "the versus map grows terrain features (%d)" % [map.terrain_features.size()])
	var broken := 0
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		for t in terr.tiles:
			if t.structure != go or map.get_mini(t.idxX, t.idxZ) != 255 or t.water:
				broken += 1
			for q in centres:
				if max(absi(t.idxX - q.x), absi(t.idxZ - q.y)) < 3:
					broken += 1
	check(broken == 0,
			"every feature tile is its structure, mini 255, dry, and Chebyshev 3 off every castle centre")

	var oversize := 0
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		for half in [0, 1]:
			var cells: Array = terr.tiles.filter(
					func(t): return (0 if t.idxZ < map.sizeZ / 2 else 1) == half)
			if cells.is_empty():
				continue
			var lo := Vector2i(map.sizeX, map.sizeZ)
			var hi := Vector2i.ZERO
			for t in cells:
				lo = lo.min(Vector2i(t.idxX, t.idxZ))
				hi = hi.max(Vector2i(t.idxX, t.idxZ))
			if hi.x - lo.x > 6 or hi.y - lo.y > 6:
				oversize += 1
	check(oversize == 0, "every feature fits a 7x7 box on each half (%d oversize)" % [oversize])

	var mismatch := 0
	for x in map.sizeX:
		for z in map.sizeZ:
			if _blocked(x, z) != _blocked(x, map.sizeZ - 1 - z):
				mismatch += 1
	check(mismatch == 0, "the halves mirror exactly (%d mismatched tiles)" % [mismatch])
	check(_rings_reach(), "every castle's build ring reaches every other's round the terrain")

	# a clump's holes stay ground (I93): a horseshoe claimed on open tiles leaves its mouth
	# buildable while its own cells refuse a wall
	var mouth := Vector2i(10, 20)
	var u_cells: Array = []
	for x in range(mouth.x - 2, mouth.x + 3):
		u_cells.append(Vector2i(x, mouth.y - 1))
	u_cells.append(Vector2i(mouth.x - 2, mouth.y))
	u_cells.append(Vector2i(mouth.x + 2, mouth.y))
	var fits_u := true
	for c in u_cells:
		fits_u = fits_u and map.tiles[c.x][c.y].is_free() and not map.tiles[c.x][c.y].water
	if fits_u:
		var u_go: Node3D = game._terrain_go("crate", u_cells)
		map.claim_terrain(u_go, u_cells)
		var hole_ok: Node3D = me.place(Catalog.get_def("wall"), mouth.x, mouth.y)
		var on_block: Node3D = me.place(Catalog.get_def("wall"), mouth.x - 2, mouth.y - 1)
		check(hole_ok != null and on_block == null,
				"a wall places in a clump's mouth, never on its cells")
		if hole_ok != null:
			map.tiles[mouth.x][mouth.y].un_build(true)
		U.comp(u_go, "Terrain").die(Vector3.INF, 0.0)
	else:
		check(false, "open ground for the horseshoe exists at the scripted spot")

	var victim = null
	for go in map.terrain_features:
		var terr = U.comp(go, "Terrain")
		if terr != null and terr.destructible and (victim == null or terr.tiles.size() < victim.tiles.size()):
			victim = terr
	check(victim != null, "a destructible feature stands on the map")
	if victim != null:
		var first = victim.tiles[0]
		check(is_equal_approx(victim.health, 10.0 * victim.tiles.size()),
				"a feature holds 10 health a tile (%d tiles, %s hp)" % [victim.tiles.size(), victim.health])
		check(not me.can_place(Catalog.get_def("wall"), first.idxX, first.idxZ)
				and me.place(Catalog.get_def("wall"), first.idxX, first.idxZ) == null,
				"no wall can be placed on a terrain tile")
		for i in victim.tiles.size() - 1:
			first.damage_building_place(10.0)
		check(map.terrain_features.has(victim.go), "the feature survives all but the last of its shells")
		var vtiles: Array = victim.tiles.duplicate()  # the dying go frees its Terrain with it
		var vgo: Node3D = victim.go
		first.damage_building_place(10.0)
		await frames(2)
		var freed := true
		var scarred := true
		for t in vtiles:
			if t.structure != null or not t.is_free() or map.get_mini(t.idxX, t.idxZ) != 0:
				freed = false
			if t.groundDamage != 10.0:
				scarred = false
		check(not map.terrain_features.has(vgo) and freed,
				"the killing shell frees every tile of the feature")
		check(scarred, "each freed tile carries the killing shell's scar")

	var mountain = null
	for go in map.terrain_features:
		var terr = U.comp(go, "Terrain")
		if terr != null and not terr.destructible:
			mountain = terr
			break
	check(mountain != null, "an indestructible feature stands on the map")
	if mountain != null:
		var stone = mountain.tiles[0]
		for i in 10:
			stone.damage_building_place(30.0)
		check(map.terrain_features.has(mountain.go) and stone.structure == mountain.go
				and is_equal_approx(mountain.health, 10.0 * mountain.tiles.size()),
				"an indestructible feature soaks every shell without a scratch")

	main.free()
	await _seed_sweep()


## The layout over more seeds and the four-player flips, each game read and freed before a
## frame passes, so no AI coroutine starts.
func _seed_sweep() -> void:
	var kinds := {true: 0, false: 0}
	var big := 0
	var solid_big := 0
	var pairs := 0
	for s in range(10, 18):
		_start("versus", s)
		var mismatch := 0
		for x in map.sizeX:
			for z in map.sizeZ:
				if _blocked(x, z) != _blocked(x, map.sizeZ - 1 - z):
					mismatch += 1
		for go in map.terrain_features:
			kinds[U.comp(go, "Terrain").destructible] += 1
		# I95: the bigger masses (five tiles across or more) are never filled rectangles, and
		# features gather: a pair touches when some two of their cells lie side by side
		var feats: Array = []
		for go in map.terrain_features:
			var terr := U.comp(go, "Terrain")
			var cells: Array = []
			for t in terr.tiles:
				cells.append(Vector2i(t.idxX, t.idxZ))
			feats.append(cells)
			var lo := Vector2i(map.sizeX, map.sizeZ)
			var hi := Vector2i.ZERO
			var n_half := 0
			for c: Vector2i in cells:
				if c.y < map.sizeZ / 2:
					lo = lo.min(c)
					hi = hi.max(c)
					n_half += 1
			if hi.x - lo.x >= 4 or hi.y - lo.y >= 4:
				big += 1
				if n_half == (hi.x - lo.x + 1) * (hi.y - lo.y + 1):
					solid_big += 1
		for i in feats.size():
			for j in range(i + 1, feats.size()):
				var gap := 99
				for a: Vector2i in feats[i]:
					for b: Vector2i in feats[j]:
						gap = mini(gap, maxi(absi(a.x - b.x), absi(a.y - b.y)))
				if gap <= 1:
					pairs += 1
		check(map.terrain_features.size() > 0 and mismatch == 0 and _rings_reach(),
				"seed %d: terrain grows, mirrors and keeps the castle rings connected (%d features)" % [s, map.terrain_features.size()])
		main.free()
	check(kinds[true] > 0 and kinds[false] > 0,
			"across the seeds both sorts appear (breakable %d, standing %d)" % [kinds[true], kinds[false]])
	check(big >= 4 and solid_big == 0,
			"bigger masses appear (%d of five tiles across or more) and none is a filled rectangle (%d solid)" % [big, solid_big])
	check(pairs >= 20, "features gather in clusters (%d touching pairs across the seeds)" % [pairs])
	_start("versus", 19, 3)
	check(map.terrain_features.size() == 3,
			"--terrain=3 draws three features a side (%d)" % [map.terrain_features.size()])
	main.free()
	_start("versus", 19, 0)
	check(map.terrain_features.is_empty(), "--terrain=0 clears the battlefield")
	main.free()
	_start("ai4", 5)
	var mismatch_z := 0
	var mismatch_x := 0
	for x in map.sizeX:
		for z in map.sizeZ:
			if _blocked(x, z) != _blocked(x, map.sizeZ - 1 - z):
				mismatch_z += 1
			if _blocked(x, z) != _blocked(map.sizeX - 1 - x, z):
				mismatch_x += 1
	check(map.terrain_features.size() > 0 and mismatch_z == 0 and mismatch_x == 0 and _rings_reach(),
			"four players: the quarters mirror under both flips and the rings stay connected")
	main.free()


## The AI's terrain tier (I92) on a bare board: a line of rocks across the middle cuts the
## AI from every castle it wants, and the same rocks lose their target once they would
## mainly open the enemy's way.
func _ai_board() -> void:
	_start("ai2")
	me.dormant = true
	enemy.dormant = true
	await frames(3)

	for go in map.terrain_features.duplicate():
		U.comp(go, "Terrain").die(Vector3(0.0, 0.0, 1.0), 0.0)
	for c in map.castles:
		if U.alive(c.go) and c.owner() == null:
			var cc := centre(c)
			for i in 12:
				map.tiles[cc.x][cc.y].damage_building_place(10.0)

	var zline := -1
	for z in range(map.sizeZ / 2 - 4, map.sizeZ / 2 + 4):
		var clear := true
		for x in map.sizeX:
			var t = map.tiles[x][z]
			if U.alive(t.structure) or t.water or t.disabled or U.alive(t.ship):
				clear = false
				break
		if clear:
			zline = z
			break
	check(zline >= 0, "a clear row crosses the middle of the bare board")
	if zline < 0:
		main.free()
		return

	var cells: Array = []
	for x in map.sizeX:
		cells.append(Vector2i(x, zline))
	var wall: Node3D = game._terrain_go("crate", cells)
	map.claim_terrain(wall, cells)
	check(not _rings_reach(), "a full-width rock line really cuts the rings (the detector sees it)")
	var gun_spot := Vector2i(-1, -1)
	for x in range(2, 14):
		for z in range(2, 14):
			if map.tiles[x][z].is_free():
				gun_spot = Vector2i(x, z)
				break
		if gun_spot.x >= 0:
			break
	me.build_building(map.tiles[gun_spot.x][gun_spot.y], Catalog.spawn("cannon"))
	me.refresh_active_cannons()

	# a neutral castle south of the line: clearing helps only the AI, so the rocks are shot
	var south := _place_neutral(zline + 6, map.sizeZ - 4)
	check(south.x >= 0, "a neutral castle stands south of the line")
	var targets: Array = me._terrain_targets(enemy)
	var on_line := true
	for t in targets:
		if t.idxZ != zline:
			on_line = false
	check(not targets.is_empty() and on_line,
			"the AI targets the rocks that cut it off from every castle it wants (%d tiles)" % [targets.size()])

	# the neutral north of the line instead: clearing would open the enemy's way, not the AI's
	for i in 12:
		map.tiles[south.x][south.y].damage_building_place(10.0)
	var north := _place_neutral(3, zline - 3)
	check(north.x >= 0, "a neutral castle stands north of the line")
	targets = me._terrain_targets(enemy)
	check(targets.is_empty(),
			"rocks that would mainly open the enemy's way are left standing (%d tiles)" % [targets.size()])

	# and with no castle left that the line does not already hide, clearing would only open
	# the enemy's way to the AI's castle: the rocks stand for that reason alone
	for i in 12:
		map.tiles[north.x][north.y].damage_building_place(10.0)
	targets = me._terrain_targets(enemy)
	check(targets.is_empty(),
			"rocks that cut both sides off equally are left standing too (%d tiles)" % [targets.size()])
	main.free()


## Places a neutral castle on a free 3x3 in z rows [lo, hi), x spread over the map.
## Returns the centre, or (-1, -1) when no spot is free.
func _place_neutral(lo: int, hi: int) -> Vector2i:
	for z in range(lo, hi):
		for x in [map.sizeX / 4, 3 * map.sizeX / 4, map.sizeX / 2 - 8, map.sizeX / 2 + 5, 3, map.sizeX - 6]:
			if x < 1 or x + 2 >= map.sizeX - 1 or z < 1 or z + 2 >= map.sizeZ - 1:
				continue
			if map.place_neutral(Catalog.get_def("castle"), x, z) != null:
				return Vector2i(x + 1, z + 1)
	return Vector2i(-1, -1)
